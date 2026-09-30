import 'dart:math';

import 'package:fc_frontend/data/models/boundary_point.dart';
import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:fc_frontend/data/models/flight_log.dart';
import 'package:fc_frontend/data/models/mission.dart';
import 'package:fc_frontend/data/models/waypoint.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

class MissionState {
  const MissionState({
    this.boundaryPoints = const [],
    this.coverageLines = const [],
    this.waypoints = const [],
    this.savedMissions = const [],
    this.spacingMeters = 3,
    this.orientationDegrees = 0,
  });

  final List<BoundaryPoint> boundaryPoints;
  final List<CoverageLine> coverageLines;
  final List<Waypoint> waypoints;
  final List<Mission> savedMissions;
  final double spacingMeters;
  final double orientationDegrees;

  MissionState copyWith({
    List<BoundaryPoint>? boundaryPoints,
    List<CoverageLine>? coverageLines,
    List<Waypoint>? waypoints,
    List<Mission>? savedMissions,
    double? spacingMeters,
    double? orientationDegrees,
  }) {
    return MissionState(
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
      coverageLines: coverageLines ?? this.coverageLines,
      waypoints: waypoints ?? this.waypoints,
      savedMissions: savedMissions ?? this.savedMissions,
      spacingMeters: spacingMeters ?? this.spacingMeters,
      orientationDegrees: orientationDegrees ?? this.orientationDegrees,
    );
  }
}

class MissionRepository extends StateNotifier<MissionState> {
  MissionRepository() : super(const MissionState());

  int _sequence = 0;

  void addBoundaryPoint({
    required double latitude,
    required double longitude,
  }) {
    final point = BoundaryPoint(
      id: _nextId('boundary'),
      latitude: latitude,
      longitude: longitude,
      order: state.boundaryPoints.length,
    );
    state = state.copyWith(
      boundaryPoints: List.unmodifiable([...state.boundaryPoints, point]),
      coverageLines: const [],
      waypoints: const [],
    );
  }

  void resetBoundary() {
    state = state.copyWith(
      boundaryPoints: const [],
      coverageLines: const [],
      waypoints: const [],
    );
  }

  void generateCoverage({
    required double spacingMeters,
    required double orientationDegrees,
  }) {
    if (spacingMeters <= 0) {
      throw ArgumentError.value(
        spacingMeters,
        'spacingMeters',
        'Spacing must be positive',
      );
    }

    final lines = _buildCoverageLines(
      boundaryPoints: state.boundaryPoints,
      spacingMeters: spacingMeters,
      orientationDegrees: orientationDegrees,
      nextId: () => _nextId('coverage'),
    );
    final sample = state.waypoints.isEmpty ? null : state.waypoints.first;
    final waypoints = _waypointsAlongLines(
      lines,
      nextId: () => _nextId('waypoint'),
      altitude: sample?.altitude ?? 30,
      speed: sample?.speed ?? 5,
      action: sample?.action ?? WaypointAction.waypoint,
    );
    state = state.copyWith(
      coverageLines: List.unmodifiable(lines),
      waypoints: List.unmodifiable(waypoints),
      spacingMeters: spacingMeters,
      orientationDegrees: orientationDegrees,
    );
  }

  void updateWaypoint(Waypoint waypoint) {
    final index = state.waypoints.indexWhere((item) => item.id == waypoint.id);
    if (index == -1) {
      return;
    }

    final updated = [...state.waypoints];
    updated[index] = waypoint;
    state = state.copyWith(waypoints: List.unmodifiable(updated));
  }

  void deleteWaypoint(String id) {
    state = state.copyWith(
      waypoints: List.unmodifiable(
        state.waypoints.where((waypoint) => waypoint.id != id),
      ),
    );
  }

  Mission saveMission(String name) {
    final mission = Mission(
      id: _nextId('mission'),
      name: name,
      waypoints: List.unmodifiable(state.waypoints),
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      savedMissions: List.unmodifiable([...state.savedMissions, mission]),
    );
    return mission;
  }

  void loadMission(String id) {
    final index = state.savedMissions.indexWhere((mission) => mission.id == id);
    if (index == -1) {
      throw ArgumentError.value(id, 'id', 'No saved mission with this id');
    }

    state = state.copyWith(
      waypoints: List.unmodifiable(state.savedMissions[index].waypoints),
    );
  }

  List<FlightLog> listFlightLogs() {
    return [
      FlightLog(
        id: 'log-1',
        date: DateTime.utc(2026, 9, 26, 6, 40),
        durationSeconds: 754,
        status: 'completed',
      ),
      FlightLog(
        id: 'log-2',
        date: DateTime.utc(2026, 9, 28, 7, 15),
        durationSeconds: 512,
        status: 'completed',
      ),
      FlightLog(
        id: 'log-3',
        date: DateTime.utc(2026, 9, 29, 16, 5),
        durationSeconds: 186,
        status: 'aborted',
      ),
    ];
  }

  String _nextId(String prefix) {
    _sequence += 1;
    return '$prefix-$_sequence';
  }
}

final missionRepositoryProvider =
    StateNotifierProvider<MissionRepository, MissionState>((ref) {
      return MissionRepository();
    });

class _LocalPoint {
  const _LocalPoint(this.x, this.y);

  final double x;
  final double y;
}

List<CoverageLine> _buildCoverageLines({
  required List<BoundaryPoint> boundaryPoints,
  required double spacingMeters,
  required double orientationDegrees,
  required String Function() nextId,
}) {
  if (boundaryPoints.length < 3) {
    return const [];
  }

  final ordered = [...boundaryPoints]
    ..sort((a, b) => a.order.compareTo(b.order));
  final originLatitude =
      ordered.map((point) => point.latitude).reduce((a, b) => a + b) /
      ordered.length;
  final originLongitude =
      ordered.map((point) => point.longitude).reduce((a, b) => a + b) /
      ordered.length;
  final alignToEast = -orientationDegrees * pi / 180;
  final localPolygon = [
    for (final point in ordered)
      _rotate(_toLocal(point, originLatitude, originLongitude), alignToEast),
  ];

  final minY = localPolygon.map((point) => point.y).reduce(min);
  final maxY = localPolygon.map((point) => point.y).reduce(max);
  final lines = <CoverageLine>[];
  var lineIndex = 0;

  for (var y = minY + spacingMeters / 2; y < maxY; y += spacingMeters) {
    final crossings = _horizontalCrossings(localPolygon, y);
    for (var pair = 0; pair + 1 < crossings.length; pair += 2) {
      final start = _fromLocal(
        _rotate(_LocalPoint(crossings[pair], y), -alignToEast),
        originLatitude,
        originLongitude,
      );
      final end = _fromLocal(
        _rotate(_LocalPoint(crossings[pair + 1], y), -alignToEast),
        originLatitude,
        originLongitude,
      );
      final forward = lineIndex.isEven;
      final segment = _insetSegment(forward ? start : end, forward ? end : start);
      lines.add(
        CoverageLine(
          id: nextId(),
          endpoints: [segment.$1, segment.$2],
          lineIndex: lineIndex,
        ),
      );
      lineIndex += 1;
    }
  }

  return lines;
}

_LocalPoint _toLocal(
  BoundaryPoint point,
  double originLatitude,
  double originLongitude,
) {
  const metersPerDegree = 111320.0;
  final longitudeScale = metersPerDegree * _cosineDegrees(originLatitude);
  return _LocalPoint(
    (point.longitude - originLongitude) * longitudeScale,
    (point.latitude - originLatitude) * metersPerDegree,
  );
}

LatLng _fromLocal(
  _LocalPoint point,
  double originLatitude,
  double originLongitude,
) {
  const metersPerDegree = 111320.0;
  final longitudeScale = metersPerDegree * _cosineDegrees(originLatitude);
  return LatLng(
    originLatitude + point.y / metersPerDegree,
    originLongitude + point.x / longitudeScale,
  );
}

_LocalPoint _rotate(_LocalPoint point, double radians) {
  final cosR = cos(radians);
  final sinR = sin(radians);
  return _LocalPoint(
    point.x * cosR - point.y * sinR,
    point.x * sinR + point.y * cosR,
  );
}

List<double> _horizontalCrossings(List<_LocalPoint> polygon, double y) {
  final crossings = <double>[];
  for (var index = 0; index < polygon.length; index++) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    final crosses =
        (start.y <= y && end.y > y) || (end.y <= y && start.y > y);
    if (!crosses) {
      continue;
    }

    final t = (y - start.y) / (end.y - start.y);
    crossings.add(start.x + t * (end.x - start.x));
  }
  crossings.sort();
  return crossings;
}

(LatLng, LatLng) _insetSegment(LatLng start, LatLng end) {
  const insetMeters = 1.0;
  final length = const Distance().as(LengthUnit.Meter, start, end);
  if (length <= insetMeters * 2) {
    return (start, end);
  }

  final t = insetMeters / length;
  return (
    LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    ),
    LatLng(
      end.latitude + (start.latitude - end.latitude) * t,
      end.longitude + (start.longitude - end.longitude) * t,
    ),
  );
}

List<Waypoint> _waypointsAlongLines(
  List<CoverageLine> lines, {
  required String Function() nextId,
  required double altitude,
  required double speed,
  required WaypointAction action,
}) {
  const intervalMeters = 12.0;
  final distance = const Distance();
  final waypoints = <Waypoint>[];

  for (final line in lines) {
    final start = line.endpoints.first;
    final end = line.endpoints.last;
    final length = distance.as(LengthUnit.Meter, start, end);
    final steps = length < 1 ? 0 : max(1, (length / intervalMeters).ceil());
    for (var step = 0; step <= steps; step++) {
      final t = steps == 0 ? 0.0 : step / steps;
      final point = LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      );
      waypoints.add(
        Waypoint(
          id: nextId(),
          latitude: point.latitude,
          longitude: point.longitude,
          altitude: altitude,
          speed: speed,
          action: action,
        ),
      );
    }
  }

  return waypoints;
}

double _cosineDegrees(double degrees) {
  final scale = cos(degrees * pi / 180).abs();
  if (scale < 1e-6) {
    return 1e-6;
  }
  return scale;
}
