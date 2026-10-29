import 'package:flutter/foundation.dart';

/// Lightweight UI context object passed to Gemini Live so the assistant
/// understands where the parent is located in the application.
@immutable
class AssistantContext {
  final String currentScreen;
  final List<String> availableActions;
  final String? childName;
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
    this.language = 'en',
  });

  Map<String, dynamic> toJson() {
    return {
      'currentScreen': currentScreen,
      'availableActions': availableActions,
      if (childName != null) 'childName': childName,
      'language': language,
    };
  }

  AssistantContext copyWith({
    String? currentScreen,
    List<String>? availableActions,
    String? childName,
    String? language,
  }) {
    return AssistantContext(
      currentScreen: currentScreen ?? this.currentScreen,
      availableActions: availableActions ?? this.availableActions,
      childName: childName ?? this.childName,
      language: language ?? this.language,
    );
  }
}
