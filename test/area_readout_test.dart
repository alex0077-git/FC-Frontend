import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the area chip, obstacle row, and undo stay in step', (tester) async {
    final repository = await _pumpPlan(tester);
    _add(repository, _at(0, 0));
    _add(repository, _at(100, 0));
    _add(repository, _at(0, 100));
    await _settleArea(tester);

    expect(find.byKey(const Key('field-area-chip')), findsOneWidget);
    expect(find.byKey(const Key('field-area-card')), findsNothing);
    expect(find.byIcon(Icons.block), findsNothing);
    expect(find.text('0.50 ha'), findsOneWidget);

    repository.addCircleObstacle(_at(30, 30));
    await _settleArea(tester);

    expect(find.byIcon(Icons.block), findsNothing);
    expect(find.text('0.03 ha'), findsOneWidget);
    expect(find.text('0.47 ha'), findsOneWidget);
    expect(find.text('0.50 ha'), findsNothing);

    _add(repository, _at(-40, 40));
    await _settleArea(tester);
    expect(repository.state.boundaryPoints, hasLength(4));
    expect(find.text('0.67 ha'), findsOneWidget);
    expect(find.text('0.03 ha'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    ).read(groundPlanSectionProvider.notifier).open(GroundPlanSection.boundary);
    await tester.pump();
    await tester.tap(find.byTooltip('Undo'));
    await _settleArea(tester);

    expect(repository.state.boundaryPoints, hasLength(3));
    expect(find.text('0.47 ha'), findsOneWidget);
    expect(find.text('0.03 ha'), findsOneWidget);
    expect(find.text('0.67 ha'), findsNothing);

    await tester.tap(find.text('0.47 ha'));
    await tester.pump();
    expect(find.text('4686 m²'), findsOneWidget);
    expect(find.text('314 m²'), findsOneWidget);
    final preferences = ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    ).read(sharedPreferencesProvider);
    expect(preferences.getString('ground_plan_area_unit'), 'squareMeter');
  });
}

LatLng _at(double east, double north) {
  return shiftByMeters(const LatLng(12.97, 77.59), east, north);
}

void _add(MissionRepository repository, LatLng point) {
  repository.addBoundaryPoint(latitude: point.latitude, longitude: point.longitude);
}

Future<void> _settleArea(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Future<MissionRepository> _pumpPlan(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const GroundPlanPage(),
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(GroundPlanPage)),
  ).read(missionRepositoryProvider.notifier);
}
