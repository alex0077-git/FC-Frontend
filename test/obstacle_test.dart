import 'dart:math';

import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:fc_frontend/data/models/obstacle.dart';
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

    await repository.generateCoverage(marginMeters: 0, spacingMeters: 10, orientationDegrees: 0);

    final lines = repository.state.coverageLines;
    expect(lines, isNotEmpty);
    expect(repository.state.coverageBlockedByObstacle, isFalse);
    for (final waypoint in repository.state.waypoints) {
      final point = LatLng(waypoint.latitude, waypoint.longitude);
      expect(repository.state.obstacles.any((zone) => zone.enters(point)), isFalse);
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
        expect(
          repository.state.obstacles.any((zone) => zone.enters(point)),
          isFalse,
        );
      }
    }

    expect(_nearLine(lines, _at(0, 8)), isTrue);
    expect(_nearLine(lines, _at(-18, 16)), isTrue);
    expect(_nearLine(lines, _at(0, 16)), isTrue);
    expect(_nearLine(lines, _at(18, 16)), isTrue);
    expect(_nearLine(lines, _at(-10, 16)), isFalse);
    expect(_nearLine(lines, _at(10, 16)), isFalse);
  });

  test('a circle follows straight sides and a square follows its edges', () {
    final circle = Obstacle(
      id: 'circle',
      type: ObstacleType.circle,
      center: _at(0, 0),
      radiusMeters: 10,
    );
    final through = circle.routeAround(_at(-40, 0), _at(40, 0));
    expect(through.length, greaterThan(4));
    expect(through.length, lessThan(Obstacle.circleRouteSides));
    final buffer = circle.radiusMeters! + Obstacle.circleBufferMeters;
    final cornerRadius = buffer / cos(pi / Obstacle.circleRouteSides);
    var cornerSteps = 0;
    for (var index = 1; index < through.length; index++) {
      expect(
        _distanceToSegment(circle.center!, through[index - 1], through[index]),
        greaterThan(circle.radiusMeters! - Obstacle.borderTouchMeters),
      );
      final previous = _xy(through[index - 1], circle.center!);
      final current = _xy(through[index], circle.center!);
      final previousDistance = sqrt(previous.$1 * previous.$1 + previous.$2 * previous.$2);
      final currentDistance = sqrt(current.$1 * current.$1 + current.$2 * current.$2);
      if ((previousDistance - cornerRadius).abs() > 0.15 ||
          (currentDistance - cornerRadius).abs() > 0.15) {
        continue;
      }
      var sweep = atan2(current.$2, current.$1) - atan2(previous.$2, previous.$1);
      while (sweep > pi) {
        sweep -= 2 * pi;
      }
      while (sweep < -pi) {
        sweep += 2 * pi;
      }
      expect(sweep.abs(), closeTo(2 * pi / Obstacle.circleRouteSides, 0.08));
      expect(previousDistance, greaterThan(buffer));
      expect(currentDistance, greaterThan(buffer));
      cornerSteps++;
    }
    expect(cornerSteps, greaterThan(0));
    expect(cornerSteps, lessThan(Obstacle.circleRouteSides));

    final square = Obstacle(
      id: 'square',
      type: ObstacleType.square,
      center: _at(0, 0),
      sideMeters: 10,
    );
    final across = square.routeAround(_at(-40, 0), _at(40, 0));
    final clip = square.routeAround(_at(-40, 3), _at(40, 6));
    expect(across.length, inInclusiveRange(3, 4));
    expect(clip.length, inInclusiveRange(3, 4));
    for (final bend in [across, clip]) {
      for (var index = 1; index < bend.length; index++) {
        expect(square.enters(bend[index]), isFalse);
      }
    }
  });

  test('a circle in the path is a bend in the same connected route', () async {
    final repository = MissionRepository();
    _addRectangle(repository);
    repository.addCircleObstacle(_at(0, 20));
    repository.updateObstacleRadius(repository.state.obstacles.single.id, 8);
    await repository.generateCoverage(marginMeters: 0, spacingMeters: 10, orientationDegrees: 0);

    expect(repository.state.coveragePaths, hasLength(1));
    final points = repository.state.coveragePaths.single.points;
    expect(points.length, greaterThan(2));
    final circle = repository.state.obstacles.single;
    final center = circle.center!;
    for (var index = 0; index < points.length; index++) {
      expect(circle.enters(points[index]), isFalse);
      if (index == 0) {
        continue;
      }
      final mid = LatLng(
        (points[index - 1].latitude + points[index].latitude) / 2,
        (points[index - 1].longitude + points[index].longitude) / 2,
      );
      expect(circle.enters(mid), isFalse);
    }

    expect(circle.outline, hasLength(72));
    for (final point in circle.outline) {
      final local = _xy(point, center);
      final distance = sqrt(local.$1 * local.$1 + local.$2 * local.$2);
      expect(distance, closeTo(8, 0.05));
    }

    final buffer = circle.radiusMeters! + Obstacle.circleBufferMeters;
    final cornerRadius = buffer / cos(pi / Obstacle.circleRouteSides);
    var cornerSteps = 0;
    for (var index = 1; index < points.length; index++) {
      final previous = _xy(points[index - 1], center);
      final current = _xy(points[index], center);
      final previousDistance = sqrt(previous.$1 * previous.$1 + previous.$2 * previous.$2);
      final currentDistance = sqrt(current.$1 * current.$1 + current.$2 * current.$2);
      if ((previousDistance - cornerRadius).abs() > 0.02 ||
          (currentDistance - cornerRadius).abs() > 0.02) {
        continue;
      }
      var sweep = atan2(current.$2, current.$1) - atan2(previous.$2, previous.$1);
      while (sweep > pi) {
        sweep -= 2 * pi;
      }
      while (sweep < -pi) {
        sweep += 2 * pi;
      }
      expect(sweep.abs(), closeTo(2 * pi / Obstacle.circleRouteSides, 0.08));
      expect(previousDistance, greaterThan(buffer));
      expect(currentDistance, greaterThan(buffer));
      cornerSteps++;
    }
    expect(cornerSteps, greaterThan(0));
    for (final point in points) {
      final local = _xy(point, center);
      final distance = sqrt(local.$1 * local.$1 + local.$2 * local.$2);
      if (distance > cornerRadius + 0.05) {
        continue;
      }
      expect(_distanceToRing(point, center, cornerRadius), lessThan(0.05));
    }
    for (var index = 1; index < points.length; index++) {
      expect(
        _distanceToSegment(center, points[index - 1], points[index]),
        greaterThan(circle.radiusMeters! - Obstacle.borderTouchMeters),
      );
    }

    final straight = repository.state.coverageLines.where((line) {
      return _distanceToSegment(center, line.endpoints[0], line.endpoints[1]) > 12;
    });
    expect(straight, isNotEmpty);
    for (final line in straight) {
      final index = _pathIndex(points, line.endpoints[0]);
      expect(index, greaterThanOrEqualTo(0));
      final nextIsEnd = index + 1 < points.length &&
          _samePoint(points[index + 1], line.endpoints[1]);
      final previousIsEnd = index > 0 && _samePoint(points[index - 1], line.endpoints[1]);
      expect(nextIsEnd || previousIsEnd, isTrue);
    }
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

    ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    ).read(groundPlanSectionProvider.notifier).open(GroundPlanSection.obstacles);
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

    final squareBefore = repository.state.obstacles.single.center!;
    final moveEast = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Move east',
    );
    await tester.ensureVisible(moveEast);
    await tester.tap(moveEast);
    await tester.pump();
    expect(repository.state.obstacles.single.sideMeters, 11);
    expect(repository.state.obstacles.single.finalized, isTrue);
    final squareShift = _xy(repository.state.obstacles.single.center!, squareBefore);
    expect(squareShift.$1, closeTo(0.5, 0.05));
    expect(squareShift.$2, closeTo(0, 0.05));
    expect(find.text('0.5'), findsOneWidget);

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

    final circle = repository.state.obstacles.firstWhere(
      (obstacle) => obstacle.id != squareId,
    );
    await repository.generateCoverage(marginMeters: 0, spacingMeters: 20, orientationDegrees: 0);
    await tester.pump();
    final circleBefore = circle.center!;
    await tester.ensureVisible(find.text('Position'));
    await tester.pump();
    await tester.tap(find.text('Position'));
    await tester.pump();
    final moveCircleEast = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Move east',
    );
    await tester.ensureVisible(moveCircleEast);
    await tester.pump();
    await tester.tap(moveCircleEast);
    await tester.pump();
    final movedCircle = repository.state.obstacles.firstWhere(
      (obstacle) => obstacle.id != squareId,
    );
    expect(movedCircle.radiusMeters, 11);
    expect(movedCircle.type, ObstacleType.circle);
    final circleShift = _xy(movedCircle.center!, circleBefore);
    expect(circleShift.$1, closeTo(0.5, 0.05));
    expect(circleShift.$2, closeTo(0, 0.05));
    _expectOutside(repository.state.coveragePaths, movedCircle);
    expect(find.text('0.5'), findsOneWidget);

    await tester.ensureVisible(find.text('OK'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('0.0'), findsNWidgets(2));

    final committed = repository.state.obstacles.firstWhere(
      (obstacle) => obstacle.id != squareId,
    ).center!;
    await tester.ensureVisible(moveCircleEast);
    await tester.pump();
    await tester.tap(moveCircleEast);
    await tester.pump();
    expect(find.text('0.5'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    final restored = repository.state.obstacles.firstWhere(
      (obstacle) => obstacle.id != squareId,
    );
    expect(_samePoint(restored.center!, committed), isTrue);
    expect(restored.radiusMeters, 11);
    expect(find.text('Radius'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('moving an obstacle keeps its size and reroutes coverage around it', (
    tester,
  ) async {
    final repository = MissionRepository();
    addTearDown(repository.dispose);
    _addRectangle(repository);
    final circleId = repository.addCircleObstacle(_at(0, 20));
    repository.updateObstacleRadius(circleId, 8);
    await repository.generateCoverage(marginMeters: 0, spacingMeters: 10, orientationDegrees: 0);

    final before = repository.state.obstacles.single.center!;
    repository.moveObstacle(circleId, eastMeters: 0, northMeters: 12);
    await tester.pump();
    final circle = repository.state.obstacles.single;
    expect(circle.radiusMeters, 8);
    final shift = _xy(circle.center!, before);
    expect(shift.$1, closeTo(0, 0.05));
    expect(shift.$2, closeTo(12, 0.05));
    _expectOutside(repository.state.coveragePaths, circle);
    expect(_hugsCircle(repository.state.coveragePaths, circle), isTrue);
    expect(_hugsCenter(repository.state.coveragePaths, before, 8), isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    repository.placeObstacle(circleId, before);
    await tester.pump();
    final restored = repository.state.obstacles.single;
    expect(_samePoint(restored.center!, before), isTrue);
    expect(restored.radiusMeters, 8);
    _expectOutside(repository.state.coveragePaths, restored);

    await tester.pump(const Duration(milliseconds: 100));
    final squareId = repository.addSquareObstacle(_at(-12, 8));
    repository.updateObstacleSide(squareId, 6);
    repository.saveObstacle(squareId);
    final squareBefore = repository.state.obstacles
        .firstWhere((obstacle) => obstacle.id == squareId)
        .center!;
    repository.moveObstacle(squareId, eastMeters: 8, northMeters: 0);
    await tester.pump();
    final square = repository.state.obstacles.firstWhere(
      (obstacle) => obstacle.id == squareId,
    );
    expect(square.sideMeters, 6);
    expect(square.finalized, isTrue);
    final squareShift = _xy(square.center!, squareBefore);
    expect(squareShift.$1, closeTo(8, 0.05));
    expect(squareShift.$2, closeTo(0, 0.05));
    _expectOutside(repository.state.coveragePaths, square);
    _expectOutside(
      repository.state.coveragePaths,
      repository.state.obstacles.firstWhere((obstacle) => obstacle.id == circleId),
    );
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('rapid obstacle moves refresh coverage on the same timer as the joystick', (
    tester,
  ) async {
    final repository = MissionRepository();
    addTearDown(repository.dispose);
    _addRectangle(repository);
    final id = repository.addCircleObstacle(_at(0, 20));
    repository.updateObstacleRadius(id, 8);
    await repository.generateCoverage(marginMeters: 0, spacingMeters: 10, orientationDegrees: 0);
    repository.moveObstacle(id, eastMeters: 6, northMeters: 0);
    await tester.pump();
    _expectOutside(repository.state.coveragePaths, repository.state.obstacles.single);

    repository.moveObstacle(id, eastMeters: 6, northMeters: 0);
    final waiting = repository.state.obstacles.single;
    final waitingShift = _xy(waiting.center!, _at(0, 20));
    expect(waitingShift.$1, closeTo(12, 0.05));
    expect(waiting.radiusMeters, 8);
    expect(
      repository.state.coveragePaths.single.points.any(waiting.enters),
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 50));
    final settled = repository.state.obstacles.single;
    expect(settled.radiusMeters, 8);
    _expectOutside(repository.state.coveragePaths, settled);
    expect(_hugsCircle(repository.state.coveragePaths, settled), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
  });
}

void _expectOutside(List<CoveragePath> paths, Obstacle obstacle) {
  for (final path in paths) {
    final points = path.points;
    for (var index = 0; index < points.length; index++) {
      expect(obstacle.enters(points[index]), isFalse);
      if (index == 0) {
        continue;
      }
      final mid = LatLng(
        (points[index - 1].latitude + points[index].latitude) / 2,
        (points[index - 1].longitude + points[index].longitude) / 2,
      );
      expect(obstacle.enters(mid), isFalse);
    }
  }
}

bool _hugsCircle(List<CoveragePath> paths, Obstacle circle) {
  final center = circle.center!;
  final cornerRadius = (circle.radiusMeters! + Obstacle.circleBufferMeters) /
      cos(pi / Obstacle.circleRouteSides);
  for (final path in paths) {
    for (final point in path.points) {
      final local = _xy(point, center);
      final distance = sqrt(local.$1 * local.$1 + local.$2 * local.$2);
      if ((distance - cornerRadius).abs() < 0.2) {
        return true;
      }
    }
  }
  return false;
}

bool _hugsCenter(List<CoveragePath> paths, LatLng center, double radiusMeters) {
  final cornerRadius =
      (radiusMeters + Obstacle.circleBufferMeters) / cos(pi / Obstacle.circleRouteSides);
  for (final path in paths) {
    for (final point in path.points) {
      final local = _xy(point, center);
      final distance = sqrt(local.$1 * local.$1 + local.$2 * local.$2);
      if ((distance - cornerRadius).abs() < 0.2) {
        return true;
      }
    }
  }
  return false;
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

int _pathIndex(List<LatLng> points, LatLng target) {
  for (var index = 0; index < points.length; index++) {
    if (_samePoint(points[index], target)) {
      return index;
    }
  }
  return -1;
}

bool _samePoint(LatLng a, LatLng b) {
  return (a.latitude - b.latitude).abs() < 1e-8 &&
      (a.longitude - b.longitude).abs() < 1e-8;
}

bool _nearLine(List<CoverageLine> lines, LatLng point) {
  for (final line in lines) {
    if (_distanceToSegment(point, line.endpoints[0], line.endpoints[1]) <= 1.5) {
      return true;
    }
  }
  return false;
}

double _distanceToRing(LatLng point, LatLng center, double cornerRadius) {
  final scale = _metersPerDegree * cos(center.latitude * pi / 180);
  final step = 2 * pi / Obstacle.circleRouteSides;
  final vertices = <LatLng>[
    for (var index = 0; index < Obstacle.circleRouteSides; index++)
      LatLng(
        center.latitude + cornerRadius * sin(index * step) / _metersPerDegree,
        center.longitude + cornerRadius * cos(index * step) / scale,
      ),
  ];
  var nearest = double.infinity;
  for (var index = 0; index < vertices.length; index++) {
    final distance = _distanceToSegment(
      point,
      vertices[index],
      vertices[(index + 1) % vertices.length],
    );
    if (distance < nearest) {
      nearest = distance;
    }
  }
  return nearest;
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
