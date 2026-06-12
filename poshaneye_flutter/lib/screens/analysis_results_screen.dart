import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AnalysisResultsScreen extends StatelessWidget {
  final VoidCallback onReset;
  const AnalysisResultsScreen({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ASSESSMENT COMPLETED',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                color: AppTheme.primary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text('Analysis Results',
            style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w800,
                color: AppTheme.onSurface, letterSpacing: -1)),
        const SizedBox(height: 6),
        Text(
          'AI-powered nutritional screening based on optical MUAC measurement and biometric visual analysis.',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 28),

        // Status card
        _StatusCard(),
        const SizedBox(height: 16),

        // Metrics row
        Row(
          children: [
            Expanded(child: _CircularMetricCard(value: '14.2', unit: 'CM', label: 'MUAC Value',
                sublabel: 'Mid-Upper Arm Circumference', progress: 0.72, color: AppTheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: _CircularMetricCard(value: '98%', unit: 'MATCH', label: 'AI Confidence',
                sublabel: 'Scan Accuracy Rating', progress: 0.98, color: AppTheme.secondary)),
          ],
        ),
        const SizedBox(height: 16),

        // Clinical explanation
        _ClinicalCard(),
        const SizedBox(height: 28),

        // Action buttons
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.picture_as_pdf),
            label: Text('Download PDF Report',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save_alt),
            label: Text('Save to Profile',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: onReset,
            child: Text('Discard analysis and re-scan',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Current Status',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Normal Nutrition',
              style: GoogleFonts.montserrat(fontSize: 36, fontWeight: FontWeight.w800,
                  color: AppTheme.secondary, letterSpacing: -1)),
          const SizedBox(height: 10),
          Text(
            "The scan indicates the child's nutritional metrics fall within the healthy range for their age group. No immediate clinical intervention is required.",
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurfaceVariant, height: 1.6),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppTheme.secondary, size: 16),
                const SizedBox(width: 6),
                Text('Low Risk Profile',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularMetricCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final String sublabel;
  final double progress;
  final Color color;

  const _CircularMetricCard({
    required this.value,
    required this.unit,
    required this.label,
    required this.sublabel,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value,
                        style: GoogleFonts.montserrat(
                            fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.onSurface)),
                    Text(unit,
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
              textAlign: TextAlign.center),
          Text(sublabel,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ClinicalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clinical Explanation',
              style: GoogleFonts.montserrat(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
          const SizedBox(height: 12),
          Text(
            'The AI vision engine analyzed multiple biometric markers including limb volume and skin texture. The detected MUAC of 14.2cm is significantly above the WHO malnutrition threshold (11.5cm).',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.6),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Findings suggest metabolic stability. Recommended follow-up assessment in 30 days to monitor growth velocity and ensure continuous healthy development.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant, height: 1.5),
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
