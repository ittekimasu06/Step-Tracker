import 'dart:async' show unawaited;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// Fires the two Notification Settings features (Settings >
/// NotificationSettingsWidget) from live steps/active-minutes/calories
/// updates: "Goal Reminders" (a text-only nudge once a metric crosses 90% of
/// its daily goal) and "Goal Completed" (a two-pulse vibration plus a
/// notification once a metric reaches 100%, formerly the inert "Haptic
/// Feedback" toggle before this phase).
///
/// Lives in the background service isolate (constructed once per
/// `onStart()`, see `background_step_service.dart`) since that's the one
/// place steps/active minutes/calories are computed continuously all day
/// regardless of whether the UI is open - a reminder fired only while the
/// app happens to be in the foreground would miss most real walks.
class GoalNotificationsService {
  GoalNotificationsService();

  static const _remindersEnabledKey = 'goal_reminders_enabled';
  static const _completedEnabledKey = 'goal_completed_enabled';

  /// A metric counts as "almost there" once it crosses this fraction of its
  /// goal (and hasn't reached 100% yet) - the common "you're close" bar used
  /// by most fitness apps' goal nudges.
  static const _almostThreshold = 0.9;

  static const _reminderChannelId = 'goal_reminders';
  static const _completedChannelId = 'goal_completed';

  // Deliberately far from the background service's own persistent
  // notification id (888, see background_step_service.dart) - Android scopes
  // notification ids per (package, tag, id) with no tag used by either
  // plugin, so a collision would silently replace the always-on tracking
  // notification instead of showing a separate one.
  static const _idStepsAlmost = 9001;
  static const _idActiveAlmost = 9002;
  static const _idCaloriesAlmost = 9003;
  static const _idStepsCompleted = 9011;
  static const _idActiveCompleted = 9012;
  static const _idCaloriesCompleted = 9013;

  final _notifications = FlutterLocalNotificationsPlugin();

  /// Whether "Goal Reminders" is on. Device-wide, not per-account - matches
  /// this app's existing precedent for notification-behavior flags (see
  /// step_tracker.dart's history with its former device-wide explicit-pause
  /// key), and keeps Settings' toggle load/save simple (no signed-in email
  /// needed just to read a preference). Read from both the UI isolate
  /// (Settings' toggle) and the background isolate (this class) - plain
  /// SharedPreferences reads/writes are isolate-safe since both just talk to
  /// the same underlying Android SharedPreferences file.
  static Future<bool> remindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_remindersEnabledKey) ?? true;
  }

  static Future<void> setRemindersEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersEnabledKey, value);
  }

  /// Whether "Goal Completed" (vibration + notification on reaching a daily
  /// goal) is on.
  static Future<bool> completedEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedEnabledKey) ?? true;
  }

  static Future<void> setCompletedEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedEnabledKey, value);
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Call once per service lifetime, before the first [checkGoals].
  Future<void> init() async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    // Both channels are created with enableVibration: false on purpose -
    // "Goal Completed"'s buzz is fired explicitly below via the `vibration`
    // package instead, since that gives an exact two-pulse pattern a
    // channel's own single default vibration can't express, and channel
    // vibration settings are locked in by Android the first time the
    // channel id is used (never change afterward short of the user editing
    // them in system settings) - so this has to be right from the start.
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _reminderChannelId,
        'Goal Reminders',
        description: "Nudges when you're close to a daily goal",
        importance: Importance.high,
        enableVibration: false,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _completedChannelId,
        'Goal Completed',
        description: 'Alerts when you reach a daily goal',
        importance: Importance.high,
        enableVibration: false,
      ),
    );
  }

  /// Checks today's steps/active minutes/calories against their goals and
  /// fires whichever of the two features just newly crossed its threshold.
  /// Safe (and expected) to call on every single sensor update - each metric
  /// only ever fires its "almost" or "completed" notification once per
  /// account per day, tracked via a per-account, per-day flag pair cleared
  /// the moment [accountKey]'s stored date stops matching today (mirrors
  /// `StepTracker`'s own day-boundary reset pattern).
  ///
  /// [accountKey] should be the signed-in user's email (or a stable
  /// fallback) - namespacing per-account, like the rest of this app's
  /// per-account state, so one account's "already notified today" doesn't
  /// suppress a different account's notification on a shared device.
  Future<void> checkGoals({
    required String accountKey,
    required int steps,
    required int stepGoal,
    required int activeMinutes,
    required int activeGoal,
    required int calories,
    required int calorieGoal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _formatDate(DateTime.now());
    final dateKey = 'goal_notify_date_$accountKey';
    if (prefs.getString(dateKey) != today) {
      for (final metric in const ['steps', 'active', 'calories']) {
        await prefs.remove('goal_almost_${metric}_$accountKey');
        await prefs.remove('goal_completed_${metric}_$accountKey');
      }
      await prefs.setString(dateKey, today);
    }

    final remindersOn = prefs.getBool(_remindersEnabledKey) ?? true;
    final completedOn = prefs.getBool(_completedEnabledKey) ?? true;

    await _checkMetric(
      prefs: prefs,
      accountKey: accountKey,
      metricKey: 'steps',
      label: 'Steps',
      value: steps,
      goal: stepGoal,
      remindersOn: remindersOn,
      completedOn: completedOn,
      almostId: _idStepsAlmost,
      completedId: _idStepsCompleted,
    );
    await _checkMetric(
      prefs: prefs,
      accountKey: accountKey,
      metricKey: 'active',
      label: 'Active time',
      value: activeMinutes,
      goal: activeGoal,
      remindersOn: remindersOn,
      completedOn: completedOn,
      almostId: _idActiveAlmost,
      completedId: _idActiveCompleted,
    );
    await _checkMetric(
      prefs: prefs,
      accountKey: accountKey,
      metricKey: 'calories',
      label: 'Calories',
      value: calories,
      goal: calorieGoal,
      remindersOn: remindersOn,
      completedOn: completedOn,
      almostId: _idCaloriesAlmost,
      completedId: _idCaloriesCompleted,
    );
  }

  Future<void> _checkMetric({
    required SharedPreferences prefs,
    required String accountKey,
    required String metricKey,
    required String label,
    required int value,
    required int goal,
    required bool remindersOn,
    required bool completedOn,
    required int almostId,
    required int completedId,
  }) async {
    if (goal <= 0) return;
    final ratio = value / goal;
    final almostKey = 'goal_almost_${metricKey}_$accountKey';
    final completedKey = 'goal_completed_${metricKey}_$accountKey';

    if (ratio >= 1.0) {
      if (prefs.getBool(completedKey) ?? false) return;
      await prefs.setBool(completedKey, true);
      // Also marks "almost" as handled, so a lump delta that jumps straight
      // past 100% (e.g. a backgrounded-resume lump - see StepTracker) never
      // fires a now-redundant "almost there" reminder after the fact.
      await prefs.setBool(almostKey, true);
      if (completedOn) await _showCompleted(completedId, label);
      return;
    }

    if (ratio >= _almostThreshold) {
      if (prefs.getBool(almostKey) ?? false) return;
      await prefs.setBool(almostKey, true);
      if (remindersOn) await _showAlmost(almostId, label);
    }
  }

  Future<void> _showAlmost(int id, String label) async {
    await _notifications.show(
      id: id,
      title: 'Almost there!',
      body: 'You almost reach your daily goal on $label, keep it up!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          'Goal Reminders',
          channelDescription: "Nudges when you're close to a daily goal",
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: false,
        ),
      ),
    );
  }

  Future<void> _showCompleted(int id, String label) async {
    await _notifications.show(
      id: id,
      title: 'Goal reached!',
      body: "You've reached your daily goal on $label! Great job!",
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _completedChannelId,
          'Goal Completed',
          channelDescription: 'Alerts when you reach a daily goal',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: false,
        ),
      ),
    );
    // Explicit pattern rather than HapticFeedback.vibrate() (which triggers
    // a single, brief, system "virtual key" tick - not length/pattern
    // controllable and easily read as just one buzz, not two) or calling it
    // twice in a row (same issue, plus no guaranteed gap between calls). The
    // Vibrator API this package wraps also works independent of the device's
    // "touch haptics" setting, unlike HapticFeedback.
    if (await Vibration.hasVibrator()) {
      unawaited(Vibration.vibrate(pattern: const [0, 300, 200, 300]));
    }
  }
}
