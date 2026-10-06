import 'package:fc_frontend/core/widgets/joystick_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the stick follows a short drag and stays still near the center', (
    tester,
  ) async {
    final reported = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                JoystickControl(
                  label: 'Orientation',
                  degrees: 0,
                  onChanged: reported.add,
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );

    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    final center = tester.getCenter(find.byType(JoystickControl));
    final disc = tester.getCenter(
      find.descendant(
        of: find.byType(JoystickControl),
        matching: find.byType(RawGestureDetector),
      ),
    );

    final wobble = await tester.startGesture(disc);
    await wobble.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(reported, isEmpty);
    await wobble.up();
    await tester.pump();

    final aim = await tester.startGesture(disc);
    await aim.moveBy(const Offset(0, 8));
    await tester.pump();
    expect(reported, isNotEmpty);
    expect(reported.last, closeTo(90, 0.2));
    await aim.moveBy(const Offset(40, -8));
    await tester.pump();
    expect(reported.last, closeTo(0, 0.2));
    await aim.up();
    await tester.pump();

    expect(scroll.position.pixels, 0);
    expect(center.dx, tester.getCenter(find.byType(JoystickControl)).dx);
  });
}
