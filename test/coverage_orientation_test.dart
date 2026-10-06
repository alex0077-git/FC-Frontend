import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('joystick angle rotates coverage lines in the same direction', () async {
    final repo = MissionRepository();
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.590);
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.595);
    repo.addBoundaryPoint(latitude: 12.974, longitude: 77.595);
    repo.addBoundaryPoint(latitude: 12.974, longitude: 77.590);

    final before = [
      for (final point in repo.state.boundaryPoints)
        (point.latitude, point.longitude),
    ];

    await repo.generateCoverage(spacingMeters: 40, orientationDegrees: 0);
    final flat = repo.state.coverageLines.first;
    final flatLat = (flat.endpoints[0].latitude - flat.endpoints[1].latitude).abs();
    final flatLng = (flat.endpoints[0].longitude - flat.endpoints[1].longitude).abs();

    await repo.generateCoverage(spacingMeters: 40, orientationDegrees: 90);
    expect(repo.state.spacingMeters, 40);
    expect(
      repo.state.spacingMeters,
      greaterThanOrEqualTo(
        MissionRepository.lineSpacingLowerBound(repo.state.boundaryPoints),
      ),
    );
    expect(
      repo.state.spacingMeters,
      lessThanOrEqualTo(
        MissionRepository.lineSpacingUpperBound(repo.state.boundaryPoints),
      ),
    );
    expect(repo.state.boundaryPoints.length, before.length);
    for (var index = 0; index < before.length; index++) {
      expect(repo.state.boundaryPoints[index].latitude, before[index].$1);
      expect(repo.state.boundaryPoints[index].longitude, before[index].$2);
    }
    final turned = repo.state.coverageLines.first;
    final turnedLat = (turned.endpoints[0].latitude - turned.endpoints[1].latitude).abs();
    final turnedLng = (turned.endpoints[0].longitude - turned.endpoints[1].longitude).abs();

    expect(flatLng, greaterThan(flatLat));
    final insetLatitude = 12.970 + defaultCoverageMarginMeters / 111320;
    expect(flat.endpoints[0].latitude, closeTo(insetLatitude, 5e-6));
    expect(flat.endpoints[1].latitude, closeTo(insetLatitude, 5e-6));
    expect(turnedLat, greaterThan(turnedLng));

    await repo.generateCoverage(spacingMeters: 1, orientationDegrees: 45);
    final clockwise = repo.state.coverageLines[repo.state.coverageLines.length ~/ 2];
    final west = clockwise.endpoints[0].longitude < clockwise.endpoints[1].longitude
        ? clockwise.endpoints[0]
        : clockwise.endpoints[1];
    final east = identical(west, clockwise.endpoints[0])
        ? clockwise.endpoints[1]
        : clockwise.endpoints[0];
    expect(east.latitude, lessThan(west.latitude));

    await repo.generateCoverage(spacingMeters: 0.2, orientationDegrees: 45);
    expect(repo.state.spacingMeters, minLineSpacingMeters);

    final widest = MissionRepository.lineSpacingUpperBound(repo.state.boundaryPoints);
    await repo.generateCoverage(spacingMeters: widest + 500, orientationDegrees: 45);
    expect(repo.state.spacingMeters, lessThanOrEqualTo(widest));
    expect(repo.state.spacingMeters, greaterThan(widest - 0.1));
  });

  testWidgets('a one degree turn slides the passes instead of jumping them', (
    tester,
  ) async {
    final repo = MissionRepository();
    addTearDown(repo.dispose);
    const origin = LatLng(12.97, 77.59);
    for (final point in [
      const LatLng(12.96955, 77.58955),
      const LatLng(12.96955, 77.59045),
      const LatLng(12.97045, 77.59045),
      const LatLng(12.97045, 77.58955),
    ]) {
      repo.addBoundaryPoint(latitude: point.latitude, longitude: point.longitude);
    }

    await repo.generateCoverage(
      spacingMeters: 10,
      orientationDegrees: 20,
      marginMeters: 0,
    );
    final before = [
      for (final line in repo.state.coverageLines) _midpoint(line, origin),
    ];

    repo.beginOrientationDrag();
    repo.scheduleCoverage(orientationDegrees: 20);
    await tester.pump();
    expect(repo.state.orientationDegrees, 20);
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    repo.scheduleCoverage(orientationDegrees: 21);
    await tester.pump();
    expect(repo.state.orientationDegrees, 20);
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(repo.state.orientationDegrees, closeTo(21, 0.01));
    final after = [
      for (final line in repo.state.coverageLines) _midpoint(line, origin),
    ];
    repo.scheduleCoverage(orientationDegrees: 40);
    await tester.pump(const Duration(milliseconds: 40));
    repo.scheduleCoverage(orientationDegrees: 55);
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pump();
    expect(repo.state.orientationDegrees, closeTo(55, 0.01));

    expect(before, isNotEmpty);
    expect(after, isNotEmpty);
    for (final point in before) {
      final nearest = after
          .map((other) => (other - point).distance)
          .reduce((a, b) => a < b ? a : b);
      expect(nearest, lessThan(2));
    }
    repo.endOrientationDrag();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
  });
}

Offset _midpoint(CoverageLine line, LatLng origin) {
  final start = toLocalMeters(line.endpoints[0], origin);
  final end = toLocalMeters(line.endpoints[1], origin);
  return Offset((start.east + end.east) / 2, (start.north + end.north) / 2);
}
