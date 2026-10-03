import 'package:fc_frontend/core/router/app_router.dart';
import 'package:fc_frontend/core/widgets/ground_plan_bar.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
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
      expect(find.text('Add Obstacle'), findsNothing);

      await tester.tap(barText('Obstacles'));
      await tester.pump();
      expect(find.text('Add Obstacle'), findsOneWidget);
      expect(find.text('Reset'), findsNothing);

      await tester.tap(barText('Obstacles'));
      await tester.pump();
      expect(find.text('Add Obstacle'), findsNothing);
      expect(find.text('Call for Job'), findsOneWidget);
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

    expect(find.text('Back to Ground Plan'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Takeoff'), findsNothing);
    expect(find.text('Boundaries'), findsNothing);
    expect(_topIcon('Profile'), findsOneWidget);
    expect(_topIcon('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _topIcon(String tooltip) {
  return find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == tooltip,
  );
}
