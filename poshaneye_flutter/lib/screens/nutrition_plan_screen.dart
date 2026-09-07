import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/meal_item.dart';
import '../models/nutrition_preferences.dart';
import '../services/food_recommendation_engine.dart';
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

  // Preferences state
  NutritionPreferences _prefs = NutritionPreferences(
    availableFoods: {'Rice', 'Dal', 'Banana', 'Vegetables', 'Milk'},
    budget: 'budget_friendly',
  );

  @override
  void initState() {
    super.initState();
    _generateMeals();
  }

  FoodRecommendationEngine get _engine => FoodRecommendationEngine(
        child: widget.child,
        preferences: _prefs,
      );

  void _generateMeals() {
    final suggestions = _engine.generateDayPlan();
    final times = ['8:00 AM', '12:30 PM', '3:30 PM', '7:00 PM'];
    final icons = [
      Icons.wb_sunny_outlined,
      Icons.restaurant_outlined,
      Icons.apple,
      Icons.nightlight_round,
    ];
    final mealTypes = ['Breakfast', 'Lunch', 'Afternoon Snack', 'Dinner'];

    _meals = List.generate(suggestions.length, (i) {
      final s = suggestions[i];
      return MealItem(
        id: 'm${i + 1}',
        mealType: mealTypes[i],
        time: times[i],
        title: s.title,
        icon: icons[i],
        tags: _tagsFromLabels(s.tags),
      );
    });
  }

  List<MealTag> _tagsFromLabels(List<String> labels) {
    return labels.map((label) {
      switch (label) {
        case 'Protein':
          return MealTag(label: label, icon: Icons.fitness_center, bgClass: const Color(0xFFB0CDBB), textClass: const Color(0xFF324C3E));
        case 'Iron':
          return MealTag(label: label, icon: Icons.local_fire_department, bgClass: const Color(0xFFB0CDBB), textClass: const Color(0xFF324C3E));
        case 'Fiber':
          return MealTag(label: label, icon: Icons.grain, bgClass: AppTheme.accentMint, textClass: AppTheme.accentSage);
        case 'Energy':
          return MealTag(label: label, icon: Icons.bolt, bgClass: AppTheme.accentMint, textClass: AppTheme.accentSage);
        case 'Vitamins':
          return MealTag(label: label, icon: Icons.auto_awesome, bgClass: const Color(0xFFBFC9BF), textClass: const Color(0xFF404941));
        case 'Calcium':
          return MealTag(label: label, icon: Icons.water_drop, bgClass: const Color(0xFFB0CDBB), textClass: const Color(0xFF324C3E));
        case 'Digestion':
          return MealTag(label: label, icon: Icons.eco, bgClass: AppTheme.accentMint, textClass: AppTheme.accentSage);
        default:
          return MealTag(label: label, icon: Icons.circle, bgClass: AppTheme.accentMint, textClass: AppTheme.accentSage);
      }
    }).toList();
  }

  void _handleSwapMeal(String mealId) {
    final meal = _meals.firstWhere((m) => m.id == mealId);
    final swaps = _engine.suggestSwaps(meal.mealType);

    if (swaps.isEmpty) return;

    setState(() => _swappingId = mealId);

    // Show swap options bottom sheet
    _showSwapSheet(meal, swaps);
  }

  void _showSwapSheet(MealItem meal, List<MealSuggestion> swaps) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBg = AppTheme.cardBgColor(context);
    final borderColor = AppTheme.borderColorValue(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Swap ${meal.mealType}',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose an alternative that works for your family',
              style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 16),
            ...swaps.map((swap) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _applySwap(meal.id, swap);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: swap.usesAvailableFood
                            ? (isDark ? AppTheme.darkCardAlt : const Color(0xFFF0F7F2))
                            : cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: swap.usesAvailableFood
                              ? AppTheme.primary.withValues(alpha: 0.3)
                              : borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: swap.usesAvailableFood
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : (isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              swap.usesAvailableFood ? Icons.check_circle_outline : Icons.add_circle_outline,
                              color: swap.usesAvailableFood ? AppTheme.primary : textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  swap.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                if (swap.tags.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    children: swap.tags.take(3).map((t) => Text(
                                          t,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: textSecondary,
                                          ),
                                        )).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (swap.usesAvailableFood)
                            Text(
                              'Available',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _swappingId = null);
    });
  }

  void _applySwap(String mealId, MealSuggestion swap) {
    setState(() {
      _meals = _meals.map((m) {
        if (m.id != mealId) return m;
        return m.copyWith(
          title: swap.title,
          tags: _tagsFromLabels(swap.tags),
        );
      }).toList();
      _swappingId = null;
    });
  }

  void _updatePreferences(NutritionPreferences newPrefs) {
    setState(() {
      _prefs = newPrefs;
      _generateMeals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${widget.child.name}'s Nutrition Plan",
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Simple food ideas based on what\u2019s available at home. Feel free to swap items.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Personalize Card
          _buildPersonalizeCard(context),
          const SizedBox(height: 24),

          // Meal Timeline
          _buildMealTimeline(context),
          const SizedBox(height: 24),

          // Quick Tip Card
          _buildQuickTipCard(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // PERSONALIZE CARD
  // ══════════════════════════════════════════════════════════════════

  Widget _buildPersonalizeCard(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBg = AppTheme.cardBgColor(context);
    final borderColor = AppTheme.borderColorValue(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final foodCount = _prefs.availableFoods.length;
    final budgetLabel = _prefs.budget == 'budget_friendly'
        ? 'Budget-friendly'
        : _prefs.budget == 'moderate'
            ? 'Moderate'
            : 'Flexible';

    return GestureDetector(
      onTap: () => _showPreferencesSheet(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Personalize this plan',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildInfoChip('$foodCount foods selected', Icons.restaurant, textSecondary, isDark),
                _buildInfoChip(budgetLabel, Icons.account_balance_wallet, textSecondary, isDark),
                if (_prefs.region != null)
                  _buildInfoChip(_prefs.region!, Icons.location_on_outlined, textSecondary, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color textSecondary, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
          ),
        ],
      ),
    );
  }

  void _showPreferencesSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBg = AppTheme.cardBgColor(context);
    final borderColor = AppTheme.borderColorValue(context);

    Set<String> selectedFoods = Set.from(_prefs.availableFoods);
    String selectedBudget = _prefs.budget;
    String? selectedRegion = _prefs.region;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personalize Meal Plan',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close, color: textSecondary, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tell us what foods are usually available at home',
                style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food Availability
                      Text(
                        'Foods available at home',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: NutritionPreferences.allFoods.map((food) {
                          final isSelected = selectedFoods.contains(food);
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                if (isSelected) {
                                  selectedFoods.remove(food);
                                } else {
                                  selectedFoods.add(food);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary.withValues(alpha: 0.12)
                                    : (isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primary : borderColor,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    Icon(Icons.check, size: 14, color: AppTheme.primary)
                                  else
                                    Icon(Icons.add, size: 14, color: textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    food,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? AppTheme.primary : textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Budget
                      Text(
                        'Food budget',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This helps us suggest affordable options',
                        style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildBudgetChip('Budget-friendly', selectedBudget, (val) {
                            setSheetState(() => selectedBudget = val);
                          }, isDark, textPrimary),
                          const SizedBox(width: 8),
                          _buildBudgetChip('Moderate', selectedBudget, (val) {
                            setSheetState(() => selectedBudget = val);
                          }, isDark, textPrimary),
                          const SizedBox(width: 8),
                          _buildBudgetChip('Flexible', selectedBudget, (val) {
                            setSheetState(() => selectedBudget = val);
                          }, isDark, textPrimary),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Region
                      Text(
                        'Where do you live?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Helps suggest locally available foods',
                        style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRegion,
                            hint: Text(
                              'Select your state',
                              style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                            ),
                            isExpanded: true,
                            dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                            items: NutritionPreferences.regions.map((region) {
                              return DropdownMenuItem(
                                value: region,
                                child: Text(
                                  region,
                                  style: GoogleFonts.inter(fontSize: 13, color: textPrimary),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setSheetState(() => selectedRegion = val);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updatePreferences(NutritionPreferences(
                              availableFoods: selectedFoods,
                              budget: selectedBudget,
                              region: selectedRegion,
                            ));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Update Meal Plan',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetChip(String label, String currentValue, ValueChanged<String> onChanged, bool isDark, Color textPrimary) {
    final isSelected = currentValue.toLowerCase().replaceAll(' ', '_') == label.toLowerCase().replaceAll(' ', '_');
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final value = label.toLowerCase().replaceAll(' ', '_');
          onChanged(value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : (isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primary : textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MEAL TIMELINE
  // ══════════════════════════════════════════════════════════════════

  Widget _buildMealTimeline(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBg = AppTheme.cardBgColor(context);
    final borderColor = AppTheme.borderColorValue(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        color: isDark
                            ? AppTheme.darkBorder
                            : const Color(0xFFBFC9BF),
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
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03), blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              meal.mealType,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCardAlt : AppTheme.lightCardAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              meal.time,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
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
                          color: textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tags + Swap Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
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
                          ),

                          // Swap Option Button
                          GestureDetector(
                            onTap: _swappingId == meal.id ? null : () => _handleSwapMeal(meal.id),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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

  // ══════════════════════════════════════════════════════════════════
  // QUICK TIP
  // ══════════════════════════════════════════════════════════════════

  Widget _buildQuickTipCard(BuildContext context) {
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBgAlt = AppTheme.cardBgAltColor(context);
    final borderColor = AppTheme.borderColorValue(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBgAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
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
                  'Keep portions small and introduce one new food at a time. These are simple food ideas, not medical advice. Please consult a healthcare professional for specific dietary concerns.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textSecondary,
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
