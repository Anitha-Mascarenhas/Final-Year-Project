import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/vital_record.dart';
import '../theme/app_theme.dart';
import '../widgets/growth_chart.dart';

class BMICalculatorScreen extends StatefulWidget {
  final ChildProfile child;
  final VitalRecord vitals;
  final ValueChanged<VitalRecord> onAddRecord;

  const BMICalculatorScreen({
    super.key,
    required this.child,
    required this.vitals,
    required this.onAddRecord,
  });

  @override
  State<BMICalculatorScreen> createState() => _BMICalculatorScreenState();
}

class _BMICalculatorScreenState extends State<BMICalculatorScreen> {
  bool _showWeight = true;

  // Sample data - replace with real data when available
  final List<FlSpot> _weightData = [
    const FlSpot(0, 12.0),
    const FlSpot(1, 12.8),
    const FlSpot(2, 13.5),
    const FlSpot(3, 14.0),
    const FlSpot(4, 14.2),
  ];

  final List<FlSpot> _heightData = [
    const FlSpot(0, 85.0),
    const FlSpot(1, 87.5),
    const FlSpot(2, 89.0),
    const FlSpot(3, 91.0),
    const FlSpot(4, 92.5),
  ];

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBg = AppTheme.cardBgColor(context);
    final borderColor = AppTheme.borderColorValue(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Growth Tracking',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monitor ${widget.child.name}\'s growth over time',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // Toggle between Weight/Height
          _buildToggleBar(isDark),

          const SizedBox(height: 16),

          // Growth Chart
          GrowthChart(
            weightData: _weightData,
            heightData: _heightData,
            showWeight: _showWeight,
            childName: widget.child.name,
          ),

          const SizedBox(height: 16),

          // Quick Stats
          _buildQuickStats(textPrimary, textSecondary, cardBg, borderColor),

          const SizedBox(height: 16),

          // WHO Info Card
          _buildWHOInfoCard(textPrimary, textSecondary, cardBg, borderColor),
        ],
      ),
    );
  }

  Widget _buildToggleBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2248) : const Color(0xFFE3E2DF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showWeight = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _showWeight
                      ? (isDark ? AppTheme.darkSurface : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Weight',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _showWeight ? AppTheme.accentGreen : AppTheme.textColorMuted(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showWeight = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_showWeight
                      ? (isDark ? AppTheme.darkSurface : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Height',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: !_showWeight ? AppTheme.accentGreen : AppTheme.textColorMuted(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(Color textPrimary, Color textSecondary, Color cardBg, Color borderColor) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Weight',
            value: '${widget.vitals.weight} kg',
            icon: Icons.monitor_weight_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Height',
            value: '${widget.vitals.height} cm',
            icon: Icons.straighten,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'BMI',
            value: widget.vitals.bmi.toStringAsFixed(1),
            icon: Icons.speed,
          ),
        ),
      ],
    );
  }

  Widget _buildWHOInfoCard(Color textPrimary, Color textSecondary, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentMint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHO Growth Standards',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on WHO child growth standards for age group.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final vitalsBg = AppTheme.vitalsCardBgColor(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vitalsBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accentSage, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
