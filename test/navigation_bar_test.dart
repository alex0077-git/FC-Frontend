import 'package:fc_frontend/core/router/app_router.dart';
import 'package:fc_frontend/core/widgets/ground_plan_bar.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:fc_frontend/features/job_execution/job_execution_page.dart';
import 'package:fc_frontend/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    appRouter.go('/');
  });

  Future<void> pumpRoute(WidgetTester tester, Size size, String route) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    appRouter.go(route);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const FcApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  Finder barText(String label) {
    return find.descendant(
      of: find.byType(GroundPlanBar),
      matching: find.text(label),
    );
  }

  testWidgets('map flight bottom bar is only the flight commands', (tester) async {
    await pumpRoute(tester, const Size(844, 390), '/map');

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Takeoff'), findsOneWidget);
    expect(find.text('RTL'), findsOneWidget);
    expect(find.text('Land'), findsOneWidget);
    expect(find.text('Boundaries'), findsNothing);
    expect(find.text('Obstacles'), findsNothing);
    expect(_topIcon('Profile'), findsOneWidget);
    expect(_topIcon('Settings'), findsOneWidget);

    await tester.tap(find.text('RTL'));
    await tester.pump();
    expect(find.text('Command the drone to return to launch?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Command sent (simulated)'), findsNothing);

    await tester.tap(find.text('Takeoff'));
    await tester.pump();
    expect(find.text('Command sent (simulated)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ground plan tools open in a sheet over the map', (tester) async {
    for (final size in [const Size(1200, 800), const Size(667, 375)]) {
      await pumpRoute(tester, size, '/ground-plan');

      expect(find.text('Home'), findsOneWidget);
      expect(barText('Boundaries'), findsOneWidget);
      expect(barText('Split'), findsOneWidget);
      expect(barText('AV'), findsNothing);
      expect(barText('Obstacles'), findsOneWidget);
      expect(barText('Waypoints'), findsOneWidget);
      expect(barText('History'), findsOneWidget);
      expect(find.text('Call for Job'), findsOneWidget);
      expect(find.text('Takeoff'), findsNothing);
      expect(find.text('Reset'), findsNothing);
      expect(find.text('Add Obstacle'), findsNothing);

      await tester.tap(barText('Boundaries'));
      await tester.pump();
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Redo'), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.redo), findsOneWidget);
      expect(find.text('Add Obstacle'), findsNothing);
      expect(find.byKey(const Key('ground-plan-sheet')), findsNothing);
      final undo = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Undo'));
      final redo = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Redo'));
      expect(undo.onPressed, isNull);
      expect(redo.onPressed, isNull);
      final undoSize = tester.getSize(find.widgetWithText(TextButton, 'Undo'));
      expect(undoSize.height, greaterThanOrEqualTo(48));
      expect(undoSize.width, greaterThanOrEqualTo(64));
      final undoColor = tester.widget<Text>(find.text('Undo')).style?.color;
      expect(undoColor, isNotNull);
      expect(undoColor!.a, greaterThan(0.3));
      expect(undoColor.a, lessThan(0.7));
      final reset = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Reset'));
      expect(reset.style?.backgroundColor?.resolve({}), Colors.red);
      final page = tester.getSize(find.byType(GroundPlanPage));
      final box = tester.getRect(find.byKey(const Key('ground-plan-boundary-box')));
      final undoRect = tester.getRect(find.widgetWithText(TextButton, 'Undo'));
      final redoRect = tester.getRect(find.widgetWithText(TextButton, 'Redo'));
      final resetRect = tester.getRect(find.widgetWithText(FilledButton, 'Reset'));
      expect(box.width, lessThan(page.width * 0.5));
      expect(box.contains(undoRect.center), isTrue);
      expect(box.contains(redoRect.center), isTrue);
      expect(box.contains(resetRect.center), isTrue);
      expect(redoRect.left, greaterThan(undoRect.left));
      expect(resetRect.left, greaterThan(redoRect.left));
      expect(resetRect.width, lessThan(page.width * 0.25));

      await tester.tap(barText('Boundaries'));
      await tester.pump();
      expect(find.text('Reset'), findsNothing);

      await tester.tap(barText('Boundaries'));
      await tester.pump();

      await tester.tap(barText('Obstacles'));
      await tester.pump();
      expect(find.text('Circle'), findsOneWidget);
      expect(find.text('Polygon'), findsOneWidget);
      expect(find.text('Add Obstacle'), findsNothing);
      expect(find.text('Reset'), findsNothing);
      expect(find.byKey(const Key('ground-plan-sheet')), findsNothing);

      await tester.tap(barText('Obstacles'));
      await tester.pump();
      expect(find.text('Circle'), findsNothing);
      expect(find.text('Call for Job'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('every ground plan sheet stays under the compact cap', (tester) async {
    const sections = ['Waypoints', 'History'];
    for (final size in [const Size(1200, 800), const Size(667, 375)]) {
      await pumpRoute(tester, size, '/ground-plan');
      final pageHeight = tester.getSize(find.byType(GroundPlanPage)).height;
      final cap = pageHeight * (pageHeight < 480 ? 0.45 : 0.34);

      for (final label in sections) {
        await tester.tap(barText(label));
        await tester.pump();
        final sheetFinder = find.byKey(const Key('ground-plan-sheet'));
        expect(sheetFinder, findsOneWidget, reason: '$label sheet at $size');
        final sheetHeight = tester.getSize(sheetFinder).height;
        expect(sheetHeight, lessThanOrEqualTo(cap + 1), reason: '$label at $size');
        expect(sheetHeight, lessThan(pageHeight * 0.5), reason: '$label at $size');
      }

      final scrollable = find.descendant(
        of: find.byKey(const Key('ground-plan-sheet')),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      expect(tester.state<ScrollableState>(scrollable).position.maxScrollExtent, greaterThan(0));

      await tester.tap(barText('Boundaries'));
      await tester.pump();
      expect(find.byKey(const Key('ground-plan-sheet')), findsNothing);
      expect(find.byKey(const Key('ground-plan-boundary-box')), findsOneWidget);

      await tester.tap(barText('Split'));
      await tester.pump();
      final splitBox = tester.getSize(find.byKey(const Key('ground-plan-split-box')));
      expect(splitBox.width, lessThanOrEqualTo(pageHeight > 0 ? tester.getSize(find.byType(GroundPlanPage)).width * 0.7 : splitBox.width));
      expect(splitBox.width, lessThanOrEqualTo(360 + 1));
      expect(find.byKey(const Key('ground-plan-sheet')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ground plan map RTL confirms then sends the flight command', (
    tester,
  ) async {
    for (final size in [const Size(1200, 800), const Size(667, 375)]) {
      await pumpRoute(tester, size, '/ground-plan');

      expect(
        find.descendant(of: find.byType(GroundPlanBar), matching: find.text('RTL')),
        findsNothing,
      );
      final button = _rtlButton();
      expect(button, findsOneWidget);
      expect(find.descendant(of: button, matching: find.byIcon(Icons.flight_land)), findsOneWidget);
      final page = tester.getRect(find.byType(GroundPlanPage));
      final buttonRect = tester.getRect(button);
      expect(page.contains(buttonRect.center), isTrue);
      expect(buttonRect.center.dx, greaterThan(page.center.dx));
      expect(buttonRect.bottom, greaterThan(page.center.dy));

      await tester.tap(button);
      await tester.pump();
      expect(find.text('Command the drone to return to launch?'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Command sent (simulated)'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      expect(find.text('Command sent (simulated)'), findsNothing);
      expect(find.text('Command the drone to return to launch?'), findsNothing);

      await tester.tap(barText('Boundaries'));
      await tester.pump();
      expect(find.text('Reset'), findsOneWidget);
      final openButton = tester.getRect(_rtlButton());
      final resetRect = tester.getRect(find.widgetWithText(FilledButton, 'Reset'));
      expect(resetRect.center.dx, lessThan(page.center.dx));
      expect(openButton.center.dx, greaterThan(page.center.dx));
      expect(openButton.overlaps(resetRect), isFalse);

      await tester.tap(_rtlButton());
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      expect(find.text('Command sent (simulated)'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(GroundPlanPage))).clearSnackBars();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('profile and settings stay in the top bar on other pages', (
    tester,
  ) async {
    await pumpRoute(tester, const Size(1200, 800), '/profile');

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Takeoff'), findsNothing);
    expect(find.text('Boundaries'), findsNothing);
    expect(_topIcon('Profile'), findsOneWidget);
    expect(_topIcon('Settings'), findsOneWidget);

    await tester.tap(_topIcon('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Calibration'), findsOneWidget);
    expect(find.text('Battery'), findsOneWidget);
    expect(find.text('Flight Parameters'), findsOneWidget);

    appRouter.go('/job-execution');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(JobExecutionPage), findsOneWidget);
    expect(find.text('Back to Ground Plan'), findsNothing);
    expect(find.text('Guidelines'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Takeoff'), findsNothing);
    expect(find.text('Boundaries'), findsNothing);
    expect(_topIcon('Profile'), findsOneWidget);
    expect(_topIcon('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _expectSheetWithinCap(WidgetTester tester) {
  final pageHeight = tester.getSize(find.byType(GroundPlanPage)).height;
  final cap = pageHeight * (pageHeight < 480 ? 0.45 : 0.34);
  final sheetHeight = tester.getSize(find.byKey(const Key('ground-plan-sheet'))).height;
  expect(sheetHeight, lessThanOrEqualTo(cap + 1));
  expect(sheetHeight, lessThan(pageHeight * 0.5));
}

Finder _rtlButton() {
  return find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == 'Return to launch',
  );
}

Finder _topIcon(String tooltip) {
  return find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == tooltip,
  );
}
