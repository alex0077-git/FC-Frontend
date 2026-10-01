import 'dart:math';

import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:fc_frontend/data/models/obstacle.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a circle and a square both block their interior', () {
    final circle = Obstacle(
      id: 'circle',
      type: ObstacleType.circle,
      center: _at(-10, 20),
      radiusMeters: 6,
    );
    expect(circle.contains(_at(-10, 20)), isTrue);
    expect(circle.contains(_at(-10, 25)), isTrue);
    expect(circle.contains(_at(-10, 27)), isFalse);

    final square = Obstacle(
      id: 'square',
      type: ObstacleType.square,
      center: _at(10, 20),
      sideMeters: 12,
    );
    expect(square.contains(_at(10, 20)), isTrue);
    expect(square.contains(_at(15, 20)), isTrue);
    expect(square.contains(_at(17, 20)), isFalse);
    expect(square.contains(_at(0, 20)), isFalse);
    expect(circle.outsidePieces(_at(-20, 20), _at(20, 20)), hasLength(2));
    expect(square.outsidePieces(_at(-20, 20), _at(20, 20)), hasLength(2));
  });

  test('waypoints cannot be placed or dragged inside either shape', () {
    final repository = MissionRepository();
    _addRectangle(repository);
    repository.addCircleObstacle(_at(-10, 20));
    repository.addSquareObstacle(_at(10, 20));

    expect(
      repository.addBoundaryPoint(
        latitude: _at(10, 20).latitude,
        longitude: _at(10, 20).longitude,
      ),
      isFalse,
    );
    expect(
      repository.addBoundaryPoint(
        latitude: _at(-10, 20).latitude,
        longitude: _at(-10, 20).longitude,
      ),
      isFalse,
    );
    expect(repository.state.boundaryPoints, hasLength(4));

    final corner = repository.state.boundaryPoints.first;
    final moved = repository.updateBoundaryPoint(
      id: corner.id,
      latitude: _at(10, 20).latitude,
      longitude: _at(10, 20).longitude,
      altitude: corner.altitude,
      speed: corner.speed,
    );
    expect(moved, isFalse);
    expect(repository.state.boundaryPoints.first.latitude, corner.latitude);
  });

  test('coverage stays outside both a circle and a square', () async {
    final repository = MissionRepository();
    _addRectangle(repository);
    repository.addCircleObstacle(_at(-10, 20));
    repository.updateObstacleRadius(repository.state.obstacles.first.id, 6);
    final squareId = repository.addSquareObstacle(_at(10, 20));
    repository.updateObstacleSide(squareId, 12);
    repository.saveObstacle(squareId);
    expect(repository.state.obstacles.last.finalized, isTrue);
    repository.updateObstacleSide(squareId, 30);
    expect(repository.state.obstacles.last.sideMeters, 12);

    await repository.generateCoverage(spacingMeters: 10, orientationDegrees: 0);

    final lines = repository.state.coverageLines;
    expect(lines, isNotEmpty);
    expect(repository.state.coverageBlockedByObstacle, isFalse);
    for (final waypoint in repository.state.waypoints) {
      expect(
        repository.isPointInsideAnyObstacle(
          LatLng(waypoint.latitude, waypoint.longitude),
        ),
        isFalse,
      );
    }
    for (final line in lines) {
      for (var step = 0; step <= 8; step++) {
        final t = step / 8;
        final point = LatLng(
          line.endpoints[0].latitude +
              (line.endpoints[1].latitude - line.endpoints[0].latitude) * t,
          line.endpoints[0].longitude +
              (line.endpoints[1].longitude - line.endpoints[0].longitude) * t,
        );
        expect(repository.isPointInsideAnyObstacle(point), isFalse);
      }
    }

    expect(_nearLine(lines, _at(0, 8)), isTrue);
    expect(_nearLine(lines, _at(-18, 16)), isTrue);
    expect(_nearLine(lines, _at(0, 16)), isTrue);
    expect(_nearLine(lines, _at(18, 16)), isTrue);
    expect(_nearLine(lines, _at(-10, 16)), isFalse);
    expect(_nearLine(lines, _at(10, 16)), isFalse);
  });

  testWidgets('square side locks after Save and a circle still resizes', (tester) async {
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

    final repository = ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    ).read(missionRepositoryProvider.notifier);
    repository.addBoundaryPoint(latitude: 12.970, longitude: 77.590);
    repository.addBoundaryPoint(latitude: 12.970, longitude: 77.595);
    repository.addBoundaryPoint(latitude: 12.974, longitude: 77.595);
    await tester.pump();

    await tester.tap(find.text('Obstacles'));
    await tester.pump();
    await tester.tap(find.text('Add Obstacle'));
    await tester.pump();
    expect(find.text('Circle'), findsOneWidget);
    expect(find.text('Square'), findsOneWidget);
    expect(find.text('Polygon'), findsNothing);

    await tester.tap(find.text('Square'));
    await tester.pump();
    final squareId = repository.addSquareObstacle(const LatLng(12.972, 77.592));
    await tester.pump();
    await tester.ensureVisible(find.text('Square zone'));
    await tester.tap(find.text('Square zone'));
    await tester.pump();
    expect(find.text('Side'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    final increaseSide = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Increase side',
    );
    await tester.ensureVisible(increaseSide);
    await tester.pump();
    await tester.tap(increaseSide);
    await tester.pump();
    expect(repository.state.obstacles.single.sideMeters, 11);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(repository.state.obstacles.single.finalized, isTrue);
    expect(find.text('Side'), findsNothing);
    expect(find.text('Save'), findsNothing);

    repository.addCircleObstacle(const LatLng(12.973, 77.593));
    await tester.pump();
    await tester.ensureVisible(find.text('Circle zone'));
    await tester.tap(find.text('Circle zone'));
    await tester.pump();
    expect(find.text('Radius'), findsOneWidget);
    final increaseRadius = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Increase radius',
    );
    await tester.ensureVisible(increaseRadius);
    await tester.pump();
    await tester.tap(increaseRadius);
    await tester.pump();
    expect(
      repository.state.obstacles
          .firstWhere((obstacle) => obstacle.id != squareId)
          .radiusMeters,
      11,
    );
  });
}

void _addRectangle(MissionRepository repository) {
  for (final point in [
    _at(-20, 0),
    _at(20, 0),
    _at(20, 40),
    _at(-20, 40),
  ]) {
    repository.addBoundaryPoint(
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }
}

bool _nearLine(List<CoverageLine> lines, LatLng point) {
  for (final line in lines) {
    if (_distanceToSegment(point, line.endpoints[0], line.endpoints[1]) <= 1.5) {
      return true;
    }
  }
  return false;
}

double _distanceToSegment(LatLng point, LatLng start, LatLng end) {
  final origin = point;
  final from = _xy(start, origin);
  final to = _xy(end, origin);
  final dx = to.$1 - from.$1;
  final dy = to.$2 - from.$2;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared < 1e-8) {
    return sqrt(from.$1 * from.$1 + from.$2 * from.$2);
  }
  final t = ((-from.$1) * dx + (-from.$2) * dy) / lengthSquared;
  final clamped = t.clamp(0.0, 1.0);
  final x = from.$1 + clamped * dx;
  final y = from.$2 + clamped * dy;
  return sqrt(x * x + y * y);
}

const _originLatitude = 12.97;
const _originLongitude = 77.59;
const _metersPerDegree = 111320.0;

LatLng _at(double east, double north) {
  final scale = _metersPerDegree * cos(_originLatitude * pi / 180);
  return LatLng(
    _originLatitude + north / _metersPerDegree,
    _originLongitude + east / scale,
  );
}

(double, double) _xy(LatLng point, LatLng origin) {
  final scale = _metersPerDegree * cos(origin.latitude * pi / 180);
  return (
    (point.longitude - origin.longitude) * scale,
    (point.latitude - origin.latitude) * _metersPerDegree,
  );
}
