import 'dart:async';
import 'package:flutter/foundation.dart';

import 'assistant_context.dart';
import 'assistant_state.dart';
import 'assistant_tools.dart';
import 'voice_assistant_service.dart';

/// Central ChangeNotifier controller for the PoshanEye Voice Assistant.
///
/// Encapsulates speech recognition (STT), speech synthesis (TTS),
/// and rule-based query handling while providing reactive state for Flutter UI.
class VoiceAssistantController extends ChangeNotifier {
  final VoiceAssistantService _service;

  VoiceAssistantState _state = VoiceAssistantState.idle;
  AssistantContext _context;
  AssistantTools? _tools;

  String? _errorMessage;
  String _recognizedText = '';
  String _lastResponse = '';
  bool _isMuted = false;

  VoiceAssistantController({
    AssistantContext context = const AssistantContext(currentScreen: 'home'),
    VoiceAssistantService? service,
  })  : _context = context,
        _service = service ?? VoiceAssistantService() {
    _initTtsCallbacks();
  }

  // --- Public Getters ---
  VoiceAssistantState get state => _state;
  AssistantContext get context => _context;
  String? get errorMessage => _errorMessage;
  String get recognizedText => _recognizedText;
  String get lastResponse => _lastResponse;
  String get lastSpokenText => _lastResponse; // for backwards compatibility
  bool get isMuted => _isMuted;
  bool get isListening => _state == VoiceAssistantState.listening;
  bool get isSpeaking => _state == VoiceAssistantState.speaking;
  bool get isActive => _state != VoiceAssistantState.idle && _state != VoiceAssistantState.error;
  bool get isAvailable => _service.isSpeechAvailable;

  /// Attaches navigation tools execution handler from the UI (MainScaffold)
  void attachTools(AssistantTools tools) {
    _tools = tools;
  }

  /// Updates current screen context as parent navigates
  void updateContext(AssistantContext newContext) {
    _context = newContext;
    notifyListeners();
  }

  void _initTtsCallbacks() {
    _service.initTts(
      onStart: () {
        if (_state != VoiceAssistantState.listening) {
          _setState(VoiceAssistantState.speaking);
        }
      },
      onDone: () {
        if (_state == VoiceAssistantState.speaking) {
          _setState(VoiceAssistantState.idle);
        }
      },
      onError: (err) {
        debugPrint('[VoiceAssistantController] TTS error: $err');
        if (_state == VoiceAssistantState.speaking) {
          _setState(VoiceAssistantState.idle);
        }
      },
    );
  }

  /// Toggles mute for voice responses
  void toggleMute() {
    _isMuted = !_isMuted;
    _service.setMuted(_isMuted);
    if (_isMuted && _state == VoiceAssistantState.speaking) {
      _setState(VoiceAssistantState.idle);
    }
    notifyListeners();
  }

  /// Starts listening for voice input.
  /// Stops any active speech, requests permissions if needed, and streams recognized text.
  Future<void> startListening() async {
    _errorMessage = null;
    await stopSpeaking();

    _setState(VoiceAssistantState.listening);

    await _service.startListening(
      onResult: (words, isFinal) {
        _recognizedText = words;
        notifyListeners();

        if (isFinal && words.trim().isNotEmpty) {
          processVoiceInput(words);
        }
      },
      onError: (err) {
        debugPrint('[VoiceAssistantController] STT error: $err');
        _errorMessage = err;
        _setState(VoiceAssistantState.error);
      },
    );
  }

  /// Stops listening and immediately processes whatever was captured.
  Future<void> stopListening() async {
    await _service.stopListening();
    if (_state == VoiceAssistantState.listening) {
      if (_recognizedText.trim().isNotEmpty) {
        await processVoiceInput(_recognizedText);
      } else {
        _setState(VoiceAssistantState.idle);
      }
    }
  }

  /// Toggles the microphone listening on and off
  Future<void> toggleListening() async {
    if (isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Stops TTS voice playback
  Future<void> stopSpeaking() async {
    await _service.stopSpeaking();
    if (_state == VoiceAssistantState.speaking) {
      _setState(VoiceAssistantState.idle);
    }
  }

  /// Processes text input against PoshanEye navigation and basic nutrition questions.
  Future<void> processVoiceInput(String text) async {
    final queryText = text.trim();
    if (queryText.isEmpty) {
      _setState(VoiceAssistantState.idle);
      return;
    }

    _recognizedText = queryText;
    _setState(VoiceAssistantState.processing);

    // Rule-based query resolution
    final result = _service.processQuery(queryText, _tools);
    _lastResponse = result.textResponse;

    if (result.isError) {
      _errorMessage = result.textResponse;
    } else {
      _errorMessage = null;
    }

    if (!_isMuted) {
      _setState(VoiceAssistantState.speaking);
      await _service.speak(result.textResponse);
    } else {
      _setState(VoiceAssistantState.idle);
    }
  }

  /// Resets assistant dialog texts
  void reset() {
    _recognizedText = '';
    _lastResponse = '';
    _errorMessage = null;
    _setState(VoiceAssistantState.idle);
  }

  void _setState(VoiceAssistantState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  // Backwards compatibility for existing button toggle calls
  Future<void> toggleSession() async {
    await toggleListening();
  }

  Future<void> stopSession() async {
    await stopListening();
    await stopSpeaking();
    _setState(VoiceAssistantState.idle);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
