import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../routes/app_routes.dart';
import '../../services/activity_estimator.dart';
import '../../services/hourly_step_service.dart';
import '../../services/profile_service.dart';
import '../../services/step_service.dart';
import '../../theme/app_theme.dart';
import './widgets/activity_ring_widget.dart';
import './widgets/date_navigation_widget.dart';
import './widgets/hourly_chart_section_widget.dart';
import './widgets/metric_cards_row_widget.dart';
import './widgets/total_stats_widget.dart';
import './widgets/weekly_mini_strip_widget.dart';

class ActivityDashboardScreen extends StatefulWidget {
  const ActivityDashboardScreen({super.key});

  @override
  State<ActivityDashboardScreen> createState() =>
      _ActivityDashboardScreenState();
}

class _ActivityDashboardScreenState extends State<ActivityDashboardScreen>
    with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();

  StreamSubscription? _activitySubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription<UserProfile>? _profileSubscription;
  int? _todaySteps;
  int? _todayActiveMinutes;
  // Today's hourly steps/active-minutes, bridged live from the background
  // tracking service's 'activityUpdate' broadcast (see
  // background_step_service.dart) - replaces the old direct
  // StepTracker.hourlyStepsToday/.hourlyActiveMinutesToday getters now that
  // this screen no longer owns a StepTracker instance itself.
  Map<int, int> _hourlySteps = {};
  Map<int, int> _hourlyActiveMinutes = {};
  bool _permissionDenied = false;
  // Guards the one-time backend seed fetch below from ever overwriting an
  // already-live value if its network response is slow to come back.
  bool _hasLiveUpdate = false;
  UserProfile? _profile;

  // Real per-day entries for dates other than today, fetched on demand from
  // the backend and cached by "yyyy-MM-dd" - see _ensureDateFetched. Today
  // itself is never stored here; it always comes from the background
  // tracking service's live broadcast instead, same as before.
  final Map<String, Map<String, dynamic>> _fetchedDayData = {};

  // Real hourly entries for dates other than today, fetched on demand from
  // the backend and cached by "yyyy-MM-dd" - see _ensureHourlyFetched. Today
  // itself is never stored here; it always comes from the live _hourlySteps/
  // _hourlyActiveMinutes fields instead. Only populated for dates within
  // kHourlyRetentionDays - the backend purges hourly detail older than that.
  final Map<String, List<Map<String, dynamic>>> _fetchedHourlyData = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _activitySubscription =
        FlutterBackgroundService().on('activityUpdate').listen((event) {
      if (!mounted || event == null) return;
      _hasLiveUpdate = true;
      setState(() {
        _todaySteps = event['steps'] as int;
        _todayActiveMinutes = event['activeMinutes'] as int;
        _hourlySteps = (event['hourlySteps'] as Map).map(
          (k, v) => MapEntry(int.parse(k as String), v as int),
        );
        _hourlyActiveMinutes = (event['hourlyActiveMinutes'] as Map).map(
          (k, v) => MapEntry(int.parse(k as String), v as int),
        );
      });
    });
    _statusSubscription =
        FlutterBackgroundService().on('trackerStatus').listen((event) {
      if (!mounted || event == null) return;
      setState(() => _permissionDenied = event['permissionDenied'] as bool);
    });
    _requestPermissionsAndStartTracking();

    // One-time seed for the very first paint, before any background-service
    // broadcast has arrived - _hasLiveUpdate guards against a slow response
    // here ever overwriting an already-live value. Necessary even beyond
    // that first paint: if the background service was *already* running
    // from a previous session (the common case - it isn't stopped just by
    // closing the app), _requestPermissionsAndStartTracking's startService()
    // call above is a no-op (isRunning() already true), so StepTracker.start
    // never re-runs and never re-broadcasts anything - the dashboard would
    // otherwise show nothing until the next real step event, which could be
    // a while. This seed is what makes reopening the app show correct data
    // immediately regardless of whether the service needed to (re)start.
    StepService.instance.fetchDailyEntry(DateTime.now()).then((entry) {
      if (!mounted || _hasLiveUpdate || entry == null) return;
      setState(() {
        _todaySteps = entry.stepCount;
        _todayActiveMinutes = entry.activeMinutes;
      });
    });

    // Same reasoning, for the hourly maps that drive the charts/weekly
    // strip/calorie estimate - there was previously no independent seed for
    // these at all, only ever set from a background-service broadcast, which
    // (per the reasoning above) may not arrive again until the next real
    // step event even on an otherwise-normal reopen.
    HourlyStepService.instance.fetchHourlyEntries(DateTime.now()).then((entries) {
      if (!mounted || _hasLiveUpdate || entries == null) return;
      final steps = <int, int>{};
      final activeMinutes = <int, int>{};
      for (final e in entries) {
        steps[e.hour] = e.stepCount;
        activeMinutes[e.hour] = e.activeMinutes;
      }
      setState(() {
        _hourlySteps = steps;
        _hourlyActiveMinutes = activeMinutes;
      });
    });

    ProfileService.instance.fetchProfile().then((profile) {
      if (mounted) setState(() => _profile = profile);
    });
    // Settings lives in a sibling tab of the same StatefulShellRoute, whose
    // State (including this one) is kept alive across tab switches rather
    // than recreated - so without this, a goal changed in Settings would
    // only ever show up here after a full app restart, not on returning to
    // this tab. See ProfileService.profileUpdates.
    _profileSubscription = ProfileService.instance.profileUpdates.listen((
      profile,
    ) {
      if (mounted) setState(() => _profile = profile);
    });

    // Prefetch the trailing week (excluding today, which is always live) so
    // the weekly strip shows real progress rings as soon as it's visible,
    // not just once each day happens to be tapped.
    final today = DateTime.now();
    for (var i = 1; i <= 6; i++) {
      _ensureDateFetched(
        DateTime(today.year, today.month, today.day).subtract(Duration(days: i)),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activitySubscription?.cancel();
    _statusSubscription?.cancel();
    _profileSubscription?.cancel();
    // No pushNow()/tracker.dispose() here anymore - the tracker now lives in
    // the background service and outlives this widget by design; it keeps
    // running (and syncing on its own 30s timer) after this screen is gone.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Fire-and-forget nudge for a prompt sync on backgrounding - the
      // service's own periodic timer is the real backstop regardless.
      if (!kIsWeb && Platform.isAndroid) {
        FlutterBackgroundService().invoke('sync');
      }
    }
  }

  /// Requests the permissions the background tracking service needs
  /// (matching today's existing UX of prompting once the user reaches the
  /// dashboard, not earlier in the boot sequence), then starts the service
  /// if not already running. Android only - see background_step_service.dart's
  /// doc for why iOS is out of scope.
  Future<void> _requestPermissionsAndStartTracking() async {
    if (kIsWeb || !Platform.isAndroid) return;

    final activityStatus = await Permission.activityRecognition.request();
    if (!mounted) return;
    if (!activityStatus.isGranted) {
      setState(() => _permissionDenied = true);
      return;
    }
    // Android 13+ only - permission_handler treats this as already-granted
    // on older versions where notifications aren't a runtime permission.
    await Permission.notification.request();

    if (!(await FlutterBackgroundService().isRunning())) {
      await FlutterBackgroundService().startService();
    }
  }

  /// Bridges RefreshIndicator's awaitable contract to the background
  /// service's fire-and-forget invoke()/on() messaging: nudges an immediate
  /// sync and waits for its 'syncComplete' reply, falling back to a short
  /// timeout in case the service isn't running.
  Future<void> _handleRefresh() {
    final completer = Completer<void>();
    late final StreamSubscription sub;
    sub = FlutterBackgroundService().on('syncComplete').listen((_) {
      if (!completer.isCompleted) completer.complete();
      sub.cancel();
    });
    FlutterBackgroundService().invoke('sync');
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => sub.cancel(),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Builds the display map every date (today or otherwise) is rendered
  /// from. Calories/distance are always derived client-side from steps plus
  /// [_profile]'s weight/height/age/gender (see [ActivityEstimator]), and
  /// goals always come from the current profile - there's no per-day
  /// historical goal, so a past day is shown against today's goals, same as
  /// "today" itself.
  ///
  /// `totalCalories` = activity calories (extra burn from walking) + resting
  /// calories (BMR - what the body burns just to function, which is most of
  /// a day's real total). [isToday] controls how much of the day's BMR to
  /// count: a completed past day gets its full 24h of resting burn, while
  /// today only counts the fraction of the day elapsed so far, so the number
  /// doesn't include calories that haven't been burned yet.
  ///
  /// Activity calories are computed via [ActivityEstimator.activityCalories]
  /// (MET-based, varies by implied walking speed) rather than a flat
  /// per-step constant. When [hourlySteps]/[hourlyActiveMinutes] are both
  /// provided (today only - see call sites), the day total is the *sum* of
  /// that formula applied per-hour rather than once on the whole day's
  /// totals - calling it once on a whole day mixes scattered/incidental
  /// steps into the cadence for an unrelated sustained bout and can
  /// meaningfully overestimate (see [ActivityEstimator.activityCalories]'s
  /// doc). Past days fall back to the single whole-day call since their
  /// hourly detail is fetched separately and may not be available yet - a
  /// known, accepted minor approximation for those, not today.
  Map<String, dynamic> _buildDayData({
    required String dateKey,
    required int steps,
    required int activeMinutes,
    required bool isToday,
    Map<int, int>? hourlySteps,
    Map<int, int>? hourlyActiveMinutes,
  }) {
    final activityCalories = (hourlySteps != null && hourlyActiveMinutes != null)
        ? _sumHourlyActivityCalories(hourlySteps, hourlyActiveMinutes)
        : ActivityEstimator.activityCalories(
            steps: steps,
            activeMinutes: activeMinutes,
            weightKg: _profile?.weightKg,
            heightCm: _profile?.heightCm,
          ).round();
    final fullDayBmr = ActivityEstimator.bmr(
      weightKg: _profile?.weightKg,
      heightCm: _profile?.heightCm,
      age: _profile?.age,
      gender: _profile?.gender,
    );
    final elapsedFraction =
        isToday ? ActivityEstimator.elapsedDayFraction(DateTime.now()) : 1.0;
    final restingCalories =
        ActivityEstimator.restingCalories(fullDayBmr, elapsedFraction).round();
    return {
      'date': dateKey,
      'steps': steps,
      'stepGoal': _profile?.stepGoal ?? kDefaultStepGoal,
      'activeMinutes': activeMinutes,
      'activeGoal': _profile?.activeMinutesGoal ?? kDefaultActiveMinutesGoal,
      'activityCalories': activityCalories,
      'calorieGoal': _profile?.calorieGoal ?? kDefaultCalorieGoal,
      'totalCalories': activityCalories + restingCalories,
      'distanceKm': ActivityEstimator.distanceKm(steps, _profile?.heightCm),
    };
  }

  /// Sums [ActivityEstimator.activityCalories] per-hour across every hour
  /// present in either map, rather than calling it once on whole-day totals
  /// - see [_buildDayData]'s doc for why.
  int _sumHourlyActivityCalories(
    Map<int, int> steps,
    Map<int, int> activeMinutes,
  ) {
    var total = 0.0;
    final hours = <int>{...steps.keys, ...activeMinutes.keys};
    for (final h in hours) {
      total += ActivityEstimator.activityCalories(
        steps: steps[h] ?? 0,
        activeMinutes: activeMinutes[h] ?? 0,
        weightKg: _profile?.weightKg,
        heightCm: _profile?.heightCm,
      );
    }
    return total.round();
  }

  /// Fetches and caches a non-today date's real entry from the backend, if
  /// not already resolved. Today is intentionally never cached here - it
  /// always comes from the background tracking service's live broadcast
  /// instead (see [_activitySubscription]).
  Future<void> _ensureDateFetched(DateTime date) async {
    if (_isToday(date)) return;
    final dateStr = _formatDate(date);
    if (_fetchedDayData.containsKey(dateStr)) return;

    final entry = await StepService.instance.fetchDailyEntry(date);
    if (!mounted) return;
    setState(() {
      _fetchedDayData[dateStr] = _buildDayData(
        dateKey: dateStr,
        steps: entry?.stepCount ?? 0,
        activeMinutes: entry?.activeMinutes ?? 0,
        isToday: false,
      );
    });
  }

  /// Today's steps and active minutes come live from the background tracking
  /// service; every other date is fetched on demand from the real backend
  /// (see [_ensureDateFetched]) and cached in [_fetchedDayData] - null here
  /// means "not resolved yet" (about to be fetched, or a fetch is in
  /// flight), not "confirmed no data". The hourly breakdown chart still uses
  /// mock data, tracked as a separate, larger follow-up.
  Map<String, dynamic>? get _todayData {
    if (_isToday(_selectedDate)) {
      return _buildDayData(
        dateKey: 'today',
        steps: _todaySteps ?? 0,
        activeMinutes: _todayActiveMinutes ?? 0,
        isToday: true,
        hourlySteps: _hourlySteps,
        hourlyActiveMinutes: _hourlyActiveMinutes,
      );
    }

    final dateStr = _formatDate(_selectedDate);
    final cached = _fetchedDayData[dateStr];
    if (cached == null) {
      _ensureDateFetched(_selectedDate);
    }
    return cached;
  }

  /// The trailing week's data for [WeeklyMiniStripWidget], including today's
  /// live entry under its real date (not the `'today'` sentinel [_todayData]
  /// uses internally) so the strip's own date-string lookup can find it.
  List<Map<String, dynamic>> get _weeklyStripData {
    final now = DateTime.now();
    final todayEntry = _buildDayData(
      dateKey: _formatDate(now),
      isToday: true,
      steps: _todaySteps ?? 0,
      activeMinutes: _todayActiveMinutes ?? 0,
      hourlySteps: _hourlySteps,
      hourlyActiveMinutes: _hourlyActiveMinutes,
    );
    return [todayEntry, ..._fetchedDayData.values];
  }

  int _daysAgo(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return today.difference(d).inDays;
  }

  /// The backend purges hourly detail older than [kHourlyRetentionDays] - so
  /// there's no point fetching (or showing empty-looking zero bars for) a
  /// date outside that window; the UI shows an explicit message instead.
  bool get _hourlyDataAvailableForSelectedDate =>
      _isToday(_selectedDate) || _daysAgo(_selectedDate) < kHourlyRetentionDays;

  List<Map<String, dynamic>> _buildHourlyChartData(
    Map<int, int> steps,
    Map<int, int> activeMinutes,
  ) {
    return List.generate(24, (h) {
      final s = steps[h] ?? 0;
      final a = activeMinutes[h] ?? 0;
      return {
        'hour': h,
        'steps': s,
        'activeMin': a,
        'calories': ActivityEstimator.activityCalories(
          steps: s,
          activeMinutes: a,
          weightKg: _profile?.weightKg,
          heightCm: _profile?.heightCm,
        ).round(),
      };
    });
  }

  /// Fetches and caches a non-today date's hourly entries, if within the
  /// retention window and not already resolved. Today always comes live from
  /// the background tracking service instead; dates outside the window are
  /// never fetched.
  Future<void> _ensureHourlyFetched(DateTime date) async {
    if (_isToday(date)) return;
    if (_daysAgo(date) >= kHourlyRetentionDays) return;
    final dateStr = _formatDate(date);
    if (_fetchedHourlyData.containsKey(dateStr)) return;

    final entries = await HourlyStepService.instance.fetchHourlyEntries(date);
    if (!mounted) return;
    final steps = <int, int>{};
    final activeMinutes = <int, int>{};
    for (final e in entries ?? const <HourlyStepEntry>[]) {
      steps[e.hour] = e.stepCount;
      activeMinutes[e.hour] = e.activeMinutes;
    }
    setState(() {
      _fetchedHourlyData[dateStr] = _buildHourlyChartData(steps, activeMinutes);
    });
  }

  /// Hourly chart data for [_selectedDate] - null means "still loading" (only
  /// possible when [_hourlyDataAvailableForSelectedDate] is true; callers
  /// should check that first for dates outside the retention window).
  List<Map<String, dynamic>>? get _selectedHourlyData {
    if (_isToday(_selectedDate)) {
      return _buildHourlyChartData(
        _hourlySteps,
        _hourlyActiveMinutes,
      );
    }
    final dateStr = _formatDate(_selectedDate);
    final cached = _fetchedHourlyData[dateStr];
    if (cached == null) {
      _ensureHourlyFetched(_selectedDate);
    }
    return cached;
  }

  /// The hour with the highest value for [dataKey], formatted as a label -
  /// each chart (steps/active time/calories) has its own real peak, not a
  /// single shared one. Returns '--' if every hour is 0.
  String _peakTimeLabel(List<Map<String, dynamic>> hourlyData, String dataKey) {
    var peakHour = 0;
    var peakValue = 0;
    for (final entry in hourlyData) {
      final value = (entry[dataKey] as num).toInt();
      if (value > peakValue) {
        peakValue = value;
        peakHour = entry['hour'] as int;
      }
    }
    if (peakValue == 0) return '--';
    final nextHour = (peakHour + 1) % 24;
    return '${peakHour.toString().padLeft(2, '0')}:00 - '
        '${nextHour.toString().padLeft(2, '0')}:00';
  }

  void _navigateDay(int delta) {
    final newDate = _selectedDate.add(Duration(days: delta));
    setState(() => _selectedDate = newDate);
    _ensureDateFetched(newDate);
    _ensureHourlyFetched(newDate);
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      // Bolds the "Select date" header and the Cancel/OK buttons, which the
      // default Material date picker theme renders in a regular weight.
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            datePickerTheme: base.datePickerTheme.copyWith(
              headerHelpStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _ensureDateFetched(picked);
      _ensureHourlyFetched(picked);
    }
  }

  //bool get _isTablet => false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final data = _todayData;
    final hourlyAvailable = _hourlyDataAvailableForSelectedDate;
    final hourlyData = hourlyAvailable ? _selectedHourlyData : null;
    final showPermissionDeniedState =
        _isToday(_selectedDate) && _permissionDenied;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(
                child: DateNavigationWidget(
                  selectedDate: _selectedDate,
                  onPrevious: () => _navigateDay(-1),
                  onNext: () => _navigateDay(1),
                ),
              ),
              SliverToBoxAdapter(
                child: WeeklyMiniStripWidget(
                  selectedDate: _selectedDate,
                  dailyData: _weeklyStripData,
                  onDayTap: (date) {
                    setState(() => _selectedDate = date);
                    _ensureDateFetched(date);
                    _ensureHourlyFetched(date);
                  },
                ),
              ),
              if (showPermissionDeniedState) ...[
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pan_tool_outlined,
                          size: 64,
                          color: AppTheme.textDisabled(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Step tracking permission needed',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Allow activity access in Settings to count your steps',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            color: AppTheme.textSecondary(context).withAlpha(179),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: openAppSettings,
                          child: Text(
                            'Open Settings',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.stepsGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (data != null) ...[
                SliverToBoxAdapter(
                  child: isTablet
                      ? _buildTabletLayout(data)
                      : _buildPhoneLayout(data),
                ),
                SliverToBoxAdapter(
                  child: TotalStatsWidget(
                    totalCalories: (data['totalCalories'] as num).toDouble(),
                    distanceKm: (data['distanceKm'] as num).toDouble(),
                  ),
                ),
                if (!hourlyAvailable) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.overlay(context, 15),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Hourly breakdown is only available for the last '
                          '$kHourlyRetentionDays days',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (hourlyData == null) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 96),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.stepsGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: HourlyChartSectionWidget(
                        hourlyData: hourlyData,
                        label: 'Steps',
                        color: AppTheme.stepsGreen,
                        dataKey: 'steps',
                        peakTimeLabel: _peakTimeLabel(hourlyData, 'steps'),
                        unit: '',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: HourlyChartSectionWidget(
                        hourlyData: hourlyData,
                        label: 'Active Time',
                        color: AppTheme.activeBlue,
                        dataKey: 'activeMin',
                        peakTimeLabel: _peakTimeLabel(hourlyData, 'activeMin'),
                        unit: 'min',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      child: HourlyChartSectionWidget(
                        hourlyData: hourlyData,
                        label: 'Activity Calories',
                        color: AppTheme.caloriesPurple,
                        dataKey: 'calories',
                        peakTimeLabel: _peakTimeLabel(hourlyData, 'calories'),
                        unit: 'kcal',
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // A non-today date only ever reaches here while its fetch is
                // still in flight - _buildDayData always returns a real
                // (possibly zero-valued) entry once resolved, so null here
                // never means "confirmed no activity", just "not yet known".
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.stepsGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading activity...',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Text(
            'Daily Activity',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.calendar_month_outlined,
              size: 22,
              color: AppTheme.textBright(context),
            ),
            onPressed: () => _pickDate(context),
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              size: 22,
              color: AppTheme.textBright(context),
            ),
            onPressed: () => context.go(AppRoutes.settingsScreen),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout(Map<String, dynamic> data) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: ActivityRingWidget(
            stepsProgress: ((data['steps'] as num) / (data['stepGoal'] as num))
                .toDouble()
                .clamp(0.0, 1.0),
            activeProgress:
                ((data['activeMinutes'] as num) / (data['activeGoal'] as num))
                    .toDouble()
                    .clamp(0.0, 1.0),
            caloriesProgress:
                ((data['activityCalories'] as num) /
                        (data['calorieGoal'] as num))
                    .toDouble()
                    .clamp(0.0, 1.0),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: MetricCardsRowWidget(
            steps: (data['steps'] as num).toInt(),
            stepGoal: (data['stepGoal'] as num).toInt(),
            activeMinutes: (data['activeMinutes'] as num).toInt(),
            activeGoal: (data['activeGoal'] as num).toInt(),
            activityCalories: (data['activityCalories'] as num).toInt(),
            calorieGoal: (data['calorieGoal'] as num).toInt(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: ActivityRingWidget(
              stepsProgress:
                  ((data['steps'] as num) / (data['stepGoal'] as num))
                      .toDouble()
                      .clamp(0.0, 1.0),
              activeProgress:
                  ((data['activeMinutes'] as num) / (data['activeGoal'] as num))
                      .toDouble()
                      .clamp(0.0, 1.0),
              caloriesProgress:
                  ((data['activityCalories'] as num) /
                          (data['calorieGoal'] as num))
                      .toDouble()
                      .clamp(0.0, 1.0),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: MetricCardsRowWidget(
              steps: (data['steps'] as num).toInt(),
              stepGoal: (data['stepGoal'] as num).toInt(),
              activeMinutes: (data['activeMinutes'] as num).toInt(),
              activeGoal: (data['activeGoal'] as num).toInt(),
              activityCalories: (data['activityCalories'] as num).toInt(),
              calorieGoal: (data['calorieGoal'] as num).toInt(),
              vertical: true,
            ),
          ),
        ],
      ),
    );
  }
}
