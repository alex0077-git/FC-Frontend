import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(flat.endpoints[0].latitude, closeTo(12.970, 1e-7));
    expect(flat.endpoints[1].latitude, closeTo(12.970, 1e-7));
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
}
