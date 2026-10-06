import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:fc_frontend/core/geometry/polygon_simple.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/models/boundary_point.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final origin = const LatLng(12.97, 77.59);
  LatLng at(double east, double north) => shiftByMeters(origin, east, north);

  test('a square is simple and a figure-8 is not', () {
    final square = [at(0, 0), at(100, 0), at(100, 100), at(0, 100)];
    expect(polygonIsSimple(square, closed: true), isTrue);
    expect(polygonIsSimple(square, closed: false), isTrue);
    expect(polygonIsSimple(square.take(3).toList(), closed: true), isTrue);

    final bowtie = [at(0, 0), at(100, 0), at(0, 100), at(100, 100)];
    expect(polygonIsSimple(bowtie, closed: false), isTrue);
    expect(polygonIsSimple(bowtie, closed: true), isFalse);

    final figureEight = [at(0, 0), at(100, 100), at(0, 100), at(100, 0)];
    expect(polygonIsSimple(figureEight, closed: false), isFalse);
    expect(polygonIsSimple(figureEight, closed: true), isFalse);
  });

  test('a crossing boundary point is refused and a square is kept', () {
    final repo = MissionRepository();
    addTearDown(repo.dispose);

    expect(_add(repo, at(0, 0)), isTrue);
    expect(_add(repo, at(100, 0)), isTrue);
    expect(_add(repo, at(0, 100)), isTrue);
    final undoSteps = repo.state.undoHistory.length;

    expect(_add(repo, at(100, 100)), isFalse);
    expect(repo.state.boundaryPoints, hasLength(3));
    expect(repo.state.undoHistory, hasLength(undoSteps));

    repo.resetBoundary();
    expect(_add(repo, at(0, 0)), isTrue);
    expect(_add(repo, at(100, 0)), isTrue);
    expect(_add(repo, at(100, 100)), isTrue);
    expect(_add(repo, at(0, 100)), isTrue);

    final corner = repo.state.boundaryPoints.last;
    final keptLatitude = corner.latitude;
    final moves = repo.state.undoHistory.length;
    expect(
      repo.updateBoundaryPoint(
        id: corner.id,
        latitude: at(150, 50).latitude,
        longitude: at(150, 50).longitude,
        altitude: corner.altitude,
        speed: corner.speed,
      ),
      isFalse,
    );
    expect(repo.state.boundaryPoints.last.latitude, keptLatitude);
    expect(repo.state.undoHistory, hasLength(moves));
  });

  test('a crossing polygon obstacle is not saved', () {
    final repo = MissionRepository();
    addTearDown(repo.dispose);
    expect(
      repo.addPolygonObstacle([at(0, 0), at(100, 0), at(100, 100), at(0, 100)]),
      isNotEmpty,
    );
    expect(
      repo.addPolygonObstacle([at(0, 0), at(100, 0), at(0, 100), at(100, 100)]),
      isEmpty,
    );
    expect(repo.state.obstacles, hasLength(1));
  });

  testWidgets('tapping a crossing boundary point shows a message and skips it', (
    tester,
  ) async {
    final repository = await _pumpPlan(tester);
    _add(repository, at(0, 0));
    _add(repository, at(100, 0));
    _add(repository, at(0, 100));
    await tester.pump();

    await _tapMap(tester, at(100, 100));

    expect(find.text(boundaryCrossesMessage), findsOneWidget);
    expect(repository.state.boundaryPoints, hasLength(3));
  });

  testWidgets('a polygon corner that crosses is skipped, and a bowtie cannot be kept', (
    tester,
  ) async {
    final repository = await _pumpPlan(tester);
    final section = ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    ).read(groundPlanSectionProvider.notifier);
    section.open(GroundPlanSection.obstacles);
    await tester.pump();
    await tester.ensureVisible(find.text('Polygon'));
    await tester.tap(find.text('Polygon'));
    await tester.pump();

    await _tapMap(tester, at(0, 0));
    await _tapMap(tester, at(100, 100));
    await _tapMap(tester, at(0, 100));
    await _tapMap(tester, at(100, 0));

    expect(find.text(obstacleCrossesMessage), findsOneWidget);
    expect(repository.state.obstacles, isEmpty);

    await tester.ensureVisible(find.text('OK'));
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(repository.state.obstacles, hasLength(1));
    expect(repository.state.obstacles.single.vertices, hasLength(3));

    ScaffoldMessenger.of(
      tester.element(find.byType(GroundPlanPage)),
    ).clearSnackBars();
    await tester.pump();

    section.open(GroundPlanSection.obstacles);
    await tester.pump();
    await tester.ensureVisible(find.text('Polygon'));
    await tester.tap(find.text('Polygon'));
    await tester.pump();
    await _tapMap(tester, at(0, 0));
    await _tapMap(tester, at(100, 0));
    await _tapMap(tester, at(0, 100));
    await _tapMap(tester, at(100, 100));
    expect(find.text(obstacleCrossesMessage), findsNothing);

    await tester.ensureVisible(find.text('OK'));
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text(closedShapeCrossesMessage), findsOneWidget);
    expect(repository.state.obstacles, hasLength(1));
  });

  testWidgets('call for job refuses a boundary that already crosses itself', (
    tester,
  ) async {
    final repository = await _pumpPlan(tester);
    repository.state = repository.state.copyWith(
      boundaryPoints: [
        for (var index = 0; index < 4; index++)
          BoundaryPoint(
            id: 'cross-$index',
            latitude: [at(0, 0), at(100, 0), at(0, 100), at(100, 100)][index]
                .latitude,
            longitude: [at(0, 0), at(100, 0), at(0, 100), at(100, 100)][index]
                .longitude,
            order: index,
          ),
      ],
    );
    await tester.pump();

    await tester.tap(find.text('Call for Job'));
    await tester.pump();

    expect(find.text(closedShapeCrossesMessage), findsOneWidget);
    expect(find.text('Select Crop'), findsNothing);
    expect(repository.state.coverageLines, isEmpty);
    expect(repository.state.boundaryEditingLocked, isFalse);
  });
}

bool _add(MissionRepository repo, LatLng point) {
  return repo.addBoundaryPoint(
    latitude: point.latitude,
    longitude: point.longitude,
  );
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

Future<void> _tapMap(WidgetTester tester, LatLng point) async {
  final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
  map.mapController!.move(point, 16);
  await tester.pump();
  await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
  await tester.pump(const Duration(milliseconds: 300));
}
