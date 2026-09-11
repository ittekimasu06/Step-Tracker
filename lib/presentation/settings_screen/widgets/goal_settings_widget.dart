import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class GoalSettingsWidget extends StatelessWidget {
  final int stepGoal;
  final int activeTimeGoal;
  final int calorieGoal;
  final ValueChanged<int> onStepGoalChanged;
  final ValueChanged<int> onActiveTimeChanged;
  final ValueChanged<int> onCalorieGoalChanged;

  const GoalSettingsWidget({
    required this.stepGoal,
    required this.activeTimeGoal,
    required this.calorieGoal,
    required this.onStepGoalChanged,
    required this.onActiveTimeChanged,
    required this.onCalorieGoalChanged,
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
            'DAILY GOALS',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _GoalSliderRow(
            label: 'Step Goal',
            value: stepGoal.toDouble(),
            min: 1000,
            max: 20000,
            divisions: 190,
            color: AppTheme.stepsGreen,
            displayValue: _formatSteps(stepGoal),
            unit: 'steps',
            onChanged: (v) => onStepGoalChanged(v.round()),
          ),
          const SizedBox(height: 16),
          _GoalSliderRow(
            label: 'Active Time Goal',
            value: activeTimeGoal.toDouble(),
            min: 10,
            max: 180,
            divisions: 170,
            color: AppTheme.activeBlue,
            displayValue: '$activeTimeGoal',
            unit: 'min',
            onChanged: (v) => onActiveTimeChanged(v.round()),
          ),
          const SizedBox(height: 16),
          _GoalSliderRow(
            label: 'Calorie Goal',
            value: calorieGoal.toDouble(),
            min: 100,
            max: 2000,
            divisions: 190,
            color: AppTheme.caloriesPurple,
            displayValue: '$calorieGoal',
            unit: 'kcal',
            onChanged: (v) => onCalorieGoalChanged(v.round()),
          ),
        ],
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(steps % 1000 == 0 ? 0 : 1)}k';
    }
    return steps.toString();
  }
}

class _GoalSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final String displayValue;
  final String unit;
  final ValueChanged<double> onChanged;

  const _GoalSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.displayValue,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textBright(context),
              ),
            ),
            Row(
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: color,
            inactiveTrackColor: color.withAlpha(51),
            thumbColor: color,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayColor: color.withAlpha(38),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${min.toInt()}',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                color: AppTheme.textMuted(context),
              ),
            ),
            Text(
              '${max.toInt()}',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                color: AppTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}