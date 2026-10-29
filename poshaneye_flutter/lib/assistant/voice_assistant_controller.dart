import 'dart:async';
import 'package:flutter/foundation.dart';

import 'assistant_chat_client.dart';
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
  final AssistantChatClient _chatClient;
  final List<Map<String, String>> _conversationHistory = [];
  int _requestId = 0;
  bool _requestInFlight = false;
  String? _accessToken;
  static const int _maxHistoryMessages = 10;

  VoiceAssistantState _state = VoiceAssistantState.idle;
  AssistantContext _context;
  AssistantTools? _tools;

  String? _errorMessage;
  String _recognizedText = '';
  String _lastResponse = '';
  List<Map<String, String>> _lastSources = const [];
  bool _isMuted = false;

  VoiceAssistantController({
    AssistantContext context = const AssistantContext(currentScreen: 'home'),
    VoiceAssistantService? service,
    AssistantChatClient? chatClient,
    String? accessToken,
  })  : _context = context,
        _service = service ?? VoiceAssistantService(),
        _chatClient = chatClient ?? BackendAssistantChatClient(),
        _accessToken = accessToken {
    _initTtsCallbacks();
  }

  // --- Public Getters ---
  VoiceAssistantState get state => _state;
  AssistantContext get context => _context;
  String? get errorMessage => _errorMessage;
  String get recognizedText => _recognizedText;
  String get lastResponse => _lastResponse;
  List<Map<String, String>> get lastSources => List.unmodifiable(_lastSources);
  String get lastSpokenText => _lastResponse; // for backwards compatibility
  bool get isMuted => _isMuted;
  bool get isListening => _state == VoiceAssistantState.listening;
  bool get isSpeaking => _state == VoiceAssistantState.speaking;
  bool get isActive =>
      _state != VoiceAssistantState.idle && _state != VoiceAssistantState.error;
  bool get isAvailable => _service.isSpeechAvailable;
  int get conversationMessageCount => _conversationHistory.length;

  /// Attaches navigation tools execution handler from the UI (MainScaffold)
  void attachTools(AssistantTools tools) {
    _tools = tools;
  }

  void updateAccessToken(String? accessToken) {
    _accessToken = accessToken;
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
    _requestId++;
    _requestInFlight = false;
    _errorMessage = null;
    await stopSpeaking();

    _setState(VoiceAssistantState.listening);

    await _service.startListening(
      localeId: _context.language == 'kn' ? 'kn_IN' : 'en_US',
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

  Future<void> processVoiceInput(String text) async {
    final queryText = text.trim();
    if (queryText.isEmpty) {
      _setState(VoiceAssistantState.idle);
      return;
    }
    if (_requestInFlight) return;

    final requestId = ++_requestId;
    _requestInFlight = true;
    _recognizedText = queryText;
    _setState(VoiceAssistantState.processing);
    try {
      await _service.stopSpeaking();
      final normalized = queryText.toLowerCase().trim();
      final localAction = _isConversationReset(normalized)
          ? null
          : _service.processAction(queryText, _tools);
      String response;
      _lastSources = const [];
      if (_isConversationReset(normalized)) {
        _conversationHistory.clear();
        response = 'Conversation cleared. What would you like to ask?';
        _errorMessage = null;
      } else if (localAction != null) {
        response = localAction.textResponse;
        _errorMessage = localAction.isError ? response : null;
      } else {
        try {
          final reply = await _chatClient.reply(
            message: queryText,
            history: List.unmodifiable(_conversationHistory),
            language: _context.language ?? 'en',
            accessToken: _accessToken,
            screen: _context.currentScreen,
            childId: _context.childId,
            nutritionRegion: _context.nutritionRegion ?? const {},
          );
          if (requestId != _requestId) return;
          response = reply.text;
          _lastSources = reply.sources;
          _conversationHistory
            ..add({'role': 'user', 'content': queryText})
            ..add({'role': 'assistant', 'content': response});
          while (_conversationHistory.length > _maxHistoryMessages) {
            _conversationHistory.removeAt(0);
          }
          _errorMessage = null;
        } catch (error) {
          if (requestId != _requestId) return;
          response = _friendlyChatError(error);
          _errorMessage = response;
        }
      }

      if (requestId != _requestId) return;
      _lastResponse = response;
      if (!_isMuted) {
        _setState(VoiceAssistantState.speaking);
        await _service.speak(response);
      } else {
        _setState(VoiceAssistantState.idle);
      }
    } finally {
      if (requestId == _requestId) _requestInFlight = false;
    }
  }

  String _friendlyChatError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('429') || message.contains('quota')) {
      return 'The assistant is busy or its request limit has been reached. Please try again later.';
    }
    if (message.contains('503')) {
      return 'The assistant service is not configured or is unavailable right now.';
    }
    if (message.contains('504') || message.contains('timed out')) {
      return 'The assistant took too long to respond. Please try again.';
    }
    if (message.contains('reach the backend') || message.contains('network')) {
      return 'I cannot reach the assistant service. Check your connection and try again.';
    }
    return 'I could not get a response just now. Please try again.';
  }

  bool _isConversationReset(String normalized) => const {
        'clear conversation',
        'reset conversation',
        'forget this conversation'
      }.contains(normalized);

  /// Resets assistant dialog texts
  void reset() {
    _requestId++;
    _requestInFlight = false;
    _conversationHistory.clear();
    _recognizedText = '';
    _lastResponse = '';
    _lastSources = const [];
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
    _requestId++;
    _requestInFlight = false;
    await stopListening();
    await stopSpeaking();
    _setState(VoiceAssistantState.idle);
  }

  @override
  void dispose() {
    _requestId++;
    _service.dispose();
    super.dispose();
  }
}
