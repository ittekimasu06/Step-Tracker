import 'package:flutter/material.dart';

enum ActivityStatus { onTrack, goalReached, belowGoal }

class StatusBadgeWidget extends StatelessWidget {
  final ActivityStatus status;

  const StatusBadgeWidget({required this.status, super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ActivityStatus.goalReached => ('Goal Reached', const Color(0xFF4CAF50)),
      ActivityStatus.onTrack => ('On Track', const Color(0xFF2196F3)),
      ActivityStatus.belowGoal => ('Below Goal', const Color(0xFF888888)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(102), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
