import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionState {
  final String? childName;
  final String? childId;
  final String? accessToken;
  final String? dateOfBirth;

  const SessionState(
      {this.childName, this.childId, this.accessToken, this.dateOfBirth});

  bool get isSignedIn => childName != null;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  void signInAs(String childName,
      {String? childId, String? accessToken, String? dateOfBirth}) {
    state = SessionState(
        childName: childName,
        childId: childId,
        accessToken: accessToken,
        dateOfBirth: dateOfBirth);
  }

  void signOut() {
    state = const SessionState();
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
