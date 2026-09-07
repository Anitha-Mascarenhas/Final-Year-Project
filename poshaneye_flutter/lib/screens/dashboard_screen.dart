import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/vital_record.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  final ChildProfile child;
  final VitalRecord vitals;
  final ValueChanged<int> onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.child,
    required this.vitals,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBg = AppTheme.cardBgColor(context);
    final vitalsBg = AppTheme.vitalsCardBgColor(context);
    final borderColor = AppTheme.borderColorValue(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Greeting
          _buildGreeting(child, textPrimary, textSecondary),
          const SizedBox(height: 16),

          // Growth Status Summary Card
          _buildGrowthStatusCard(child, textPrimary, textSecondary, cardBg, borderColor),
          const SizedBox(height: 12),

          // Current Vitals Card (3 Columns)
          _buildCurrentVitalsCard(vitals, textPrimary, textSecondary, vitalsBg),
          const SizedBox(height: 12),

          // Latest Assessment Card
          _buildLatestAssessmentCard(textPrimary, textSecondary, cardBg, borderColor, context),
          const SizedBox(height: 16),

          // Action Buttons
          _buildActionButtons(context, onNavigateTab),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGreeting(ChildProfile child, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning,',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${child.name} is doing well.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthStatusCard(ChildProfile child, Color textPrimary, Color textSecondary, Color cardBg, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'GROWTH STATUS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Normal Growth',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${child.name} remains in the healthy percentile for his age group.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentVitalsCard(VitalRecord vitals, Color textPrimary, Color textSecondary, Color vitalsBg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vitalsBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Vitals',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                vitals.date,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _VitalItem(
                  label: 'Weight',
                  value: '${vitals.weight}',
                  unit: 'kg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VitalItem(
                  label: 'Height',
                  value: '${vitals.height}',
                  unit: 'cm',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VitalItem(
                  label: 'MUAC',
                  value: '${vitals.muac}',
                  unit: 'cm',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLatestAssessmentCard(Color textPrimary, Color textSecondary, Color cardBg, Color borderColor, BuildContext context) {
    final cardBgAlt = AppTheme.cardBgAltColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_turned_in_outlined, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest Assessment',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last scan was 2 days ago. Healthy nutritional milestones.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => onNavigateTab(1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View report',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14, color: AppTheme.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ValueChanged<int> onNavigateTab) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => onNavigateTab(2),
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            label: Text(
              'Start New Scan',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => onNavigateTab(3),
            icon: const Icon(Icons.restaurant_outlined, size: 20),
            label: Text(
              'Nutrition Plan',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _VitalItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _VitalItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              children: [
                TextSpan(text: value, style: const TextStyle(fontSize: 16)),
                TextSpan(text: ' $unit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
