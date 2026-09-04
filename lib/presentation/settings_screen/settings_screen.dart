import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/activity_estimator.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
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

  // Profile (loaded from the backend)
  String _userName = '';
  int _userAge = 0;
  double _userWeightKg = 0;
  double _userHeightCm = 0;

  // Preferences
  bool _useMetric = true;
  bool _goalReminders = true;
  bool _morningReminder = true;
  bool _eveningReminder = false;
  bool _vibrationFeedback = true;

  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.instance.fetchProfile();
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = false;
      if (profile != null) {
        _userName = profile.fullName;
        _userAge = profile.age ?? 0;
        _userWeightKg = profile.weightKg ?? 0;
        _userHeightCm = profile.heightCm ?? 0;
        _stepGoal = profile.stepGoal ?? kDefaultStepGoal;
        _activeTimeGoal = profile.activeMinutesGoal ?? kDefaultActiveMinutesGoal;
        _calorieGoal = profile.calorieGoal ?? kDefaultCalorieGoal;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _isLoadingProfile
                    ? _buildProfileSkeleton()
                    : ProfileSettingsWidget(
                  userName: _userName,
                  userAge: _userAge,
                  weightKg: _userWeightKg,
                  heightCm: _userHeightCm,
                  onNameChanged: (v) => setState(() => _userName = v),
                  onAgeChanged: (v) => setState(() => _userAge = v),
                  onWeightChanged: (v) =>
                      setState(() => _userWeightKg = v),
                  onHeightChanged: (v) =>
                      setState(() => _userHeightCm = v),
                ),
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
    );
  }

  Widget _buildProfileSkeleton() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15), width: 1),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.stepsGreen,
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
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Settings',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE6E6E6),
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
            onPressed: _saveSettings,
            child: const Text(
              'Save',
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
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCF6679).withAlpha(77),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DANGER ZONE',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFCF6679),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showSignOutDialog(context),
            borderRadius: BorderRadius.circular(10),
            splashColor: const Color(0xFFCF6679).withAlpha(26),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCF6679).withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFCF6679),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFCF6679),
                          ),
                        ),
                        Text(
                          'Sign out of your account',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF666666),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 16),
          InkWell(
            onTap: () => _showResetDialog(context),
            borderRadius: BorderRadius.circular(10),
            splashColor: const Color(0xFFCF6679).withAlpha(26),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCF6679).withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restart_alt_rounded,
                      color: Color(0xFFCF6679),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset All Goals',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFCF6679),
                          ),
                        ),
                        Text(
                          'Restore default step, time, and calorie targets',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF666666),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 16),
          InkWell(
            onTap: () => _showDeleteAccountDialog(context),
            borderRadius: BorderRadius.circular(10),
            splashColor: const Color(0xFFCF6679).withAlpha(26),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCF6679).withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFCF6679),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFCF6679),
                          ),
                        ),
                        Text(
                          'Permanently delete your account and all data',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF666666),
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

  Future<void> _saveSettings() async {
    setState(() => _isSavingProfile = true);

    final currentProfile = await ProfileService.instance.fetchProfile();
    final updatedProfile = UserProfile(
      id: currentProfile?.id ?? '',
      email: currentProfile?.email ?? '',
      fullName: _userName,
      age: _userAge > 0 ? _userAge : null,
      weightKg: _userWeightKg > 0 ? _userWeightKg : null,
      heightCm: _userHeightCm > 0 ? _userHeightCm : null,
      gender: currentProfile?.gender,
      profileCompleted: true,
      stepGoal: _stepGoal,
      activeMinutesGoal: _activeTimeGoal,
      calorieGoal: _calorieGoal,
    );

    final success = await ProfileService.instance.saveProfile(updatedProfile);

    if (!mounted) return;
    setState(() => _isSavingProfile = false);

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
            : const Color(0xFFCF6679),
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
        backgroundColor: AppTheme.surfaceVariantDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset Goals?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: Color(0xFFE6E6E6),
          ),
        ),
        content: const Text(
          'This will restore default targets:\n• Steps: 6,000/day\n• Active time: 90 min/day\n• Calories: 500 kcal/day',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: Color(0xFFAAAAAA),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Manrope', color: Color(0xFF888888)),
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
            child: const Text(
              'Reset',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Color(0xFFCF6679),
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
        backgroundColor: AppTheme.surfaceVariantDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: Color(0xFFE6E6E6),
          ),
        ),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: Color(0xFFAAAAAA),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Manrope', color: Color(0xFF888888)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<AuthProvider>().signOut();
              if (mounted) context.go(AppRoutes.loginScreen);
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Color(0xFFCF6679),
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
        backgroundColor: AppTheme.surfaceVariantDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Account?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: Color(0xFFE6E6E6),
          ),
        ),
        content: const Text(
          'This action is permanent and cannot be undone. Your account and all associated data will be deleted.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: Color(0xFFAAAAAA),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Manrope', color: Color(0xFF888888)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteAccount();
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Color(0xFFCF6679),
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
        backgroundColor: const Color(0xFFCF6679),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
