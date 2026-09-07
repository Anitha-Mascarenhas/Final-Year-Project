import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/prediction_result.dart';
import '../theme/app_theme.dart';

class AnalysisResultsScreen extends StatelessWidget {
  final PredictionResult result;
  final VoidCallback onReset;

  const AnalysisResultsScreen({
    super.key,
    required this.result,
    required this.onReset,
  });

  String _formatLabel(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'healthy':
        return 'Normal Nutrition';
      case 'underweight':
        return 'Underweight Detected';
      case 'stunted':
        return 'Stunting Detected';
      case 'stunted and underweight':
        return 'Stunting & Underweight Detected';
      default:
        return prediction.toUpperCase();
    }
  }

  String _formatDescription(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'healthy':
        return "The scan indicates the child's nutritional metrics fall within the healthy range for their age group.";
      case 'underweight':
        return "The scan indicates the child may be underweight for their age group. Please consult a healthcare provider for further assessment.";
      case 'stunted':
        return "The scan indicates signs of stunting, which may reflect chronic nutritional deficiency. Please consult a healthcare provider promptly.";
      case 'stunted and underweight':
        return "The scan indicates the child may be both stunted and underweight, suggesting significant nutritional concern. Please consult a healthcare provider as soon as possible.";
      default:
        return "The AI analysis has completed. Please review the results below.";
    }
  }

  Color _statusAccentColor(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'healthy':
        return AppTheme.accentMint;
      case 'underweight':
        return const Color(0xFFFFF3E0);
      case 'stunted':
        return const Color(0xFFFFF3E0);
      case 'stunted and underweight':
        return const Color(0xFFFDECEA);
      default:
        return AppTheme.accentMint;
    }
  }

  Color _statusTextColor(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'healthy':
        return AppTheme.primaryDark;
      case 'underweight':
        return const Color(0xFFE65100);
      case 'stunted':
        return const Color(0xFFE65100);
      case 'stunted and underweight':
        return const Color(0xFFBA1A1A);
      default:
        return AppTheme.primaryDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prediction = result.prediction;
    final confidence = result.confidence;
    final probabilities = result.probabilities;

    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final textMuted = AppTheme.textColorMuted(context);
    final cardBg = AppTheme.cardBgColor(context);
    final cardBgAlt = AppTheme.cardBgAltColor(context);
    final borderColor = AppTheme.borderColorValue(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'ASSESSMENT COMPLETED',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analysis Results',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'AI-powered nutritional screening based on optical MUAC measurement and biometric visual analysis.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Primary Result Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _statusAccentColor(prediction),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatLabel(prediction),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _statusTextColor(prediction),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDescription(prediction),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _statusTextColor(prediction),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Confidence Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONFIDENCE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: confidence,
                          minHeight: 10,
                          backgroundColor: borderColor,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${(confidence * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Probability Breakdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROBABILITY BREAKDOWN',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                ..._buildProbabilityRows(probabilities, prediction, textPrimary, textSecondary, borderColor),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Disclaimer
          Text(
            'DISCLAIMER',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This AI screening is intended as a preliminary assessment tool and does not replace professional medical advice. Please consult a qualified healthcare provider for definitive diagnosis and treatment.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Action Buttons
          Center(
            child: TextButton(
              onPressed: onReset,
              child: Text(
                'Discard analysis and re-scan',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProbabilityRows(
    Map<String, double> probabilities,
    String prediction,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final entries = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((entry) {
      final isPrimary = entry.key.toLowerCase() == prediction.toLowerCase();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPrimary)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          _capitalizeEachWord(entry.key),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
                            color: isPrimary ? AppTheme.primary : textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(entry.value * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
                    color: isPrimary ? AppTheme.primary : textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: entry.value,
                minHeight: 6,
                backgroundColor: borderColor,
                color: isPrimary ? AppTheme.primary : AppTheme.accentBlue,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _capitalizeEachWord(String text) {
    return text
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
