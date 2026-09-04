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
        goal: '/$stepGoal',
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

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
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
        color: AppTheme.surfaceDark,
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
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ],
          ),
          Text(
            goal,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              color: Color(0xFF888888),
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
