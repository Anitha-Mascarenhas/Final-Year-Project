import 'package:flutter/foundation.dart';

/// Function declarations and tool executor for the PoshanEye Voice Assistant.
///
/// Only safe whitelisted navigation actions are permitted.
class AssistantTools {
  /// Gemini Function Declarations schema for Gemini Live WebSocket API.
  static final List<Map<String, dynamic>> declarations = [
    {
      'name': 'navigate_home',
      'description': 'Navigate the parent to the Home Dashboard screen.',
      'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
      'name': 'navigate_screening',
      'description': 'Navigate to the AI Scan / Malnutrition Screening screen.',
      'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
      'name': 'navigate_results',
      'description': 'Navigate to the Child Growth & Screening Results screen.',
      'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
      'name': 'navigate_nutrition',
      'description': 'Navigate to the Nutrition Plan screen.',
      'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
      'name': 'navigate_profile',
      'description': 'Navigate to the User Profile screen.',
      'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
      'name': 'go_back',
      'description': 'Navigate back to the previous screen or tab.',
      'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
      'name': 'repeat_current_page',
      'description': 'Repeat or verbally explain the current page the parent is viewing.',
      'parameters': {'type': 'OBJECT', 'properties': {}},
    },
  ];

  final VoidCallback onNavigateHome;
  final VoidCallback onNavigateScreening;
  final VoidCallback onNavigateResults;
  final VoidCallback onNavigateNutrition;
  final VoidCallback onNavigateProfile;
  final VoidCallback onGoBack;
  final VoidCallback onRepeatCurrentPage;

  AssistantTools({
    required this.onNavigateHome,
    required this.onNavigateScreening,
    required this.onNavigateResults,
    required this.onNavigateNutrition,
    required this.onNavigateProfile,
    required this.onGoBack,
    required this.onRepeatCurrentPage,
  });

  /// Validates and executes a tool call requested by Gemini Live.
  ///
  /// Returns a result map to send back as a tool response to Gemini.
  Map<String, dynamic> executeTool(String name, Map<String, dynamic> args) {
    debugPrint('[AssistantTools] Executing tool: $name with args: $args');

    switch (name) {
      case 'navigate_home':
        onNavigateHome();
        return {'status': 'success', 'message': 'Navigated to Home Dashboard'};

      case 'navigate_screening':
        onNavigateScreening();
        return {'status': 'success', 'message': 'Navigated to AI Malnutrition Screening'};

      case 'navigate_results':
        onNavigateResults();
        return {'status': 'success', 'message': 'Navigated to Child Growth and Results'};

      case 'navigate_nutrition':
        onNavigateNutrition();
        return {'status': 'success', 'message': 'Navigated to Nutrition Plan'};

      case 'navigate_profile':
        onNavigateProfile();
        return {'status': 'success', 'message': 'Navigated to Profile'};

      case 'go_back':
        onGoBack();
        return {'status': 'success', 'message': 'Navigated back'};

      case 'repeat_current_page':
        onRepeatCurrentPage();
        return {'status': 'success', 'message': 'Repeating current page information'};

      default:
        debugPrint('[AssistantTools] Unknown tool call rejected: $name');
        return {'status': 'error', 'message': 'Unknown or unauthorized tool call: $name'};
    }
  }
}
