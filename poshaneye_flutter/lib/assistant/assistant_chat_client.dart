import '../services/api_service.dart';

abstract interface class AssistantChatClient {
  Future<AssistantReply> reply({
    required String message,
    required List<Map<String, String>> history,
    required String language,
    required String? accessToken,
    required String screen,
    required String? childId,
    required Map<String, String> nutritionRegion,
  });
}

class AssistantReply {
  final String text;
  final List<Map<String, String>> sources;

  const AssistantReply({required this.text, this.sources = const []});
}

class BackendAssistantChatClient implements AssistantChatClient {
  @override
  Future<AssistantReply> reply({
    required String message,
    required List<Map<String, String>> history,
    required String language,
    required String? accessToken,
    required String screen,
    required String? childId,
    required Map<String, String> nutritionRegion,
  }) async {
    final result = await ApiService.askAssistant(
        message: message,
        history: history,
        language: language,
        token: accessToken,
        screen: screen,
        childId: childId,
        nutritionRegion: nutritionRegion,
      );
    final sources = (result['sources'] as List)
        .whereType<Map>()
        .map((source) => source.map((key, value) => MapEntry('$key', '$value')))
        .toList(growable: false);
    return AssistantReply(text: result['response'] as String, sources: sources);
  }
}
