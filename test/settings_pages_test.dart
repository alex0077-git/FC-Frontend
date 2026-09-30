import 'package:fc_frontend/core/router/app_router.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/theme/theme_mode_provider.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/profile/profile_page.dart';
import 'package:fc_frontend/features/settings/battery/battery_settings_page.dart';
import 'package:fc_frontend/features/settings/calibration/calibration_page.dart';
import 'package:fc_frontend/features/settings/flight_parameters/flight_parameters_page.dart';
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
    await preferences.clear();
    appRouter.go('/');
  });

  testWidgets('profile theme toggle switches ThemeData', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _ThemeHarness()));

    expect(Theme.of(tester.element(find.text('About'))).brightness, Brightness.dark);

    expect(find.widgetWithText(OutlinedButton, 'Light'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Light'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Light'), findsOneWidget);

    expect(
      Theme.of(tester.element(find.text('About'))).brightness,
      Brightness.light,
    );
    expect(find.text('Version $appVersion'), findsOneWidget);
  });

  testWidgets('calibration finishes after the progress animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CalibrationPage())),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Start Calibration').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(find.text('Calibrated'), findsOneWidget);
  });

  testWidgets('battery settings reject bad input and persist valid values', (
    tester,
  ) async {
    await _pump(tester, preferences, const BatterySettingsPage());

    await tester.enterText(_field('First Warning Threshold (%)'), 'abc');
    await tester.pump();
    expect(find.text('Enter a whole number'), findsOneWidget);
    expect(preferences.getInt('battery.first_warning_percent'), isNull);

    await tester.enterText(_field('First Warning Threshold (%)'), '30');
    await tester.pump();
    expect(preferences.getInt('battery.first_warning_percent'), 30);

    await _pump(tester, preferences, const BatterySettingsPage());
    expect(find.text('30'), findsWidgets);
  });

  testWidgets('flight parameters reject bad input and persist valid values', (
    tester,
  ) async {
    await _pump(tester, preferences, const FlightParametersPage());

    await tester.enterText(_field('Cruise Speed'), 'fast');
    await tester.pump();
    expect(find.text('Enter a number'), findsOneWidget);
    expect(preferences.getDouble('flight.cruise_speed'), isNull);

    await tester.enterText(_field('Cruise Speed'), '9');
    await tester.pump();
    expect(preferences.getDouble('flight.cruise_speed'), 9);

    await _pump(tester, preferences, const FlightParametersPage());
    expect(find.text('9'), findsWidgets);
  });

  testWidgets('settings routes render from the app router', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const FcApp(),
      ),
    );

    appRouter.go('/profile');
    await tester.pumpAndSettle();
    expect(find.text('Username'), findsOneWidget);

    appRouter.go('/settings/calibration');
    await tester.pumpAndSettle();
    expect(find.text('IMU 1'), findsOneWidget);
    expect(find.text('IMU 2'), findsOneWidget);

    appRouter.go('/settings/battery');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Calibrate Battery'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Calibrate Battery'), findsOneWidget);

    appRouter.go('/settings/flight-parameters');
    await tester.pumpAndSettle();
    expect(find.text('Max Yaw Rate'), findsOneWidget);
  });
}

Finder _field(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences preferences,
  Widget page,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: MaterialApp(theme: AppTheme.dark, home: Scaffold(body: page)),
    ),
  );
}

class _ThemeHarness extends ConsumerWidget {
  const _ThemeHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: const Scaffold(body: ProfilePage()),
    );
  }
}
