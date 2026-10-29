import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poshaneye_auth/assistant/assistant_chat_client.dart';
import 'package:poshaneye_auth/assistant/assistant_context.dart';
import 'package:poshaneye_auth/assistant/assistant_tools.dart';
import 'package:poshaneye_auth/assistant/voice_assistant_controller.dart';
import 'package:poshaneye_auth/assistant/voice_assistant_service.dart';

class FakeVoiceService extends VoiceAssistantService {
  final List<String> spoken = [];
  String? listenedLocale;

  @override
  Future<void> initTts(
      {VoidCallback? onStart,
      VoidCallback? onDone,
      Function(String error)? onError}) async {}

  @override
  Future<void> startListening(
      {required Function(String, bool) onResult,
      String localeId = 'en_US',
      Function(String error)? onError}) async {
    listenedLocale = localeId;
  }

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> dispose() async {}
}

class FakeChatClient implements AssistantChatClient {
  final List<List<Map<String, String>>> receivedHistories = [];
  final List<String> receivedMessages = [];
  final List<String> answers = [];
  Completer<AssistantReply>? pending;
  Object? failure;

  @override
  Future<AssistantReply> reply(
      {required String message,
      required List<Map<String, String>> history,
      required String language,
      required String? accessToken,
      required String screen,
      required String? childId,
      required Map<String, String> nutritionRegion}) async {
    receivedMessages.add(message);
    receivedHistories
        .add(history.map((turn) => Map<String, String>.from(turn)).toList());
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return AssistantReply(text: answers.removeAt(0));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVoiceService voice;
  late FakeChatClient chat;
  late VoiceAssistantController controller;

  setUp(() {
    voice = FakeVoiceService();
    chat = FakeChatClient();
    controller = VoiceAssistantController(service: voice, chatClient: chat);
  });

  tearDown(() => controller.dispose());

  test('answers an open question and reads the Sarvam reply aloud', () async {
    chat.answers.add('A binary search halves the remaining choices each step.');

    await controller
        .processVoiceInput('Explain binary search with a simple example.');

    expect(chat.receivedMessages,
        ['Explain binary search with a simple example.']);
    expect(controller.lastResponse, contains('binary search'));
    expect(voice.spoken, [controller.lastResponse]);
    expect(controller.conversationMessageCount, 2);
  });

  test('sends recent turns so follow-up questions have context', () async {
    chat.answers.addAll(
        ['Plants use sunlight to make food.', 'They do this in their leaves.']);

    await controller.processVoiceInput('How does photosynthesis work?');
    await controller.processVoiceInput('Where does it happen?');

    expect(chat.receivedHistories[1], [
      {'role': 'user', 'content': 'How does photosynthesis work?'},
      {'role': 'assistant', 'content': 'Plants use sunlight to make food.'},
    ]);
  });

  test('runs supported navigation locally without calling Sarvam', () async {
    var wentHome = false;
    controller.attachTools(AssistantTools(
      onNavigateHome: () => wentHome = true,
      onNavigateScreening: () {},
      onNavigateResults: () {},
      onNavigateNutrition: () {},
      onNavigateProfile: () {},
      onGoBack: () {},
      onRepeatCurrentPage: () {},
    ));

    await controller.processVoiceInput('Go to home');

    expect(wentHome, isTrue);
    expect(chat.receivedMessages, isEmpty);
    expect(controller.lastResponse, contains('home'));
  });

  test('does not mistake a nutrition question for the nutrition tab action',
      () async {
    chat.answers.add('Nutrition is how the body gets and uses food.');

    await controller.processVoiceInput('What is nutrition?');

    expect(chat.receivedMessages, ['What is nutrition?']);
    expect(controller.lastResponse, contains('body'));
  });

  test('selects Kannada speech recognition when app language is Kannada',
      () async {
    controller.updateContext(
        const AssistantContext(currentScreen: 'home', language: 'kn'));

    await controller.startListening();

    expect(voice.listenedLocale, 'kn_IN');
  });

  test('shows and speaks a clear quota error without retrying', () async {
    chat.failure = Exception('429 quota exhausted');

    await controller.processVoiceInput('Tell me about photosynthesis.');

    expect(chat.receivedMessages, hasLength(1));
    expect(controller.lastResponse, contains('request limit'));
    expect(voice.spoken.single, controller.lastResponse);
  });

  test('ignores a pending answer after the user interrupts to speak again',
      () async {
    final response = Completer<AssistantReply>();
    chat.pending = response;
    final pendingRequest = controller.processVoiceInput('First question');
    await controller.startListening();
    response.complete(const AssistantReply(text: 'A stale answer'));
    await pendingRequest;

    expect(controller.lastResponse, isEmpty);
    expect(voice.spoken, isEmpty);
  });

  test('reset clears recent conversation context', () async {
    chat.answers.add('First answer.');
    await controller.processVoiceInput('First question');

    controller.reset();

    expect(controller.conversationMessageCount, 0);
  });
}
