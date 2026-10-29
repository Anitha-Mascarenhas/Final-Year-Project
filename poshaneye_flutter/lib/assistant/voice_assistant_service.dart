import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'assistant_tools.dart';

/// Result produced after processing user speech.
class VoiceQueryResult {
  final String textResponse;
  final bool isNavigation;
  final String? navigatedTo;
  final bool isError;

  const VoiceQueryResult({
    required this.textResponse,
    this.isNavigation = false,
    this.navigatedTo,
    this.isError = false,
  });
}

/// Service handling Speech-to-Text (speech_to_text),
/// Text-to-Speech (flutter_tts), and rule-based intent parsing for PoshanEye.
class VoiceAssistantService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isTtsInitialized = false;
  bool _isSpeechAvailable = false;
  bool _isMuted = false;

  // Getters
  bool get isSpeechAvailable => _isSpeechAvailable;
  bool get isListening => _speechToText.isListening;
  bool get isMuted => _isMuted;

  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      stopSpeaking();
    }
  }

  /// Initialize Speech Recognition with graceful fallback for unsupported platforms.
  Future<bool> initSpeech({
    Function(String status)? onStatus,
    Function(String error)? onError,
  }) async {
    if (_isSpeechInitialized) return _isSpeechAvailable;

    try {
      if (!kIsWeb) {
        final micStatus = await Permission.microphone.request();
        if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
          onError?.call('Microphone permission is required for voice recognition.');
          _isSpeechAvailable = false;
          _isSpeechInitialized = true;
          return false;
        }
      }

      _isSpeechAvailable = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('[VoiceAssistantService] Speech status: $status');
          onStatus?.call(status);
        },
        onError: (SpeechRecognitionError error) {
          debugPrint('[VoiceAssistantService] Speech error: ${error.errorMsg}');
          onError?.call(error.errorMsg);
        },
        debugLogging: false,
      );

      _isSpeechInitialized = true;
      return _isSpeechAvailable;
    } catch (e) {
      debugPrint('[VoiceAssistantService] Speech init exception: $e');
      _isSpeechAvailable = false;
      _isSpeechInitialized = true;
      onError?.call('Speech recognition is not available on this device.');
      return false;
    }
  }

  /// Initialize Text-to-Speech engine.
  Future<void> initTts({
    VoidCallback? onStart,
    VoidCallback? onDone,
    Function(String error)? onError,
  }) async {
    if (_isTtsInitialized) return;

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        debugPrint('[VoiceAssistantService] TTS started');
        onStart?.call();
      });

      _flutterTts.setCompletionHandler(() {
        debugPrint('[VoiceAssistantService] TTS completed');
        onDone?.call();
      });

      _flutterTts.setCancelHandler(() {
        debugPrint('[VoiceAssistantService] TTS cancelled');
        onDone?.call();
      });

      _flutterTts.setErrorHandler((dynamic msg) {
        debugPrint('[VoiceAssistantService] TTS error: $msg');
        onError?.call(msg.toString());
        onDone?.call();
      });

      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('[VoiceAssistantService] TTS init exception: $e');
      _isTtsInitialized = false;
    }
  }

  /// Start listening for English voice input.
  Future<void> startListening({
    required Function(String words, bool isFinal) onResult,
    Function(String error)? onError,
  }) async {
    // Always stop any ongoing TTS when starting speech interaction
    await stopSpeaking();

    if (!_isSpeechInitialized) {
      final ok = await initSpeech(onError: onError);
      if (!ok) {
        onError?.call('Speech recognition is not available or microphone permission was denied.');
        return;
      }
    }

    if (!_isSpeechAvailable) {
      onError?.call('Speech recognition is not supported on this device.');
      return;
    }

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      debugPrint('[VoiceAssistantService] startListening error: $e');
      onError?.call('Could not start listening: $e');
    }
  }

  /// Stop listening explicitly.
  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('[VoiceAssistantService] stopListening error: $e');
    }
  }

  /// Speak response aloud using TTS if unmuted.
  Future<void> speak(String text) async {
    if (_isMuted || text.trim().isEmpty) return;

    try {
      if (!_isTtsInitialized) {
        await initTts();
      }
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[VoiceAssistantService] speak error: $e');
    }
  }

  /// Stop speech playback.
  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('[VoiceAssistantService] stopSpeaking error: $e');
    }
  }

  /// Rule-based query interpreter for PoshanEye navigation and child nutrition questions.
  VoiceQueryResult processQuery(String rawInput, AssistantTools? tools) {
    final query = rawInput.toLowerCase().trim();
    final clean = query.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ');

    if (clean.isEmpty) {
      return const VoiceQueryResult(
        textResponse: "Sorry, I didn't catch that. Could you please try again?",
      );
    }

    // =========================================================================
    // 1. BASIC POSHANEYE QUESTIONS & ADVICE (Prioritized over keyword nav)
    // =========================================================================

    // Question: "What should I do if my child is underweight?"
    if (_matches(clean, [
      'what should i do if my child is underweight',
      'what to do if child is underweight',
      'child is underweight',
      'my child is underweight',
      'child underweight what to do',
      'if child is underweight',
      'if my child is underweight',
      'underweight child care',
      'what should i do if child is underweight',
    ])) {
      return const VoiceQueryResult(
        textResponse:
            'PoshanEye recommends offering nutrient-rich balanced meals, monitoring progress, and consulting your local healthcare or Anganwadi worker for a personalized medical evaluation.',
      );
    }

    // Question: "How does nutrition screening work?"
    if (_matches(clean, [
      'how does nutrition screening work',
      'how does screening work',
      'how does the scan work',
      'how does poshaneye work',
      'how does nutrition screening function',
      'how screening works',
      'screening work',
    ])) {
      return const VoiceQueryResult(
        textResponse:
            'PoshanEye analyzes facial and posture features from photos alongside height and weight measurements to estimate malnutrition risk indicators safely.',
      );
    }

    // Question: "What is PoshanEye?"
    if (_matches(clean, [
      'what is poshaneye',
      'what is poshan eye',
      'about poshaneye',
      'who are you',
      'what does poshaneye do',
      'tell me about poshaneye',
      'poshaneye',
      'poshan eye',
    ])) {
      return const VoiceQueryResult(
        textResponse:
            'PoshanEye is an AI-powered screening and growth monitoring app for children. It helps parents and health workers detect malnutrition risk early. Please remember it is a screening tool, not a substitute for professional medical advice.',
      );
    }

    // Question: "What is malnutrition?"
    if (_matches(clean, [
      'what is malnutrition',
      'define malnutrition',
      'tell me about malnutrition',
      'what does malnutrition mean',
      'malnutrition',
      'undernutrition',
    ])) {
      return const VoiceQueryResult(
        textResponse:
            'Malnutrition occurs when a child does not get the right balance of nutrients needed for healthy growth and development. For medical guidance, always consult a healthcare professional.',
      );
    }

    // Question: "What is underweight?"
    if (_matches(clean, [
      'what is underweight',
      'define underweight',
      'what does underweight mean',
      'underweight',
    ])) {
      return const VoiceQueryResult(
        textResponse:
            "Underweight means a child's weight is significantly below the expected range for their age. PoshanEye helps monitor growth trends, but consult a doctor for clinical assessment.",
      );
    }

    // Question: "What is stunting?"
    if (_matches(clean, [
      'what is stunting',
      'define stunting',
      'what does stunting mean',
      'stunting',
      'stunted growth',
      'stunted child',
    ])) {
      return const VoiceQueryResult(
        textResponse:
            'Stunting refers to impaired growth and low height-for-age, usually caused by long-term nutritional deficiency. PoshanEye tracks these indicators to support early intervention.',
      );
    }

    // Question: "What is wasting?"
    if (_matches(clean, [
      'what is wasting',
      'define wasting',
      'what does wasting mean',
      'wasting',
      'wasted child',
      'acute malnutrition',
    ])) {
      return const VoiceQueryResult(
        textResponse:
            'Wasting is low weight-for-height, indicating acute or recent rapid weight loss. Prompt consultation with an Anganwadi or healthcare worker is recommended.',
      );
    }

    // Friendly greetings & help
    if (_matches(clean, ['hello', 'hi', 'hey', 'good morning', 'good afternoon'])) {
      return const VoiceQueryResult(
        textResponse:
            'Hello! I am your PoshanEye assistant. You can ask me questions about child nutrition or tell me where to navigate.',
      );
    }

    if (_matches(clean, ['help', 'what can you do', 'commands'])) {
      return const VoiceQueryResult(
        textResponse:
            'You can ask me to navigate to home, growth tracking, nutrition screening, history, or profile, or ask questions about malnutrition, stunting, or wasting.',
      );
    }

    // =========================================================================
    // 2. NAVIGATION COMMANDS
    // =========================================================================
    // Existing PoshanEye screens only: Home, Growth Tracking, Nutrition Screening, History, Nutrition Plan, Profile.

    // A) Home
    if (_matches(clean, [
      'go to home',
      'open home',
      'home',
      'take me home',
      'go home',
      'home dashboard',
      'open dashboard',
      'dashboard',
    ])) {
      tools?.onNavigateHome();
      return const VoiceQueryResult(
        textResponse: 'Opening home dashboard.',
        isNavigation: true,
        navigatedTo: 'home',
      );
    }

    // B) Nutrition Screening (AI Scan)
    if (_matches(clean, [
      'open nutrition screening',
      'open screening',
      'nutrition screening',
      'screening',
      'start screening',
      'open scan',
      'scan',
      'open ai scan',
      'ai scan',
      'screen child',
      'take scan',
    ])) {
      tools?.onNavigateScreening();
      return const VoiceQueryResult(
        textResponse: 'Opening nutrition screening.',
        isNavigation: true,
        navigatedTo: 'screening',
      );
    }

    // C) History
    if (_matches(clean, [
      'open history',
      'history',
      'show history',
      'past scans',
      'screening history',
      'growth history',
      'view history',
      'records history',
    ])) {
      if (tools?.onNavigateHistory != null) {
        tools!.onNavigateHistory!();
      } else {
        tools?.onNavigateResults();
      }
      return const VoiceQueryResult(
        textResponse: 'Opening growth and screening history.',
        isNavigation: true,
        navigatedTo: 'history',
      );
    }

    // D) Growth Tracking
    if (_matches(clean, [
      'open growth tracking',
      'growth tracking',
      'open growth',
      'growth',
      'open tracking',
      'tracking',
      'open results',
      'growth results',
      'growth chart',
    ])) {
      tools?.onNavigateResults();
      return const VoiceQueryResult(
        textResponse: 'Opening growth tracking.',
        isNavigation: true,
        navigatedTo: 'growth_tracking',
      );
    }

    // E) Nutrition Plan (exclude if talking about malnutrition)
    if (!clean.contains('malnutrition') &&
        _matches(clean, [
          'open nutrition plan',
          'nutrition plan',
          'open nutrition',
          'nutrition',
          'diet plan',
          'open diet plan',
          'food plan',
          'meal plan',
          'diet recommendation',
        ])) {
      tools?.onNavigateNutrition();
      return const VoiceQueryResult(
        textResponse: 'Opening nutrition plan.',
        isNavigation: true,
        navigatedTo: 'nutrition_plan',
      );
    }

    // F) Profile
    if (_matches(clean, [
      'open profile',
      'profile',
      'my profile',
      'child profile',
      'user profile',
      'account',
      'open account',
    ])) {
      tools?.onNavigateProfile();
      return const VoiceQueryResult(
        textResponse: 'Opening profile.',
        isNavigation: true,
        navigatedTo: 'profile',
      );
    }

    // G) Back
    if (_matches(clean, ['go back', 'back', 'previous screen'])) {
      tools?.onGoBack();
      return const VoiceQueryResult(
        textResponse: 'Going back.',
        isNavigation: true,
        navigatedTo: 'back',
      );
    }

    // H) Explicit requests for non-existent screens
    if (_isNonExistentScreenRequest(clean)) {
      return const VoiceQueryResult(
        textResponse: 'Sorry, that screen does not exist in PoshanEye.',
        isError: true,
      );
    }

    // =========================================================================
    // 3. FALLBACK REQUIREMENT
    // =========================================================================
    // If the assistant does not understand a question, respond:
    // "Sorry, I didn't understand that. Could you please try again?"
    return const VoiceQueryResult(
      textResponse: "Sorry, I didn't understand that. Could you please try again?",
    );
  }

  /// Helper to check if input matches any of the candidate phrases with word boundary safety.
  bool _matches(String input, List<String> candidates) {
    for (final c in candidates) {
      if (input == c) return true;
      // Whole-word regex match to avoid partial substrings (e.g. 'nutrition' in 'malnutrition')
      final pattern = RegExp(r'\b' + RegExp.escape(c) + r'\b');
      if (pattern.hasMatch(input)) return true;
    }
    return false;
  }

  /// Detects navigation intents directed at screens not present in PoshanEye.
  bool _isNonExistentScreenRequest(String clean) {
    final navTriggers = ['open', 'go to', 'show', 'view', 'navigate to', 'take me to'];
    final bool hasNavIntent = navTriggers.any((t) => clean.startsWith(t) || clean.contains(t));

    if (!hasNavIntent) return false;

    final knownTargets = [
      'home',
      'dashboard',
      'growth',
      'tracking',
      'screening',
      'scan',
      'history',
      'results',
      'nutrition',
      'plan',
      'profile',
      'account',
      'back',
    ];

    final bool referencesKnownTarget = knownTargets.any((k) => clean.contains(k));
    return !referencesKnownTarget;
  }

  /// Clean disposal of resources.
  Future<void> dispose() async {
    try {
      await stopListening();
      await stopSpeaking();
      _speechToText.cancel();
    } catch (e) {
      debugPrint('[VoiceAssistantService] dispose error: $e');
    }
  }
}
