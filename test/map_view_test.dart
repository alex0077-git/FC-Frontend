import 'package:fc_frontend/core/map/map_view.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:fc_frontend/features/job_execution/job_execution_page.dart';
import 'package:fc_frontend/features/map_flight/map_flight_page.dart';
import 'package:fc_frontend/features/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

  Finder styleButton(String tooltip) {
    return find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == tooltip,
    );
  }

  IconData styleIcon(WidgetTester tester) {
    final icon = tester.widget<Icon>(
      find.descendant(
        of: styleButton('Map style'),
        matching: find.byType(Icon),
      ),
    );
    return icon.icon!;
  }

  testWidgets('map style toggle is shared by every map page', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    final page = ValueNotifier<Widget>(const GroundPlanPage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: ValueListenableBuilder<Widget>(
          valueListenable: page,
          builder: (context, child, _) {
            return MaterialApp(
              theme: AppTheme.dark,
              home: Scaffold(body: child),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(styleButton('Map style'), findsOneWidget);
    expect(styleIcon(tester), Icons.map);
    expect(tileUrl(tester), MapTileLayer.streetUrl);

    await tester.tap(styleButton('Map style'));
    await tester.pumpAndSettle();
    expect(find.text('Digital Sky'), findsOneWidget);
    expect(find.byIcon(Icons.flight), findsOneWidget);

    await tester.tap(find.text('Satellite').last);
    await tester.pumpAndSettle();

    expect(styleButton('Map style'), findsOneWidget);
    expect(styleIcon(tester), Icons.satellite_alt);
    expect(tileUrl(tester), MapTileLayer.satelliteUrl);

    page.value = const MapFlightPage();
    await tester.pump();

    expect(styleButton('Map style'), findsOneWidget);
    expect(styleIcon(tester), Icons.satellite_alt);
    expect(tileUrl(tester), MapTileLayer.satelliteUrl);
    expect(find.text('Tiles © Esri'), findsOneWidget);

    page.value = const JobExecutionPage();
    await tester.pump();

    expect(styleButton('Map style'), findsOneWidget);
    expect(styleIcon(tester), Icons.satellite_alt);
    expect(tileUrl(tester), MapTileLayer.satelliteUrl);

    page.value = const ProfilePage();
    await tester.pump();

    final dropdown = tester.widget<DropdownButtonFormField<MapViewMode>>(
      find.byType(DropdownButtonFormField<MapViewMode>),
    );
    expect(dropdown.initialValue, MapViewMode.satellite);

    await tester.tap(find.text('Satellite'));
    await tester.pumpAndSettle();
    expect(find.text('Digital Sky'), findsOneWidget);
    await tester.tap(find.text('Street').last);
    await tester.pumpAndSettle();

    page.value = const GroundPlanPage();
    await tester.pump();

    expect(styleButton('Map style'), findsOneWidget);
    expect(styleIcon(tester), Icons.map);
    expect(tileUrl(tester), MapTileLayer.streetUrl);
  });
}

String? tileUrl(WidgetTester tester) {
  return tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate;
}
