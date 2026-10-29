import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poshaneye_auth/widgets/child_id_dialog.dart';

void main() {
  testWidgets('shows the assigned ID once and waits for dismissal',
      (tester) async {
    var dialogCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              dialogCalls++;
              showChildIdDialog(context,
                  childId: 'CHD00841', childName: 'Test Child');
            },
            child: const Text('Register'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(dialogCalls, 1);
    expect(find.text('CHD00841'), findsOneWidget);
    expect(find.text('Welcome, Test Child!'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Got it, Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
