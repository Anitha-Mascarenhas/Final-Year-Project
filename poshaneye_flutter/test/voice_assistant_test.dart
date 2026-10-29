import 'package:flutter_test/flutter_test.dart';
import 'package:poshaneye_auth/assistant/assistant_tools.dart';
import 'package:poshaneye_auth/assistant/voice_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceAssistantService - Rule-based intent recognition', () {
    late VoiceAssistantService service;

    setUp(() {
      service = VoiceAssistantService();
    });

    test('Navigates to home', () {
      bool homeNavigated = false;
      final tools = AssistantTools(
        onNavigateHome: () => homeNavigated = true,
        onNavigateScreening: () {},
        onNavigateResults: () {},
        onNavigateNutrition: () {},
        onNavigateProfile: () {},
        onGoBack: () {},
        onRepeatCurrentPage: () {},
      );

      final result = service.processQuery('Go to home', tools);
      expect(homeNavigated, isTrue);
      expect(result.isNavigation, isTrue);
      expect(result.textResponse.toLowerCase(), contains('home'));
    });

    test('Navigates to growth tracking', () {
      bool growthNavigated = false;
      final tools = AssistantTools(
        onNavigateHome: () {},
        onNavigateScreening: () {},
        onNavigateResults: () => growthNavigated = true,
        onNavigateNutrition: () {},
        onNavigateProfile: () {},
        onGoBack: () {},
        onRepeatCurrentPage: () {},
      );

      final result = service.processQuery('Open growth tracking', tools);
      expect(growthNavigated, isTrue);
      expect(result.isNavigation, isTrue);
      expect(result.textResponse.toLowerCase(), contains('growth tracking'));
    });

    test('Navigates to nutrition screening', () {
      bool screeningNavigated = false;
      final tools = AssistantTools(
        onNavigateHome: () {},
        onNavigateScreening: () => screeningNavigated = true,
        onNavigateResults: () {},
        onNavigateNutrition: () {},
        onNavigateProfile: () {},
        onGoBack: () {},
        onRepeatCurrentPage: () {},
      );

      final result = service.processQuery('Open nutrition screening', tools);
      expect(screeningNavigated, isTrue);
      expect(result.isNavigation, isTrue);
      expect(result.textResponse.toLowerCase(), contains('nutrition screening'));
    });

    test('Navigates to history', () {
      bool historyNavigated = false;
      final tools = AssistantTools(
        onNavigateHome: () {},
        onNavigateScreening: () {},
        onNavigateResults: () {},
        onNavigateHistory: () => historyNavigated = true,
        onNavigateNutrition: () {},
        onNavigateProfile: () {},
        onGoBack: () {},
        onRepeatCurrentPage: () {},
      );

      final result = service.processQuery('Open history', tools);
      expect(historyNavigated, isTrue);
      expect(result.isNavigation, isTrue);
      expect(result.textResponse.toLowerCase(), contains('history'));
    });

    test('Navigates to profile', () {
      bool profileNavigated = false;
      final tools = AssistantTools(
        onNavigateHome: () {},
        onNavigateScreening: () {},
        onNavigateResults: () {},
        onNavigateNutrition: () {},
        onNavigateProfile: () => profileNavigated = true,
        onGoBack: () {},
        onRepeatCurrentPage: () {},
      );

      final result = service.processQuery('Open profile', tools);
      expect(profileNavigated, isTrue);
      expect(result.isNavigation, isTrue);
      expect(result.textResponse.toLowerCase(), contains('profile'));
    });

    test('Handles non-existent screen gracefully', () {
      final tools = AssistantTools(
        onNavigateHome: () {},
        onNavigateScreening: () {},
        onNavigateResults: () {},
        onNavigateNutrition: () {},
        onNavigateProfile: () {},
        onGoBack: () {},
        onRepeatCurrentPage: () {},
      );

      final result = service.processQuery('Open settings', tools);
      expect(result.textResponse, 'Sorry, that screen does not exist in PoshanEye.');
      expect(result.isError, isTrue);
    });

    test('Answers "What is PoshanEye?"', () {
      final result = service.processQuery('What is PoshanEye?', null);
      expect(result.textResponse, contains('PoshanEye is an AI-powered screening and growth monitoring app'));
      expect(result.textResponse, contains('screening tool'));
    });

    test('Answers "What is malnutrition?"', () {
      final result = service.processQuery('What is malnutrition?', null);
      expect(result.textResponse, contains('Malnutrition occurs when a child does not get the right balance of nutrients'));
      expect(result.textResponse, contains('healthcare professional'));
    });

    test('Answers "What is underweight?"', () {
      final result = service.processQuery('What is underweight?', null);
      expect(result.textResponse, contains('weight is significantly below'));
      expect(result.textResponse, contains('consult a doctor'));
    });

    test('Answers "What is stunting?"', () {
      final result = service.processQuery('What is stunting?', null);
      expect(result.textResponse, contains('low height-for-age'));
    });

    test('Answers "What is wasting?"', () {
      final result = service.processQuery('What is wasting?', null);
      expect(result.textResponse, contains('low weight-for-height'));
    });

    test('Answers "How does nutrition screening work?"', () {
      final result = service.processQuery('How does nutrition screening work?', null);
      expect(result.textResponse, contains('facial and posture features'));
    });

    test('Answers "What should I do if my child is underweight?"', () {
      final result = service.processQuery('What should I do if my child is underweight?', null);
      expect(result.textResponse, contains('nutrient-rich balanced meals'));
      expect(result.textResponse, contains('consulting your local healthcare'));
    });

    test('Fallback on unknown input matches exact requirement', () {
      final result = service.processQuery('Can you fly me to Mars?', null);
      expect(result.textResponse, "Sorry, I didn't understand that. Could you please try again?");
    });
  });
}
