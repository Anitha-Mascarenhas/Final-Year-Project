import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/child_profile.dart';
import '../models/prediction_result.dart';
import '../models/vital_record.dart';
import '../theme/app_theme.dart';

class HealthReportScreen extends StatelessWidget {
  final ChildProfile child;
  final VitalRecord vitals;
  final PredictionResult result;
  final VoidCallback onNewScan;
  final VoidCallback onViewNutritionPlan;

  const HealthReportScreen({
    super.key,
    required this.child,
    required this.vitals,
    required this.result,
    required this.onNewScan,
    required this.onViewNutritionPlan,
  });

  Color _predictionColor(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'healthy':
        return const Color(0xFF16A34A); // green
      case 'underweight':
        return const Color(0xFFEA580C); // orange
      case 'stunted':
        return const Color(0xFFDC2626); // red
      case 'stunted and underweight':
        return const Color(0xFF9333EA); // purple
      default:
        return AppTheme.primary;
    }
  }

  IconData _predictionIcon(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'healthy':
        return Icons.check_circle_outline;
      case 'underweight':
        return Icons.warning_amber_rounded;
      case 'stunted':
        return Icons.error_outline;
      case 'stunted and underweight':
        return Icons.priority_high;
      default:
        return Icons.info_outline;
    }
  }

  String _predictionLabel(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'healthy':
        return 'Healthy';
      case 'underweight':
        return 'Underweight';
      case 'stunted':
        return 'Stunted';
      case 'stunted and underweight':
        return 'Stunted & Underweight';
      default:
        return prediction;
    }
  }

  String _explanation(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'healthy':
        return 'The screening result does not indicate one of the modeled malnutrition categories. Continue monitoring your child\'s growth regularly.';
      case 'underweight':
        return 'The screening result indicates that the child\'s measurements are associated with the underweight category in the model. Consider following up with a healthcare professional.';
      case 'stunted':
        return 'The screening result indicates that the child\'s measurements are associated with the stunted category in the model. Consider consulting a healthcare professional for guidance.';
      case 'stunted and underweight':
        return 'The model classified the screening as both stunted and underweight. This suggests the child may benefit from professional nutritional support.';
      default:
        return 'The screening has been completed. Please consult a healthcare professional to understand the results.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBg = AppTheme.cardBgColor(context);
    final borderColor = AppTheme.borderColorValue(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final predictionColor = _predictionColor(result.prediction);

    final confidencePercent = (result.confidence * 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBgColor(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: onNewScan,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios, size: 16, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Back to Scan',
                      style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Health Report',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Screening result for ${child.name}',
                style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
              ),
              const SizedBox(height: 8),
              // Scan timestamp
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 14, color: textSecondary),
                    const SizedBox(width: 6),
                    Text(
                  'Scan completed ${DateFormat('d MMMM yyyy \u2022 h:mm a').format(result.scanTimestamp)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ══════════════════════════════════════════════════════════
              // A. PREDICTION RESULT CARD
              // ══════════════════════════════════════════════════════════
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04), blurRadius: 12),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: predictionColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _predictionIcon(result.prediction),
                        color: predictionColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Screening Result',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _predictionLabel(result.prediction),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: predictionColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: predictionColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Confidence: $confidencePercent%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: predictionColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ══════════════════════════════════════════════════════════
              // B. PROBABILITY BREAKDOWN
              // ══════════════════════════════════════════════════════════
              _buildSectionHeader('Probability Breakdown', textPrimary),
              const SizedBox(height: 12),
              _buildProbabilityCard(context, result.probabilities, textPrimary, textSecondary, cardBg, borderColor, isDark),
              const SizedBox(height: 20),

              // ══════════════════════════════════════════════════════════
              // C. CHILD SUMMARY
              // ══════════════════════════════════════════════════════════
              _buildSectionHeader('Child Summary', textPrimary),
              const SizedBox(height: 12),
              _buildChildSummaryCard(context, textPrimary, textSecondary, cardBg, borderColor, isDark),
              const SizedBox(height: 20),

              // ══════════════════════════════════════════════════════════
              // D. GROWTH MEASUREMENTS
              // ══════════════════════════════════════════════════════════
              _buildSectionHeader('Growth Measurements', textPrimary),
              const SizedBox(height: 12),
              _buildMeasurementsCard(context, textPrimary, textSecondary, cardBg, borderColor, isDark),
              const SizedBox(height: 20),

              // ══════════════════════════════════════════════════════════
              // E. UNDERSTAND THE RESULT
              // ══════════════════════════════════════════════════════════
              _buildSectionHeader('Understand the Result', textPrimary),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  _explanation(result.prediction),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ══════════════════════════════════════════════════════════
              // F. NEXT STEPS
              // ══════════════════════════════════════════════════════════
              _buildSectionHeader('What You Can Do Next', textPrimary),
              const SizedBox(height: 12),
              _buildNextStepsCard(context, textPrimary, textSecondary, cardBg, borderColor, isDark),
              const SizedBox(height: 24),

              // ══════════════════════════════════════════════════════════
              // G. ACTION BUTTONS
              // ══════════════════════════════════════════════════════════
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onViewNutritionPlan,
                  icon: const Icon(Icons.restaurant_outlined, size: 20),
                  label: Text(
                    'View Nutrition Plan',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: onNewScan,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(
                    'Start New Scan',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 2),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Medical disclaimer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardAlt : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is an AI-based screening tool, not a medical diagnosis. Please consult a qualified healthcare professional for clinical decisions.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textPrimary) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    );
  }

  // ── Probability Breakdown ──────────────────────────────────────

  Widget _buildProbabilityCard(
    BuildContext context,
    Map<String, double> probabilities,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    // Order: healthy, underweight, stunted, stunted and underweight
    final orderedKeys = [
      'healthy',
      'underweight',
      'stunted',
      'stunted and underweight',
    ];

    // Filter to only keys that exist in the response
    final displayKeys = orderedKeys.where((k) => probabilities.containsKey(k)).toList();

    // Add any remaining keys not in the predefined order
    for (final key in probabilities.keys) {
      if (!displayKeys.contains(key)) {
        displayKeys.add(key);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: displayKeys.map((key) {
          final value = probabilities[key] ?? 0;
          final percent = (value * 100).toStringAsFixed(1);
          final color = _predictionColor(key);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _predictionLabel(key),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: isDark ? AppTheme.darkCardAlt : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Child Summary ──────────────────────────────────────────────

  Widget _buildChildSummaryCard(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    final ageText = child.ageYears > 0
        ? '${child.ageYears}y ${child.ageMonths}m'
        : '${child.ageMonths} months';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: child.gender.toLowerCase() == 'girl'
                ? const Icon(Icons.girl, color: AppTheme.primary, size: 28)
                : const Icon(Icons.boy, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$ageText • ${child.gender[0].toUpperCase()}${child.gender.substring(1)}',
                  style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                ),
                if (child.status.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      child.status,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Growth Measurements ────────────────────────────────────────

  Widget _buildMeasurementsCard(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    final measurements = [
      {'label': 'Height', 'value': '${vitals.height} cm', 'icon': Icons.height},
      {'label': 'Weight', 'value': '${vitals.weight} kg', 'icon': Icons.monitor_weight_outlined},
      {'label': 'MUAC', 'value': '${vitals.muac} cm', 'icon': Icons.straighten},
      {'label': 'BMI', 'value': '${vitals.bmi.toStringAsFixed(1)}', 'icon': Icons.calculate_outlined},
      {'label': 'Head Circumference', 'value': vitals.headCircumference != null ? '${vitals.headCircumference} cm' : 'Not recorded', 'icon': Icons.record_voice_over},
      {'label': 'Age', 'value': '${child.ageYears}y ${child.ageMonths}m', 'icon': Icons.cake_outlined},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: measurements.map((m) {
          final isLast = m == measurements.last;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(m['icon'] as IconData, size: 18, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m['label'] as String,
                    style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                  ),
                ),
                Text(
                  m['value'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Next Steps ─────────────────────────────────────────────────

  Widget _buildNextStepsCard(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    final steps = [
      'Continue monitoring ${child.name}\'s growth measurements regularly.',
      'Follow the personalized nutrition suggestions in the app.',
      'If you have concerns about ${child.name}\'s growth, consult a qualified healthcare professional.',
      'Keep track of feeding patterns and any changes in appetite.',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
