import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'assistant_context.dart';
import 'assistant_tools.dart';

/// Callbacks fired by GeminiLiveService to notify the controller of events.
typedef OnToolCallReceived = Future<Map<String, dynamic>> Function(
    String toolName, Map<String, dynamic> args);
typedef OnTextResponseReceived = void Function(String text);
typedef OnAudioDataReceived = void Function(Uint8List audioBytes);
typedef OnStateChanged = void Function(String status);
typedef OnErrorOccurred = void Function(String error);

/// Service for handling real-time WebSocket communication with Google Gemini Live API.
class GeminiLiveService {
  /// Default model constant for Gemini Live API (supports --dart-define=GEMINI_LIVE_MODEL=...)
  static const String defaultModelName = String.fromEnvironment(
    'GEMINI_LIVE_MODEL',
    defaultValue: 'gemini-2.0-flash-exp',
  );


  /// Configurable active model instance
  final String activeModel;

  GeminiLiveService({this.activeModel = defaultModelName});

  /// Official Gemini Live Bidi WebSocket base URL
  static const String _wsBaseUrl =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent';


  /// Strict System Instruction mandated for PoshanEye Navigation Assistant
  static const String systemInstruction = '''
You are PoshanEye Voice Assistant.

Your primary job is to help parents navigate the PoshanEye application.

You can explain how to use the application.

You may navigate only through the approved navigation tools.

Never invent navigation functions.

Never provide a medical diagnosis.

Never change screening results.

Never change anthropometric measurements.

Never claim that a child is healthy, malnourished, stunted, or underweight unless that information already exists in the application's displayed result and the user asks for an explanation.

When the user asks to navigate, use the appropriate navigation function.

Keep spoken responses short, simple, and parent-friendly.

Prefer simple English.

If the user speaks another supported language, respond in that language if practical.

If a request is ambiguous, ask a short clarification question.

Never execute arbitrary code.
''';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;

  OnToolCallReceived? onToolCallReceived;
  OnTextResponseReceived? onTextResponseReceived;
  OnAudioDataReceived? onAudioDataReceived;
  OnErrorOccurred? onErrorOccurred;
  OnStateChanged? onStateChanged;

  bool get isConnected => _isConnected;

  /// Connect to Gemini Live WebSocket endpoint with ephemeral token.
  Future<void> connect({
    required String ephemeralToken,
    required AssistantContext context,
  }) async {
    if (_isConnected) return;

    final String uriString = '$_wsBaseUrl?key=$ephemeralToken';
    debugPrint('[GeminiLiveService] Connecting to Gemini Live WebSocket...');

    try {
      onStateChanged?.call('connecting');
      _channel = WebSocketChannel.connect(Uri.parse(uriString));
      _isConnected = true;

      // Listen to incoming WebSocket messages
      _subscription = _channel!.stream.listen(
        _handleServerMessage,
        onError: (error) {
          debugPrint('[GeminiLiveService] WebSocket error: $error');
          _handleDisconnect('Connection error: $error');
        },
        onDone: () {
          debugPrint('[GeminiLiveService] WebSocket closed by server');
          _handleDisconnect('Session ended');
        },
      );

      // Send initial setup configuration
      _sendSetupMessage(context);
      onStateChanged?.call('connected');
    } catch (e) {
      debugPrint('[GeminiLiveService] Failed to establish connection: $e');
      _isConnected = false;
      onErrorOccurred?.call('Failed to connect to Gemini Live service: $e');
    }
  }

  /// Send setup message with model, system instructions, and tool declarations
  void _sendSetupMessage(AssistantContext context) {
    final setupMessage = {
      'setup': {
        'model': 'models/$activeModel',
        'generationConfig': {
          'responseModalities': ['AUDIO', 'TEXT'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': 'Puck' // Warm, clear voice for parent guidance
              }
            }
          }
        },
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
            {'text': 'Current App Context: ${jsonEncode(context.toJson())}'}
          ]
        },
        'tools': [
          {'functionDeclarations': AssistantTools.declarations}
        ]
      }
    };

    _sendJson(setupMessage);
  }

  /// Process incoming JSON frames from Gemini Live WebSocket.
  void _handleServerMessage(dynamic message) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(message is String ? message : utf8.decode(message));

      if (data.containsKey('serverContent')) {
        final serverContent = data['serverContent'];

        if (serverContent.containsKey('modelTurn')) {
          final parts = serverContent['modelTurn']['parts'] as List? ?? [];
          for (final part in parts) {
            // Text response
            if (part.containsKey('text')) {
              onTextResponseReceived?.call(part['text']);
            }
            // Audio response chunk (base64 PCM)
            if (part.containsKey('inlineData')) {
              final inlineData = part['inlineData'];
              if (inlineData['mimeType']?.startsWith('audio/') ?? false) {
                final base64Audio = inlineData['data'];
                if (base64Audio != null) {
                  final audioBytes = base64Decode(base64Audio);
                  onAudioDataReceived?.call(audioBytes);
                }
              }
            }
          }
        }

        if (serverContent['turnComplete'] == true) {
          onStateChanged?.call('listening');
        }
      }

      // Tool / Function Call requested by Gemini
      if (data.containsKey('toolCall')) {
        _handleToolCall(data['toolCall']);
      }
    } catch (e) {
      debugPrint('[GeminiLiveService] Error parsing message: $e');
    }
  }

  /// Handles incoming tool call from Gemini and dispatches function execution
  Future<void> _handleToolCall(Map<String, dynamic> toolCall) async {
    onStateChanged?.call('processing');
    final functionCalls = toolCall['functionCalls'] as List? ?? [];

    for (final fc in functionCalls) {
      final String id = fc['id'] ?? 'call_0';
      final String name = fc['name'] ?? '';
      final Map<String, dynamic> args = fc['args'] ?? {};

      debugPrint('[GeminiLiveService] Received tool call request: $name (id=$id)');

      if (onToolCallReceived != null) {
        final result = await onToolCallReceived!(name, args);
        _sendToolResponse(id, name, result);
      }
    }
  }

  /// Sends function response back to Gemini Live WebSocket
  void _sendToolResponse(String callId, String name, Map<String, dynamic> response) {
    final responsePayload = {
      'toolResponse': {
        'functionResponses': [
          {
            'response': {'output': response},
            'id': callId,
          }
        ]
      }
    };
    debugPrint('[GeminiLiveService] Sending tool response back to Gemini');
    _sendJson(responsePayload);
  }

  /// Stream realtime audio input bytes (PCM 16-bit 16kHz) to Gemini Live
  void sendAudioChunk(Uint8List pcmBytes) {
    if (!_isConnected) return;

    final base64Audio = base64Encode(pcmBytes);
    final audioPayload = {
      'realtimeInput': {
        'mediaChunks': [
          {
            'mimeType': 'audio/pcm;rate=16000',
            'data': base64Audio,
          }
        ]
      }
    };

    _sendJson(audioPayload);
  }

  /// Send text prompt to Gemini Live
  void sendTextMessage(String text) {
    if (!_isConnected) return;

    final textPayload = {
      'realtimeInput': {
        'parts': [
          {'text': text}
        ]
      }
    };

    _sendJson(textPayload);
  }

  void _sendJson(Map<String, dynamic> jsonMap) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(jsonMap));
    }
  }

  void disconnect() {
    _handleDisconnect('Disconnected by user');
  }

  void _handleDisconnect(String reason) {
    if (!_isConnected) return;
    _isConnected = false;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    onStateChanged?.call('idle');
    debugPrint('[GeminiLiveService] Disconnected: $reason');
  }
}
