import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class WeeklyMiniStripWidget extends StatelessWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> dailyData;
  final ValueChanged<DateTime> onDayTap;

  const WeeklyMiniStripWidget({
    required this.selectedDate,
    required this.dailyData,
    required this.onDayTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Build 7-day strip ending today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          final isSelected =
              day.year == selectedDate.year &&
              day.month == selectedDate.month &&
              day.day == selectedDate.day;
          final isToday =
              day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;

          final dateStr =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          Map<String, dynamic>? data;
          try {
            data = dailyData.firstWhere((d) => d['date'] == dateStr);
          } catch (_) {
            data = null;
          }

          final stepsProgress = data != null
              ? ((data['steps'] as num) / (data['stepGoal'] as num))
                    .toDouble()
                    .clamp(0.0, 1.0)
              : 0.0;

          const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
          final label = weekdayLabels[day.weekday - 1];

          return GestureDetector(
            onTap: () => onDayTap(day),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isToday
                        ? AppTheme.stepsGreen
                        : const Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 6),
                _MiniRingWidget(
                  progress: stepsProgress,
                  isSelected: isSelected,
                  isToday: isToday,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MiniRingWidget extends StatelessWidget {
  final double progress;
  final bool isSelected;
  final bool isToday;

  const _MiniRingWidget({
    required this.progress,
    required this.isSelected,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppTheme.stepsGreen : Colors.transparent,
          width: 2,
        ),
      ),
      child: CustomPaint(
        painter: _MiniRingPainter(progress: progress),
        child: Center(
          child: Icon(
            Icons.directions_walk_rounded,
            size: 14,
            color: progress > 0 ? AppTheme.stepsGreen : const Color(0xFF444444),
          ),
        ),
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  const _MiniRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Track
    final trackPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = AppTheme.stepsGreen
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2,
        2 * 3.14159 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) => old.progress != progress;
}
