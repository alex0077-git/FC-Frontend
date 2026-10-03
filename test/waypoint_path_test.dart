import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/models/waypoint.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_section.dart';
import 'package:fc_frontend/features/ground_plan/waypoint_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('manual waypoints show start, end, and a line in list order', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    final repository = MissionRepository(
      initialState: MissionState(
        waypoints: [
          _waypoint('a', 12.971, 77.590),
          _waypoint('b', 12.972, 77.592),
          _waypoint('c', 12.973, 77.594),
        ],
      ),
    );
    repository.addCircleObstacle(const LatLng(12.980, 77.600));

    await _pumpPlan(tester, preferences, repository);

    expect(find.text('S'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(_path(tester).points.map((point) => point.latitude), [
      12.971,
      12.972,
      12.973,
    ]);

    repository.updateWaypoint(_waypoint('b', 12.980, 77.600));
    await tester.pump();
    expect(repository.state.waypoints[1].latitude, 12.972);

    repository.updateWaypoint(_waypoint('b', 12.975, 77.591));
    await tester.pump();
    expect(_path(tester).points[1].latitude, 12.975);

    repository.deleteWaypoint('a');
    await tester.pump();
    expect(repository.state.waypoints.first.id, 'b');
    expect(_path(tester).points.map((point) => point.latitude), [12.975, 12.973]);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(find.text('2'), findsNothing);

    ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    ).read(groundPlanSectionProvider.notifier).open(GroundPlanSection.waypoints);
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);

    repository.deleteWaypoint('c');
    await tester.pump();
    expect(find.text('S'), findsOneWidget);
    expect(find.text('E'), findsNothing);
    expect(_hasPath(tester), isFalse);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsNothing);
  });

  testWidgets('coverage lines stay separate from the waypoint path', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await _pumpPlan(tester, preferences, null);
    final repository = ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    ).read(missionRepositoryProvider.notifier);
    repository.addBoundaryPoint(latitude: 12.970, longitude: 77.590);
    repository.addBoundaryPoint(latitude: 12.970, longitude: 77.595);
    repository.addBoundaryPoint(latitude: 12.974, longitude: 77.595);
    repository.addBoundaryPoint(latitude: 12.974, longitude: 77.590);
    await repository.generateCoverage(spacingMeters: 40, orientationDegrees: 0);
    await tester.pump();

    final waypoints = repository.state.waypoints;
    final path = repository.state.coveragePaths.single.points;
    expect(waypoints.length, greaterThan(1));
    expect(repository.state.coveragePaths, hasLength(1));
    expect(waypoints.first.latitude, closeTo(path.first.latitude, 1e-7));
    expect(waypoints.last.latitude, closeTo(path.last.latitude, 1e-7));
    expect(_hasPath(tester), isFalse);
    expect(
      tester
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .expand((layer) => layer.polylines)
          .where((line) => line.color == const Color(0xFFFACC15)),
      hasLength(1),
    );
    expect(find.text('S'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
  });
}

Waypoint _waypoint(String id, double latitude, double longitude) {
  return Waypoint(
    id: id,
    latitude: latitude,
    longitude: longitude,
    altitude: 30,
    speed: 5,
    action: WaypointAction.waypoint,
  );
}

Future<void> _pumpPlan(
  WidgetTester tester,
  SharedPreferences preferences,
  MissionRepository? repository,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        if (repository != null)
          missionRepositoryProvider.overrideWith((ref) => repository),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const GroundPlanPage(),
      ),
    ),
  ).then((_) => tester.pump());
}

bool _hasPath(WidgetTester tester) {
  return tester
      .widgetList<PolylineLayer>(find.byType(PolylineLayer))
      .expand((layer) => layer.polylines)
      .any((line) => line.color == waypointPathColor);
}

Polyline _path(WidgetTester tester) {
  return tester
      .widgetList<PolylineLayer>(find.byType(PolylineLayer))
      .expand((layer) => layer.polylines)
      .firstWhere((line) => line.color == waypointPathColor);
}
