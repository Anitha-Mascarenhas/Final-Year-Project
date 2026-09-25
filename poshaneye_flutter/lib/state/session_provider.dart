import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionState {
  final String? childName;

  const SessionState({this.childName});

  bool get isSignedIn => childName != null;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  void signInAs(String childName) {
    state = SessionState(childName: childName);
  }

  void signOut() {
    state = const SessionState();
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
