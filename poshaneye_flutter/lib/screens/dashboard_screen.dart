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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Header
          Text(
            'Good morning,',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${child.name} is doing well.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Growth Status Summary Card
          _buildGrowthStatusCard(),
          const SizedBox(height: 24),

          // Current Vitals Card (3 Columns)
          _buildCurrentVitalsCard(),
          const SizedBox(height: 24),

          // Latest Assessment Card
          _buildLatestAssessmentCard(),
          const SizedBox(height: 28),

          // Action Buttons
          _buildActionButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGrowthStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.accentSage,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'GROWTH STATUS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryContainer,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Normal Growth',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${child.name} remains in the healthy percentile for his age group. Keep up the great work.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentVitalsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.vitalsCardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Vitals',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                vitals.date,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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

  Widget _buildLatestAssessmentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBgAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppTheme.accentMint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_turned_in_outlined, color: AppTheme.accentSage, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest Assessment',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last scan was 2 days ago. The analysis indicates healthy nutritional milestones.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => onNavigateTab(1), // Go to Growth Tracking tab
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View full report',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 16, color: AppTheme.primary),
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Start New Scan
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => onNavigateTab(2), // Scan tab
            icon: const Icon(Icons.qr_code_scanner, size: 22),
            label: Text(
              'Start New Scan',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Nutrition Plan
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () => onNavigateTab(3), // Nutrition tab
            icon: const Icon(Icons.restaurant_outlined, size: 22),
            label: Text(
              'Nutrition Plan',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Ask PoshanAi Voice Assistant
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => onNavigateTab(5), // PoshanAi sheet / tab
            icon: const Icon(Icons.mic, size: 22),
            label: Text(
              'Ask PoshanAi Voice Assistant',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentMint,
              foregroundColor: AppTheme.darkGreenText,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              children: [
                TextSpan(text: value, style: const TextStyle(fontSize: 18)),
                TextSpan(text: ' $unit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
