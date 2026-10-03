import 'dart:async';
import 'dart:math';

import 'package:fc_frontend/core/geometry/boundary_orientation.dart';
import 'package:fc_frontend/core/geometry/boundary_split.dart';
import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:fc_frontend/core/geometry/polygon_inset.dart';
import 'package:fc_frontend/data/models/boundary_edit.dart';
import 'package:fc_frontend/data/models/boundary_point.dart';
import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:fc_frontend/data/models/flight_log.dart';
import 'package:fc_frontend/data/models/mission.dart';
import 'package:fc_frontend/data/models/obstacle.dart';
import 'package:fc_frontend/data/models/waypoint.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

const maxCoverageLines = 2000;
const minLineSpacingMeters = 1.0;
const defaultCoverageMarginMeters = 2.0;
const maxCoverageMarginMeters = 20.0;

class MissionState {
  const MissionState({
    this.boundaryPoints = const [],
    this.coverageLines = const [],
    this.coveragePaths = const [],
    this.waypoints = const [],
    this.savedMissions = const [],
    this.spacingMeters = 1,
    this.orientationDegrees = 0,
    this.marginMeters = defaultCoverageMarginMeters,
    this.undoHistory = const [],
    this.redoHistory = const [],
    this.splits = const [],
    this.obstacles = const [],
    this.boundaryEditingLocked = false,
    this.activeSplit = -1,
    this.coverageBlockedByObstacle = false,
  });

  final List<BoundaryPoint> boundaryPoints;
  final List<CoverageLine> coverageLines;

  /// The lawnmower route in order. Each pass is joined to the next by the
  /// short turn at the side where the previous pass ended.
  final List<CoveragePath> coveragePaths;
  final List<Waypoint> waypoints;
  final List<Mission> savedMissions;
  final double spacingMeters;
  final double orientationDegrees;

  /// How far inside the drawn boundary the spray lines must stay.
  final double marginMeters;
  final List<BoundaryEdit> undoHistory;
  final List<BoundaryEdit> redoHistory;
  final List<SplitCut> splits;
  final List<Obstacle> obstacles;

  /// True after Call for Job has built coverage. Planning edits stay off
  /// so undo cannot change those coverage lines.
  final bool boundaryEditingLocked;

  /// -1 shows every split. 0 keeps Split A active. 1 keeps Split B active.
  final int activeSplit;

  /// True only if a coverage waypoint still landed inside a no-fly zone after
  /// the outside portions of each pass were kept. A normal circle or square
  /// cut does not set this.
  final bool coverageBlockedByObstacle;

  MissionState copyWith({
    List<BoundaryPoint>? boundaryPoints,
    List<CoverageLine>? coverageLines,
    List<CoveragePath>? coveragePaths,
    List<Waypoint>? waypoints,
    List<Mission>? savedMissions,
    double? spacingMeters,
    double? orientationDegrees,
    double? marginMeters,
    List<BoundaryEdit>? undoHistory,
    List<BoundaryEdit>? redoHistory,
    List<SplitCut>? splits,
    List<Obstacle>? obstacles,
    bool? boundaryEditingLocked,
    int? activeSplit,
    bool? coverageBlockedByObstacle,
  }) {
    return MissionState(
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
      coverageLines: coverageLines ?? this.coverageLines,
      coveragePaths: coveragePaths ?? this.coveragePaths,
      waypoints: waypoints ?? this.waypoints,
      savedMissions: savedMissions ?? this.savedMissions,
      spacingMeters: spacingMeters ?? this.spacingMeters,
      orientationDegrees: orientationDegrees ?? this.orientationDegrees,
      marginMeters: marginMeters ?? this.marginMeters,
      undoHistory: undoHistory ?? this.undoHistory,
      redoHistory: redoHistory ?? this.redoHistory,
      splits: splits ?? this.splits,
      obstacles: obstacles ?? this.obstacles,
      boundaryEditingLocked:
          boundaryEditingLocked ?? this.boundaryEditingLocked,
      activeSplit: activeSplit ?? this.activeSplit,
      coverageBlockedByObstacle:
          coverageBlockedByObstacle ?? this.coverageBlockedByObstacle,
    );
  }
}

class MissionRepository extends StateNotifier<MissionState> {
  MissionRepository({MissionState initialState = const MissionState()})
      : super(initialState);

  int _sequence = 0;
  Timer? _coverageTimer;
  bool _coverageQueued = false;
  double? _pendingSpacing;
  double? _pendingOrientation;
  double? _pendingMargin;
  bool _closed = false;

  @override
  void dispose() {
    _closed = true;
    _coverageTimer?.cancel();
    super.dispose();
  }

  bool addBoundaryPoint({
    required double latitude,
    required double longitude,
  }) {
    if (state.boundaryEditingLocked) {
      return false;
    }
    if (isPointInsideAnyObstacle(LatLng(latitude, longitude))) {
      return false;
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
    return true;
  }

  bool updateBoundaryPoint({
    required String id,
    required double latitude,
    required double longitude,
    required double altitude,
    required double speed,
  }) {
    if (state.boundaryEditingLocked) {
      return false;
    }

    final before = List<BoundaryPoint>.of(state.boundaryPoints);
    final index = before.indexWhere((point) => point.id == id);
    if (index == -1) {
      return false;
    }

    final current = before[index];
    if (_sameBoundaryPoint(
      current,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      speed: speed,
    )) {
      return true;
    }
    if (isPointInsideAnyObstacle(LatLng(latitude, longitude))) {
      return false;
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
    return true;
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
      splits: const [],
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
      splits: const [],
    );
  }

  void resetBoundary() {
    state = state.copyWith(
      boundaryPoints: const [],
      coverageLines: const [],
      coveragePaths: const [],
      waypoints: const [],
      undoHistory: const [],
      redoHistory: const [],
      splits: const [],
      obstacles: const [],
      boundaryEditingLocked: false,
      activeSplit: -1,
      coverageBlockedByObstacle: false,
    );
  }

  String addCircleObstacle(LatLng center) {
    final obstacle = Obstacle(
      id: _nextId('obstacle'),
      type: ObstacleType.circle,
      center: center,
      radiusMeters: Obstacle.defaultRadiusMeters,
    );
    _setObstacles([...state.obstacles, obstacle]);
    return obstacle.id;
  }

  String addSquareObstacle(LatLng center) {
    final obstacle = Obstacle(
      id: _nextId('obstacle'),
      type: ObstacleType.square,
      center: center,
      sideMeters: Obstacle.defaultSideMeters,
      finalized: false,
    );
    _setObstacles([...state.obstacles, obstacle]);
    return obstacle.id;
  }

  void updateObstacleRadius(String id, double newRadius) {
    _replaceMatchedObstacle(id, (current) {
      if (current.type != ObstacleType.circle || current.center == null) {
        return null;
      }
      final radius = newRadius
          .clamp(Obstacle.minSizeMeters, Obstacle.maxSizeMeters)
          .toDouble();
      if (current.radiusMeters == radius) {
        return null;
      }
      return Obstacle(
        id: id,
        type: ObstacleType.circle,
        center: current.center,
        radiusMeters: radius,
      );
    });
  }

  void updateObstacleSide(String id, double sideMeters) {
    _replaceMatchedObstacle(id, (current) {
      if (current.type != ObstacleType.square ||
          current.center == null ||
          current.finalized) {
        return null;
      }
      final side = sideMeters
          .clamp(Obstacle.minSizeMeters, Obstacle.maxSizeMeters)
          .toDouble();
      if (current.sideMeters == side) {
        return null;
      }
      return Obstacle(
        id: id,
        type: ObstacleType.square,
        center: current.center,
        sideMeters: side,
        finalized: false,
      );
    });
  }

  void _replaceMatchedObstacle(
    String id,
    Obstacle? Function(Obstacle current) update,
  ) {
    final index = state.obstacles.indexWhere((obstacle) => obstacle.id == id);
    if (index == -1) {
      return;
    }
    final next = update(state.obstacles[index]);
    if (next == null) {
      return;
    }
    _setObstacles([
      for (final obstacle in state.obstacles)
        if (obstacle.id == id) next else obstacle,
    ]);
  }

  /// Slides the zone by [eastMeters] and [northMeters]. Size and shape stay
  /// the same. Coverage follows on the same timer as the line-angle joystick.
  void moveObstacle(
    String id, {
    required double eastMeters,
    required double northMeters,
  }) {
    if (eastMeters == 0 && northMeters == 0) {
      return;
    }
    final current = _obstacleById(id);
    final center = current?.center;
    if (current == null || center == null) {
      return;
    }
    _replaceObstacle(
      _obstacleAt(current, shiftByMeters(center, eastMeters, northMeters)),
    );
  }

  /// Puts the zone back on an exact center. Used when Cancel undoes a move.
  void placeObstacle(String id, LatLng center) {
    final current = _obstacleById(id);
    final currentCenter = current?.center;
    if (current == null || currentCenter == null) {
      return;
    }
    if (sameLatLng(currentCenter, center)) {
      return;
    }
    _replaceObstacle(_obstacleAt(current, center));
  }

  Obstacle? _obstacleById(String id) {
    for (final obstacle in state.obstacles) {
      if (obstacle.id == id) {
        return obstacle;
      }
    }
    return null;
  }

  Obstacle _obstacleAt(Obstacle current, LatLng center) {
    return Obstacle(
      id: current.id,
      type: current.type,
      center: center,
      radiusMeters: current.radiusMeters,
      sideMeters: current.sideMeters,
      finalized: current.finalized,
    );
  }

  void _replaceObstacle(Obstacle next) {
    state = state.copyWith(
      obstacles: List.unmodifiable([
        for (final obstacle in state.obstacles)
          if (obstacle.id == next.id) next else obstacle,
      ]),
    );
    if (state.coverageLines.isEmpty || state.boundaryPoints.length < 3) {
      return;
    }
    scheduleCoverage();
  }

  void saveObstacle(String id) {
    final index = state.obstacles.indexWhere((obstacle) => obstacle.id == id);
    if (index == -1) {
      return;
    }
    final current = state.obstacles[index];
    if (current.type != ObstacleType.square || current.finalized) {
      return;
    }
    state = state.copyWith(
      obstacles: List.unmodifiable([
        for (final obstacle in state.obstacles)
          if (obstacle.id == id)
            Obstacle(
              id: id,
              type: ObstacleType.square,
              center: current.center,
              sideMeters: current.sideMeters,
              finalized: true,
            )
          else
            obstacle,
      ]),
    );
  }

  void removeObstacle(String id) {
    if (!state.obstacles.any((obstacle) => obstacle.id == id)) {
      return;
    }
    _setObstacles([
      for (final obstacle in state.obstacles)
        if (obstacle.id != id) obstacle,
    ]);
  }

  /// Buffer expansion, when it is added later, stays inside [Obstacle.contains].
  bool isPointInsideAnyObstacle(LatLng point) {
    for (final obstacle in state.obstacles) {
      if (obstacle.contains(point)) {
        return true;
      }
    }
    return false;
  }

  /// True when a flight-path point is through the red fill. A point that only
  /// touches the painted edge is allowed.
  bool _pathEntersObstacle(LatLng point) {
    for (final obstacle in state.obstacles) {
      if (obstacle.enters(point)) {
        return true;
      }
    }
    return false;
  }

  Obstacle? obstacleAt(LatLng point) {
    for (final obstacle in state.obstacles.reversed) {
      if (obstacle.contains(point)) {
        return obstacle;
      }
    }
    return null;
  }

  void _setObstacles(List<Obstacle> obstacles) {
    final hadCoverage = state.coverageLines.isNotEmpty;
    state = state.copyWith(obstacles: List.unmodifiable(obstacles));
    if (hadCoverage && state.boundaryPoints.length >= 3) {
      _publishNow(state.spacingMeters, state.orientationDegrees);
    }
  }

  /// Separates the field at two boundary positions. Returns false when those
  /// positions do not divide the field into two sides.
  bool splitBoundary({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    if (state.boundaryPoints.length < 3) {
      return false;
    }

    final ring = _ringOf(state.boundaryPoints);
    final cut = SplitCut(
      LatLng(startLatitude, startLongitude),
      LatLng(endLatitude, endLongitude),
    );
    final after = boundarySections(ring, [cut]);
    if (after.length < 2) {
      return false;
    }

    final hadCoverage = state.coverageLines.isNotEmpty;
    state = state.copyWith(
      splits: List.unmodifiable([cut]),
      activeSplit: -1,
    );
    if (hadCoverage) {
      _publishNow(state.spacingMeters, state.orientationDegrees);
    }
    return true;
  }

  /// Removes the latest cut and rebuilds the flight lines when they exist.
  void selectSplit(int section) {
    if (section != 0 && section != 1) {
      return;
    }
    state = state.copyWith(activeSplit: section);
  }

  void undoSplit() {
    if (state.splits.isEmpty) {
      return;
    }

    final cuts = [...state.splits]..removeLast();
    final hadCoverage = state.coverageLines.isNotEmpty;
    state = state.copyWith(
      splits: List.unmodifiable(cuts),
      activeSplit: -1,
    );
    if (hadCoverage) {
      _publishNow(state.spacingMeters, state.orientationDegrees);
    }
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
      splits: const [],
      coverageLines: clearDerived ? const [] : state.coverageLines,
      coveragePaths: clearDerived ? const [] : state.coveragePaths,
      waypoints: clearDerived ? const [] : state.waypoints,
      coverageBlockedByObstacle: clearDerived
          ? false
          : state.coverageBlockedByObstacle,
    );
  }

  Future<void> generateCoverage({
    required double spacingMeters,
    required double orientationDegrees,
    double? marginMeters,
  }) async {
    _coverageTimer?.cancel();
    _coverageTimer = null;
    _pendingSpacing = null;
    _pendingOrientation = null;
    _pendingMargin = null;
    _publishNow(
      spacingMeters,
      orientationDegrees,
      marginMeters: marginMeters == null ? null : _clampMargin(marginMeters),
    );
    if (state.coverageLines.isNotEmpty) {
      state = state.copyWith(boundaryEditingLocked: true);
    }
  }

  /// Applies the latest spacing and line angle. The joystick draws its own
  /// knob while this runs, so a drag does not rebuild the map on every degree.
  /// The coverage lines follow on the next frame, then at most every 50
  /// milliseconds until the finger stops.
  /// Stores the edge gap and rebuilds the spray lines with the same spacing
  /// and angle.
  void setCoverageMargin(double marginMeters) {
    final margin = _clampMargin(marginMeters);
    if (state.coverageLines.isEmpty || state.boundaryPoints.length < 3) {
      state = state.copyWith(marginMeters: margin);
      return;
    }
    scheduleCoverage(marginMeters: margin);
  }

  /// Turns the spray lines so they run along the longest side of the field.
  /// The joystick can still change the angle afterwards.
  void alignCoverageToLongestEdge() {
    if (state.boundaryPoints.length < 2) {
      return;
    }
    final degrees = longestEdgeOrientationDegrees(_ringOf(state.boundaryPoints));
    state = state.copyWith(orientationDegrees: degrees);
    if (state.boundaryPoints.length < 3) {
      return;
    }
    scheduleCoverage(orientationDegrees: degrees);
  }

  void scheduleCoverage({
    double? spacingMeters,
    double? orientationDegrees,
    double? marginMeters,
  }) {
    if (spacingMeters != null) {
      _pendingSpacing = spacingMeters;
    }
    if (orientationDegrees != null) {
      _pendingOrientation = orientationDegrees;
    }
    if (marginMeters != null) {
      _pendingMargin = _clampMargin(marginMeters);
    }
    _pendingSpacing ??= state.spacingMeters;
    _pendingOrientation ??= state.orientationDegrees;
    if (_coverageTimer != null || _coverageQueued) {
      return;
    }

    _coverageQueued = true;
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _coverageQueued = false;
      if (_closed) {
        return;
      }
      _publishPending();
      _armCoverageCooldown();
    });
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
    final margin = _pendingMargin;
    if (spacing == null || orientation == null) {
      return;
    }
    _pendingSpacing = null;
    _pendingOrientation = null;
    _pendingMargin = null;
    _publishNow(spacing, orientation, marginMeters: margin);
  }

  void _publishNow(
    double spacingMeters,
    double orientationDegrees, {
    double? marginMeters,
  }) {
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
    final margin = marginMeters ?? state.marginMeters;
    final sample = _requestFromState(
      spacingMeters: spacing,
      orientationDegrees: orientationDegrees,
    );
    final ring = _ringOf(state.boundaryPoints);
    final sections = boundarySections(ring, state.splits);
    final lines = <List<double>>[];
    final sectionIndexes = <int>[];
    final routeBreaks = <bool>[];
    final paths = <List<LatLng>>[];
    final pathSections = <int>[];
    final pathPumps = <List<bool>>[];
    final planningSections = <List<LatLng>>[];
    final loopedObstacles = <String>{};
    var blockedByObstacle = false;
    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      final planning = margin <= 0 ? section : insetPolygon(section, margin);
      planningSections.add(planning.length >= 3 ? planning : const []);
      if (planningSections.last.length < 3) {
        continue;
      }
      final geometry = _coverageGeometry(
        _CoverageRequest(
          latitudes: [for (final point in planning) point.latitude],
          longitudes: [for (final point in planning) point.longitude],
          orders: [for (var index = 0; index < planning.length; index++) index],
          spacingMeters: spacing,
          orientationDegrees: orientationDegrees,
          altitude: sample.altitude,
          speed: sample.speed,
          actionIndex: sample.actionIndex,
        ),
      );
      var breakNext = false;
      LatLng? previousEnd;
      for (final line in geometry.lines) {
        final start = LatLng(line[0], line[1]);
        final end = LatLng(line[2], line[3]);
        if (lineRunsAlongCut(start, end, ring, state.splits)) {
          continue;
        }
        final pieces = _piecesOutsideObstacles(start, end);
        if (pieces.isEmpty) {
          breakNext = true;
          continue;
        }
        for (var pieceIndex = 0; pieceIndex < pieces.length; pieceIndex++) {
          final piece = pieces[pieceIndex];
          var pieceStart = piece.$1;
          if (pieceIndex > 0) {
            final resume = _spliceDetour(
              from: pieces[pieceIndex - 1].$2,
              to: piece.$1,
              section: section,
              sectionIndex: sectionIndex,
              lines: lines,
              paths: paths,
              pathSections: pathSections,
              pathPumps: pathPumps,
              loopedObstacles: loopedObstacles,
            );
            if (_joinsAtStart(piece.$1, piece.$2, resume)) {
              pieceStart = resume;
            }
          } else if (!breakNext && previousEnd != null) {
            final link = _piecesOutsideObstacles(previousEnd, piece.$1);
            if (link.length != 1) {
              final resume = _bridgeLink(
                from: previousEnd,
                to: piece.$1,
                link: link,
                section: section,
                sectionIndex: sectionIndex,
                lines: lines,
                paths: paths,
                pathSections: pathSections,
                pathPumps: pathPumps,
                loopedObstacles: loopedObstacles,
              );
              if (_joinsAtStart(piece.$1, piece.$2, resume)) {
                pieceStart = resume;
              }
            }
          }
          final startsRoute = breakNext && pieceIndex == 0;
          lines.add([
            pieceStart.latitude,
            pieceStart.longitude,
            piece.$2.latitude,
            piece.$2.longitude,
          ]);
          sectionIndexes.add(sectionIndex);
          routeBreaks.add(startsRoute);
          _extendCoveragePath(
            paths: paths,
            pathSections: pathSections,
            pathPumps: pathPumps,
            start: pieceStart,
            end: piece.$2,
            sectionIndex: sectionIndex,
            startsRoute: startsRoute,
            pumpOn: true,
          );
          breakNext = false;
          previousEnd = piece.$2;
        }
      }
    }
    _keepRoutesInside(
      sections: sections,
      paths: paths,
      pathSections: pathSections,
      pathPumps: pathPumps,
      lines: lines,
      sectionIndexes: sectionIndexes,
      routeBreaks: routeBreaks,
    );
    final waypointLatitudes = <double>[];
    final waypointLongitudes = <double>[];
    final waypointSections = <int>[];
    final waypointPumps = <bool>[];
    for (var pathIndex = 0; pathIndex < paths.length; pathIndex++) {
      final path = paths[pathIndex];
      final pumps = pathPumps[pathIndex];
      for (var pointIndex = 0; pointIndex + 1 < path.length; pointIndex++) {
        _appendWaypoints(
          path[pointIndex],
          path[pointIndex + 1],
          waypointLatitudes,
          waypointLongitudes,
          waypointSections,
          waypointPumps,
          pathSections[pathIndex],
          _pathEntersObstacle,
          includeStart: pointIndex == 0,
          pumpOn: pointIndex < pumps.length ? pumps[pointIndex] : true,
        );
      }
    }
    _publishCoverage(
      sample,
      marginMeters: margin,
      _CoverageGeometry(
        lines: lines,
        paths: [
          for (var index = 0; index < paths.length; index++)
            CoveragePath(
              points: List.unmodifiable(paths[index]),
              sectionIndex: pathSections[index],
              pumpOn: List.unmodifiable(pathPumps[index]),
            ),
        ],
        waypointLatitudes: waypointLatitudes,
        waypointLongitudes: waypointLongitudes,
        waypointSections: waypointSections,
        waypointPumpOn: waypointPumps,
        sectionIndexes: sectionIndexes,
        routeBreaks: routeBreaks,
      ),
      blockedByObstacle: blockedByObstacle,
    );
  }

  LatLng _spliceDetour({
    required LatLng from,
    required LatLng to,
    required List<LatLng> section,
    required int sectionIndex,
    required List<List<double>> lines,
    required List<List<LatLng>> paths,
    required List<int> pathSections,
    required List<List<bool>> pathPumps,
    required Set<String> loopedObstacles,
  }) {
    final blocker = _obstacleBetween(from, to);
    final bend = blocker?.routeAround(
          from,
          to,
          insideField: (point) => boundaryContains(section, point),
        ) ??
        [from, to];
    final route = _outlineThenBend(
      blocker: blocker,
      bend: bend,
      section: section,
      loopedObstacles: loopedObstacles,
    );
    if (route.length >= 2) {
      _pullEndBack(lines, paths, route.first);
    }
    for (var index = 0; index < route.length - 1; index++) {
      _extendCoveragePath(
        paths: paths,
        pathSections: pathSections,
        pathPumps: pathPumps,
        start: route[index],
        end: route[index + 1],
        sectionIndex: sectionIndex,
        startsRoute: false,
        pumpOn: false,
      );
    }
    return route.last;
  }

  /// The first time a pass meets an obstacle, draw that obstacle's whole
  /// outline, then continue along the short side to the other end of the pass.
  List<LatLng> _outlineThenBend({
    required Obstacle? blocker,
    required List<LatLng> bend,
    required List<LatLng> section,
    required Set<String> loopedObstacles,
  }) {
    if (blocker == null ||
        blocker.type == ObstacleType.circle ||
        bend.length < 3 ||
        !loopedObstacles.add(blocker.id)) {
      return bend;
    }
    final loop = blocker.routeLoop(bend.first);
    if (loop.length < 4 || !loop.every((point) => boundaryContains(section, point))) {
      loopedObstacles.remove(blocker.id);
      return bend;
    }
    return [...loop, ...bend.skip(1)];
  }

  /// Draws the straight parts of a pass-to-pass link, and bends only the
  /// stretch that actually enters a no-fly zone.
  LatLng _bridgeLink({
    required LatLng from,
    required LatLng to,
    required List<(LatLng, LatLng)> link,
    required List<LatLng> section,
    required int sectionIndex,
    required List<List<double>> lines,
    required List<List<LatLng>> paths,
    required List<int> pathSections,
    required List<List<bool>> pathPumps,
    required Set<String> loopedObstacles,
  }) {
    if (link.isEmpty) {
      return _spliceDetour(
        from: from,
        to: to,
        section: section,
        sectionIndex: sectionIndex,
        lines: lines,
        paths: paths,
        pathSections: pathSections,
        pathPumps: pathPumps,
        loopedObstacles: loopedObstacles,
      );
    }
    const distance = Distance();
    var cursor = from;
    for (final part in link) {
      var partStart = part.$1;
      if (distance.as(LengthUnit.Meter, cursor, part.$1) > 0.2) {
        final resume = _spliceDetour(
          from: cursor,
          to: part.$1,
          section: section,
          sectionIndex: sectionIndex,
          lines: lines,
          paths: paths,
          pathSections: pathSections,
          pathPumps: pathPumps,
          loopedObstacles: loopedObstacles,
        );
        if (_joinsAtStart(part.$1, part.$2, resume)) {
          partStart = resume;
        }
      }
      _extendCoveragePath(
        paths: paths,
        pathSections: pathSections,
        pathPumps: pathPumps,
        start: partStart,
        end: part.$2,
        sectionIndex: sectionIndex,
        startsRoute: false,
        pumpOn: true,
      );
      cursor = part.$2;
    }
    return cursor;
  }

  void _pullEndBack(
    List<List<double>> lines,
    List<List<LatLng>> paths,
    LatLng point,
  ) {
    if (lines.isNotEmpty) {
      final line = lines.last;
      final start = LatLng(line[0], line[1]);
      final end = LatLng(line[2], line[3]);
      if (_joinsAtEnd(start, end, point)) {
        line[2] = point.latitude;
        line[3] = point.longitude;
      }
    }
    if (paths.isNotEmpty && paths.last.length >= 2) {
      final path = paths.last;
      if (_joinsAtEnd(path[path.length - 2], path.last, point)) {
        path[path.length - 1] = point;
      }
    }
  }

  bool _joinsAtEnd(LatLng start, LatLng end, LatLng point) {
    return _onSegment(start, end, point) || _justPastEnd(start, end, point);
  }

  bool _joinsAtStart(LatLng start, LatLng end, LatLng point) {
    return _onSegment(start, end, point) || _justBeforeStart(start, end, point);
  }

  bool _justPastEnd(LatLng start, LatLng end, LatLng point) {
    const distance = Distance();
    final span = distance.as(LengthUnit.Meter, start, end);
    final toEnd = distance.as(LengthUnit.Meter, end, point);
    final toStart = distance.as(LengthUnit.Meter, start, point);
    if (span < 1e-6 || toEnd > 1 || toEnd + 0.05 >= toStart) {
      return false;
    }
    return (toStart - (span + toEnd)).abs() <= 0.25;
  }

  bool _justBeforeStart(LatLng start, LatLng end, LatLng point) {
    const distance = Distance();
    final span = distance.as(LengthUnit.Meter, start, end);
    final toStart = distance.as(LengthUnit.Meter, start, point);
    final toEnd = distance.as(LengthUnit.Meter, end, point);
    if (span < 1e-6 || toStart > 1 || toStart + 0.05 >= toEnd) {
      return false;
    }
    return (toEnd - (span + toStart)).abs() <= 0.25;
  }

  bool _onSegment(LatLng start, LatLng end, LatLng point) {
    const distance = Distance();
    final span = distance.as(LengthUnit.Meter, start, end);
    if (span < 1e-6) {
      return false;
    }
    final along = distance.as(LengthUnit.Meter, start, point);
    final rest = distance.as(LengthUnit.Meter, point, end);
    return (along + rest - span).abs() <= 0.15 && along <= span + 0.05;
  }

  Obstacle? _obstacleBetween(LatLng from, LatLng to) {
    for (var step = 1; step < 8; step++) {
      final t = step / 8;
      final point = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      for (final obstacle in state.obstacles) {
        if (obstacle.contains(point)) {
          return obstacle;
        }
      }
    }
    return null;
  }

  /// Keeps every part of a pass that is outside every obstacle's flight ring.
  /// A dropped stretch is the part whose midpoint is inside that ring. The
  /// kept ends are the exact points where the path meets the ring.
  List<(LatLng, LatLng)> _piecesOutsideObstacles(LatLng start, LatLng end) {
    var pieces = <(LatLng, LatLng)>[(start, end)];
    for (final obstacle in state.obstacles) {
      final next = <(LatLng, LatLng)>[];
      for (final piece in pieces) {
        next.addAll(obstacle.outsidePieces(piece.$1, piece.$2));
      }
      pieces = next;
    }
    return pieces;
  }

  static List<LatLng> _ringOf(List<BoundaryPoint> points) {
    final ordered = [...points]..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (final point in ordered) LatLng(point.latitude, point.longitude),
    ];
  }

  static double lineSpacingUpperBound(List<BoundaryPoint> points) {
    final span = _boundarySpanMeters(points);
    if (span <= 0) {
      return minLineSpacingMeters;
    }
    return span;
  }

  static double _clampMargin(double marginMeters) {
    if (!marginMeters.isFinite || marginMeters <= 0) {
      return 0;
    }
    if (marginMeters > maxCoverageMarginMeters) {
      return maxCoverageMarginMeters;
    }
    return marginMeters;
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

  void _publishCoverage(
    _CoverageRequest request,
    _CoverageGeometry geometry, {
    required bool blockedByObstacle,
    required double marginMeters,
  }) {
    final action = WaypointAction.values[request.actionIndex];
    final lines = <CoverageLine>[
      for (var index = 0; index < geometry.lines.length; index++)
        CoverageLine(
          endpoints: [
            LatLng(geometry.lines[index][0], geometry.lines[index][1]),
            LatLng(geometry.lines[index][2], geometry.lines[index][3]),
          ],
          sectionIndex: index < geometry.sectionIndexes.length
              ? geometry.sectionIndexes[index]
              : 0,
          startsRoute: index < geometry.routeBreaks.length && geometry.routeBreaks[index],
        ),
    ];
    final waypoints = <Waypoint>[];
    var blocked = blockedByObstacle;
    for (var index = 0; index < geometry.waypointLatitudes.length; index++) {
      final point = LatLng(
        geometry.waypointLatitudes[index],
        geometry.waypointLongitudes[index],
      );
      if (_pathEntersObstacle(point)) {
        blocked = true;
        continue;
      }
      waypoints.add(
        Waypoint(
          id: _nextId('waypoint'),
          latitude: point.latitude,
          longitude: point.longitude,
          altitude: request.altitude,
          speed: request.speed,
          action: action,
          sectionIndex: index < geometry.waypointSections.length
              ? geometry.waypointSections[index]
              : 0,
          pumpOn: index < geometry.waypointPumpOn.length
              ? geometry.waypointPumpOn[index]
              : true,
        ),
      );
    }
    state = state.copyWith(
      coverageLines: List.unmodifiable(lines),
      coveragePaths: List.unmodifiable(geometry.paths),
      waypoints: List.unmodifiable(waypoints),
      spacingMeters: request.spacingMeters,
      orientationDegrees: request.orientationDegrees,
      marginMeters: marginMeters,
      coverageBlockedByObstacle: blocked,
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
    final current = state.waypoints[index];
    final moved = current.latitude != waypoint.latitude ||
        current.longitude != waypoint.longitude;
    if (moved &&
        isPointInsideAnyObstacle(LatLng(waypoint.latitude, waypoint.longitude))) {
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
        date: DateTime.utc(2026, 9, 26, 6, 40),
        durationSeconds: 754,
        status: 'completed',
      ),
      FlightLog(
        date: DateTime.utc(2026, 9, 28, 7, 15),
        durationSeconds: 512,
        status: 'completed',
      ),
      FlightLog(
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
    this.paths = const [],
    this.sectionIndexes = const [],
    this.waypointSections = const [],
    this.waypointPumpOn = const [],
    this.routeBreaks = const [],
  });

  /// Each line is `[startLat, startLng, endLat, endLng]`.
  final List<List<double>> lines;
  final List<CoveragePath> paths;
  final List<int> sectionIndexes;
  final List<bool> routeBreaks;
  final List<double> waypointLatitudes;
  final List<double> waypointLongitudes;
  final List<int> waypointSections;
  final List<bool> waypointPumpOn;
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
  final ys = <double>[
    for (var index = 0; index < lineCount; index++) minY + index * step,
  ];

  final sweeps = <_Sweep>[];
  for (final y in ys) {
    final crossings = _horizontalCrossings(localPolygon, y);
    for (var pair = 0; pair + 1 < crossings.length; pair += 2) {
      if ((crossings[pair + 1] - crossings[pair]).abs() < 0.05) {
        continue;
      }
      final leftX = crossings[pair];
      final rightX = crossings[pair + 1];
      sweeps.add(
        _Sweep(
          y: y,
          leftX: leftX,
          rightX: rightX,
          left: _sweepPoint(
            x: leftX,
            y: y,
            alignToEast: alignToEast,
            originLatitude: originLatitude,
            originLongitude: originLongitude,
          ),
          right: _sweepPoint(
            x: rightX,
            y: y,
            alignToEast: alignToEast,
            originLatitude: originLatitude,
            originLongitude: originLongitude,
          ),
        ),
      );
    }
  }

  final lines = _shortestSweepLines(sweeps);
  return _CoverageGeometry(
    lines: lines,
    waypointLatitudes: const [],
    waypointLongitudes: const [],
  );
}

class _Sweep {
  const _Sweep({
    required this.y,
    required this.leftX,
    required this.rightX,
    required this.left,
    required this.right,
  });

  final double y;
  final double leftX;
  final double rightX;
  final LatLng left;
  final LatLng right;
}

LatLng _sweepPoint({
  required double x,
  required double y,
  required double alignToEast,
  required double originLatitude,
  required double originLongitude,
}) {
  return _fromLocal(
    _rotate(_LocalPoint(x, y), -alignToEast),
    originLatitude,
    originLongitude,
  );
}

/// Four lawnmower orders of the same passes: low edge or high edge first,
/// and the first pass left-to-right or right-to-left. The reverses share a
/// length, so the shorter connector side wins. A tie keeps the earlier order.
List<List<double>> _shortestSweepLines(List<_Sweep> sweeps) {
  if (sweeps.isEmpty) {
    return const [];
  }
  final lowToHigh = [...sweeps]..sort((a, b) => a.y.compareTo(b.y));
  final candidates = [
    _orderSweeps(lowToHigh, startAtHighY: false, firstGoesRight: true),
    _orderSweeps(lowToHigh, startAtHighY: false, firstGoesRight: false),
    _orderSweeps(lowToHigh, startAtHighY: true, firstGoesRight: true),
    _orderSweeps(lowToHigh, startAtHighY: true, firstGoesRight: false),
  ];
  var best = candidates.first;
  var bestLength = _routeLength(best);
  for (final candidate in candidates.skip(1)) {
    final length = _routeLength(candidate);
    if (length + 0.05 < bestLength) {
      best = candidate;
      bestLength = length;
    }
  }
  return best;
}

List<List<double>> _orderSweeps(
  List<_Sweep> lowToHigh, {
  required bool startAtHighY,
  required bool firstGoesRight,
}) {
  final visit = startAtHighY ? lowToHigh.reversed.toList() : lowToHigh;
  final lines = <List<double>>[];
  for (var index = 0; index < visit.length; index++) {
    final sweep = visit[index];
    final goesRight = firstGoesRight == index.isEven;
    final from = goesRight ? sweep.left : sweep.right;
    final to = goesRight ? sweep.right : sweep.left;
    lines.add([from.latitude, from.longitude, to.latitude, to.longitude]);
  }
  return lines;
}

double _routeLength(List<List<double>> lines) {
  var total = 0.0;
  LatLng? previousEnd;
  for (final line in lines) {
    final start = LatLng(line[0], line[1]);
    final end = LatLng(line[2], line[3]);
    if (previousEnd != null) {
      total += _metersBetween(previousEnd, start);
    }
    total += _metersBetween(start, end);
    previousEnd = end;
  }
  return total;
}

double _metersBetween(LatLng a, LatLng b) {
  return const Distance().as(LengthUnit.Meter, a, b);
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
  final local = toLocalMeters(
    LatLng(latitude, longitude),
    LatLng(originLatitude, originLongitude),
  );
  return _LocalPoint(local.east, local.north);
}

LatLng _fromLocal(
  _LocalPoint point,
  double originLatitude,
  double originLongitude,
) {
  return fromLocalMeters(
    LocalMeters(point.x, point.y),
    LatLng(originLatitude, originLongitude),
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

/// Pulls every published route back inside its field section. A straight
/// pass, a turn, or an obstacle bend that would leave is replaced by the
/// boundary edge between the exit and the return.
void _keepRoutesInside({
  required List<List<LatLng>> sections,
  required List<List<LatLng>> paths,
  required List<int> pathSections,
  required List<List<bool>> pathPumps,
  required List<List<double>> lines,
  required List<int> sectionIndexes,
  required List<bool> routeBreaks,
}) {
  final keptPaths = <List<LatLng>>[];
  final keptPathSections = <int>[];
  final keptPumps = <List<bool>>[];
  for (var index = 0; index < paths.length; index++) {
    final section = _sectionAt(sections, pathSections[index]);
    final points = paths[index];
    final pumps = index < pathPumps.length ? pathPumps[index] : const <bool>[];
    final clipped = section == null ? points : pathInsideBoundary(points, section);
    if (clipped.length < 2) {
      continue;
    }
    keptPaths.add(clipped);
    keptPathSections.add(pathSections[index]);
    keptPumps.add(_pumpsForClippedPath(points, pumps, clipped));
  }
  paths
    ..clear()
    ..addAll(keptPaths);
  pathSections
    ..clear()
    ..addAll(keptPathSections);
  pathPumps
    ..clear()
    ..addAll(keptPumps);

  final keptLines = <List<double>>[];
  final keptSections = <int>[];
  final keptBreaks = <bool>[];
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final section = _sectionAt(sections, sectionIndexes[index]);
    final clipped = section == null
        ? <LatLng>[
            LatLng(line[0], line[1]),
            LatLng(line[2], line[3]),
          ]
        : pathInsideBoundary(
            [
              LatLng(line[0], line[1]),
              LatLng(line[2], line[3]),
            ],
            section,
          );
    for (var point = 0; point + 1 < clipped.length; point++) {
      keptLines.add([
        clipped[point].latitude,
        clipped[point].longitude,
        clipped[point + 1].latitude,
        clipped[point + 1].longitude,
      ]);
      keptSections.add(sectionIndexes[index]);
      keptBreaks.add(point == 0 && routeBreaks[index]);
    }
  }
  lines
    ..clear()
    ..addAll(keptLines);
  sectionIndexes
    ..clear()
    ..addAll(keptSections);
  routeBreaks
    ..clear()
    ..addAll(keptBreaks);
}

List<LatLng>? _sectionAt(List<List<LatLng>> sections, int index) {
  if (index < 0 || index >= sections.length || sections[index].length < 3) {
    return null;
  }
  return sections[index];
}

List<bool> _pumpsForClippedPath(
  List<LatLng> original,
  List<bool> pumps,
  List<LatLng> clipped,
) {
  if (original.length < 2) {
    return List<bool>.filled(clipped.length - 1, true);
  }
  return [
    for (var index = 0; index + 1 < clipped.length; index++)
      _pumpOnNear(
        original,
        pumps,
        LatLng(
          (clipped[index].latitude + clipped[index + 1].latitude) / 2,
          (clipped[index].longitude + clipped[index + 1].longitude) / 2,
        ),
      ),
  ];
}

bool _pumpOnNear(List<LatLng> original, List<bool> pumps, LatLng point) {
  var best = double.infinity;
  var sprays = true;
  final local = toLocalMeters(point, original.first);
  for (var index = 0; index + 1 < original.length; index++) {
    final start = toLocalMeters(original[index], original.first);
    final end = toLocalMeters(original[index + 1], original.first);
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
      sprays = index < pumps.length ? pumps[index] : true;
    }
  }
  return sprays;
}

void _extendCoveragePath({
  required List<List<LatLng>> paths,
  required List<int> pathSections,
  required List<List<bool>> pathPumps,
  required LatLng start,
  required LatLng end,
  required int sectionIndex,
  required bool startsRoute,
  required bool pumpOn,
}) {
  final continues = !startsRoute &&
      paths.isNotEmpty &&
      pathSections.last == sectionIndex;
  if (!continues) {
    paths.add([start, end]);
    pathSections.add(sectionIndex);
    pathPumps.add([pumpOn]);
    return;
  }

  final path = paths.last;
  final pumps = pathPumps.last;
  if (!sameLatLng(path.last, start)) {
    _addPathPoint(path, pumps, start, pumpOn);
  }
  _addPathPoint(path, pumps, end, pumpOn);
}

void _addPathPoint(
  List<LatLng> path,
  List<bool> pumps,
  LatLng point,
  bool pumpOn,
) {
  if (path.isNotEmpty && sameLatLng(path.last, point)) {
    return;
  }
  if (path.length >= 2 &&
      pumps.isNotEmpty &&
      pumps.last == pumpOn &&
      _runsStraight(path[path.length - 2], path.last, point)) {
    path[path.length - 1] = point;
    return;
  }
  path.add(point);
  pumps.add(pumpOn);
}

bool _runsStraight(LatLng start, LatLng middle, LatLng end) {
  // True when [middle] already lies on the straight segment from [start] to
  // [end]. A summed length hides a corner when one leg is very short, and
  // dropping that corner lets the path cut into the no-fly zone.
  final endLocal = toLocalMeters(end, start);
  final midLocal = toLocalMeters(middle, start);
  final endEast = endLocal.east;
  final endNorth = endLocal.north;
  final midEast = midLocal.east;
  final midNorth = midLocal.north;
  final lengthSquared = endEast * endEast + endNorth * endNorth;
  if (lengthSquared < 1e-8) {
    return midEast * midEast + midNorth * midNorth <= 0.0004;
  }
  final t = (midEast * endEast + midNorth * endNorth) / lengthSquared;
  if (t < -0.001 || t > 1.001) {
    return false;
  }
  final offEast = midEast - t * endEast;
  final offNorth = midNorth - t * endNorth;
  return offEast * offEast + offNorth * offNorth <= 0.0004;
}

bool _appendWaypoints(
  LatLng start,
  LatLng end,
  List<double> latitudes,
  List<double> longitudes,
  List<int> sections,
  List<bool> pumps,
  int sectionIndex,
  bool Function(LatLng point) blocked, {
  bool includeStart = true,
  bool pumpOn = true,
}) {
  const intervalMeters = 12.0;
  const interiorBudget = 2500;
  final length = const Distance().as(LengthUnit.Meter, start, end);
  final steps = length < 1 || latitudes.length >= interiorBudget
      ? 1
      : max(1, (length / intervalMeters).ceil());
  var droppedInside = false;
  for (var step = 0; step <= steps; step++) {
    if (!includeStart && step == 0) {
      continue;
    }
    final t = step / steps;
    final point = LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
    if (blocked(point)) {
      droppedInside = true;
      continue;
    }
    latitudes.add(point.latitude);
    longitudes.add(point.longitude);
    sections.add(sectionIndex);
    pumps.add(pumpOn);
  }
  return droppedInside;
}

