import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../theme/app_theme.dart';

class BMICalculatorScreen extends StatefulWidget {
  const BMICalculatorScreen({super.key});

  @override
  State<BMICalculatorScreen> createState() => _BMICalculatorScreenState();
}

class _BMICalculatorScreenState extends State<BMICalculatorScreen> {
  String _gender = 'boy';
  int _age = 7;
  double _height = 122;
  double _weight = 24.5;

  double get bmi {
    final h = _height / 100;
    return _weight / (h * h);
  }

  String get bmiCategory {
    final b = bmi;
    if (b < 13) return 'Underweight';
    if (b < 18) return 'Normal';
    if (b < 22) return 'Overweight';
    return 'Obese';
  }

  Color get bmiColor {
    final b = bmi;
    if (b < 13) return Colors.blue;
    if (b < 18) return AppTheme.secondary;
    if (b < 22) return Colors.orange;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildGenderSelector(),
        const SizedBox(height: 20),
        _buildAgeStepper(),
        const SizedBox(height: 20),
        _buildSlider(
          label: 'Height (cm)',
          value: _height,
          min: 50,
          max: 220,
          onChanged: (v) => setState(() => _height = v),
          displayValue: '${_height.toStringAsFixed(0)} cm',
          marks: ['50cm', '135cm', '220cm'],
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: 'Weight (kg)',
          value: _weight,
          min: 5,
          max: 150,
          onChanged: (v) => setState(() => _weight = v),
          displayValue: '${_weight.toStringAsFixed(1)} kg',
          marks: ['5kg', '77kg', '150kg'],
        ),
        const SizedBox(height: 28),
        _buildBMIResult(),
        const SizedBox(height: 20),
        _buildCategoryBar(),
        const SizedBox(height: 20),
        _buildInsightCard(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            child: Text('Save to Growth Journal',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildHealthPillars(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Clinical Analysis',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppTheme.onSecondaryContainer, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: GoogleFonts.montserrat(fontSize: 34, fontWeight: FontWeight.w800,
                color: AppTheme.onSurface, letterSpacing: -1),
            children: [
              const TextSpan(text: 'Growth '),
              TextSpan(
                text: 'Precision.',
                style: GoogleFonts.montserrat(color: AppTheme.primary, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Track your child's BMI accurately with our clinical-grade calculator designed for pediatric development cycles.",
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECT GENDER',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceVariant, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _GenderButton(label: 'Boy', selected: _gender == 'boy',
                    onTap: () => setState(() => _gender = 'boy')),
                _GenderButton(label: 'Girl', selected: _gender == 'girl',
                    onTap: () => setState(() => _gender = 'girl')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeStepper() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AGE (YEARS)',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant, letterSpacing: 1.5)),
              Text('$_age',
                  style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove,
                onTap: () => setState(() => _age = max(0, _age - 1)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _age / 20,
                      minHeight: 8,
                      backgroundColor: AppTheme.surfaceContainerHigh,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: () => setState(() => _age = min(20, _age + 1)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String displayValue,
    required List<String> marks,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant, letterSpacing: 1)),
              Text(displayValue,
                  style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.primary)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.surfaceContainerHigh,
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: marks.map((m) => Text(m,
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
                    color: AppTheme.outline, letterSpacing: 0.5))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBMIResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Text("Your Child's BMI",
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.8), letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bmi.toStringAsFixed(1),
                  style: GoogleFonts.montserrat(fontSize: 72, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -2, height: 1)),
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(bmiCategory.toUpperCase(),
                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w800,
                        color: AppTheme.onSecondaryContainer)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Healthier than 68% of children the same age.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.7), height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEVELOPMENT CATEGORY',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceVariant, letterSpacing: 1)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(flex: 15, child: Container(height: 14, color: Colors.blue[300])),
                Expanded(flex: 45, child: Container(height: 14, color: AppTheme.secondaryContainer)),
                Expanded(flex: 20, child: Container(height: 14, color: Colors.orange[300])),
                Expanded(flex: 20, child: Container(height: 14, color: AppTheme.errorContainer)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Underweight', 'Healthy', 'Overweight', 'Obese'].map((l) =>
                Text(l, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
                    color: AppTheme.onSurfaceVariant))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb, color: AppTheme.secondary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Growth Insight',
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'A BMI of ${bmi.toStringAsFixed(1)} is optimal for a $_age-year-old ${_gender}. Continue focusing on diverse whole foods and active play.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthPillars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Health Pillars',
            style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w800,
                color: AppTheme.onSurface, letterSpacing: -0.5)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _PillarCard(icon: Icons.restaurant, title: 'Balanced Diet',
                desc: 'Optimal micronutrients for bone density.',
                color: AppTheme.surfaceContainerLow, textColor: AppTheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: _PillarCard(icon: Icons.directions_run, title: 'Active Play',
                desc: '60 mins of daily vigorous movement.',
                color: AppTheme.secondaryContainer, textColor: AppTheme.onSecondaryContainer)),
            const SizedBox(width: 10),
            Expanded(child: _PillarCard(icon: Icons.bedtime, title: 'Restorative Sleep',
                desc: 'Essential for growth hormone release.',
                color: AppTheme.tertiaryContainer, textColor: AppTheme.onTertiaryContainer)),
          ],
        ),
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.child_care, size: 18,
                    color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
                        color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: AppTheme.onSurface),
      ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final Color textColor;
  const _PillarCard({required this.icon, required this.title, required this.desc,
    required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: textColor, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 2),
              Text(desc, style: GoogleFonts.inter(fontSize: 10, color: textColor.withOpacity(0.7), height: 1.4)),
            ],
          ),
        ],
      ),
    );
  }
}
