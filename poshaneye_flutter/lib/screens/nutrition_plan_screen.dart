import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/meal_item.dart';
import '../theme/app_theme.dart';

class NutritionPlanScreen extends StatefulWidget {
  final ChildProfile child;

  const NutritionPlanScreen({
    super.key,
    required this.child,
  });

  @override
  State<NutritionPlanScreen> createState() => _NutritionPlanScreenState();
}

class _NutritionPlanScreenState extends State<NutritionPlanScreen> {
  late List<MealItem> _meals;
  String? _swappingId;

  @override
  void initState() {
    super.initState();
    _meals = _getInitialMeals();
  }

  List<MealItem> _getInitialMeals() {
    return [
      MealItem(
        id: 'm1',
        mealType: 'Breakfast',
        time: '8:00 AM',
        title: 'Oatmeal with mashed bananas',
        icon: Icons.wb_sunny_outlined,
        tags: [
          MealTag(label: 'Fiber', icon: Icons.grain, bgClass: AppTheme.accentMint, textClass: AppTheme.accentSage),
          MealTag(label: 'Energy', icon: Icons.bolt, bgClass: AppTheme.accentMint, textClass: AppTheme.accentSage),
        ],
      ),
      MealItem(
        id: 'm2',
        mealType: 'Lunch',
        time: '12:30 PM',
        title: 'Soft lentil soup (Dal) with mashed rice',
        icon: Icons.restaurant_outlined,
        tags: [
          MealTag(label: 'Protein', icon: Icons.fitness_center, bgClass: const Color(0xFFB0CDBB), textClass: const Color(0xFF324C3E)),
          MealTag(label: 'Iron', icon: Icons.local_fire_department, bgClass: const Color(0xFFB0CDBB), textClass: const Color(0xFF324C3E)),
        ],
      ),
      MealItem(
        id: 'm3',
        mealType: 'Afternoon Snack',
        time: '3:30 PM',
        title: 'Thinly sliced apples or pureed fruit',
        icon: Icons.apple,
        tags: [
          MealTag(label: 'Vitamins', icon: Icons.auto_awesome, bgClass: const Color(0xFFBFC9BF), textClass: const Color(0xFF404941)),
        ],
      ),
      MealItem(
        id: 'm4',
        mealType: 'Dinner',
        time: '7:00 PM',
        title: 'Steamed vegetables and quinoa porridge',
        icon: Icons.nightlight_round,
        tags: [
          MealTag(label: 'Digestion', icon: Icons.eco, bgClass: AppTheme.accentMint, textClass: AppTheme.accentSage),
          MealTag(label: 'Sleep Aid', icon: Icons.bedtime, bgClass: AppTheme.accentMint, textClass: AppTheme.accentSage),
        ],
      ),
    ];
  }

  void _handleSwapMeal(String mealId) {
    setState(() => _swappingId = mealId);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _meals = _meals.map((m) {
            if (m.id != mealId) return m;
            if (m.mealType == 'Breakfast') {
              return m.copyWith(title: 'Warm ragi porridge with grated apples & almonds');
            } else if (m.mealType == 'Lunch') {
              return m.copyWith(title: 'Mashed khichdi with ghee and steamed carrots');
            } else if (m.mealType == 'Afternoon Snack') {
              return m.copyWith(title: 'Steamed sweet potato sticks with curd dip');
            } else {
              return m.copyWith(title: 'Soft pumpkin soup with whole wheat mini roti');
            }
          }).toList();
          _swappingId = null;
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
          Text(
            "${widget.child.name}'s Nutrition Plan",
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Here is a gentle, nourishing meal guide for today. Feel free to swap items based on what ${widget.child.name} is in the mood for.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Meal Timeline
          _buildMealTimeline(),
          const SizedBox(height: 24),

          // Quick Tip Card
          _buildQuickTipCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMealTimeline() {
    return Column(
      children: List.generate(_meals.length, (index) {
        final meal = _meals[index];
        final isLast = index == _meals.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline Dot + Connecting Line
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentMint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(meal.icon, color: AppTheme.accentSage, size: 20),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: const Color(0xFFBFC9BF),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Meal Card Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            meal.mealType,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              meal.time,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        meal.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tags + Swap Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: 6,
                            children: meal.tags.map((t) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: t.bgClass,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(t.icon, size: 12, color: t.textClass),
                                    const SizedBox(width: 4),
                                    Text(
                                      t.label,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: t.textClass,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                          // Swap Option Button
                          GestureDetector(
                            onTap: _swappingId == meal.id ? null : () => _handleSwapMeal(meal.id),
                            child: Row(
                              children: [
                                _swappingId == meal.id
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                      )
                                    : const Icon(Icons.refresh, size: 14, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _swappingId == meal.id ? 'Swapping...' : 'Swap Option',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildQuickTipCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBgAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A quick tip',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Remember to keep portions small and introduce one new food at a time to monitor for any sensitivities.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
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
