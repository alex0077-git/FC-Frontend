import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:fc_frontend/features/job_execution/job_execution_page.dart';
import 'package:fc_frontend/features/map_flight/map_flight_page.dart';
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
  });

  Future<void> pumpPage(WidgetTester tester, Size size, Widget page) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('map flight fits a phone in landscape', (tester) async {
    await pumpPage(tester, const Size(844, 390), const MapFlightPage());
    expect(find.text('Takeoff'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ground plan fits a phone in landscape', (tester) async {
    await pumpPage(tester, const Size(667, 375), const GroundPlanPage());
    expect(find.text('Call for Job'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('job execution fits a phone in landscape', (tester) async {
    await pumpPage(tester, const Size(844, 390), const JobExecutionPage());
    await tester.scrollUntilVisible(
      find.text('Next Line'),
      80,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Next Line'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
