import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poshaneye_auth/widgets/interactive_eye_logo.dart';

void main() {
  testWidgets('InteractiveEyeLogo renders correctly and handles pointer updates',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveEyeLogo(width: 60),
          ),
        ),
      ),
    );

    // Verify widget is present
    expect(find.byType(InteractiveEyeLogo), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    // Simulate pointer hover/movement over the center of the widget
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 50));

    // Verify state updates without errors
    final state = tester.state<InteractiveEyeLogoState>(find.byType(InteractiveEyeLogo));
    expect(state, isNotNull);

    await gesture.removePointer();
  });
}
