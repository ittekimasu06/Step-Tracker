import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class ActivityRingWidget extends StatefulWidget {
  final double stepsProgress;
  final double activeProgress;
  final double caloriesProgress;

  const ActivityRingWidget({
    required this.stepsProgress,
    required this.activeProgress,
    required this.caloriesProgress,
    super.key,
  });

  @override
  State<ActivityRingWidget> createState() => _ActivityRingWidgetState();
}

class _ActivityRingWidgetState extends State<ActivityRingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(15), width: 1),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Column(
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: _TripleRingPainter(
                    stepsProgress: widget.stepsProgress * _animation.value,
                    activeProgress: widget.activeProgress * _animation.value,
                    caloriesProgress:
                        widget.caloriesProgress * _animation.value,
                  ),
                  child: Center(child: _buildHeartIcon()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeartIcon() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.stepsGreen,
          AppTheme.activeBlue,
          AppTheme.caloriesPurple,
        ],
      ).createShader(bounds),
      child: const Icon(Icons.favorite_rounded, size: 72, color: Colors.white),
    );
  }
}

class _TripleRingPainter extends CustomPainter {
  final double stepsProgress;
  final double activeProgress;
  final double caloriesProgress;

  const _TripleRingPainter({
    required this.stepsProgress,
    required this.activeProgress,
    required this.caloriesProgress,
  });

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
    Color color,
    double strokeWidth,
  ) {
    // Track
    final trackPaint = Paint()
      ..color = color.withAlpha(46)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi * progress.clamp(0.0, 1.0),
        colors: [color.withAlpha(153), color],
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );

    // End cap dot
    if (progress > 0.02) {
      final angle = -math.pi / 2 + 2 * math.pi * progress.clamp(0.0, 1.0);
      final dotOffset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotOffset, strokeWidth / 2, dotPaint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 14.0;
    const gap = 10.0;

    _drawRing(
      canvas,
      center,
      90,
      stepsProgress,
      AppTheme.stepsGreen,
      strokeWidth,
    );
    _drawRing(
      canvas,
      center,
      90 - strokeWidth - gap,
      activeProgress,
      AppTheme.activeBlue,
      strokeWidth,
    );
    _drawRing(
      canvas,
      center,
      90 - 2 * (strokeWidth + gap),
      caloriesProgress,
      AppTheme.caloriesPurple,
      strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_TripleRingPainter old) =>
      old.stepsProgress != stepsProgress ||
      old.activeProgress != activeProgress ||
      old.caloriesProgress != caloriesProgress;
}
