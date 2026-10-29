import 'package:flutter_test/flutter_test.dart';
import 'package:poshaneye_auth/services/auth_registration.dart';
import 'package:poshaneye_auth/widgets/child_id_dialog.dart';

void main() {
  test('uses the Child ID actually returned by parent registration', () async {
    var requests = 0;
    final childId = await registerParentAndReadChildId(register: () async {
      requests++;
      return {'childId': 'CHD123'};
    });

    expect(requests, 1);
    expect(childId, 'CHD123');
  });

  test('does not fabricate an ID when registration response omits it', () async {
    var requests = 0;
    await expectLater(
      registerParentAndReadChildId(register: () async {
        requests++;
        return {'message': 'Account created successfully'};
      }),
      throwsFormatException,
    );
    expect(requests, 1);
  });

  test('rejects malformed IDs and propagates registration failures', () async {
    await expectLater(
      registerParentAndReadChildId(
          register: () async => {'childId': 'CHD-FAKE'}),
      throwsFormatException,
    );
    await expectLater(
      registerParentAndReadChildId(
          register: () async => throw Exception('registration failed')),
      throwsException,
    );
  });

  test('accepts the backend Child ID sequence format without a fixed length', () {
    expect(isValidChildId('CHD001'), isTrue);
    expect(isValidChildId('CHD12345'), isTrue);
    expect(isValidChildId(''), isFalse);
    expect(isValidChildId('HW001'), isFalse);
  });
}
