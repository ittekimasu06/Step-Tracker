import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/activity_estimator.dart';
import '../../services/api_client.dart';
import '../../services/profile_service.dart';
import '../../services/settings_dirty_state.dart';
import '../../theme/app_theme.dart';
import './widgets/appearance_settings_widget.dart';
import './widgets/goal_settings_widget.dart';
import './widgets/notification_settings_widget.dart';
import './widgets/profile_settings_widget.dart';
import './widgets/units_settings_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Goals
  int _stepGoal = kDefaultStepGoal;
  int _activeTimeGoal = kDefaultActiveMinutesGoal;
  int _calorieGoal = kDefaultCalorieGoal;

  // Preferences - not yet actually persisted anywhere (no backend field for
  // either group exists), but still tracked for dirty-state/Save purposes to
  // match what this button visually appears to cover; a pre-existing gap,
  // not something this phase introduces or fixes.
  bool _useMetric = true;
  bool _goalReminders = true;
  bool _morningReminder = true;
  bool _eveningReminder = false;
  bool _vibrationFeedback = true;

  bool _isSavingProfile = false;

  // The last-loaded/last-saved snapshot every field above is compared
  // against to compute [_hasUnsavedChanges] - refreshed on initial load and
  // after every successful save. Profile (name/age/weight/height/username/
  // etc.) is deliberately excluded - it's now self-contained in
  // ProfileSettingsWidget with its own inline Save, not part of this
  // screen's global Save at all.
  _GoalsSnapshot _lastSaved = const _GoalsSnapshot(
    stepGoal: kDefaultStepGoal,
    activeTimeGoal: kDefaultActiveMinutesGoal,
    calorieGoal: kDefaultCalorieGoal,
    useMetric: true,
    goalReminders: true,
    morningReminder: true,
    eveningReminder: false,
    vibrationFeedback: true,
  );

  bool get _hasUnsavedChanges =>
      _stepGoal != _lastSaved.stepGoal ||
      _activeTimeGoal != _lastSaved.activeTimeGoal ||
      _calorieGoal != _lastSaved.calorieGoal ||
      _useMetric != _lastSaved.useMetric ||
      _goalReminders != _lastSaved.goalReminders ||
      _morningReminder != _lastSaved.morningReminder ||
      _eveningReminder != _lastSaved.eveningReminder ||
      _vibrationFeedback != _lastSaved.vibrationFeedback;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    SettingsDirtyState.instance.registerDiscardHandler(_discardChanges);
  }

  @override
  void dispose() {
    SettingsDirtyState.instance.unregisterDiscardHandler();
    super.dispose();
  }

  /// Called by [SettingsDirtyState] after the user confirms discarding, from
  /// [AppNavigation]'s leave-tab guard - resets every tracked field back to
  /// the last-loaded/saved snapshot.
  void _discardChanges() {
    if (!mounted) return;
    setState(() {
      _stepGoal = _lastSaved.stepGoal;
      _activeTimeGoal = _lastSaved.activeTimeGoal;
      _calorieGoal = _lastSaved.calorieGoal;
      _useMetric = _lastSaved.useMetric;
      _goalReminders = _lastSaved.goalReminders;
      _morningReminder = _lastSaved.morningReminder;
      _eveningReminder = _lastSaved.eveningReminder;
      _vibrationFeedback = _lastSaved.vibrationFeedback;
    });
  }

  void _takeSnapshot() {
    _lastSaved = _GoalsSnapshot(
      stepGoal: _stepGoal,
      activeTimeGoal: _activeTimeGoal,
      calorieGoal: _calorieGoal,
      useMetric: _useMetric,
      goalReminders: _goalReminders,
      morningReminder: _morningReminder,
      eveningReminder: _eveningReminder,
      vibrationFeedback: _vibrationFeedback,
    );
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.instance.fetchProfile();
    if (!mounted) return;
    setState(() {
      if (profile != null) {
        _stepGoal = profile.stepGoal ?? kDefaultStepGoal;
        _activeTimeGoal = profile.activeMinutesGoal ?? kDefaultActiveMinutesGoal;
        _calorieGoal = profile.calorieGoal ?? kDefaultCalorieGoal;
      }
      _takeSnapshot();
    });
  }

  Future<bool> _confirmDiscardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard Changes?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'You have unsaved changes on this screen. Leaving now will discard them.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Manrope', color: AppTheme.textSecondary(ctx)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Discard',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Theme.of(ctx).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    // Kept in sync on every rebuild rather than threaded through each
    // individual onChanged callback above - simpler, and every field change
    // already triggers a rebuild via its own setState anyway. Safe to set
    // synchronously here: SettingsDirtyState has no listeners that rebuild
    // anything reactively (AppNavigation only reads .value at tap-time), so
    // this can't trigger a setState-during-build issue.
    SettingsDirtyState.instance.value = _hasUnsavedChanges;
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await _confirmDiscardDialog();
        if (discard && mounted) {
          SettingsDirtyState.instance.discard();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ProfileSettingsWidget(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GoalSettingsWidget(
                  stepGoal: _stepGoal,
                  activeTimeGoal: _activeTimeGoal,
                  calorieGoal: _calorieGoal,
                  onStepGoalChanged: (v) => setState(() => _stepGoal = v),
                  onActiveTimeChanged: (v) =>
                      setState(() => _activeTimeGoal = v),
                  onCalorieGoalChanged: (v) => setState(() => _calorieGoal = v),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AppearanceSettingsWidget(
                  themeMode: themeProvider.themeMode,
                  onThemeModeChanged: themeProvider.setThemeMode,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: UnitsSettingsWidget(
                  useMetric: _useMetric,
                  onUnitChanged: (v) => setState(() => _useMetric = v),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: NotificationSettingsWidget(
                  goalReminders: _goalReminders,
                  morningReminder: _morningReminder,
                  eveningReminder: _eveningReminder,
                  vibrationFeedback: _vibrationFeedback,
                  onGoalRemindersChanged: (v) =>
                      setState(() => _goalReminders = v),
                  onMorningChanged: (v) => setState(() => _morningReminder = v),
                  onEveningChanged: (v) => setState(() => _eveningReminder = v),
                  onVibrationChanged: (v) =>
                      setState(() => _vibrationFeedback = v),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                child: _buildDangerZone(context),
              ),
            ),
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
          GestureDetector(
            onTap: () => context.go(AppRoutes.activityDashboardScreen),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppTheme.textBright(context),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Settings',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          _isSavingProfile
              ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.stepsGreen,
              ),
            ),
          )
              : TextButton(
            onPressed: _hasUnsavedChanges ? _saveSettings : null,
            child: Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _hasUnsavedChanges
                    ? AppTheme.stepsGreen
                    : AppTheme.textDisabled(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error.withAlpha(77),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DANGER ZONE',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: error,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showSignOutDialog(context),
            borderRadius: BorderRadius.circular(10),
            splashColor: error.withAlpha(26),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: error.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: error,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: error,
                          ),
                        ),
                        Text(
                          'Sign out of your account',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 16),
          InkWell(
            onTap: () => _showResetDialog(context),
            borderRadius: BorderRadius.circular(10),
            splashColor: error.withAlpha(26),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: error.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.restart_alt_rounded,
                      color: error,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset All Goals',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: error,
                          ),
                        ),
                        Text(
                          'Restore default step, time, and calorie targets',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 16),
          InkWell(
            onTap: () => _showDeleteAccountDialog(context),
            borderRadius: BorderRadius.circular(10),
            splashColor: error.withAlpha(26),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: error.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: error,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: error,
                          ),
                        ),
                        Text(
                          'Permanently delete your account and all data',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Saves only Goals (Units/Notifications have no backend field to persist
  /// to yet - a pre-existing gap, unchanged by this phase). Profile is no
  /// longer touched here at all - it's self-contained in
  /// ProfileSettingsWidget with its own inline Save. Every field left null
  /// below is left untouched server-side, per ProfileService's partial-
  /// update convention.
  Future<void> _saveSettings() async {
    if (!_hasUnsavedChanges) return;
    setState(() => _isSavingProfile = true);

    final request = UserProfile(
      id: '',
      email: '',
      fullName: '',
      profileCompleted: true,
      stepGoal: _stepGoal,
      activeMinutesGoal: _activeTimeGoal,
      calorieGoal: _calorieGoal,
    );

    var success = true;
    try {
      await ProfileService.instance.saveProfile(request);
    } on ApiException {
      success = false;
    }

    if (!mounted) return;
    setState(() {
      _isSavingProfile = false;
      if (success) _takeSnapshot();
    });
    SettingsDirtyState.instance.value = _hasUnsavedChanges;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Settings saved successfully' : 'Failed to save settings',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: success
            ? AppTheme.stepsGreen
            : Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Goals?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This will restore default targets:\n• Steps: 6,000/day\n• Active time: 90 min/day\n• Calories: 500 kcal/day',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: AppTheme.textSecondary(ctx),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _stepGoal = kDefaultStepGoal;
                _activeTimeGoal = kDefaultActiveMinutesGoal;
                _calorieGoal = kDefaultCalorieGoal;
              });
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Reset',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Theme.of(ctx).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'You will be returned to the login screen.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: AppTheme.textSecondary(ctx),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<AuthProvider>().signOut();
              if (mounted) context.go(AppRoutes.loginScreen);
            },
            child: Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Theme.of(ctx).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Account?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This action is permanent and cannot be undone. Your account and all associated data will be deleted.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: AppTheme.textSecondary(ctx),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteAccount();
            },
            child: Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Theme.of(ctx).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final success = await context.read<AuthProvider>().deleteAccount();

    if (!mounted) return;

    if (success) {
      context.go(AppRoutes.loginScreen);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Failed to delete account. Please try again.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// The last-loaded/last-saved values [_SettingsScreenState]'s dirty-check
/// compares live state against - see [_SettingsScreenState._hasUnsavedChanges].
class _GoalsSnapshot {
  final int stepGoal;
  final int activeTimeGoal;
  final int calorieGoal;
  final bool useMetric;
  final bool goalReminders;
  final bool morningReminder;
  final bool eveningReminder;
  final bool vibrationFeedback;

  const _GoalsSnapshot({
    required this.stepGoal,
    required this.activeTimeGoal,
    required this.calorieGoal,
    required this.useMetric,
    required this.goalReminders,
    required this.morningReminder,
    required this.eveningReminder,
    required this.vibrationFeedback,
  });
}
