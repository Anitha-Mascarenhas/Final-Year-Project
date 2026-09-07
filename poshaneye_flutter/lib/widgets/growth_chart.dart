import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class GrowthChart extends StatefulWidget {
  final List<FlSpot> weightData;
  final List<FlSpot> heightData;
  final bool showWeight;
  final String childName;

  const GrowthChart({
    super.key,
    required this.weightData,
    required this.heightData,
    this.showWeight = true,
    required this.childName,
  });

  @override
  State<GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<GrowthChart> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animProgress;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final textMuted = AppTheme.textColorMuted(context);
    final borderColor = AppTheme.borderColorValue(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final data = widget.showWeight ? widget.weightData : widget.heightData;
    final unit = widget.showWeight ? 'kg' : 'cm';
    final label = widget.showWeight ? 'Weight' : 'Height';

    // Calculate min/max for y-axis
    double minY = 0;
    double maxY = 100;
    if (data.isNotEmpty) {
      final values = data.map((e) => e.y).toList();
      minY = (values.reduce((a, b) => a < b ? a : b) * 0.8).clamp(0, double.infinity);
      maxY = values.reduce((a, b) => a > b ? a : b) * 1.2;
    }

    return AnimatedBuilder(
      animation: _animProgress,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chart Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (data.isNotEmpty)
                        Text(
                          '${data.last.y.toStringAsFixed(1)} $unit',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: isDark ? AppTheme.accentGreen : AppTheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'On Track',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.accentGreen : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Chart
              SizedBox(
                height: 200,
                child: data.isEmpty
                    ? _buildEmptyState(textSecondary)
                    : LineChart(
                        _buildChartData(data, minY, maxY, textMuted, borderColor, isDark),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                      ),
              ),

              const SizedBox(height: 16),

              // X-axis labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMonthLabel('Jan', textMuted),
                  _buildMonthLabel('Feb', textMuted),
                  _buildMonthLabel('Mar', textMuted),
                  _buildMonthLabel('Apr', textMuted),
                  _buildMonthLabel('Now', textMuted, isHighlight: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  LineChartData _buildChartData(
    List<FlSpot> data,
    double minY,
    double maxY,
    Color textMuted,
    Color borderColor,
    bool isDark,
  ) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: borderColor.withValues(alpha: 0.5),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: textMuted,
                ),
              );
            },
          ),
        ),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: data.length > 1 ? (data.length - 1).toDouble() : 1,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: data,
          isCurved: true,
          curveSmoothness: 0.4,
          color: isDark ? AppTheme.accentGreen : AppTheme.primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) {
              final isLast = index == data.length - 1;
              return FlDotCirclePainter(
                radius: isLast ? 6 : 4,
                color: isDark ? AppTheme.accentGreen : AppTheme.primary,
                strokeWidth: isLast ? 3 : 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (isDark ? AppTheme.accentGreen : AppTheme.primary).withValues(alpha: 0.2),
                (isDark ? AppTheme.accentGreen : AppTheme.primary).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} ${widget.showWeight ? 'kg' : 'cm'}',
                GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.accentGreen : AppTheme.primary,
                ),
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
      ),
    );
  }

  Widget _buildEmptyState(Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart_rounded, size: 48, color: textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'No growth data yet',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add measurements to see the chart',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthLabel(String text, Color color, {bool isHighlight = false}) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
        color: isHighlight ? AppTheme.accentGreen : color,
      ),
    );
  }
}
