import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/ephemeral_token_service.dart';
import 'assistant_context.dart';
import 'assistant_state.dart';
import 'assistant_tools.dart';
import 'gemini_live_service.dart';

/// Central ChangeNotifier controller for the PoshanEye Gemini Live Voice Assistant.
///
/// Cleanly isolates Flutter UI components from Gemini Live WebSocket networking
/// and underlying audio device hardware.
class VoiceAssistantController extends ChangeNotifier {
  final GeminiLiveService _liveService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();

  VoiceAssistantState _state = VoiceAssistantState.idle;
  AssistantContext _context;
  AssistantTools? _tools;

  String? _errorMessage;
  String _lastSpokenText = '';
  StreamSubscription? _audioRecordSubscription;

  VoiceAssistantController({
    AssistantContext context = const AssistantContext(currentScreen: 'home'),
    String? modelName,
  })  : _context = context,
        _liveService = GeminiLiveService(
          activeModel: modelName ?? GeminiLiveService.defaultModelName,
        ) {
    _setupServiceCallbacks();
  }


  // --- Public Getters ---
  VoiceAssistantState get state => _state;
  AssistantContext get context => _context;
  String? get errorMessage => _errorMessage;
  String get lastSpokenText => _lastSpokenText;
  bool get isActive => _state != VoiceAssistantState.idle && _state != VoiceAssistantState.error;

  /// Attaches navigation tools execution handler from the UI (MainScaffold)
  void attachTools(AssistantTools tools) {
    _tools = tools;
  }

  /// Updates current screen context as parent navigates
  void updateContext(AssistantContext newContext) {
    _context = newContext;
    notifyListeners();
  }

  /// Binds Gemini Live service callbacks to controller state updates
  void _setupServiceCallbacks() {
    _liveService.onStateChanged = (status) {
      switch (status) {
        case 'connecting':
          _setState(VoiceAssistantState.connecting);
          break;
        case 'listening':
          _setState(VoiceAssistantState.listening);
          break;
        case 'processing':
          _setState(VoiceAssistantState.processing);
          break;
        case 'connected':
          _setState(VoiceAssistantState.listening);
          _startMicrophoneStream();
          break;
        case 'idle':
          _stopMicrophoneStream();
          _setState(VoiceAssistantState.idle);
          break;
      }
    };

    _liveService.onTextResponseReceived = (text) {
      debugPrint('[VoiceAssistantController] Assistant text: $text');
      _lastSpokenText = text;
      _setState(VoiceAssistantState.speaking);
      notifyListeners();
    };

    _liveService.onAudioDataReceived = (audioBytes) async {
      _setState(VoiceAssistantState.speaking);
      try {
        // Play audio chunk received from Gemini
        await _audioPlayer.play(BytesSource(audioBytes));
      } catch (e) {
        debugPrint('[VoiceAssistantController] Audio playback error: $e');
      }
    };

    _liveService.onToolCallReceived = (toolName, args) async {
      _setState(VoiceAssistantState.processing);
      if (_tools != null) {
        final result = _tools!.executeTool(toolName, args);
        return result;
      }
      return {'status': 'error', 'message': 'Navigation tools not attached'};
    };

    _liveService.onErrorOccurred = (error) {
      _setError(error);
    };

    _audioPlayer.onPlayerComplete.listen((_) {
      if (_state == VoiceAssistantState.speaking) {
        _setState(VoiceAssistantState.listening);
      }
    });
  }

  /// Toggles the Voice Assistant session on/off
  Future<void> toggleSession() async {
    if (isActive) {
      await stopSession();
    } else {
      await startSession();
    }
  }

  /// Starts Gemini Live session: requests permission, gets token, connects WS
  Future<void> startSession() async {
    _errorMessage = null;
    _setState(VoiceAssistantState.connecting);

    // 1. Check & Request Microphone Permission
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        _setError('Microphone permission is required to use Voice Assistant.');
        return;
      }
    }

    try {
      // 2. Fetch Ephemeral Token from backend (Never hardcode permanent keys)
      final String token = await EphemeralTokenService.getEphemeralToken();

      if (token.isEmpty) {
        _setError('Gemini API key is not configured on the backend server.');
        return;
      }

      // 3. Connect to Gemini Live Service WebSocket
      await _liveService.connect(
        ephemeralToken: token,
        context: _context,
      );
    } catch (e) {
      debugPrint('[VoiceAssistantController] Start session error: $e');
      _setError('Could not start voice session: $e');
    }
  }

  /// Begins streaming PCM microphone audio to Gemini Live WebSocket
  Future<void> _startMicrophoneStream() async {
    try {
      if (await _recorder.hasPermission()) {
        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        _audioRecordSubscription = stream.listen((chunk) {
          if (_liveService.isConnected && _state == VoiceAssistantState.listening) {
            _liveService.sendAudioChunk(chunk);
          }
        });
      }
    } catch (e) {
      debugPrint('[VoiceAssistantController] Failed to start microphone stream: $e');
    }
  }

  /// Stops streaming microphone audio
  Future<void> _stopMicrophoneStream() async {
    await _audioRecordSubscription?.cancel();
    _audioRecordSubscription = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('[VoiceAssistantController] Stop recorder error: $e');
    }
  }

  /// Stops current voice assistant session completely
  Future<void> stopSession() async {
    await _stopMicrophoneStream();
    await _audioPlayer.stop();
    _liveService.disconnect();
    _setState(VoiceAssistantState.idle);
  }

  void _setState(VoiceAssistantState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _setState(VoiceAssistantState.error);
    notifyListeners();
  }

  @override
  void dispose() {
    stopSession();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
