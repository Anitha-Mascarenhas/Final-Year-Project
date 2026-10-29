import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

class NutritionRecommendationNotifier extends Notifier<Map<String, dynamic>?> {
  String? _childId;

  @override
  Map<String, dynamic>? build() => null;

  Future<Map<String, dynamic>> load({
    required String childId,
    required String token,
    Map<String, String> region = const {},
  }) async {
    final result = await ApiService.getNutritionRecommendation(
      childId: childId,
      token: token,
      region: region,
    );
    _childId = childId;
    state = result;
    return result;
  }

  void clear() {
    _childId = null;
    state = null;
  }

  bool belongsTo(String childId) => _childId == childId;
}

final nutritionRecommendationProvider = NotifierProvider<
    NutritionRecommendationNotifier, Map<String, dynamic>?>(
  NutritionRecommendationNotifier.new,
);
