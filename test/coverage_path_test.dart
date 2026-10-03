import 'dart:math';

import 'package:fc_frontend/core/geometry/boundary_split.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/coverage_lines.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('the path stays one route inside the boundary as the angle changes', () async {
    final repo = MissionRepository();
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.590);
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.595);
    repo.addBoundaryPoint(latitude: 12.974, longitude: 77.595);
    repo.addBoundaryPoint(latitude: 12.974, longitude: 77.590);
    final boundary = [
      for (final point in repo.state.boundaryPoints)
        LatLng(point.latitude, point.longitude),
    ];

    const angles = <double>[0, 15, 45, 90, 135, 180, 210, 270, 315];
    final starts = <LatLng>[];
    for (final angle in angles) {
      await repo.generateCoverage(spacingMeters: 40, orientationDegrees: angle);

      expect(repo.state.coveragePaths, hasLength(1), reason: 'angle $angle');
      final points = repo.state.coveragePaths.single.points;
      expect(points.length, greaterThan(1), reason: 'angle $angle');
      expect(repo.state.waypoints.first.latitude, points.first.latitude);
      expect(repo.state.waypoints.first.longitude, points.first.longitude);
      expect(repo.state.waypoints.last.latitude, points.last.latitude);
      expect(repo.state.waypoints.last.longitude, points.last.longitude);
      starts.add(points.first);

      final drawn = coveragePolylines(
        repo.state.coverageLines,
        paths: repo.state.coveragePaths,
      );
      expect(drawn, hasLength(1), reason: 'angle $angle');

      for (var index = 0; index < points.length; index++) {
        expect(
          boundaryContains(boundary, points[index]),
          isTrue,
          reason: 'angle $angle point $index',
        );
        if (index + 1 == points.length) {
          continue;
        }
        for (var step = 1; step < 8; step++) {
          final t = step / 8;
          final sample = LatLng(
            points[index].latitude +
                (points[index + 1].latitude - points[index].latitude) * t,
            points[index].longitude +
                (points[index + 1].longitude - points[index].longitude) * t,
          );
          expect(
            boundaryContains(boundary, sample),
            isTrue,
            reason: 'angle $angle segment $index',
          );
        }
      }
    }

    final moved = starts.any(
      (start) =>
          (start.latitude - starts.first.latitude).abs() > 1e-7 ||
          (start.longitude - starts.first.longitude).abs() > 1e-7,
    );
    expect(moved, isTrue);
  });

  test('a slanted field uses the shorter end-to-end connection', () async {
    final repo = MissionRepository();
    for (final point in [
      _at(0, 0),
      _at(100, 0),
      _at(10, 30),
      _at(0, 30),
    ]) {
      repo.addBoundaryPoint(latitude: point.latitude, longitude: point.longitude);
    }

    await repo.generateCoverage(spacingMeters: 40, orientationDegrees: 0);

    final points = repo.state.coveragePaths.single.points;
    expect(_pathMeters(points), lessThan(160));
    final start = _xy(points.first, _at(0, 0));
    expect(start.$1, closeTo(100, 1.5));
    expect(start.$2, closeTo(0, 1.5));
  });

  testWidgets('the start marker moves when the pattern rotates', (tester) async {
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
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.590);
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.595);
    repo.addBoundaryPoint(latitude: 12.974, longitude: 77.595);
    repo.addBoundaryPoint(latitude: 12.974, longitude: 77.590);
    await repo.generateCoverage(spacingMeters: 40, orientationDegrees: 0);
    await tester.pump();

    final startBefore = tester.getCenter(find.text('S'));
    final endBefore = tester.getCenter(find.text('E'));

    await repo.generateCoverage(spacingMeters: 40, orientationDegrees: 80);
    await tester.pump();

    final startAfter = tester.getCenter(find.text('S'));
    final endAfter = tester.getCenter(find.text('E'));
    expect((startAfter - startBefore).distance, greaterThan(0));
    expect((endAfter - endBefore).distance, greaterThan(0));
  });
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

double _pathMeters(List<LatLng> points) {
  const distance = Distance();
  var total = 0.0;
  for (var index = 1; index < points.length; index++) {
    total += distance.as(LengthUnit.Meter, points[index - 1], points[index]);
  }
  return total;
}
