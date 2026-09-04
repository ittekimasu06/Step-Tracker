import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class UnitsSettingsWidget extends StatelessWidget {
  final bool useMetric;
  final ValueChanged<bool> onUnitChanged;

  const UnitsSettingsWidget({
    required this.useMetric,
    required this.onUnitChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UNITS',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(128),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _UnitToggleButton(
                label: 'Metric',
                sublabel: 'km, kg, cm',
                isSelected: useMetric,
                onTap: () => onUnitChanged(true),
              ),
              const SizedBox(width: 8),
              _UnitToggleButton(
                label: 'Imperial',
                sublabel: 'mi, lb, ft',
                isSelected: !useMetric,
                onTap: () => onUnitChanged(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnitToggleButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitToggleButton({
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
                : Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.stepsGreen.withAlpha(128)
                  : Colors.white.withAlpha(20),
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
                      : const Color(0xFF888888),
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
                      : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}