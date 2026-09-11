import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';

class HourlyChartSectionWidget extends StatefulWidget {
  final List<Map<String, dynamic>> hourlyData;
  final String label;
  final Color color;
  final String dataKey;
  final String peakTimeLabel;
  final String unit;

  const HourlyChartSectionWidget({
    required this.hourlyData,
    required this.label,
    required this.color,
    required this.dataKey,
    required this.peakTimeLabel,
    required this.unit,
    super.key,
  });

  @override
  State<HourlyChartSectionWidget> createState() =>
      _HourlyChartSectionWidgetState();
}

class _HourlyChartSectionWidgetState extends State<HourlyChartSectionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleY = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _maxValue {
    double max = 1;
    for (final d in widget.hourlyData) {
      final v = (d[widget.dataKey] as num).toDouble();
      if (v > max) max = v;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = _maxValue;

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
            widget.label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 12,
                color: AppTheme.textSecondary(context),
              ),
              const SizedBox(width: 4),
              Text(
                'Most active: ${widget.peakTimeLabel}',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _scaleY,
            builder: (context, _) {
              return SizedBox(
                height: 80,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceBetween,
                    maxY: maxVal * 1.15,
                    minY: 0,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        tooltipRoundedRadius: 8,
                        tooltipBgColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final val =
                              (widget.hourlyData[group.x][widget.dataKey]
                                      as num)
                                  .toInt();
                          if (val == 0) return null;
                          return BarTooltipItem(
                            '${group.x}:00\n$val${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''}',
                            TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              color: widget.color,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 18,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final h = value.toInt();
                            if (h == 0 || h == 6 || h == 12 || h == 18) {
                              return Text(
                                '$h',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 10,
                                  color: AppTheme.textMuted(context),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxVal / 2,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppTheme.overlay(context, 13),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: widget.hourlyData.map((d) {
                      final h = (d['hour'] as int);
                      final rawVal = (d[widget.dataKey] as num).toDouble();
                      final animatedVal = rawVal * _scaleY.value;
                      return BarChartGroupData(
                        x: h,
                        barRods: [
                          BarChartRodData(
                            toY: animatedVal,
                            color: animatedVal > 0
                                ? widget.color
                                : Colors.transparent,
                            width: 6,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxVal * 1.15,
                              color: Colors.transparent,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  color: AppTheme.textMuted(context),
                ),
              ),
              Text(
                '(hrs)',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  color: AppTheme.textMuted(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}