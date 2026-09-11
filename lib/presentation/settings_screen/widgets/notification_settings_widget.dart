import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class NotificationSettingsWidget extends StatelessWidget {
  final bool goalReminders;
  final bool morningReminder;
  final bool eveningReminder;
  final bool vibrationFeedback;
  final ValueChanged<bool> onGoalRemindersChanged;
  final ValueChanged<bool> onMorningChanged;
  final ValueChanged<bool> onEveningChanged;
  final ValueChanged<bool> onVibrationChanged;

  const NotificationSettingsWidget({
    required this.goalReminders,
    required this.morningReminder,
    required this.eveningReminder,
    required this.vibrationFeedback,
    required this.onGoalRemindersChanged,
    required this.onMorningChanged,
    required this.onEveningChanged,
    required this.onVibrationChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.overlay(context, 15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, 'NOTIFICATIONS'),
          const SizedBox(height: 12),
          _ToggleRow(
            icon: Icons.notifications_active_outlined,
            iconColor: AppTheme.totalOrange,
            title: 'Goal Reminders',
            subtitle: 'Alert when approaching daily targets',
            value: goalReminders,
            onChanged: onGoalRemindersChanged,
          ),
          _divider(context),
          _ToggleRow(
            icon: Icons.wb_sunny_outlined,
            iconColor: AppTheme.stepsGreen,
            title: 'Morning Check-in',
            subtitle: 'Daily nudge at 7:00 AM',
            value: morningReminder,
            onChanged: onMorningChanged,
          ),
          _divider(context),
          _ToggleRow(
            icon: Icons.nights_stay_outlined,
            iconColor: AppTheme.activeBlue,
            title: 'Evening Summary',
            subtitle: 'End-of-day recap at 9:00 PM',
            value: eveningReminder,
            onChanged: onEveningChanged,
          ),
          _divider(context),
          _ToggleRow(
            icon: Icons.vibration_rounded,
            iconColor: AppTheme.caloriesPurple,
            title: 'Haptic Feedback',
            subtitle: 'Vibrate on goal milestones',
            value: vibrationFeedback,
            onChanged: onVibrationChanged,
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1, color: AppTheme.overlay(context, 13)),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary(context),
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(38),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}