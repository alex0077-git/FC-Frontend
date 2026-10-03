import 'package:fc_frontend/core/router/app_router.dart';
import 'package:fc_frontend/core/widgets/bottom_nav_bar.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:fc_frontend/features/map_flight/map_flight_page.dart';
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

  Future<void> pumpLanding(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const FcApp(),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Ground Plan'), findsOneWidget);
    expect(find.text('Fuselage'), findsOneWidget);
    expect(find.text('Connect to your drone to begin'), findsOneWidget);
    expect(find.byType(BottomNavBar), findsNothing);
  }

  testWidgets('Ground Plan opens the ground plan page in the app shell', (
    tester,
  ) async {
    await pumpLanding(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ground Plan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GroundPlanPage), findsOneWidget);
    expect(find.byType(MapFlightPage), findsNothing);
    expect(find.byType(BottomNavBar), findsOneWidget);
    expect(find.text('Call for Job'), findsOneWidget);
    expect(find.text('Boundaries'), findsOneWidget);
    expect(find.text('Takeoff'), findsNothing);
    expect(_topIcon('Profile'), findsOneWidget);
    expect(_topIcon('Settings'), findsOneWidget);
  });

  testWidgets('Start still opens the map and flight page in the app shell', (
    tester,
  ) async {
    await pumpLanding(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MapFlightPage), findsOneWidget);
    expect(find.byType(GroundPlanPage), findsNothing);
    expect(find.byType(BottomNavBar), findsOneWidget);
    expect(find.text('Takeoff'), findsOneWidget);
    expect(find.text('Boundaries'), findsNothing);
    expect(_topIcon('Profile'), findsOneWidget);
    expect(_topIcon('Settings'), findsOneWidget);
  });
}

Finder _topIcon(String tooltip) {
  return find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == tooltip,
  );
}
