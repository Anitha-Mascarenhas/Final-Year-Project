import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AnalysisResultsScreen extends StatelessWidget {
  final VoidCallback onReset;
  const AnalysisResultsScreen({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ASSESSMENT COMPLETED',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('Analysis Results',
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'AI-powered nutritional screening based on optical MUAC measurement and biometric visual analysis.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.accentMint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Normal Nutrition', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                const SizedBox(height: 8),
                Text(
                  "The scan indicates the child's nutritional metrics fall within the healthy range for their age group.",
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkGreenText, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: onReset,
              child: Text('Discard analysis and re-scan',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
