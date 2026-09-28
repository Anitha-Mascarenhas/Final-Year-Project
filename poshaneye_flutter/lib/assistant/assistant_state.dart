/// Represents the active state of the PoshanEye Gemini Live Voice Assistant.
enum VoiceAssistantState {
  idle,
  connecting,
  listening,
  processing,
  speaking,
  error,
}

extension VoiceAssistantStateX on VoiceAssistantState {
  bool get isIdle => this == VoiceAssistantState.idle;
  bool get isConnecting => this == VoiceAssistantState.connecting;
  bool get isListening => this == VoiceAssistantState.listening;
  bool get isProcessing => this == VoiceAssistantState.processing;
  bool get isSpeaking => this == VoiceAssistantState.speaking;
  bool get isError => this == VoiceAssistantState.error;

  String get label {
    switch (this) {
      case VoiceAssistantState.idle:
        return 'Tap to speak';
      case VoiceAssistantState.connecting:
        return 'Connecting to Gemini...';
      case VoiceAssistantState.listening:
        return 'Listening...';
      case VoiceAssistantState.processing:
        return 'Thinking...';
      case VoiceAssistantState.speaking:
        return 'Assistant speaking...';
      case VoiceAssistantState.error:
        return 'Assistant error';
    }
  }
}
