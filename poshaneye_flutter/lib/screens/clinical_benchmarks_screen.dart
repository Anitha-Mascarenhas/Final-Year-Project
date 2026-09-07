import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ClinicalBenchmarksScreen extends StatefulWidget {
  const ClinicalBenchmarksScreen({super.key});

  @override
  State<ClinicalBenchmarksScreen> createState() => _ClinicalBenchmarksScreenState();
}

class _ClinicalBenchmarksScreenState extends State<ClinicalBenchmarksScreen> {
  String _selectedGender = 'Boys';

  final List<Map<String, String>> _tableData = [
    {'age': 'Birth', 'weight': '3.3', 'height': '49.9', 'muac': '10.5 — 11.2', 'status': 'Standard'},
    {'age': '6 Months', 'weight': '7.9', 'height': '67.6', 'muac': '12.1 — 13.5', 'status': 'Standard'},
    {'age': '12 Months', 'weight': '9.6', 'height': '75.7', 'muac': '13.5 — 14.8', 'status': 'Optimal'},
    {'age': '18 Months', 'weight': '10.9', 'height': '82.3', 'muac': '14.1 — 15.2', 'status': 'Standard'},
    {'age': '24 Months', 'weight': '12.2', 'height': '87.8', 'muac': '14.5 — 15.8', 'status': 'Standard'},
  ];

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBg = AppTheme.cardBgColor(context);
    final cardBgAlt = AppTheme.cardBgAltColor(context);
    final borderColor = AppTheme.borderColorValue(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(textPrimary, textSecondary, cardBg, isDark),
          const SizedBox(height: 24),
          _buildTable(textPrimary, textSecondary, cardBg, cardBgAlt, borderColor),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary, Color cardBg, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHO CHILD GROWTH STANDARDS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Clinical Nutrition Benchmarks',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: ['Boys', 'Girls'].map((g) {
              final sel = _selectedGender == g;
              return GestureDetector(
                onTap: () => setState(() => _selectedGender = g),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? (isDark ? AppTheme.darkSurface : Colors.white) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    g,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppTheme.primary : textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(Color textPrimary, Color textSecondary, Color cardBg, Color cardBgAlt, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('AGE')),
              DataColumn(label: Text('WEIGHT')),
              DataColumn(label: Text('HEIGHT')),
              DataColumn(label: Text('MUAC')),
              DataColumn(label: Text('STATUS')),
            ],
            rows: _tableData.map((row) => DataRow(
              cells: [
                DataCell(Text(row['age']!, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.primary))),
                DataCell(Text('${row['weight']} kg', style: TextStyle(color: textPrimary))),
                DataCell(Text('${row['height']} cm', style: TextStyle(color: textPrimary))),
                DataCell(Text(row['muac']!, style: TextStyle(color: textPrimary))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: row['status'] == 'Optimal' ? AppTheme.accentMint : cardBgAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      row['status']!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: row['status'] == 'Optimal' ? AppTheme.primary : textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            )).toList(),
          ),
        ),
      ),
    );
  }
}
