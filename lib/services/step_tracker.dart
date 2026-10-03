import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_estimator.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'hourly_step_service.dart';
import 'step_service.dart';

const _syncInterval = Duration(seconds: 30);
const _earnedKeyPrefix = 'step_earned_';
const _earnedDateKeyPrefix = 'step_earned_date_';
const _globalCheckpointKey = 'step_global_checkpoint';
const _globalCheckpointTimeKey = 'step_global_checkpoint_time';
const _activeMinutesKeyPrefix = 'active_minutes_earned_';
const _activeMinutesDateKeyPrefix = 'active_minutes_earned_date_';
const _windowSamplesKey = 'active_minute_window_samples';
const _lastActiveEventTimeKey = 'active_minute_last_event_time';
const _activeMillisKey = 'active_minute_millis_accumulator';
const _hourlyDataKeyPrefix = 'hourly_data_';

/// Beyond this, a lump step delta (app backgrounded/closed for a while) is no
/// longer split proportionally across hours - see `_attributeDeltaToHours`.
const _maxHourSplitGap = Duration(hours: 2);

/// Tracks today's step count and active minutes from the device's
/// step-counter sensor.
///
/// Android's `TYPE_STEP_COUNTER` sensor is a single cumulative count for the
/// whole device, since last reboot - it has no idea which account is
/// currently signed in. That means a naive "subtract a fixed per-account
/// baseline" design breaks the moment two accounts are used on the same
/// device on the same day: whichever account resumes next would have all the
/// *other* account's steps folded into its own total, because the sensor
/// kept climbing the whole time regardless of who was "active".
///
/// This tracker instead splits the state in two:
/// - A **device-wide** "checkpoint" (`step_global_checkpoint`, not scoped to
///   any account) - the sensor reading as of the last time *any* tracker,
///   for *any* account, processed an event.
/// - A **per-account** "earned" total (`step_earned_<email>`) - how many
///   steps this account has actually accumulated today, incremented only by
///   the delta since the checkpoint *while this account's tracker is the one
///   advancing it*.
///
/// Concretely: while account B is active, B's tracker is the one moving the
/// shared checkpoint forward, so B correctly earns those steps and A's
/// stored total is left untouched. When A resumes, the checkpoint is already
/// wherever B left it, so A's first delta is 0 - A stays at its own total
/// until genuinely new steps happen after A resumes. A normal single-account
/// day (app closed and reopened, nobody else using the phone in between)
/// still works exactly as before, since nothing else advances the checkpoint
/// while this account is the only one using it.
///
/// Active minutes reuse the exact same device-wide/per-account split, for the
/// exact same reason, and are computed as a **rolling window**, not fixed
/// clock-aligned minutes: each event's step delta is added to a device-wide
/// list of recent (timestamp, steps) samples, pruned to the trailing
/// [kActiveWindowSeconds]; if the samples remaining in that window sum to at
/// least [kActiveMinuteStepThreshold], the time elapsed since the previous
/// event is added to a millisecond accumulator, and every time that
/// accumulator crosses 60,000ms a whole active minute is credited (with the
/// remainder carried forward - so bursts of activity separated by rest
/// naturally add up, rather than needing to be continuous).
///
/// This replaced an earlier fixed-clock-minute-bucket design after on-device
/// testing (walking normally, checked live via logcat) surfaced two real
/// problems with it: (1) a bucket's threshold had to be cleared using the
/// *whole* 60-second window, so any brief pause within a clock minute could
/// drop otherwise-solid activity to zero, and (2) a burst of walking that
/// happened to straddle a clock-minute boundary (which the walker has no
/// control over) got split into two partial buckets, either or both of which
/// could fall short even though the combined burst was clearly real
/// activity. A sliding window sidesteps both: it doesn't care where a burst
/// falls relative to the clock, and it credits actual elapsed moving time
/// rather than a per-fixed-minute total.
///
/// Only a tracker whose step delta was actually accepted (i.e. `delta > 0` -
/// see [_onStepCount]) ever touches the shared window/accumulator state, for
/// the same reason as the step checkpoint above: a `delta` of 0 means either
/// a first-ever/reboot reading, or a racing stale tracker from an account
/// just switched away from whose event was already claimed by someone else -
/// in both cases there's nothing new to attribute to activity time, and
/// touching the shared state anyway would risk double-crediting the same
/// physical time to two different accounts.
///
/// Hourly detail (steps and active minutes bucketed by hour-of-day, synced to
/// the backend's `hourly_steps` table for the dashboard's hourly charts)
/// reuses the same per-account map as everything else - no new device-wide
/// state is needed to decide *which account* a step belongs to, since by the
/// time `_onStepCount` computes a positive `delta` the checkpoint above has
/// already exclusively attributed it. Deciding *which hour(s)* a delta
/// belongs to is a separate problem: if the app was backgrounded or closed
/// for a while, the sensor's next event can deliver one lump delta covering
/// the whole gap. That lump is split proportionally across the hour(s) it
/// spans, weighted by elapsed time in each (see `_attributeDeltaToHours`),
/// rather than dumped entirely into the hour it happened to arrive in - for
/// that, a new device-wide `_globalCheckpointTime` records when the
/// checkpoint was last at its previous value (paired with `_globalCheckpoint`
/// itself, same persistence/re-read-fresh pattern), since it describes the
/// physical sensor's cadence, not any one account. Active minutes credited
/// from a live, continuously-streamed event never need this (the rolling
/// window is only [kActiveWindowSeconds] wide, so a live-gated credit can
/// never span more than one hour boundary in practice) - but a credit earned
/// from a backgrounded-resume lump (see `_onActiveMinuteTick`'s gap branch)
/// genuinely can cover a long real gap. Unlike steps, that credit is *not*
/// proportionally split across the hours it spans - it's attributed entirely
/// to the hour of the event that credited it, an accepted simplification
/// (the millisecond-accumulator model that decides *how many* minutes to
/// credit doesn't retain enough of the gap's internal timing to split them
/// meaningfully, the way the step delta above can be split by simple
/// elapsed-time proportion).
///
/// Sync to the backend is foreground-only (a 30s timer plus a few explicit
/// trigger points) - there is no background sync in v1.
///
/// A `StepTracker` is scoped to whichever account was signed in when [start]
/// was called: it captures that session's token once and uses that exact
/// token for every request it ever makes, for its whole lifetime. This
/// matters because the widget that owns a tracker (the dashboard, inside a
/// `StatefulShellRoute`) is *not* disposed just by switching tabs - only by
/// navigating fully away from the shell (e.g. to the login screen), and
/// Flutter delays that disposal until the exit transition finishes. In that
/// window, a tracker from the previous account can still be alive - with its
/// sync timer still ticking - while a new account is already signed in. If
/// requests read whichever token happens to be stored *at send time* (as
/// `ApiClient` does by default), a stale tracker's pending sync can end up
/// attaching the *new* account's token to the *old* account's step count.
/// Pinning to a captured token closes that off entirely: a tracker's syncs
/// always land under the account that actually generated the data, no matter
/// how long it lingers or what the ambient signed-in session becomes later.
class StepTracker {
  final _controller = StreamController<int>.broadcast();
  final _activeMinutesController = StreamController<int>.broadcast();
  StreamSubscription<StepCount>? _subscription;
  Timer? _syncTimer;
  SharedPreferences? _prefs;

  int _earnedSoFar = 0;
  String? _earnedDate;
  int? _globalCheckpoint;
  DateTime? _globalCheckpointTime;
  int? _lastSyncedSteps;
  String _earnedKey = _earnedKeyPrefix;
  String _earnedDateKey = _earnedDateKeyPrefix;
  String? _authToken;

  int _activeMinutesSoFar = 0;
  int? _lastSyncedActiveMinutes;
  String _activeMinutesKey = _activeMinutesKeyPrefix;
  String _activeMinutesDateKey = _activeMinutesDateKeyPrefix;
  DateTime? _lastActiveEventTime;
  int _activeMillisAccumulator = 0;

  Map<int, int> _hourlySteps = {};
  Map<int, int> _hourlyActiveMinutes = {};
  Map<int, int> _lastSyncedHourlySteps = {};
  Map<int, int> _lastSyncedHourlyActiveMinutes = {};
  String _hourlyDataKey = _hourlyDataKeyPrefix;

  bool permissionDenied = false;
  bool sensorUnavailable = false;

  Stream<int> get todaySteps => _controller.stream;
  Stream<int> get todayActiveMinutes => _activeMinutesController.stream;

  /// Today's steps/active minutes bucketed by hour-of-day (0-23; hours with
  /// no activity yet are simply absent). Not a stream - both maps are only
  /// ever read at moments [todaySteps]/[todayActiveMinutes] already trigger a
  /// rebuild, since they're updated synchronously in the same call chain.
  Map<int, int> get hourlyStepsToday => Map.unmodifiable(_hourlySteps);
  Map<int, int> get hourlyActiveMinutesToday => Map.unmodifiable(_hourlyActiveMinutes);

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseTimestamp(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);

  /// [requestPermission] must be `false` when called from the background
  /// service's isolate (see `background_step_service.dart`) - `.request()`
  /// needs a live Android `Activity` to host the permission dialog, which
  /// doesn't exist there and throws a `PlatformException`. The UI isolate
  /// (dashboard/auth) is the only place that should ever prompt; the
  /// background isolate just checks whether it's already granted.
  Future<void> start({bool requestPermission = true}) async {
    if (kIsWeb) {
      sensorUnavailable = true;
      return;
    }

    if (Platform.isAndroid) {
      final status = requestPermission
          ? await Permission.activityRecognition.request()
          : await Permission.activityRecognition.status;
      if (!status.isGranted) {
        permissionDenied = true;
        return;
      }
    }

    // Capture this session's token once and use it for every request this
    // tracker ever makes - see the class doc for why. Everything below is
    // derived from this same captured token, not the ambient signed-in one,
    // so a stale tracker can never end up syncing under a different account.
    _authToken = await ApiClient.instance.getToken();
    final userEmail =
        (_authToken != null ? AuthService.instance.emailFromToken(_authToken!) : null) ??
        'anonymous';
    _earnedKey = '$_earnedKeyPrefix$userEmail';
    _earnedDateKey = '$_earnedDateKeyPrefix$userEmail';
    _activeMinutesKey = '$_activeMinutesKeyPrefix$userEmail';
    _activeMinutesDateKey = '$_activeMinutesDateKeyPrefix$userEmail';
    _hourlyDataKey = '$_hourlyDataKeyPrefix$userEmail';

    _prefs = await SharedPreferences.getInstance();
    final today = _formatDate(DateTime.now());

    _earnedDate = _prefs!.getString(_earnedDateKey);
    final earnedWasToday = _earnedDate == today;
    _earnedSoFar = earnedWasToday ? (_prefs!.getInt(_earnedKey) ?? 0) : 0;
    _earnedDate = today;

    final activeMinutesDate = _prefs!.getString(_activeMinutesDateKey);
    _activeMinutesSoFar =
        activeMinutesDate == today ? (_prefs!.getInt(_activeMinutesKey) ?? 0) : 0;

    // Hourly data resets on the exact same day-boundary as _earnedSoFar - the
    // same _onStepCount check clears both - so it's seeded from the same
    // earnedWasToday check rather than a second, separately-tracked date key
    // that could drift out of sync with it.
    if (earnedWasToday) {
      for (final raw in _prefs!.getStringList(_hourlyDataKey) ?? const []) {
        final parts = raw.split(':');
        final hour = int.parse(parts[0]);
        _hourlySteps[hour] = int.parse(parts[1]);
        _hourlyActiveMinutes[hour] = int.parse(parts[2]);
      }
    }

    // start() only ever (re)runs when the service genuinely wasn't running -
    // an ordinary UI close/reopen never stops it, so reaching this point at
    // all means tracking actually went through a real stop, whether
    // deliberate (Close App, sign-out) or involuntary (the OS/OEM battery
    // manager killing the foreground service - confirmed via on-device
    // dumpsys to happen periodically on real hardware even with
    // isForegroundMode + the health service type). Either way, wipe every
    // piece of device-wide sensor-derived state below *before* it's read, so
    // the upcoming first event re-baselines (delta=0, same path as a device
    // reboot) instead of crediting whatever the sensor accumulated during the
    // gap as a backfill. Clearing _lastActiveEventTimeKey/_windowSamplesKey/
    // _activeMillisKey too, not just the step checkpoint, matters just as
    // much: leaving a stale _lastActiveEventTime in place would make the
    // *next* real event after resuming compute its elapsed-since-last-event
    // gap across the entire downtime anyway, silently reintroducing exactly
    // the credit this is meant to suppress.
    //
    // This used to only run for a deliberate stop (an earlier,
    // now-removed `markExplicitlyPaused` flag gated it), leaving an
    // involuntary gap to fall through to the gap-estimation fallback in
    // `_onActiveMinuteTick` instead. That let steps (recovered exactly, via
    // the sensor's own cumulative count) and active minutes (recovered only
    // as a cadence *estimate*, which a long idle gap easily dilutes to zero)
    // visibly disagree after the same restart - confirmed on-device: a
    // Samsung battery-killed overnight restart backfilled real steps but
    // credited zero active minutes/calories for the same gap. Explicitly
    // chosen over keeping the accurate step backfill: discarding a real,
    // exactly-known step delta is worse data than not having it, but a
    // metric that's sometimes retroactively right and sometimes silently
    // wrong depending on gap shape is worse UX than one that's consistently
    // "doesn't count time it wasn't actually watching."
    await _prefs!.remove(_globalCheckpointKey);
    await _prefs!.remove(_globalCheckpointTimeKey);
    await _prefs!.remove(_lastActiveEventTimeKey);
    await _prefs!.remove(_windowSamplesKey);
    await _prefs!.remove(_activeMillisKey);
    _globalCheckpoint = null;
    _globalCheckpointTime = null;
    _lastActiveEventTime = null;
    _activeMillisAccumulator = 0;

    // Reseed hourly detail from the backend *before* the daily seed below
    // fires its stream broadcasts - deliberately reordered from an earlier
    // version of this method, which did this the other way around. A plain
    // getter-based UI (this class's original only consumer) wouldn't have
    // cared about the order, since it re-reads hourlyStepsToday/
    // hourlyActiveMinutesToday live at every rebuild regardless of which
    // stream triggered it. But a listener that bridges these streams to a
    // point-in-time snapshot payload (see background_step_service.dart's
    // broadcastActivity, which reads those same getters synchronously inside
    // the todaySteps/todayActiveMinutes listeners below) captures whatever
    // they hold *at that exact moment* - if this reseed still ran after the
    // daily seed's broadcasts, the very first snapshot sent to the UI would
    // carry correct steps/active-minutes but empty hourly maps, only
    // self-correcting on the next real sensor event. Confirmed via a real
    // report: steps/active time displayed correctly, hourly charts stayed
    // empty until the user walked more, which is the exact would-be
    // signature. The server's hourly values fully replace, not merge with,
    // the local seed above - recovers from reinstall/cleared storage.
    final hourlySeeded = await HourlyStepService.instance.fetchHourlyEntries(
      DateTime.now(),
      token: _authToken,
    );
    if (hourlySeeded != null) {
      _hourlySteps = {};
      _hourlyActiveMinutes = {};
      for (final entry in hourlySeeded) {
        _hourlySteps[entry.hour] = entry.stepCount;
        _hourlyActiveMinutes[entry.hour] = entry.activeMinutes;
      }
    }

    final seeded = await StepService.instance.fetchDailyEntry(DateTime.now(), token: _authToken);
    if (seeded != null) {
      _earnedSoFar = seeded.stepCount;
      _activeMinutesSoFar = seeded.activeMinutes;
      if (!_controller.isClosed) _controller.add(_earnedSoFar);
      if (!_activeMinutesController.isClosed) {
        _activeMinutesController.add(_activeMinutesSoFar);
      }
    }

    _subscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (_) {
        sensorUnavailable = true;
      },
    );

    _syncTimer = Timer.periodic(_syncInterval, (_) => pushNow());
  }

  // Computing "today" once in start() and closing over that single value
  // (the previous shape of this method, before the background-tracking
  // service existed) was harmless when a StepTracker's lifetime was capped
  // at one app session - the user reopening the app the next day always
  // meant a brand new start() call with a freshly-computed value. Once the
  // background service can run for days at a stretch without ever
  // restarting, that stale captured value silently stopped being "today"
  // the moment midnight passed, and the day-boundary reset below
  // (`_earnedDate != today`) could never fire again - confirmed by a real
  // report of steps/active minutes accumulating across a day boundary
  // instead of resetting. Recomputed fresh from this event's own timestamp
  // on every call instead.
  void _onStepCount(StepCount event) {
    final today = _formatDate(event.timeStamp);
    final cumulative = event.steps;

    if (_earnedDate != today) {
      _earnedSoFar = 0;
      _activeMinutesSoFar = 0;
      _hourlySteps = {};
      _hourlyActiveMinutes = {};
      _lastSyncedHourlySteps = {};
      _lastSyncedHourlyActiveMinutes = {};
      _earnedDate = today;
    }

    // Re-read rather than trust the in-memory value: if a tracker from the
    // account just switched away from is still alive (see the class doc -
    // widget disposal can lag a route transition by a couple hundred ms),
    // both it and this fresh tracker are independently subscribed to the
    // same sensor stream. Reading the checkpoint fresh means whichever one
    // processes a given event second sees the first one's already-persisted
    // update and correctly credits zero (or a smaller delta) instead of both
    // crediting the same physical steps to two different accounts.
    _globalCheckpoint = _prefs?.getInt(_globalCheckpointKey) ?? _globalCheckpoint;
    _globalCheckpointTime =
        _parseTimestamp(_prefs?.getString(_globalCheckpointTimeKey)) ?? _globalCheckpointTime;
    final checkpointTimeBefore = _globalCheckpointTime;

    final isReboot = _globalCheckpoint != null && cumulative < _globalCheckpoint!;
    final int delta;
    if (_globalCheckpoint == null || isReboot) {
      // First-ever reading, or the device rebooted since the last checkpoint
      // (the sensor resets to 0 on reboot) - nothing to credit this round,
      // just establish a fresh reference point.
      _globalCheckpoint = cumulative;
      delta = 0;
    } else {
      delta = cumulative - _globalCheckpoint!;
      _earnedSoFar += delta;
      _globalCheckpoint = cumulative;
    }
    _globalCheckpointTime = event.timeStamp;

    _prefs?.setInt(_earnedKey, _earnedSoFar);
    _prefs?.setString(_earnedDateKey, _earnedDate!);
    _prefs?.setInt(_globalCheckpointKey, _globalCheckpoint!);
    _prefs?.setString(_globalCheckpointTimeKey, _globalCheckpointTime!.toIso8601String());

    if (!_controller.isClosed) {
      _controller.add(_earnedSoFar);
    }

    if (delta > 0) {
      _attributeDeltaToHours(checkpointTimeBefore, event.timeStamp, delta);
    }

    _onActiveMinuteTick(event, today, delta);
  }

  /// Splits [delta] across the hour(s) between [from] and [to], weighted by
  /// elapsed time in each - so a lump delta covering a gap in sensor
  /// delivery (app backgrounded/closed, then reopened later) lands
  /// approximately where it actually happened, not entirely in the hour it
  /// happened to arrive in. Clips [from] to the start of [to]'s calendar day,
  /// so a gap spanning midnight never attributes into a different day's
  /// (already-reset) bucket map - a small accepted edge case.
  ///
  /// Beyond [_maxHourSplitGap], stops splitting and credits the whole delta
  /// to [to]'s hour instead. Found via real on-device testing: every full
  /// hour inside a gap has the same duration relative to the total gap, so a
  /// long gap (phone idle for hours, then a short burst of walking right
  /// before reopening) doesn't taper down like a real distribution - it
  /// produces a flat plateau of an identical share repeated across every
  /// full hour, fabricating hours of "steady activity" that never happened.
  /// Past the cap there's no real basis for *where* in the gap the steps
  /// occurred anyway, so an honest single spike at the arrival hour beats a
  /// misleading multi-hour plateau.
  void _attributeDeltaToHours(DateTime? from, DateTime to, int delta) {
    final startOfToday = DateTime(to.year, to.month, to.day);
    var cursor = (from == null || from.isBefore(startOfToday)) ? startOfToday : from;

    if (!cursor.isBefore(to) || to.difference(cursor) > _maxHourSplitGap) {
      _hourlySteps[to.hour] = (_hourlySteps[to.hour] ?? 0) + delta;
      _persistHourlyData();
      return;
    }

    final totalMs = to.difference(cursor).inMilliseconds;
    var attributed = 0;
    while (cursor.isBefore(to)) {
      final hourEnd = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
      ).add(const Duration(hours: 1));
      final segmentEnd = hourEnd.isBefore(to) ? hourEnd : to;
      final isLastSegment = segmentEnd.isAtSameMomentAs(to);
      final share = isLastSegment
          ? delta - attributed
          : (delta * segmentEnd.difference(cursor).inMilliseconds / totalMs).round();
      _hourlySteps[cursor.hour] = (_hourlySteps[cursor.hour] ?? 0) + share;
      attributed += share;
      cursor = segmentEnd;
    }

    _persistHourlyData();
  }

  void _persistHourlyData() {
    final hours = <int>{..._hourlySteps.keys, ..._hourlyActiveMinutes.keys};
    final encoded = hours
        .map((h) => '$h:${_hourlySteps[h] ?? 0}:${_hourlyActiveMinutes[h] ?? 0}')
        .toList();
    _prefs?.setStringList(_hourlyDataKey, encoded);
  }

  void _onActiveMinuteTick(StepCount event, String today, int delta) {
    // Only the tracker whose delta was actually accepted above touches the
    // shared rolling-window state - see the class doc for why a delta of 0
    // (first-ever/reboot reading, or a racing stale tracker whose event was
    // already claimed by someone else) must be a no-op here.
    if (delta <= 0) return;

    // Re-read fresh, same reasoning as the step checkpoint: a second, racing
    // tracker may have already advanced this shared state.
    final rawSamples = _prefs?.getStringList(_windowSamplesKey) ?? const [];
    _lastActiveEventTime =
        _parseTimestamp(_prefs?.getString(_lastActiveEventTimeKey)) ?? _lastActiveEventTime;
    _activeMillisAccumulator = _prefs?.getInt(_activeMillisKey) ?? _activeMillisAccumulator;

    final eventTime = event.timeStamp;
    final windowStart = eventTime.subtract(const Duration(seconds: kActiveWindowSeconds));

    // Drop samples that have aged out of the trailing window, then add this
    // one - this list of raw "millis:steps" pairs *is* the rolling window.
    var stepsInWindow = delta;
    final samples = <String>['${eventTime.millisecondsSinceEpoch}:$delta'];
    for (final raw in rawSamples) {
      final parts = raw.split(':');
      final sampleTime = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0]));
      if (sampleTime.isAfter(windowStart)) {
        samples.add(raw);
        stepsInWindow += int.parse(parts[1]);
      }
    }

    if (_lastActiveEventTime != null) {
      final elapsedMs = eventTime.difference(_lastActiveEventTime!).inMilliseconds;
      if (elapsedMs <= kActiveWindowSeconds * 1000) {
        // A live, continuously-streamed event (app in foreground) - gate on
        // the trailing window's cadence exactly as always. Bursts separated
        // by rest still add up: the accumulator only resets by being spent
        // on a whole credited minute, never by going idle in between.
        if (stepsInWindow >= kActiveMinuteStepThreshold) {
          _activeMillisAccumulator += elapsedMs;
        }
      } else {
        // This event arrived after a gap wider than the window - the app
        // was backgrounded/closed and only just received one lump
        // `StepCount` on resume (the OS sensor itself never stops counting,
        // only this app's ability to *see* individual events while it isn't
        // running does - see the class doc). The trailing window is
        // meaningless here (it holds only this one sample, since every older
        // sample aged out), so the old `stepsInWindow >= threshold` check
        // degenerated into "did this lump have >= kActiveMinuteStepThreshold
        // raw steps total", with no regard for how long the gap actually
        // was - capping the credited time at just [kActiveWindowSeconds]
        // regardless of delta size meant a genuine 20-minute walk with the
        // app closed credited at most ~30s (often not even a whole minute).
        // Gate on this delta's own average cadence over the *real* elapsed
        // gap instead, and if it clears the same per-ms threshold, credit
        // the actual elapsed time - capped at [_maxHourSplitGap] for the
        // same reason step-hour attribution caps there: past that, there's
        // no real basis for assuming the whole gap was continuous activity
        // rather than a short burst right before reopening the app.
        final thresholdPerMs = kActiveMinuteStepThreshold / (kActiveWindowSeconds * 1000);
        if (delta / elapsedMs >= thresholdPerMs) {
          _activeMillisAccumulator += elapsedMs.clamp(0, _maxHourSplitGap.inMilliseconds);
        }
      }
    }
    _lastActiveEventTime = eventTime;

    var creditedMinutes = 0;
    while (_activeMillisAccumulator >= 60000) {
      _activeMinutesSoFar += 1;
      _activeMillisAccumulator -= 60000;
      creditedMinutes += 1;
    }
    if (creditedMinutes > 0) {
      // All credited this event, so all attributed to this event's hour -
      // see the class doc for why this needs no proportional split the way
      // the step delta above does.
      _hourlyActiveMinutes[eventTime.hour] =
          (_hourlyActiveMinutes[eventTime.hour] ?? 0) + creditedMinutes;
      _persistHourlyData();
    }

    _prefs?.setStringList(_windowSamplesKey, samples);
    _prefs?.setString(_lastActiveEventTimeKey, eventTime.toIso8601String());
    _prefs?.setInt(_activeMillisKey, _activeMillisAccumulator);
    _prefs?.setInt(_activeMinutesKey, _activeMinutesSoFar);
    _prefs?.setString(_activeMinutesDateKey, today);

    if (!_activeMinutesController.isClosed) {
      _activeMinutesController.add(_activeMinutesSoFar);
    }
  }

  /// Pushes the current in-memory counts to the backend if either has
  /// changed since the last successful sync. Used by the periodic timer,
  /// app-lifecycle transitions, and pull-to-refresh.
  Future<void> pushNow() async {
    if (_earnedSoFar == _lastSyncedSteps &&
        _activeMinutesSoFar == _lastSyncedActiveMinutes) {
      // If the daily aggregate hasn't changed, the hourly buckets that sum
      // to it haven't either - nothing to sync there either.
      return;
    }
    final success = await StepService.instance.syncDailyEntry(
      DateTime.now(),
      stepCount: _earnedSoFar,
      activeMinutes: _activeMinutesSoFar,
      token: _authToken,
    );
    if (success) {
      _lastSyncedSteps = _earnedSoFar;
      _lastSyncedActiveMinutes = _activeMinutesSoFar;
    }
    await _syncDirtyHours();
  }

  /// Sends every hour whose steps or active minutes differ from what was
  /// last synced, in one batched request - not one PUT per hour, to keep
  /// this feature's added sync traffic to roughly one extra call per tick
  /// rather than one per dirty hour.
  Future<void> _syncDirtyHours() async {
    final dirty = <HourlyStepEntry>[];
    for (final hour in _hourlySteps.keys) {
      final steps = _hourlySteps[hour]!;
      final activeMin = _hourlyActiveMinutes[hour] ?? 0;
      if (_lastSyncedHourlySteps[hour] != steps ||
          _lastSyncedHourlyActiveMinutes[hour] != activeMin) {
        dirty.add(HourlyStepEntry(hour: hour, stepCount: steps, activeMinutes: activeMin));
      }
    }
    if (dirty.isEmpty) return;

    final success = await HourlyStepService.instance.syncHours(
      DateTime.now(),
      dirty,
      token: _authToken,
    );
    if (success) {
      for (final entry in dirty) {
        _lastSyncedHourlySteps[entry.hour] = entry.stepCount;
        _lastSyncedHourlyActiveMinutes[entry.hour] = entry.activeMinutes;
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _syncTimer?.cancel();
    _controller.close();
    _activeMinutesController.close();
  }
}
