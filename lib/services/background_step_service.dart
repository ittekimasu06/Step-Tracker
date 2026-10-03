import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'activity_estimator.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'goal_notifications_service.dart';
import 'profile_service.dart';
import 'step_tracker.dart';

/// Configures the Android foreground service that keeps [StepTracker] running
/// continuously - whether the app's own UI is foregrounded, backgrounded, or
/// fully closed - so active minutes are computed from real, live sensor
/// events all day instead of estimated after the fact from a single lump
/// delta on app resume (see [StepTracker]'s gap-estimation fallback, which
/// stays in place as a backstop for whenever this service does get killed by
/// an aggressive OEM battery manager despite `isForegroundMode`+`health`).
///
/// Android only: iOS has no equivalent persistent-foreground-service model,
/// and this app's real-world usage/testing is Android-only. `iosConfiguration`
/// is still required by the plugin's API shape, but nothing ever calls
/// `startService()` on iOS - see the `Platform.isAndroid` guards at every
/// start call site (`AuthProvider`, `ActivityDashboardScreen`).
///
/// Call once, early in `main()`, before the first frame - this only
/// registers configuration, it doesn't request any permission or start
/// anything itself (`autoStart: true` only takes effect once a permission
/// grant elsewhere calls `startService()`).
Future<void> initializeStepTrackingService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      // NOT the same thing as autoStartOnBoot below, despite the name -
      // `autoStart: true` makes the plugin call its own `start()`
      // synchronously inside configure() (confirmed by reading
      // FlutterBackgroundServicePlugin.java's `if (autoStart) { start(); }`),
      // i.e. on *every single app launch*, from this exact call in main(),
      // before any permission has ever been requested and before the first
      // frame renders. Explicit tracking/notification start belongs in
      // AuthProvider/ActivityDashboardScreen, gated on permission already
      // being granted - not here.
      autoStart: false,
      // This is the actual reboot-survival flag (via the plugin's own
      // BootReceiver/WatchdogReceiver) - only takes effect once the service
      // has already been explicitly started at least once via
      // startService() elsewhere, which only happens after permission is
      // granted.
      autoStartOnBoot: true,
      isForegroundMode: true,
      // Deliberately no custom notificationChannelId: passing one here
      // requires the app to have already created that exact channel itself
      // (confirmed by reading BackgroundService.java's onCreate - it only
      // auto-creates a channel when notificationChannelId is null, falling
      // back to its own "FOREGROUND_DEFAULT"). Nothing in this codebase
      // creates a channel (no flutter_local_notifications dependency by
      // design - see class doc), so a custom id here meant startForeground()
      // was posting to a channel that never existed - this is what crashed
      // the app on every launch. Omitting it lets the plugin safely create
      // and use its own default channel instead.
      initialNotificationTitle: 'steptrack is tracking your activity',
      initialNotificationContent: 'Counting steps and active minutes',
      foregroundServiceNotificationId: 888,
      // Must match android:foregroundServiceType="health" in
      // AndroidManifest.xml - Android 14+ rejects a foreground service start
      // whose runtime-declared type(s) don't match the manifest.
      foregroundServiceTypes: [AndroidForegroundType.health],
    ),
    iosConfiguration: IosConfiguration(),
  );
}

/// Runs in a separate Flutter engine/isolate the OS keeps alive via the
/// Android foreground service - not the UI's engine, and not disposed just
/// because the UI is backgrounded or closed.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Required for shared_preferences/flutter_secure_storage/permission_handler
  // plugin channels to work in this isolate - confirmed via the plugin's own
  // published example, which calls this and nothing else (no
  // WidgetsFlutterBinding.ensureInitialized()) before touching those plugins
  // from an Android onStart.
  DartPluginRegistrant.ensureInitialized();

  final tracker = StepTracker();
  final goalNotifier = GoalNotificationsService();
  await goalNotifier.init();

  // Fetched independently here rather than via tracker.authToken, so goals
  // are already in hand *before* subscribing below - the seed broadcast
  // fired synchronously partway through tracker.start() (see the comment on
  // the listen() calls below) can otherwise race a same-isolate profile
  // fetch kicked off only after that point, risking the very first
  // goal-threshold check running against kDefault* placeholders instead of
  // the signed-in user's real goals. Mirrors StepTracker's own token capture
  // (see its class doc) rather than reading the token off the tracker, for
  // exactly that ordering reason - not because the two could ever actually
  // disagree.
  final token = await ApiClient.instance.getToken();
  final accountKey =
      (token != null ? AuthService.instance.emailFromToken(token) : null) ??
      'anonymous';
  final profile = await ProfileService.instance.fetchProfile(token: token);

  // Broadcasts everything the dashboard needs (steps, active minutes, and
  // both hourly maps) as one merged event on either stream firing, rather
  // than two separate events - the dashboard's hourly charts/weekly strip
  // need the hourly maps too, and splitting this into "steps" and "active
  // minutes" events (mirroring StepTracker's own two streams) would leave
  // no single event carrying a guaranteed-consistent snapshot of both. Race
  // free: _onStepCount finishes mutating every StepTracker field
  // synchronously before either underlying StreamController.add() call
  // runs (neither controller is constructed with `sync: true`), so a
  // synchronous read of hourlyStepsToday/hourlyActiveMinutesToday here always
  // sees a fully-settled snapshot, no matter which listener fired.
  var lastSteps = 0;
  var lastActiveMinutes = 0;

  void broadcastActivity() {
    service.invoke('activityUpdate', {
      'steps': lastSteps,
      'activeMinutes': lastActiveMinutes,
      // Stringify int keys explicitly rather than sending Map<int,int> -
      // defensive against the standard method codec's map-key constraints
      // crossing the isolate boundary.
      'hourlySteps': tracker.hourlyStepsToday.map((h, v) => MapEntry('$h', v)),
      'hourlyActiveMinutes':
          tracker.hourlyActiveMinutesToday.map((h, v) => MapEntry('$h', v)),
    });
  }

  // Fire-and-forget on every update, same as broadcastActivity - cheap
  // (a few SharedPreferences reads/writes, see GoalNotificationsService),
  // and each goal only ever actually fires its "almost"/"completed"
  // notification once per day regardless of how often this runs.
  void checkGoals() {
    final calories = ActivityEstimator.sumHourlyActivityCalories(
      tracker.hourlyStepsToday,
      tracker.hourlyActiveMinutesToday,
      weightKg: profile?.weightKg,
      heightCm: profile?.heightCm,
    );
    goalNotifier.checkGoals(
      accountKey: accountKey,
      steps: lastSteps,
      stepGoal: profile?.stepGoal ?? kDefaultStepGoal,
      activeMinutes: lastActiveMinutes,
      activeGoal: profile?.activeMinutesGoal ?? kDefaultActiveMinutesGoal,
      calories: calories,
      calorieGoal: profile?.calorieGoal ?? kDefaultCalorieGoal,
    );
  }

  // Subscribed BEFORE start() is awaited, deliberately - start()'s own
  // backend seed fetch calls todaySteps/todayActiveMinutes's underlying
  // StreamController.add() synchronously partway through its execution
  // (well before the returned Future completes), and neither is a buffered
  // stream. Awaiting start() first and subscribing only after it returns
  // (as an earlier version of this file did) silently drops that seed
  // broadcast - today's real totals from the backend - for any subscriber
  // set up afterward, since a broadcast StreamController never replays a
  // missed event. Subscribing first, then calling start() without awaiting
  // its internal work having already begun, mirrors the ordering the
  // dashboard's own pre-background-service code always used for exactly
  // this reason.
  tracker.todaySteps.listen((steps) {
    lastSteps = steps;
    broadcastActivity();
    checkGoals();
  });
  tracker.todayActiveMinutes.listen((minutes) {
    lastActiveMinutes = minutes;
    broadcastActivity();
    checkGoals();
  });

  // Never .request() here - there's no Android Activity in this isolate to
  // host the permission dialog; only check whatever the UI isolate already
  // obtained. See StepTracker.start's doc.
  await tracker.start(requestPermission: false);

  service.invoke('trackerStatus', {
    'permissionDenied': tracker.permissionDenied,
    'sensorUnavailable': tracker.sensorUnavailable,
  });

  // On-demand sync, bridged from the UI isolate's pull-to-refresh /
  // app-paused trigger points (StepTracker.pushNow itself already runs on
  // its own 30s timer regardless - this just lets the UI force an
  // immediate one and know when it's done).
  service.on('sync').listen((_) async {
    await tracker.pushNow();
    service.invoke('syncComplete');
  });

  service.on('stop').listen((_) {
    tracker.dispose();
    service.stopSelf();
  });
}
