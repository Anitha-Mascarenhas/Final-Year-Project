import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_eye_logo.dart';

class NutritionPlanScreen extends StatefulWidget {
  final String childName;

  const NutritionPlanScreen({
    Key? key,
    this.childName = 'Aarav',
  }) : super(key: key);

  @override
  State<NutritionPlanScreen> createState() => _NutritionPlanScreenState();
}

class _MealData {
  final String id;
  final String category;
  final String time;
  final IconData icon;
  int currentOptionIndex = 0;
  bool isExpanded = false;
  bool isSwapping = false;
  final List<Map<String, String>> options;

  _MealData({
    required this.id,
    required this.category,
    required this.time,
    required this.icon,
    required this.options,
  });
}

class _NutritionPlanScreenState extends State<NutritionPlanScreen> {
  bool _isDarkMode = false;
  Timer? _timer;
  final int _startMinutes = 8 * 60; // 8:00 AM
  final int _endMinutes = 19 * 60; // 7:00 PM

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _calculateDayProgress() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    if (currentMinutes <= _startMinutes) return 0.0;
    if (currentMinutes >= _endMinutes) return 1.0;

    return (currentMinutes - _startMinutes) / (_endMinutes - _startMinutes);
  }

  Color get _pageBackground =>
      _isDarkMode ? const Color(0xFF14241B) : const Color(0xFFEEF3ED);
  Color get _primaryText =>
      _isDarkMode ? const Color(0xFFE8F2EA) : const Color(0xFF0C2417);
  Color get _secondaryText =>
      _isDarkMode ? const Color(0xFFA9C0B1) : const Color(0xFF556D5E);
  Color get _cardColor => _isDarkMode ? const Color(0xFF1D3528) : Colors.white;
  Color get _cardBorder =>
      _isDarkMode ? const Color(0xFF34513F) : const Color(0xFFE2EAE2);
  Color get _softSurface =>
      _isDarkMode ? const Color(0xFF294535) : const Color(0xFFF1F6F1);
  Color get _timelineSurface =>
      _isDarkMode ? const Color(0xFF294535) : const Color(0xFFE3ECE3);

  late final List<_MealData> _meals = [
    _MealData(
      id: 'breakfast',
      category: 'Breakfast',
      time: '8:00 AM',
      icon: Icons.coffee,
      options: [
        {
          'title': 'Oatmeal with mashed bananas & almond dust',
          'nutrition':
              'Nutritional value: Approx. 220 kcal · 7 g protein · 5 g fiber',
        },
        {
          'title': 'Warm ragi porridge with grated apples & almonds',
          'nutrition':
              'Nutritional value: Approx. 220 kcal · 7 g protein · 5 g fiber',
        },
        {
          'title': 'Steamed idli with mild vegetable sambar & coconut drizzle',
          'nutrition':
              'Nutritional value: Approx. 205 kcal · 6.5 g protein · 4.5 g fiber',
        },
      ],
    ),
    _MealData(
      id: 'lunch',
      category: 'Lunch',
      time: '12:30 PM',
      icon: Icons.restaurant,
      options: [
        {
          'title': 'Soft lentil soup (Dal) with mashed rice & ghee',
          'nutrition':
              'Nutritional value: Approx. 340 kcal · 11 g protein · 6 g fiber',
        },
        {
          'title': 'Mashed khichdi with ghee and steamed carrots',
          'nutrition':
              'Nutritional value: Approx. 315 kcal · 10.5 g protein · 6.5 g fiber',
        },
        {
          'title': 'Curd rice with steamed beetroot & tempered cumin',
          'nutrition':
              'Nutritional value: Approx. 290 kcal · 9.2 g protein · 4.8 g fiber',
        },
      ],
    ),
    _MealData(
      id: 'snack',
      category: 'Afternoon Snack',
      time: '3:30 PM',
      icon: Icons.apple,
      options: [
        {
          'title': 'Thinly sliced apples or pureed fruit with curd',
          'nutrition':
              'Nutritional value: Approx. 135 kcal · 3.5 g protein · 4.2 g fiber',
        },
        {
          'title': 'Roasted makhana with mashed banana puree',
          'nutrition':
              'Nutritional value: Approx. 145 kcal · 4 g protein · 3.8 g fiber',
        },
      ],
    ),
    _MealData(
      id: 'dinner',
      category: 'Dinner',
      time: '7:00 PM',
      icon: Icons.nightlight_round,
      options: [
        {
          'title': 'Steamed vegetables and pumpkin porridge',
          'nutrition':
              'Nutritional value: Approx. 235 kcal · 5.5 g protein · 6.2 g fiber',
        },
        {
          'title': 'Soft moong dal cheela with mild mint dip',
          'nutrition':
              'Nutritional value: Approx. 250 kcal · 9 g protein · 5.5 g fiber',
        },
      ],
    ),
  ];

  void _swapMeal(_MealData meal) async {
    if (meal.isSwapping) return;
    setState(() => meal.isSwapping = true);

    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;

    setState(() {
      meal.currentOptionIndex =
          (meal.currentOptionIndex + 1) % meal.options.length;
      meal.isSwapping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeTransition(
      isDark: _isDarkMode,
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(),
                      const SizedBox(height: 10),
                      _buildTimelineList(),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: _primaryText),
                onPressed: () => Navigator.of(context).pop(),
              ),
              InteractiveEyeLogo(width: 26, color: _primaryText),
              const SizedBox(width: 6),
              Text(
                'Nutrition Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                child: Container(
                  width: 54,
                  height: 28,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _isDarkMode
                        ? const Color(0xFF294535)
                        : const Color(0xFFDFE8DF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDarkMode
                          ? const Color(0xFF45624E)
                          : const Color(0xFFCEDECE),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: _isDarkMode
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF0F3827)
                              : const Color(0xFF2AE196),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                          size: 13,
                          color: _isDarkMode
                              ? Colors.white
                              : const Color(0xFF0C2417),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: _isDarkMode
                    ? const Color(0xFF2AE196)
                    : const Color(0xFF0C2417),
                child: Icon(
                  Icons.person_outline,
                  size: 16,
                  color: _isDarkMode ? const Color(0xFF0C2417) : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${widget.childName}'s Nutrition Plan",
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: _primaryText,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Nourishing meal guide tailored for today.',
            style: TextStyle(
              fontSize: 13.5,
              color: _secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    final progress = _calculateDayProgress();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          // Background Track Line & Animated Fill Line
          Positioned(
            left: 16,
            top: 24,
            bottom: 30,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? const Color(0xFF264232)
                    : const Color(0xFFD3ECE1),
                borderRadius: BorderRadius.circular(2.5),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progress),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: value,
                      child: Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF86BF15),
                          borderRadius: BorderRadius.circular(2.5),
                          boxShadow: [
                            BoxShadow(
                              color: (_isDarkMode
                                      ? const Color(0xFF4ADE80)
                                      : const Color(0xFF86BF15))
                                  .withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Column(
            children: _meals.map((meal) => _buildMealCard(meal)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(_MealData meal) {
    final currentOption = meal.options[meal.currentOptionIndex];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Node
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: _timelineSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isDarkMode
                    ? const Color(0xFF65B879)
                    : const Color(0xFFB5DAB5),
                width: 2,
              ),
            ),
            child: Icon(
              meal.icon,
              size: 16,
              color: _isDarkMode
                  ? const Color(0xFF9BE6AA)
                  : const Color(0xFF2D613D),
            ),
          ),
          const SizedBox(width: 12),

          // Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row category & time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        meal.category,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _primaryText,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _softSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Text(
                          meal.time,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Option title
                  Text(
                    currentOption['title']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isDarkMode
                          ? const Color(0xFFD1E0D4)
                          : const Color(0xFF2C3F33),
                      height: 1.35,
                    ),
                  ),

                  // Expanded info
                  if (meal.isExpanded) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? const Color(0xFF233E2E)
                            : const Color(0xFFFBFDFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Text(
                        currentOption['nutrition']!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Actions: Read More & Swap Option
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => meal.isExpanded = !meal.isExpanded),
                        child: Row(
                          children: [
                            Text(
                              meal.isExpanded ? 'Read less' : 'Read more',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _primaryText,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              meal.isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 16,
                              color: _primaryText,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _swapMeal(meal),
                        child: Row(
                          children: [
                            meal.isSwapping
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF059669)),
                                  )
                                : Icon(Icons.sync,
                                    size: 16, color: _primaryText),
                            const SizedBox(width: 6),
                            Text(
                              meal.isSwapping ? 'Swapping...' : 'Swap Option',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _primaryText,
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
  }
}
