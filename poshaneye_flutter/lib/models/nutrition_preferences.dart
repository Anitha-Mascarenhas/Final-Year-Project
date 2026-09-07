/// Stores parent's food preferences for personalized meal recommendations.
class NutritionPreferences {
  /// Foods commonly available at home.
  final Set<String> availableFoods;

  /// Budget preference: 'budget_friendly', 'moderate', 'flexible'.
  final String budget;

  /// State/region for locally relevant suggestions.
  final String? region;

  NutritionPreferences({
    this.availableFoods = const {},
    this.budget = 'budget_friendly',
    this.region,
  });

  NutritionPreferences copyWith({
    Set<String>? availableFoods,
    String? budget,
    String? region,
    bool clearRegion = false,
  }) {
    return NutritionPreferences(
      availableFoods: availableFoods ?? this.availableFoods,
      budget: budget ?? this.budget,
      region: clearRegion ? null : (region ?? this.region),
    );
  }

  /// All recognized food items parents can select.
  static const List<String> allFoods = [
    'Rice',
    'Ragi',
    'Wheat',
    'Dal',
    'Eggs',
    'Milk',
    'Curd',
    'Groundnuts',
    'Banana',
    'Other fruits',
    'Vegetables',
    'Coconut',
  ];

  /// Indian states/regions for location selection.
  static const List<String> regions = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Other',
  ];
}
