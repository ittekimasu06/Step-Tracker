import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AppearanceSettingsWidget extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const AppearanceSettingsWidget({
    required this.themeMode,
    required this.onThemeModeChanged,
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
          Text(
            'APPEARANCE',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.overlay(context, 128),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ThemeModeToggleButton(
                label: 'System',
                sublabel: 'Match device',
                isSelected: themeMode == ThemeMode.system,
                onTap: () => onThemeModeChanged(ThemeMode.system),
              ),
              const SizedBox(width: 8),
              _ThemeModeToggleButton(
                label: 'Light',
                sublabel: 'Always light',
                isSelected: themeMode == ThemeMode.light,
                onTap: () => onThemeModeChanged(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              _ThemeModeToggleButton(
                label: 'Dark',
                sublabel: 'Always dark',
                isSelected: themeMode == ThemeMode.dark,
                onTap: () => onThemeModeChanged(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeModeToggleButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeToggleButton({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.stepsGreen.withAlpha(38)
                : AppTheme.overlay(context, 10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.stepsGreen.withAlpha(128)
                  : AppTheme.overlay(context, 20),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppTheme.stepsGreen
                      : AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  color: isSelected
                      ? AppTheme.stepsGreen.withAlpha(179)
                      : AppTheme.textMuted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
