import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/vital_record.dart';
import '../theme/app_theme.dart';

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
  int _activeSubTab = 0; // 0 = Trends, 1 = Calculator

  // Form State
  late String _gender;
  late int _ageYears;
  late int _ageMonths;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  bool _isCalculating = false;
  Map<String, String>? _calcResult;

  @override
  void initState() {
    super.initState();
    _gender = widget.child.gender;
    _ageYears = widget.child.ageYears;
    _ageMonths = widget.child.ageMonths;
    _weightController = TextEditingController(text: '${widget.vitals.weight}');
    _heightController = TextEditingController(text: '${widget.vitals.height}');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _handleCalculate() {
    setState(() {
      _isCalculating = true;
      _calcResult = null;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      final w = double.tryParse(_weightController.text) ?? widget.vitals.weight;
      final h = double.tryParse(_heightController.text) ?? widget.vitals.height;
      final hMeters = h / 100;
      final bmiVal = w / (hMeters * hMeters);

      final newRecord = VitalRecord(
        weight: w,
        height: h,
        muac: widget.vitals.muac,
        date: 'Today',
        bmi: double.parse(bmiVal.toStringAsFixed(1)),
        percentile: '75th',
      );

      widget.onAddRecord(newRecord);

      if (mounted) {
        setState(() {
          _isCalculating = false;
          _calcResult = {
            'bmi': bmiVal.toStringAsFixed(1),
            'percentile': '75th',
            'status': 'On Track',
            'advice': '${widget.child.name} is tracking beautifully in the healthy range according to WHO growth curves.',
          };
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tab Switcher
          _buildSubTabSwitcher(),
          const SizedBox(height: 24),

          if (_activeSubTab == 0) _buildTrendsView() else _buildCalculatorView(),
        ],
      ),
    );
  }

  Widget _buildSubTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E2DF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSubTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeSubTab == 0 ? AppTheme.background : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: _activeSubTab == 0
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Growth Trends',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSubTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeSubTab == 1 ? AppTheme.background : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: _activeSubTab == 1
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Log & Calculate',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
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

  Widget _buildTrendsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overview Banner Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.child.name} is thriving!',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Following a healthy growth path compared to WHO standards.',
                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'On Track',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Key Metrics Row
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.monitor_weight_outlined,
                value: '${widget.vitals.weight}',
                unit: 'kg',
                label: 'Weight',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                icon: Icons.straighten,
                value: '${widget.vitals.height}',
                unit: 'cm',
                label: 'Height',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Weight Trend Curve Card
        _buildTrendChartCard(
          title: 'Weight Trend',
          months: ['Jan', 'Feb', 'Mar', 'Apr', 'Now'],
          isWeight: true,
        ),
        const SizedBox(height: 24),

        // Height Trend Curve Card
        _buildTrendChartCard(
          title: 'Height Trend',
          months: ['Jan', 'Feb', 'Mar', 'Apr', 'Now'],
          isWeight: false,
        ),
        const SizedBox(height: 24),

        // CTA Add Measurement
        Center(
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _activeSubTab = 1),
            icon: const Icon(Icons.add, size: 20),
            label: Text(
              'Add Measurement',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChartCard({
    required String title,
    required List<String> months,
    required bool isWeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 130,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WHOTrendPainter(isWeight: isWeight),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: months.map((m) {
                  final isNow = m == 'Now';
                  return Text(
                    m,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
                      color: isNow ? AppTheme.accentSage : AppTheme.textSecondary,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Let's check in on their growth.",
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter a few quick details to see how they are tracking today.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),

        // Gender Selector
        Text(
          'WHO ARE WE CHECKING?',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE3E2DF),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _gender = 'boy'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _gender == 'boy' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Center(
                      child: Text(
                        'Boy',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _gender = 'girl'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _gender == 'girl' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Center(
                      child: Text(
                        'Girl',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Age Inputs
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Age (Years)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: '$_ageYears',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _ageYears = int.tryParse(v) ?? 0,
                    decoration: _inputDecoration('e.g. 2'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Months', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: '$_ageMonths',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _ageMonths = int.tryParse(v) ?? 0,
                    decoration: _inputDecoration('e.g. 3'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Weight & Height
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weight (kg)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('14.2', icon: Icons.monitor_weight_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Height (cm)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('92.5', icon: Icons.straighten),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Calculate Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isCalculating ? null : _handleCalculate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: _isCalculating
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text('Calculating WHO Growth...', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Calculate Growth', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),
        ),

        // Calculation Results
        if (_calcResult != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.accentMint,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: AppTheme.primary, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  'Calculation Complete',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _calcResult!['advice']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.darkGreenText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 6),
                          Text('Percentile', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _calcResult!['percentile']!,
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.speed, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 6),
                          Text('BMI', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _calcResult!['bmi']!,
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppTheme.cardBgAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      suffixIcon: icon != null ? Icon(icon, color: AppTheme.textMuted, size: 20) : null,
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _MetricTile({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accentSage, size: 22),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              children: [
                TextSpan(text: value, style: const TextStyle(fontSize: 22)),
                TextSpan(text: ' $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _WHOTrendPainter extends CustomPainter {
  final bool isWeight;
  _WHOTrendPainter({required this.isWeight});

  @override
  void paint(Canvas canvas, Size size) {
    // WHO Corridor Paint
    final corridorPaint = Paint()
      ..color = AppTheme.accentMint.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;

    final activeDotPaint = Paint()
      ..color = AppTheme.accentSage
      ..style = PaintingStyle.fill;

    // Corridor Path
    final corridorPath = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.5, size.width, size.height * 0.25)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(corridorPath, corridorPaint);

    // Child Line
    final linePath = Path()
      ..moveTo(0, size.height * 0.8)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.7,
        size.width * 0.5,
        size.height * 0.45,
        size.width,
        size.height * 0.3,
      );

    canvas.drawPath(linePath, linePaint);

    // Draw Points
    final pts = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.25, size.height * 0.72),
      Offset(size.width * 0.5, size.height * 0.52),
      Offset(size.width * 0.75, size.height * 0.4),
      Offset(size.width, size.height * 0.3),
    ];

    for (int i = 0; i < pts.length; i++) {
      if (i == pts.length - 1) {
        canvas.drawCircle(pts[i], 6, activeDotPaint);
        canvas.drawCircle(pts[i], 8, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
      } else {
        canvas.drawCircle(pts[i], 4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
