import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class TotalStatsWidget extends StatelessWidget {
  final double totalCalories;
  final double distanceKm;

  const TotalStatsWidget({
    required this.totalCalories,
    required this.distanceKm,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(15), width: 1),
        ),
        child: Column(
          children: [
            _StatRow(
              label: 'Total calories burned',
              value: '${totalCalories.toInt()} kcal',
              valueColor: AppTheme.totalOrange,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Colors.white.withAlpha(15)),
            ),
            _StatRow(
              label: 'Distance during activity',
              value: '${distanceKm.toStringAsFixed(2)} km',
              valueColor: const Color(0xFFE6E6E6),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              color: Color(0xFFAAAAAA),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
