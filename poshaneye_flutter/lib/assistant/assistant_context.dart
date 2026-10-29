import 'package:flutter/foundation.dart';

/// Lightweight UI context object used by the voice assistant
/// understands where the parent is located in the application.
@immutable
class AssistantContext {
  final String currentScreen;
  final List<String> availableActions;
  final String? childName;
  final String? childId;
  final Map<String, String>? nutritionRegion;
  final String? language;

  const AssistantContext({
    required this.currentScreen,
    this.availableActions = const [
      'navigate_home',
      'navigate_screening',
      'navigate_results',
      'navigate_nutrition',
      'navigate_profile',
      'go_back',
      'repeat_current_page',
    ],
    this.childName,
    this.childId,
    this.nutritionRegion,
    this.language = 'en',
  });

  Map<String, dynamic> toJson() {
    return {
      'currentScreen': currentScreen,
      'availableActions': availableActions,
      if (childName != null) 'childName': childName,
      if (childId != null) 'childId': childId,
      if (nutritionRegion != null) 'nutritionRegion': nutritionRegion,
      'language': language,
    };
  }

  AssistantContext copyWith({
    String? currentScreen,
    List<String>? availableActions,
    String? childName,
    String? childId,
    Map<String, String>? nutritionRegion,
    String? language,
  }) {
    return AssistantContext(
      currentScreen: currentScreen ?? this.currentScreen,
      availableActions: availableActions ?? this.availableActions,
      childName: childName ?? this.childName,
      childId: childId ?? this.childId,
      nutritionRegion: nutritionRegion ?? this.nutritionRegion,
      language: language ?? this.language,
    );
  }
}
