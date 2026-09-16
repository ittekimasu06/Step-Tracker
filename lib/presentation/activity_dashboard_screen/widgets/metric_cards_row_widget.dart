import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class MetricCardsRowWidget extends StatelessWidget {
  final int steps;
  final int stepGoal;
  final int activeMinutes;
  final int activeGoal;
  final int activityCalories;
  final int calorieGoal;
  final bool vertical;

  const MetricCardsRowWidget({
    required this.steps,
    required this.stepGoal,
    required this.activeMinutes,
    required this.activeGoal,
    required this.activityCalories,
    required this.calorieGoal,
    this.vertical = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        label: 'Steps',
        value: _formatNumber(steps),
        goal: '/${_formatNumber(stepGoal)}',
        color: AppTheme.stepsGreen,
        progress: (steps / stepGoal).clamp(0.0, 1.0),
        unit: '',
      ),
      _MetricCard(
        label: 'Active Time',
        value: '$activeMinutes',
        goal: '/$activeGoal',
        color: AppTheme.activeBlue,
        progress: (activeMinutes / activeGoal).clamp(0.0, 1.0),
        unit: 'min',
      ),
      _MetricCard(
        label: 'Calories',
        value: '$activityCalories',
        goal: '/$calorieGoal',
        color: AppTheme.caloriesPurple,
        progress: (activityCalories / calorieGoal).clamp(0.0, 1.0),
        unit: 'kcal',
      ),
    ];

    if (vertical) {
      return Column(
        children: cards
            .map(
              (c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
            )
            .toList(),
      );
    }

    return Row(
      children: cards
          .map(
            (c) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: cards.indexOf(c) < 2 ? 8 : 0),
                child: c,
              ),
            ),
          )
          .toList(),
    );
  }

  /// Full exact value with thousands separators (e.g. "12,345"), not an
  /// abbreviated "12.3k" form.
  String _formatNumber(int n) {
    final digits = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String goal;
  final Color color;
  final double progress;
  final String unit;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    required this.progress,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(64), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
          Text(
            goal,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withAlpha(38),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
