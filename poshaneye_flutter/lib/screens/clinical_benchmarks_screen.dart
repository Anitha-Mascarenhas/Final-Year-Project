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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildStatCards(),
        const SizedBox(height: 20),
        _buildGrowthTrendCard(),
        const SizedBox(height: 20),
        _buildTable(),
        const SizedBox(height: 28),
        _buildClinicalInsight(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WHO CHILD GROWTH STANDARDS',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
                      color: AppTheme.primary, letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Text('Clinical Nutrition\nBenchmarks',
                  style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface, letterSpacing: -0.5, height: 1.1)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: ['Boys', 'Girls'].map((g) {
              final sel = _selectedGender == g;
              return GestureDetector(
                onTap: () => setState(() => _selectedGender = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.surfaceContainerLowest : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : null,
                  ),
                  child: Text(g,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                          color: sel ? AppTheme.primary : AppTheme.onSurfaceVariant)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    final stats = [
      _Stat(icon: Icons.monitor_weight_outlined, label: 'Median Weight', value: '12.2', unit: 'kg',
          color: AppTheme.secondaryContainer.withOpacity(0.4), textColor: AppTheme.onSecondaryContainer),
      _Stat(icon: Icons.straighten, label: 'Median Height', value: '87.8', unit: 'cm',
          color: AppTheme.primaryContainer.withOpacity(0.15), textColor: AppTheme.primary),
      _Stat(icon: Icons.my_location, label: 'MUAC (Green)', value: '> 12.5', unit: 'cm',
          color: AppTheme.tertiaryFixed.withOpacity(0.2), textColor: const Color(0xFF00796B)),
    ];
    return Row(
      children: stats.expand((s) => [
        Expanded(child: _StatCard(stat: s)),
        if (s != stats.last) const SizedBox(width: 10),
      ]).toList(),
    );
  }

  Widget _buildGrowthTrendCard() {
    final bars = [0.40, 0.55, 0.70, 0.85, 0.95, 0.80, 0.60, 0.75];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Growth Trend',
              style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
          const SizedBox(height: 4),
          Text('Aggregate percentile curve (0-24m)',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((h) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 80 * h,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.25),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.trending_up, color: AppTheme.secondary, size: 16),
              const SizedBox(width: 6),
              Text('+1.2% deviance threshold',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.surfaceContainerLow),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) return AppTheme.surfaceContainerHigh;
              return AppTheme.surfaceContainerLowest;
            }),
            columnSpacing: 20,
            headingTextStyle: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppTheme.onSurfaceVariant, letterSpacing: 1),
            dataTextStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurface),
            columns: const [
              DataColumn(label: Text('AGE')),
              DataColumn(label: Text('WEIGHT')),
              DataColumn(label: Text('HEIGHT')),
              DataColumn(label: Text('MUAC')),
              DataColumn(label: Text('STATUS')),
            ],
            rows: _tableData.map((row) => DataRow(
              cells: [
                DataCell(Text(row['age']!,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.primary))),
                DataCell(Text('${row['weight']} kg')),
                DataCell(Text('${row['height']} cm')),
                DataCell(Text(row['muac']!)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: row['status'] == 'Optimal'
                          ? AppTheme.primaryContainer.withOpacity(0.2)
                          : AppTheme.secondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(row['status']!,
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: row['status'] == 'Optimal' ? AppTheme.primary : AppTheme.onSecondaryContainer)),
                  ),
                ),
              ],
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildClinicalInsight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuClrJUHsmu9xMu-IaybVsrOslR-FsWwbxO60wbWcsxjl98YxI6qUet7sGFnRmhI2yxJgQVXrWboawc7N3wRpiyvj-n6RLniJMtGEEE4pJr1fvHIJ8gbZhHys34i9trJvkLMYWccEUjpuKFZfT3gaFMQmrTWfkWDCxbhTlIHEUuUHLCQKBYNoW0jpavaLbw47KjZ5WLFG3Xv52uNcSWmHQ7G9he8e3Io8LF51d7YjrgyUOqVH7vp3t1NmyiyGMgKC6qrc4SP8tSA-_sY',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              color: AppTheme.surfaceContainerHigh,
              child: const Icon(Icons.image, size: 48, color: AppTheme.outlineVariant),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppTheme.onSecondaryContainer),
              const SizedBox(width: 6),
              Text('Clinical Insight',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppTheme.onSecondaryContainer)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Proactive Monitoring of Growth Velocities',
            style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w700,
                color: AppTheme.onSurface, letterSpacing: -0.5, height: 1.2)),
        const SizedBox(height: 10),
        Text(
          "Growth monitoring shouldn't just be about meeting current benchmarks. Our AI engine tracks the rate of change to identify potential stunting up to 3 months before traditional methods detect visible symptoms.",
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.6),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download),
            label: Text('Download Growth Charts (PDF)',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color textColor;
  const _Stat({required this.icon, required this.label, required this.value,
    required this.unit, required this.color, required this.textColor});
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stat.color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: stat.textColor, size: 22),
          const SizedBox(height: 8),
          Text(stat.label.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700,
                  color: stat.textColor, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: stat.textColor),
              children: [
                TextSpan(text: stat.value, style: const TextStyle(fontSize: 18)),
                TextSpan(text: ' ${stat.unit}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
