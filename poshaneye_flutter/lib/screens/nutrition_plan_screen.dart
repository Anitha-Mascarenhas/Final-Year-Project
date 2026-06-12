import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class NutritionPlanScreen extends StatelessWidget {
  const NutritionPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildRecapCards(),
        const SizedBox(height: 28),
        Text("Today's Regimen",
            style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w700,
                color: AppTheme.onSurface, letterSpacing: -0.5)),
        const SizedBox(height: 20),
        _buildMealTimeline(),
        const SizedBox(height: 28),
        _buildWhyCard(),
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
              Text('Nutrition Protocol',
                  style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800,
                      color: AppTheme.primary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Personalized clinical recommendations',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.refresh, size: 18),
          label: Text('Generate New', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ],
    );
  }

  Widget _buildRecapCards() {
    final cards = [
      ('Patient Age', '24 Months', AppTheme.primary),
      ('Risk Level', 'Moderate', AppTheme.error),
      ('Plan Goal', 'Fortification', AppTheme.secondary),
      ('Daily Kcal', '1,250', Colors.teal),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: cards.map((c) => _RecapCard(label: c.$1, value: c.$2, borderColor: c.$3)).toList(),
    );
  }

  Widget _buildMealTimeline() {
    final meals = [
      _MealData(time: '08:00 AM', type: 'Breakfast', title: 'Fortified Porridge with Banana',
          tags: ['Iron High', '280 kcal', 'Fiber 4g'], icon: Icons.wb_sunny_outlined),
      _MealData(time: '01:00 PM', type: 'Lunch', title: 'Lentil Stew with Steamed Spinach',
          tags: ['Protein 12g', '420 kcal', 'Vit A High'], icon: Icons.restaurant_outlined),
      _MealData(time: '04:30 PM', type: 'Afternoon Snack', title: 'Greek Yogurt with Crushed Walnuts',
          tags: ['Calcium 15%', '150 kcal', 'Omega 3'], icon: Icons.cookie_outlined),
      _MealData(time: '07:30 PM', type: 'Dinner', title: 'Mashed Sweet Potato & Grilled Fish',
          tags: ['DHA + EPA', '340 kcal', 'Zinc 2mg'], icon: Icons.bedtime_outlined),
    ];

    return Column(
      children: meals.asMap().entries.map((entry) {
        final i = entry.key;
        final m = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dot + line
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.surfaceContainerLowest, width: 2),
                    ),
                    child: Icon(m.icon, size: 18, color: AppTheme.primary),
                  ),
                  if (i < meals.length - 1)
                    Container(
                      width: 2,
                      height: 80,
                      color: AppTheme.outlineVariant.withOpacity(0.4),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(child: _MealCard(meal: m)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWhyCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primaryFixed.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.description_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Why this plan?',
                      style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                  Text('Clinical Rationale & Evidence',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.primaryFixed),
          const SizedBox(height: 16),
          _WhySection(
            title: 'Cognitive Development',
            desc: 'The inclusion of DHA-rich fish and walnuts supports the rapid neural myelination occurring during the 24-month developmental window.',
          ),
          const SizedBox(height: 16),
          _WhySection(
            title: 'Anemia Prevention',
            desc: 'Combining lentils (non-heme iron) with spinach (vitamin C) optimizes absorption rates, specifically addressing the identified moderate risk level.',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppTheme.secondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This protocol is based on WHO Pediatric Nutrition Guidelines for stunted growth prevention in high-risk demographic clusters.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic, height: 1.5),
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

class _MealData {
  final String time;
  final String type;
  final String title;
  final List<String> tags;
  final IconData icon;
  const _MealData({required this.time, required this.type, required this.title,
    required this.tags, required this.icon});
}

class _RecapCard extends StatelessWidget {
  final String label;
  final String value;
  final Color borderColor;
  const _RecapCard({required this.label, required this.value, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceVariant, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface)),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final _MealData meal;
  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(meal.type,
                  style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
              Text(meal.time,
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          Text(meal.title,
              style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: meal.tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(tag,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _WhySection extends StatelessWidget {
  final String title;
  final String desc;
  const _WhySection({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
        const SizedBox(height: 4),
        Text(desc, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.55)),
      ],
    );
  }
}
