/// Represents the active state of the PoshanEye Voice Assistant.
enum VoiceAssistantState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

extension VoiceAssistantStateX on VoiceAssistantState {
  bool get isIdle => this == VoiceAssistantState.idle;
  bool get isListening => this == VoiceAssistantState.listening;
  bool get isProcessing => this == VoiceAssistantState.processing;
  bool get isSpeaking => this == VoiceAssistantState.speaking;
  bool get isError => this == VoiceAssistantState.error;

  String get label {
    switch (this) {
      case VoiceAssistantState.idle:
        return 'Ready to listen';
      case VoiceAssistantState.listening:
        return 'Listening... Speak now';
      case VoiceAssistantState.processing:
        return 'Processing...';
      case VoiceAssistantState.speaking:
        return 'Assistant speaking...';
      case VoiceAssistantState.error:
        return 'Assistant error';
    }
  }
}
