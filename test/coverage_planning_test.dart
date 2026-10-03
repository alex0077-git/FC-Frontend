import 'dart:math';

import 'package:fc_frontend/core/geometry/boundary_orientation.dart';
import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:fc_frontend/core/geometry/polygon_inset.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/coverage_lines.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('5 m spacing stays 5 m on the ground where longitude is shorter', () async {
    const origin = LatLng(60, 10);
    final repo = MissionRepository();
    _addRectangle(repo, origin, halfEast: 20, halfNorth: 11.5);

    await repo.generateCoverage(
      spacingMeters: 5,
      orientationDegrees: 0,
      marginMeters: 0,
    );
    final northGaps = _lineGaps(repo, origin);
    expect(northGaps, isNotEmpty);
    for (final gap in northGaps) {
      expect(gap, closeTo(4.6, 0.15));
      expect(gap, lessThanOrEqualTo(5.05));
    }

    await repo.generateCoverage(
      spacingMeters: 5,
      orientationDegrees: 90,
      marginMeters: 0,
    );
    final eastGaps = _lineGaps(repo, origin);
    expect(eastGaps, isNotEmpty);
    for (final gap in eastGaps) {
      expect(gap, lessThanOrEqualTo(5.05));
    }

    final longitudes = [
      for (final line in repo.state.coverageLines)
        (line.endpoints[0].longitude + line.endpoints[1].longitude) / 2,
    ]..sort();
    final degreeGap = (longitudes[1] - longitudes[0]).abs();
    final groundGap = degreeGap * longitudeMetersPerDegree(origin.latitude);
    expect(degreeGap * metersPerDegree, greaterThan(groundGap * 1.5));
    expect(groundGap, closeTo(eastGaps.first, 0.15));
  });

  test('coverage stays the margin distance inside the drawn boundary', () async {
    const origin = LatLng(12.97, 77.59);
    final repo = MissionRepository();
    final boundary = _addRectangle(repo, origin, halfEast: 40, halfNorth: 25);
    final before = [
      for (final point in repo.state.boundaryPoints)
        (point.latitude, point.longitude),
    ];

    await repo.generateCoverage(
      spacingMeters: 10,
      orientationDegrees: 0,
      marginMeters: 3,
    );

    for (var index = 0; index < before.length; index++) {
      expect(repo.state.boundaryPoints[index].latitude, before[index].$1);
      expect(repo.state.boundaryPoints[index].longitude, before[index].$2);
    }
    expect(repo.state.coveragePaths, isNotEmpty);
    for (final path in repo.state.coveragePaths) {
      for (final point in path.points) {
        expect(_distanceToRing(point, boundary), greaterThanOrEqualTo(2.6));
      }
    }

    final inset = insetPolygon(boundary, 3);
    expect(inset, hasLength(4));
    final width = _distance(inset[0], inset[1]);
    final height = _distance(inset[1], inset[2]);
    expect(min(width, height), closeTo(44, 0.2));
    expect(max(width, height), closeTo(74, 0.2));
  });

  test('obstacle detours turn the sprayer off and look dashed', () async {
    const origin = LatLng(12.97, 77.59);
    final repo = MissionRepository();
    _addRectangle(repo, origin, halfEast: 40, halfNorth: 40);
    final circleId = repo.addCircleObstacle(origin);
    repo.updateObstacleRadius(circleId, 8);

    await repo.generateCoverage(
      spacingMeters: 15,
      orientationDegrees: 0,
      marginMeters: 0,
    );

    final waypoints = repo.state.waypoints;
    expect(waypoints.any((waypoint) => waypoint.pumpOn), isTrue);
    final detours = waypoints.where((waypoint) => !waypoint.pumpOn).toList();
    expect(detours, isNotEmpty);
    for (final waypoint in detours) {
      final distance = _distance(
        LatLng(waypoint.latitude, waypoint.longitude),
        origin,
      );
      expect(distance, inInclusiveRange(7.5, 10));
    }

    final drawn = coveragePolylines(
      repo.state.coverageLines,
      paths: repo.state.coveragePaths,
    );
    expect(drawn.any((line) => line.strokeWidth < 0.25), isTrue);
    expect(drawn.any((line) => line.strokeWidth > 0.3), isTrue);
    expect(
      drawn.where((line) => line.strokeWidth < 0.25).every(
        (line) => line.pattern != const StrokePattern.solid(),
      ),
      isTrue,
    );
  });

  test('auto-align uses the longest edge angle', () {
    const origin = LatLng(12.97, 77.59);
    final eastWest = [
      shiftByMeters(origin, -50, -10),
      shiftByMeters(origin, 50, -10),
      shiftByMeters(origin, 50, 10),
      shiftByMeters(origin, -50, 10),
    ];
    expect(longestEdgeOrientationDegrees(eastWest), closeTo(0, 0.2));

    final diagonal = [
      shiftByMeters(origin, 0, 0),
      shiftByMeters(origin, 80, 40),
      shiftByMeters(origin, 70, 50),
      shiftByMeters(origin, -10, 10),
    ];
    expect(longestEdgeOrientationDegrees(diagonal), closeTo(153.43, 0.2));
  });

  testWidgets('Auto-align turns coverage parallel to the long side', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const GroundPlanPage(),
        ),
      ),
    );
    await tester.pump();

    final repo = ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    ).read(missionRepositoryProvider.notifier);
    const origin = LatLng(12.97, 77.59);
    _addRectangle(repo, origin, halfEast: 50, halfNorth: 10);
    await repo.generateCoverage(
      spacingMeters: 5,
      orientationDegrees: 90,
      marginMeters: 0,
    );
    await tester.pump();

    expect(_lineIsNorthSouth(repo.state.coverageLines.first), isTrue);
    await tester.ensureVisible(find.text('Auto-align'));
    await tester.pump();
    await tester.tap(find.text('Auto-align'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.state.orientationDegrees, closeTo(0, 0.2));
    expect(_lineIsNorthSouth(repo.state.coverageLines.first), isFalse);
    expect(find.text('Edge margin'), findsOneWidget);
  });
}

List<LatLng> _addRectangle(
  MissionRepository repo,
  LatLng origin, {
  required double halfEast,
  required double halfNorth,
}) {
  final ring = [
    shiftByMeters(origin, -halfEast, -halfNorth),
    shiftByMeters(origin, halfEast, -halfNorth),
    shiftByMeters(origin, halfEast, halfNorth),
    shiftByMeters(origin, -halfEast, halfNorth),
  ];
  for (final point in ring) {
    repo.addBoundaryPoint(latitude: point.latitude, longitude: point.longitude);
  }
  return ring;
}

List<double> _lineGaps(MissionRepository repo, LatLng origin) {
  final lines = repo.state.coverageLines;
  final firstStart = toLocalMeters(lines.first.endpoints[0], origin);
  final firstEnd = toLocalMeters(lines.first.endpoints[1], origin);
  final east = firstEnd.east - firstStart.east;
  final north = firstEnd.north - firstStart.north;
  final length = sqrt(east * east + north * north);
  final normalEast = -north / length;
  final normalNorth = east / length;
  final offsets = <double>[];
  for (final line in lines) {
    final start = toLocalMeters(line.endpoints[0], origin);
    final end = toLocalMeters(line.endpoints[1], origin);
    final midEast = (start.east + end.east) / 2;
    final midNorth = (start.north + end.north) / 2;
    offsets.add(midEast * normalEast + midNorth * normalNorth);
  }
  offsets.sort();
  final unique = <double>[offsets.first];
  for (final offset in offsets.skip(1)) {
    if ((offset - unique.last).abs() > 0.2) {
      unique.add(offset);
    }
  }
  return [
    for (var index = 1; index < unique.length; index++)
      unique[index] - unique[index - 1],
  ];
}

double _distanceToRing(LatLng point, List<LatLng> ring) {
  final origin = ring.first;
  final local = toLocalMeters(point, origin);
  var best = double.infinity;
  for (var index = 0; index < ring.length; index++) {
    final start = toLocalMeters(ring[index], origin);
    final end = toLocalMeters(ring[(index + 1) % ring.length], origin);
    final distance = distanceToSegmentMeters(
      pointEast: local.east,
      pointNorth: local.north,
      startEast: start.east,
      startNorth: start.north,
      endEast: end.east,
      endNorth: end.north,
    );
    if (distance < best) {
      best = distance;
    }
  }
  return best;
}

double _distance(LatLng a, LatLng b) {
  final local = toLocalMeters(a, b);
  return sqrt(local.east * local.east + local.north * local.north);
}

bool _lineIsNorthSouth(dynamic line) {
  final endpoints = line.endpoints as List<LatLng>;
  final latitude = (endpoints[0].latitude - endpoints[1].latitude).abs();
  final longitude = (endpoints[0].longitude - endpoints[1].longitude).abs();
  return latitude > longitude;
}
