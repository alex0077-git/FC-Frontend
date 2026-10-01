import 'dart:async';
import 'dart:math';

import 'package:fc_frontend/data/models/boundary_edit.dart';
import 'package:fc_frontend/data/models/boundary_point.dart';
import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:fc_frontend/data/models/flight_log.dart';
import 'package:fc_frontend/data/models/mission.dart';
import 'package:fc_frontend/data/models/waypoint.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

const maxCoverageLines = 2000;
const minLineSpacingMeters = 1.0;

class MissionState {
  const MissionState({
    this.boundaryPoints = const [],
    this.coverageLines = const [],
    this.waypoints = const [],
    this.savedMissions = const [],
    this.spacingMeters = 1,
    this.orientationDegrees = 0,
    this.undoHistory = const [],
    this.redoHistory = const [],
    this.boundaryEditingLocked = false,
  });

  final List<BoundaryPoint> boundaryPoints;
  final List<CoverageLine> coverageLines;
  final List<Waypoint> waypoints;
  final List<Mission> savedMissions;
  final double spacingMeters;
  final double orientationDegrees;
  final List<BoundaryEdit> undoHistory;
  final List<BoundaryEdit> redoHistory;

  /// True after Call for Job has built coverage. Planning edits stay off
  /// so undo cannot change those coverage lines.
  final bool boundaryEditingLocked;

  MissionState copyWith({
    List<BoundaryPoint>? boundaryPoints,
    List<CoverageLine>? coverageLines,
    List<Waypoint>? waypoints,
    List<Mission>? savedMissions,
    double? spacingMeters,
    double? orientationDegrees,
    List<BoundaryEdit>? undoHistory,
    List<BoundaryEdit>? redoHistory,
    bool? boundaryEditingLocked,
  }) {
    return MissionState(
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
      coverageLines: coverageLines ?? this.coverageLines,
      waypoints: waypoints ?? this.waypoints,
      savedMissions: savedMissions ?? this.savedMissions,
      spacingMeters: spacingMeters ?? this.spacingMeters,
      orientationDegrees: orientationDegrees ?? this.orientationDegrees,
      undoHistory: undoHistory ?? this.undoHistory,
      redoHistory: redoHistory ?? this.redoHistory,
      boundaryEditingLocked:
          boundaryEditingLocked ?? this.boundaryEditingLocked,
    );
  }
}

class MissionRepository extends StateNotifier<MissionState> {
  MissionRepository() : super(const MissionState());

  int _sequence = 0;
  Timer? _coverageTimer;
  double? _pendingSpacing;
  double? _pendingOrientation;
  bool _closed = false;

  @override
  void dispose() {
    _closed = true;
    _coverageTimer?.cancel();
    super.dispose();
  }

  void addBoundaryPoint({
    required double latitude,
    required double longitude,
  }) {
    if (state.boundaryEditingLocked) {
      return;
    }

    final before = List<BoundaryPoint>.of(state.boundaryPoints);
    final point = BoundaryPoint(
      id: _nextId('boundary'),
      latitude: latitude,
      longitude: longitude,
      order: before.length,
    );
    _commitBoundaryEdit(
      kind: BoundaryEditKind.add,
      before: before,
      after: [...before, point],
      clearDerived: true,
    );
  }

  void updateBoundaryPoint({
    required String id,
    required double latitude,
    required double longitude,
    required double altitude,
    required double speed,
  }) {
    if (state.boundaryEditingLocked) {
      return;
    }

    final before = List<BoundaryPoint>.of(state.boundaryPoints);
    final index = before.indexWhere((point) => point.id == id);
    if (index == -1) {
      return;
    }

    final current = before[index];
    if (_sameBoundaryPoint(
      current,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      speed: speed,
    )) {
      return;
    }

    final after = [
      for (final point in before)
        if (point.id == id)
          point.copyWith(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            speed: speed,
          )
        else
          point,
    ];
    _commitBoundaryEdit(
      kind: BoundaryEditKind.move,
      before: before,
      after: after,
    );
  }

  void deleteBoundaryPoint(String id) {
    if (state.boundaryEditingLocked) {
      return;
    }

    final before = List<BoundaryPoint>.of(state.boundaryPoints);
    if (!before.any((point) => point.id == id)) {
      return;
    }

    final kept = before.where((point) => point.id != id).toList();
    final after = [
      for (var index = 0; index < kept.length; index++)
        kept[index].copyWith(order: index),
    ];
    _commitBoundaryEdit(
      kind: BoundaryEditKind.delete,
      before: before,
      after: after,
    );
  }

  void undoBoundaryEdit() {
    if (state.boundaryEditingLocked || state.undoHistory.isEmpty) {
      return;
    }

    final undo = [...state.undoHistory];
    final edit = undo.removeLast();
    state = state.copyWith(
      boundaryPoints: List.unmodifiable(edit.before),
      undoHistory: List.unmodifiable(undo),
      redoHistory: List.unmodifiable([...state.redoHistory, edit]),
    );
  }

  void redoBoundaryEdit() {
    if (state.boundaryEditingLocked || state.redoHistory.isEmpty) {
      return;
    }

    final redo = [...state.redoHistory];
    final edit = redo.removeLast();
    state = state.copyWith(
      boundaryPoints: List.unmodifiable(edit.after),
      undoHistory: List.unmodifiable([...state.undoHistory, edit]),
      redoHistory: List.unmodifiable(redo),
    );
  }

  void resetBoundary() {
    state = state.copyWith(
      boundaryPoints: const [],
      coverageLines: const [],
      waypoints: const [],
      undoHistory: const [],
      redoHistory: const [],
      boundaryEditingLocked: false,
    );
  }

  void _commitBoundaryEdit({
    required BoundaryEditKind kind,
    required List<BoundaryPoint> before,
    required List<BoundaryPoint> after,
    bool clearDerived = false,
  }) {
    final edit = BoundaryEdit(
      kind: kind,
      before: List.unmodifiable(before),
      after: List.unmodifiable(after),
    );
    state = state.copyWith(
      boundaryPoints: List.unmodifiable(after),
      undoHistory: List.unmodifiable([...state.undoHistory, edit]),
      redoHistory: const [],
      coverageLines: clearDerived ? const [] : state.coverageLines,
      waypoints: clearDerived ? const [] : state.waypoints,
    );
  }

  Future<void> generateCoverage({
    required double spacingMeters,
    required double orientationDegrees,
  }) async {
    _coverageTimer?.cancel();
    _coverageTimer = null;
    _pendingSpacing = null;
    _pendingOrientation = null;
    _publishNow(spacingMeters, orientationDegrees);
    if (state.coverageLines.isNotEmpty) {
      state = state.copyWith(boundaryEditingLocked: true);
    }
  }

  /// Applies the latest spacing and line angle. The first call paints
  /// immediately; later calls during a drag replace that pending angle.
  void scheduleCoverage({
    required double spacingMeters,
    required double orientationDegrees,
  }) {
    _pendingSpacing = spacingMeters;
    _pendingOrientation = orientationDegrees;
    if (_coverageTimer != null) {
      return;
    }

    _publishPending();
    _armCoverageCooldown();
  }

  void _armCoverageCooldown() {
    _coverageTimer = Timer(const Duration(milliseconds: 50), () {
      _coverageTimer = null;
      if (_closed || _pendingSpacing == null || _pendingOrientation == null) {
        return;
      }
      _publishPending();
      _armCoverageCooldown();
    });
  }

  void _publishPending() {
    final spacing = _pendingSpacing;
    final orientation = _pendingOrientation;
    if (spacing == null || orientation == null) {
      return;
    }
    _pendingSpacing = null;
    _pendingOrientation = null;
    _publishNow(spacing, orientation);
  }

  void _publishNow(double spacingMeters, double orientationDegrees) {
    if (!spacingMeters.isFinite || spacingMeters <= 0) {
      throw ArgumentError.value(
        spacingMeters,
        'spacingMeters',
        'Spacing must be a positive finite number',
      );
    }
    if (state.boundaryPoints.length < 3) {
      return;
    }

    final lower = lineSpacingLowerBound(state.boundaryPoints);
    final upper = lineSpacingUpperBound(state.boundaryPoints);
    final spacing = ((_spacingWithinBoundary(spacingMeters, state.boundaryPoints) * 10)
                .roundToDouble() /
            10)
        .clamp(lower, upper)
        .toDouble();
    final request = _requestFromState(
      spacingMeters: spacing,
      orientationDegrees: orientationDegrees,
    );
    _publishCoverage(request, _coverageGeometry(request));
  }

  static double lineSpacingUpperBound(List<BoundaryPoint> points) {
    final span = _boundarySpanMeters(points);
    if (span <= 0) {
      return minLineSpacingMeters;
    }
    return span;
  }

  static double lineSpacingLowerBound(List<BoundaryPoint> points) {
    final upper = lineSpacingUpperBound(points);
    return min(minLineSpacingMeters, upper);
  }

  static double _spacingWithinBoundary(
    double spacingMeters,
    List<BoundaryPoint> points,
  ) {
    return spacingMeters.clamp(
      lineSpacingLowerBound(points),
      lineSpacingUpperBound(points),
    );
  }

  static double _boundarySpanMeters(List<BoundaryPoint> points) {
    if (points.length < 2) {
      return minLineSpacingMeters;
    }
    var span = 0.0;
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final meters = const Distance().as(
          LengthUnit.Meter,
          LatLng(points[i].latitude, points[i].longitude),
          LatLng(points[j].latitude, points[j].longitude),
        );
        if (meters > span) {
          span = meters;
        }
      }
    }
    return span;
  }

  _CoverageRequest _requestFromState({
    required double spacingMeters,
    required double orientationDegrees,
  }) {
    final sample = state.waypoints.isEmpty ? null : state.waypoints.first;
    final points = state.boundaryPoints;
    return _CoverageRequest(
      latitudes: [for (final point in points) point.latitude],
      longitudes: [for (final point in points) point.longitude],
      orders: [for (final point in points) point.order],
      spacingMeters: spacingMeters,
      orientationDegrees: orientationDegrees,
      altitude: sample?.altitude ?? 30,
      speed: sample?.speed ?? 5,
      actionIndex: (sample?.action ?? WaypointAction.waypoint).index,
    );
  }

  void _publishCoverage(_CoverageRequest request, _CoverageGeometry geometry) {
    final action = WaypointAction.values[request.actionIndex];
    final lines = <CoverageLine>[
      for (var index = 0; index < geometry.lines.length; index++)
        CoverageLine(
          id: _nextId('coverage'),
          endpoints: [
            LatLng(geometry.lines[index][0], geometry.lines[index][1]),
            LatLng(geometry.lines[index][2], geometry.lines[index][3]),
          ],
          lineIndex: index,
        ),
    ];
    final waypoints = <Waypoint>[
      for (var index = 0; index < geometry.waypointLatitudes.length; index++)
        Waypoint(
          id: _nextId('waypoint'),
          latitude: geometry.waypointLatitudes[index],
          longitude: geometry.waypointLongitudes[index],
          altitude: request.altitude,
          speed: request.speed,
          action: action,
        ),
    ];
    state = state.copyWith(
      coverageLines: List.unmodifiable(lines),
      waypoints: List.unmodifiable(waypoints),
      spacingMeters: request.spacingMeters,
      orientationDegrees: request.orientationDegrees,
    );
  }

  void updateWaypoint(Waypoint waypoint) {
    if (state.boundaryEditingLocked) {
      return;
    }
    final index = state.waypoints.indexWhere((item) => item.id == waypoint.id);
    if (index == -1) {
      return;
    }

    final updated = [...state.waypoints];
    updated[index] = waypoint;
    state = state.copyWith(waypoints: List.unmodifiable(updated));
  }

  void deleteWaypoint(String id) {
    if (state.boundaryEditingLocked) {
      return;
    }
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

bool _sameBoundaryPoint(
  BoundaryPoint point, {
  required double latitude,
  required double longitude,
  required double altitude,
  required double speed,
}) {
  return point.latitude == latitude &&
      point.longitude == longitude &&
      point.altitude == altitude &&
      point.speed == speed;
}

final missionRepositoryProvider =
    StateNotifierProvider<MissionRepository, MissionState>((ref) {
      return MissionRepository();
    });

class _CoverageRequest {
  const _CoverageRequest({
    required this.latitudes,
    required this.longitudes,
    required this.orders,
    required this.spacingMeters,
    required this.orientationDegrees,
    required this.altitude,
    required this.speed,
    required this.actionIndex,
  });

  final List<double> latitudes;
  final List<double> longitudes;
  final List<int> orders;
  final double spacingMeters;
  final double orientationDegrees;
  final double altitude;
  final double speed;
  final int actionIndex;
}

class _CoverageGeometry {
  const _CoverageGeometry({
    required this.lines,
    required this.waypointLatitudes,
    required this.waypointLongitudes,
  });

  /// Each line is `[startLat, startLng, endLat, endLng]`.
  final List<List<double>> lines;
  final List<double> waypointLatitudes;
  final List<double> waypointLongitudes;
}

class _LocalPoint {
  const _LocalPoint(this.x, this.y);

  final double x;
  final double y;
}

_CoverageGeometry _coverageGeometry(_CoverageRequest request) {
  final count = request.latitudes.length;
  if (count < 3) {
    return const _CoverageGeometry(
      lines: [],
      waypointLatitudes: [],
      waypointLongitudes: [],
    );
  }

  final order = List<int>.generate(count, (index) => index)
    ..sort((a, b) => request.orders[a].compareTo(request.orders[b]));
  var originLatitude = 0.0;
  var originLongitude = 0.0;
  for (final index in order) {
    originLatitude += request.latitudes[index];
    originLongitude += request.longitudes[index];
  }
  originLatitude /= count;
  originLongitude /= count;

  // Joystick degrees increase clockwise because screen Y points down.
  // Local map Y points north, so a positive rotation is anti-clockwise.
  // Using the joystick angle directly makes coverage lines follow the stick.
  final alignToEast = request.orientationDegrees * pi / 180;
  final localPolygon = [
    for (final index in order)
      _rotate(
        _toLocal(
          request.latitudes[index],
          request.longitudes[index],
          originLatitude,
          originLongitude,
        ),
        alignToEast,
      ),
  ];

  final sweepExtent = _sweepExtent(localPolygon);
  if (!sweepExtent.isFinite || sweepExtent <= 0) {
    return const _CoverageGeometry(
      lines: [],
      waypointLatitudes: [],
      waypointLongitudes: [],
    );
  }

  final minY = localPolygon.map((point) => point.y).reduce(min);
  final lineCount = min(
    maxCoverageLines,
    max(2, (sweepExtent / request.spacingMeters).ceil() + 1),
  );
  // Spread the requested gap so the first and last lines sit on the
  // boundary edges. The gap never exceeds the spacing the user set.
  final step = sweepExtent / (lineCount - 1);
  final lines = <List<double>>[];
  final waypointLatitudes = <double>[];
  final waypointLongitudes = <double>[];

  for (var index = 0; index < lineCount; index++) {
    final y = minY + index * step;
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
      if ((crossings[pair + 1] - crossings[pair]).abs() < 0.05) {
        continue;
      }
      final forward = lines.length.isEven;
      final from = forward ? start : end;
      final to = forward ? end : start;
      lines.add([
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      ]);
      _appendWaypoints(from, to, waypointLatitudes, waypointLongitudes);
    }
  }

  return _CoverageGeometry(
    lines: lines,
    waypointLatitudes: waypointLatitudes,
    waypointLongitudes: waypointLongitudes,
  );
}

double _sweepExtent(List<_LocalPoint> polygon) {
  var minY = polygon.first.y;
  var maxY = polygon.first.y;
  for (final point in polygon.skip(1)) {
    minY = min(minY, point.y);
    maxY = max(maxY, point.y);
  }
  return maxY - minY;
}

_LocalPoint _toLocal(
  double latitude,
  double longitude,
  double originLatitude,
  double originLongitude,
) {
  const metersPerDegree = 111320.0;
  final longitudeScale = metersPerDegree * _cosineDegrees(originLatitude);
  return _LocalPoint(
    (longitude - originLongitude) * longitudeScale,
    (latitude - originLatitude) * metersPerDegree,
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
  const yEpsilon = 1e-6;
  const xEpsilon = 1e-4;
  final crossings = <double>[];

  for (var index = 0; index < polygon.length; index++) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    final y0 = start.y;
    final y1 = end.y;

    if ((y0 - y).abs() <= yEpsilon && (y1 - y).abs() <= yEpsilon) {
      crossings.add(start.x);
      crossings.add(end.x);
      continue;
    }

    final dy = y1 - y0;
    if (dy.abs() <= yEpsilon) {
      continue;
    }

    final low = min(y0, y1);
    final high = max(y0, y1);
    final throughEdge = y >= low && y < high;
    final throughTop = (y - high).abs() <= yEpsilon;
    if (!throughEdge && !throughTop) {
      continue;
    }

    final t = ((y - y0) / dy).clamp(0.0, 1.0);
    crossings.add(start.x + t * (end.x - start.x));
  }

  if (crossings.isEmpty) {
    return crossings;
  }
  crossings.sort();
  final unique = <double>[crossings.first];
  for (final x in crossings.skip(1)) {
    if (x - unique.last > xEpsilon) {
      unique.add(x);
    }
  }
  return unique;
}

void _appendWaypoints(
  LatLng start,
  LatLng end,
  List<double> latitudes,
  List<double> longitudes,
) {
  const intervalMeters = 12.0;
  const interiorBudget = 2500;
  final length = const Distance().as(LengthUnit.Meter, start, end);
  final steps = length < 1 || latitudes.length >= interiorBudget
      ? 1
      : max(1, (length / intervalMeters).ceil());
  for (var step = 0; step <= steps; step++) {
    final t = step / steps;
    latitudes.add(start.latitude + (end.latitude - start.latitude) * t);
    longitudes.add(start.longitude + (end.longitude - start.longitude) * t);
  }
}

double _cosineDegrees(double degrees) {
  final scale = cos(degrees * pi / 180).abs();
  if (scale < 1e-6) {
    return 1e-6;
  }
  return scale;
}
