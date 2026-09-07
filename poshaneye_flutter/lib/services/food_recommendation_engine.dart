import '../models/child_profile.dart';
import '../models/nutrition_preferences.dart';

/// A single meal suggestion with title and nutritional tags.
class MealSuggestion {
  final String title;
  final List<String> tags; // e.g. 'Protein', 'Iron', 'Fiber', 'Energy', 'Vitamins'
  final bool usesAvailableFood; // whether this meal uses only available foods

  const MealSuggestion({
    required this.title,
    this.tags = const [],
    this.usesAvailableFood = true,
  });
}

/// Local rule-based recommendation engine.
/// Generates age-appropriate, preference-aware meal suggestions.
class FoodRecommendationEngine {
  final ChildProfile child;
  final NutritionPreferences preferences;

  FoodRecommendationEngine({required this.child, required this.preferences});

  /// Total age in months for age-appropriate recommendations.
  int get _ageMonths => child.ageYears * 12 + child.ageMonths;

  /// Whether child is an infant (< 12 months).
  bool get _isInfant => _ageMonths < 12;

  /// Whether child is a toddler (12-24 months).
  bool get _isToddler => _ageMonths >= 12 && _ageMonths < 24;

  /// Whether the family has this food available.
  bool _has(String food) => preferences.availableFoods.contains(food);

  /// Generate the full day meal plan.
  List<MealSuggestion> generateDayPlan() {
    return [
      _suggestBreakfast(),
      _suggestLunch(),
      _suggestSnack(),
      _suggestDinner(),
    ];
  }

  // ── Breakfast ──────────────────────────────────────────────────

  MealSuggestion _suggestBreakfast() {
    // Priority: use available foods, age-appropriate
    if (_isInfant) {
      if (_has('Ragi')) {
        return MealSuggestion(
          title: 'Ragi porridge with mashed banana',
          tags: ['Fiber', 'Iron', 'Energy'],
        );
      }
      if (_has('Rice')) {
        return MealSuggestion(
          title: 'Rice cereal with mashed banana',
          tags: ['Energy', 'Easy to digest'],
        );
      }
      return MealSuggestion(
        title: 'Mashed banana with breast milk',
        tags: ['Energy', 'Gentle'],
      );
    }

    if (_isToddler) {
      if (_has('Ragi') && _has('Banana')) {
        return MealSuggestion(
          title: 'Ragi porridge with banana',
          tags: ['Fiber', 'Iron', 'Energy'],
        );
      }
      if (_has('Ragi')) {
        return MealSuggestion(
          title: 'Warm ragi porridge with grated apple',
          tags: ['Fiber', 'Iron'],
        );
      }
      if (_has('Rice') && _has('Milk')) {
        return MealSuggestion(
          title: 'Rice kanji with milk',
          tags: ['Energy', 'Calcium'],
        );
      }
      if (_has('Wheat')) {
        return MealSuggestion(
          title: 'Soft wheat upma with vegetables',
          tags: ['Energy', 'Fiber'],
        );
      }
    }

    // Young child (2-5 years) and above
    if (_has('Ragi') && _has('Banana')) {
      return MealSuggestion(
        title: 'Ragi porridge with banana and a dash of ghee',
        tags: ['Fiber', 'Iron', 'Energy'],
      );
    }
    if (_has('Wheat') && _has('Eggs')) {
      return MealSuggestion(
        title: 'Whole wheat paratha with scrambled egg',
        tags: ['Protein', 'Energy', 'Fiber'],
      );
    }
    if (_has('Rice') && _has('Dal')) {
      return MealSuggestion(
        title: 'Soft idli with dal sambar',
        tags: ['Protein', 'Energy'],
      );
    }
    if (_has('Wheat')) {
      return MealSuggestion(
        title: 'Soft chapati with dal',
        tags: ['Protein', 'Fiber'],
      );
    }
    if (_has('Rice')) {
      return MealSuggestion(
        title: 'Rice porridge with ghee',
        tags: ['Energy', 'Easy to digest'],
      );
    }
    return MealSuggestion(
      title: 'Oatmeal with mashed banana',
      tags: ['Fiber', 'Energy'],
    );
  }

  // ── Lunch ──────────────────────────────────────────────────────

  MealSuggestion _suggestLunch() {
    if (_isInfant) {
      if (_has('Rice') && _has('Dal')) {
        return MealSuggestion(
          title: 'Mashed rice with thin dal',
          tags: ['Protein', 'Energy'],
        );
      }
      return MealSuggestion(
        title: 'Soft mashed rice with ghee',
        tags: ['Energy'],
      );
    }

    if (_has('Rice') && _has('Dal') && _has('Vegetables')) {
      return MealSuggestion(
        title: 'Rice, dal, and steamed vegetables',
        tags: ['Protein', 'Iron', 'Vitamins'],
      );
    }
    if (_has('Rice') && _has('Dal')) {
      return MealSuggestion(
        title: 'Rice with dal and a spoon of ghee',
        tags: ['Protein', 'Energy'],
      );
    }
    if (_has('Wheat') && _has('Dal')) {
      return MealSuggestion(
        title: 'Soft roti with dal and vegetables',
        tags: ['Protein', 'Fiber', 'Vitamins'],
      );
    }
    if (_has('Rice')) {
      return MealSuggestion(
        title: 'Mashed rice with ghee',
        tags: ['Energy'],
      );
    }
    if (_has('Wheat')) {
      return MealSuggestion(
        title: 'Khichdi with vegetables',
        tags: ['Energy', 'Easy to digest'],
      );
    }
    return MealSuggestion(
      title: 'Soft khichdi with ghee',
      tags: ['Energy', 'Easy to digest'],
    );
  }

  // ── Snack ──────────────────────────────────────────────────────

  MealSuggestion _suggestSnack() {
    if (_isInfant) {
      if (_has('Banana')) {
        return MealSuggestion(
          title: 'Mashed banana',
          tags: ['Energy', 'Potassium'],
        );
      }
      return MealSuggestion(
        title: 'Steamed and mashed fruit',
        tags: ['Vitamins'],
      );
    }

    if (_has('Banana') && _has('Groundnuts')) {
      return MealSuggestion(
        title: 'Banana with a few roasted groundnuts',
        tags: ['Energy', 'Protein'],
      );
    }
    if (_has('Banana') && _has('Milk')) {
      return MealSuggestion(
        title: 'Banana milkshake',
        tags: ['Energy', 'Calcium'],
      );
    }
    if (_has('Other fruits')) {
      return MealSuggestion(
        title: 'Seasonal fruit slices',
        tags: ['Vitamins', 'Fiber'],
      );
    }
    if (_has('Banana')) {
      return MealSuggestion(
        title: 'Banana',
        tags: ['Energy', 'Potassium'],
      );
    }
    if (_has('Curd')) {
      return MealSuggestion(
        title: 'Curd with a pinch of sugar',
        tags: ['Calcium', 'Probiotics'],
      );
    }
    if (_has('Groundnuts')) {
      return MealSuggestion(
        title: 'Roasted groundnuts',
        tags: ['Protein', 'Energy'],
      );
    }
    return MealSuggestion(
      title: 'Thinly sliced fruit or mashed fruit',
      tags: ['Vitamins'],
    );
  }

  // ── Dinner ─────────────────────────────────────────────────────

  MealSuggestion _suggestDinner() {
    if (_isInfant) {
      if (_has('Rice') && _has('Dal')) {
        return MealSuggestion(
          title: 'Mashed rice with thin dal',
          tags: ['Protein', 'Energy'],
        );
      }
      return MealSuggestion(
        title: 'Soft mashed rice with ghee',
        tags: ['Energy'],
      );
    }

    if (_has('Rice') && _has('Dal') && _has('Eggs')) {
      return MealSuggestion(
        title: 'Rice, dal, and a boiled egg',
        tags: ['Protein', 'Iron', 'Energy'],
      );
    }
    if (_has('Rice') && _has('Dal')) {
      return MealSuggestion(
        title: 'Rice with dal',
        tags: ['Protein', 'Energy'],
      );
    }
    if (_has('Wheat') && _has('Eggs')) {
      return MealSuggestion(
        title: 'Soft chapati with egg curry',
        tags: ['Protein', 'Energy'],
      );
    }
    if (_has('Wheat') && _has('Dal')) {
      return MealSuggestion(
        title: 'Soft roti with dal',
        tags: ['Protein', 'Fiber'],
      );
    }
    if (_has('Rice')) {
      return MealSuggestion(
        title: 'Warm rice with ghee',
        tags: ['Energy'],
      );
    }
    if (_has('Wheat')) {
      return MealSuggestion(
        title: 'Khichdi',
        tags: ['Energy', 'Easy to digest'],
      );
    }
    return MealSuggestion(
      title: 'Steamed vegetables and rice porridge',
      tags: ['Digestion', 'Energy'],
    );
  }

  // ── Swap Suggestions ───────────────────────────────────────────

  /// Generate alternative suggestions for a given meal type.
  List<MealSuggestion> suggestSwaps(String mealType) {
    List<MealSuggestion> swaps = [];

    switch (mealType) {
      case 'Breakfast':
        swaps = _swapBreakfast();
        break;
      case 'Lunch':
        swaps = _swapLunch();
        break;
      case 'Afternoon Snack':
        swaps = _swapSnack();
        break;
      case 'Dinner':
        swaps = _swapDinner();
        break;
    }

    // Prioritize meals using available foods
    swaps.sort((a, b) {
      if (a.usesAvailableFood && !b.usesAvailableFood) return -1;
      if (!a.usesAvailableFood && b.usesAvailableFood) return 1;
      return 0;
    });

    return swaps.take(4).toList();
  }

  List<MealSuggestion> _swapBreakfast() {
    List<MealSuggestion> options = [];

    if (_has('Ragi') && _has('Milk')) {
      options.add(MealSuggestion(title: 'Ragi malt with milk', tags: ['Iron', 'Calcium']));
    }
    if (_has('Wheat') && _has('Eggs')) {
      options.add(MealSuggestion(title: 'Egg toast with soft wheat bread', tags: ['Protein', 'Energy']));
    }
    if (_has('Rice') && _has('Curd')) {
      options.add(MealSuggestion(title: 'Curd rice', tags: ['Probiotics', 'Energy']));
    }
    if (_has('Wheat')) {
      options.add(MealSuggestion(title: 'Soft chapati with dal', tags: ['Protein', 'Fiber']));
    }
    if (_has('Ragi')) {
      options.add(MealSuggestion(title: 'Ragi dosa with chutney', tags: ['Iron', 'Fiber']));
    }
    if (_has('Rice') && _has('Coconut')) {
      options.add(MealSuggestion(title: 'Rice kanji with coconut', tags: ['Energy', 'Healthy fats']));
    }
    if (_has('Banana') && _has('Milk')) {
      options.add(MealSuggestion(title: 'Banana milkshake', tags: ['Energy', 'Calcium']));
    }

    // Fallback options regardless of availability
    if (options.isEmpty) {
      options.addAll([
        MealSuggestion(title: 'Warm porridge with mashed fruit', tags: ['Energy', 'Gentle'], usesAvailableFood: false),
        MealSuggestion(title: 'Soft bread with banana', tags: ['Energy'], usesAvailableFood: false),
      ]);
    }

    return options;
  }

  List<MealSuggestion> _swapLunch() {
    List<MealSuggestion> options = [];

    if (_has('Rice') && _has('Dal') && _has('Vegetables')) {
      options.add(MealSuggestion(title: 'Rice, dal, and vegetable sabzi', tags: ['Protein', 'Vitamins']));
    }
    if (_has('Wheat') && _has('Dal')) {
      options.add(MealSuggestion(title: 'Dal roti with a side of curd', tags: ['Protein', 'Probiotics']));
    }
    if (_has('Rice') && _has('Eggs')) {
      options.add(MealSuggestion(title: 'Egg fried rice with vegetables', tags: ['Protein', 'Vitamins']));
    }
    if (_has('Wheat') && _has('Vegetables')) {
      options.add(MealSuggestion(title: 'Vegetable paratha with curd', tags: ['Fiber', 'Vitamins']));
    }
    if (_has('Rice')) {
      options.add(MealSuggestion(title: 'Lemon rice with dal', tags: ['Energy', 'Protein']));
    }
    if (_has('Rice') && _has('Coconut')) {
      options.add(MealSuggestion(title: 'Coconut rice with vegetables', tags: ['Energy', 'Healthy fats']));
    }

    if (options.isEmpty) {
      options.addAll([
        MealSuggestion(title: 'Mashed khichdi with ghee', tags: ['Energy', 'Easy to digest'], usesAvailableFood: false),
        MealSuggestion(title: 'Rice with soft dal', tags: ['Protein', 'Energy'], usesAvailableFood: false),
      ]);
    }

    return options;
  }

  List<MealSuggestion> _swapSnack() {
    List<MealSuggestion> options = [];

    if (_has('Banana') && _has('Groundnuts')) {
      options.add(MealSuggestion(title: 'Banana with roasted groundnuts', tags: ['Energy', 'Protein']));
    }
    if (_has('Curd') && _has('Banana')) {
      options.add(MealSuggestion(title: 'Curd with mashed banana', tags: ['Probiotics', 'Energy']));
    }
    if (_has('Other fruits')) {
      options.add(MealSuggestion(title: 'Seasonal fruit slices', tags: ['Vitamins', 'Fiber']));
    }
    if (_has('Milk')) {
      options.add(MealSuggestion(title: 'Warm milk with a pinch of turmeric', tags: ['Calcium', 'Immunity']));
    }
    if (_has('Groundnuts')) {
      options.add(MealSuggestion(title: 'Roasted groundnuts', tags: ['Protein', 'Energy']));
    }
    if (_has('Coconut')) {
      options.add(MealSuggestion(title: 'Fresh coconut pieces', tags: ['Healthy fats', 'Energy']));
    }

    if (options.isEmpty) {
      options.addAll([
        MealSuggestion(title: 'Steamed sweet potato', tags: ['Energy', 'Vitamins'], usesAvailableFood: false),
        MealSuggestion(title: 'Thinly sliced fruit', tags: ['Vitamins'], usesAvailableFood: false),
      ]);
    }

    return options;
  }

  List<MealSuggestion> _swapDinner() {
    List<MealSuggestion> options = [];

    if (_has('Rice') && _has('Dal') && _has('Eggs')) {
      options.add(MealSuggestion(title: 'Rice, dal, and boiled egg', tags: ['Protein', 'Iron', 'Energy']));
    }
    if (_has('Wheat') && _has('Eggs')) {
      options.add(MealSuggestion(title: 'Egg curry with soft roti', tags: ['Protein', 'Energy']));
    }
    if (_has('Rice') && _has('Vegetables')) {
      options.add(MealSuggestion(title: 'Vegetable rice with dal', tags: ['Vitamins', 'Protein']));
    }
    if (_has('Wheat') && _has('Dal')) {
      options.add(MealSuggestion(title: 'Dal with soft roti', tags: ['Protein', 'Fiber']));
    }
    if (_has('Rice') && _has('Coconut')) {
      options.add(MealSuggestion(title: 'Coconut rice with dal', tags: ['Energy', 'Healthy fats']));
    }
    if (_has('Rice')) {
      options.add(MealSuggestion(title: 'Warm rice with ghee and dal', tags: ['Energy', 'Protein']));
    }

    if (options.isEmpty) {
      options.addAll([
        MealSuggestion(title: 'Soft khichdi with ghee', tags: ['Energy', 'Easy to digest'], usesAvailableFood: false),
        MealSuggestion(title: 'Mashed rice with vegetables', tags: ['Energy', 'Vitamins'], usesAvailableFood: false),
      ]);
    }

    return options;
  }
}
