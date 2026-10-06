import 'dart:math';

import 'package:clipper2/clipper2.dart';
import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:fc_frontend/core/geometry/polygon_simple.dart';
import 'package:latlong2/latlong.dart';

const squareMetersPerHectare = 10000.0;
const squareMetersPerAcre = 4046.8564224;
const squareMetersPerMu = 10000.0 / 15.0;

/// Sides used only when clipping a circle. The number shown for that circle
/// is still the exact disk area.
const circleClipSides = 64;

enum AreaUnit { hectare, squareMeter, acre, mu }

enum FieldAreaProblem { needsThreePoints, boundaryCrosses }

/// A circle or polygon the area maths should measure. This is not the saved
/// obstacle; it is only the shape the calculation needs.
class AreaSubject {
  const AreaSubject.circle({
    required this.center,
    required this.radiusMeters,
  }) : vertices = const [];

  const AreaSubject.polygon(this.vertices) : center = null, radiusMeters = null;

  final LatLng? center;
  final double? radiusMeters;
  final List<LatLng> vertices;

  bool get isCircle => center != null && radiusMeters != null;
}

/// One obstacle's own area, and how much of it lies inside the field.
class ObstacleArea {
  const ObstacleArea({
    required this.squareMeters,
    required this.insideSquareMeters,
    required this.outsideField,
  });

  final double squareMeters;
  final double insideSquareMeters;
  final bool outsideField;
}

/// Areas derived from a boundary and its obstacles. Numbers are null when
/// [problem] is set, so a bad boundary never produces a figure.
class FieldArea {
  const FieldArea._({
    required this.problem,
    required this.fieldSquareMeters,
    required this.obstacles,
    required this.unionSquareMeters,
    required this.netSquareMeters,
    required this.overlapCountedOnce,
    required this.label,
  });

  const FieldArea.invalid(FieldAreaProblem this.problem)
    : fieldSquareMeters = null,
      obstacles = const [],
      unionSquareMeters = null,
      netSquareMeters = null,
      overlapCountedOnce = false,
      label = null;

  final FieldAreaProblem? problem;
  final double? fieldSquareMeters;
  final List<ObstacleArea> obstacles;
  final double? unionSquareMeters;
  final double? netSquareMeters;
  final bool overlapCountedOnce;

  /// A point inside the field, used to pin the area chip on the map.
  final LatLng? label;

  bool get isValid => problem == null;
}

String formatArea(double squareMeters, AreaUnit unit) {
  final text = areaInUnit(squareMeters, unit).toStringAsFixed(
    areaFractionDigits(unit),
  );
  return '$text ${areaUnitSuffix(unit)}';
}

/// The obstacle's own area, before it is clipped to the field.
double subjectSquareMeters(AreaSubject subject) {
  if (subject.isCircle) {
    final radius = subject.radiusMeters ?? 0;
    if (radius <= 0) {
      return 0;
    }
    return pi * radius * radius;
  }
  if (subject.vertices.length < 3) {
    return 0;
  }
  return _ringArea(_metersOf(subject.vertices, subject.vertices.first));
}

double areaInUnit(double squareMeters, AreaUnit unit) {
  switch (unit) {
    case AreaUnit.hectare:
      return squareMeters / squareMetersPerHectare;
    case AreaUnit.squareMeter:
      return squareMeters;
    case AreaUnit.acre:
      return squareMeters / squareMetersPerAcre;
    case AreaUnit.mu:
      return squareMeters / squareMetersPerMu;
  }
}

int areaFractionDigits(AreaUnit unit) {
  return unit == AreaUnit.squareMeter ? 0 : 2;
}

String areaUnitSuffix(AreaUnit unit) {
  switch (unit) {
    case AreaUnit.hectare:
      return 'ha';
    case AreaUnit.squareMeter:
      return 'm²';
    case AreaUnit.acre:
      return 'acre';
    case AreaUnit.mu:
      return 'mu';
  }
}

/// Field area, each obstacle, and the net area after overlapping obstacles
/// are subtracted once. All figures are square metres.
FieldArea measureFieldArea({
  required List<LatLng> boundary,
  required List<AreaSubject> obstacles,
}) {
  if (boundary.length < 3) {
    return const FieldArea.invalid(FieldAreaProblem.needsThreePoints);
  }
  if (!polygonIsSimple(boundary, closed: true)) {
    return const FieldArea.invalid(FieldAreaProblem.boundaryCrosses);
  }

  final origin = _vertexCentroid(boundary);
  final fieldRing = _metersOf(boundary, origin);
  final fieldPath = _path(fieldRing);
  final fieldArea = _ringArea(fieldRing);
  final measured = <ObstacleArea>[];
  final clipped = <PathD>[];
  var insideTotal = 0.0;

  for (final obstacle in obstacles) {
    final reading = _measureObstacle(obstacle, origin, fieldPath);
    measured.add(reading.area);
    insideTotal += reading.area.insideSquareMeters;
    clipped.addAll(reading.paths);
  }

  final unionArea = _unionArea(clipped);
  final overlap = insideTotal > unionArea + _overlapSlack(unionArea);
  return FieldArea._(
    problem: null,
    fieldSquareMeters: fieldArea,
    obstacles: measured,
    unionSquareMeters: unionArea,
    netSquareMeters: fieldArea - unionArea,
    overlapCountedOnce: overlap,
    label: fromLocalMeters(_visualCenter(fieldRing), origin),
  );
}

class _ClippedObstacle {
  const _ClippedObstacle(this.area, this.paths);

  final ObstacleArea area;
  final List<PathD> paths;
}

_ClippedObstacle _measureObstacle(
  AreaSubject obstacle,
  LatLng origin,
  PathD fieldPath,
) {
  final ownRing = _subjectRing(obstacle, origin);
  final ownArea = obstacle.isCircle
      ? pi * obstacle.radiusMeters! * obstacle.radiusMeters!
      : _ringArea(ownRing);
  if (ownRing.length < 3 || ownArea <= 0) {
    return const _ClippedObstacle(
      ObstacleArea(
        squareMeters: 0,
        insideSquareMeters: 0,
        outsideField: false,
      ),
      [],
    );
  }

  final insidePaths = Clipper.intersectD(
    subject: [_path(ownRing)],
    clip: [fieldPath],
    fillRule: FillRule.nonZero,
    precision: _clipDecimals,
  );
  final insideArea = _pathsArea(insidePaths);
  return _ClippedObstacle(
    ObstacleArea(
      squareMeters: ownArea,
      insideSquareMeters: insideArea,
      outsideField: ownArea > _outsideSlack && insideArea <= _outsideSlack,
    ),
    insidePaths,
  );
}

List<LocalMeters> _subjectRing(AreaSubject obstacle, LatLng origin) {
  if (obstacle.isCircle) {
    final center = toLocalMeters(obstacle.center!, origin);
    return _circleClipRing(center, obstacle.radiusMeters!);
  }
  if (obstacle.vertices.length < 3) {
    return const [];
  }
  return _metersOf(obstacle.vertices, origin);
}

List<LocalMeters> _circleClipRing(LocalMeters center, double radius) {
  final outer = radius / cos(pi / circleClipSides);
  return [
    for (var index = 0; index < circleClipSides; index++)
      LocalMeters(
        center.east + outer * cos(2 * pi * index / circleClipSides),
        center.north + outer * sin(2 * pi * index / circleClipSides),
      ),
  ];
}

double _unionArea(List<PathD> clipped) {
  if (clipped.isEmpty) {
    return 0;
  }
  if (clipped.length == 1) {
    return _pathsArea(clipped);
  }
  return _pathsArea(
    Clipper.unionD(
      subject: clipped,
      clip: <PathD>[],
      fillRule: FillRule.nonZero,
      precision: _clipDecimals,
    ),
  );
}

const _clipDecimals = 4;
const _outsideSlack = 0.05;

double _overlapSlack(double unionArea) {
  return max(0.05, unionArea * 0.0002);
}

LatLng _vertexCentroid(List<LatLng> points) {
  var latitude = 0.0;
  var longitude = 0.0;
  for (final point in points) {
    latitude += point.latitude;
    longitude += point.longitude;
  }
  final count = points.length;
  return LatLng(latitude / count, longitude / count);
}

List<LocalMeters> _metersOf(List<LatLng> points, LatLng origin) {
  return [for (final point in points) toLocalMeters(point, origin)];
}

PathD _path(List<LocalMeters> ring) {
  return [for (final point in ring) PointD(point.east, point.north)];
}

double _ringArea(List<LocalMeters> ring) {
  if (ring.length < 3) {
    return 0;
  }
  var sum = 0.0;
  for (var index = 0; index < ring.length; index++) {
    final next = ring[(index + 1) % ring.length];
    final point = ring[index];
    sum += point.east * next.north - next.east * point.north;
  }
  return sum.abs() * 0.5;
}

double _pathsArea(List<PathD> paths) {
  var sum = 0.0;
  for (final path in paths) {
    sum += path.area;
  }
  return sum.abs();
}

LocalMeters _visualCenter(List<LocalMeters> ring) {
  var west = ring.first.east;
  var east = west;
  var south = ring.first.north;
  var north = south;
  for (final point in ring) {
    west = min(west, point.east);
    east = max(east, point.east);
    south = min(south, point.north);
    north = max(north, point.north);
  }

  LocalMeters? best;
  var bestClearance = -1.0;
  void consider(LocalMeters point) {
    if (!_insideRing(ring, point)) {
      return;
    }
    final clearance = _clearance(ring, point);
    if (clearance > bestClearance) {
      best = point;
      bestClearance = clearance;
    }
  }

  var left = west;
  var right = east;
  var bottom = south;
  var top = north;
  const divisions = 24;
  for (var pass = 0; pass < 5; pass++) {
    final stepEast = (right - left) / divisions;
    final stepNorth = (top - bottom) / divisions;
    if (stepEast <= 0 || stepNorth <= 0) {
      break;
    }
    for (var column = 0; column <= divisions; column++) {
      for (var row = 0; row <= divisions; row++) {
        consider(
          LocalMeters(left + stepEast * column, bottom + stepNorth * row),
        );
      }
    }
    final found = best;
    if (found == null) {
      break;
    }
    left = found.east - stepEast;
    right = found.east + stepEast;
    bottom = found.north - stepNorth;
    top = found.north + stepNorth;
  }
  return best ?? _inwardFromEdge(ring);
}

LocalMeters _inwardFromEdge(List<LocalMeters> ring) {
  for (var index = 0; index < ring.length; index++) {
    final start = ring[index];
    final end = ring[(index + 1) % ring.length];
    final east = end.east - start.east;
    final north = end.north - start.north;
    final length = sqrt(east * east + north * north);
    if (length < 1e-6) {
      continue;
    }
    final midEast = (start.east + end.east) / 2;
    final midNorth = (start.north + end.north) / 2;
    final left = LocalMeters(
      midEast - north / length * 0.5,
      midNorth + east / length * 0.5,
    );
    if (_insideRing(ring, left)) {
      return left;
    }
    final right = LocalMeters(
      midEast + north / length * 0.5,
      midNorth - east / length * 0.5,
    );
    if (_insideRing(ring, right)) {
      return right;
    }
  }
  return ring.first;
}

bool _insideRing(List<LocalMeters> ring, LocalMeters point) {
  var inside = false;
  for (var index = 0, previous = ring.length - 1; index < ring.length; previous = index++) {
    final start = ring[previous];
    final end = ring[index];
    final crosses = (start.north > point.north) != (end.north > point.north);
    if (!crosses) {
      continue;
    }
    final east = start.east +
        (end.east - start.east) * (point.north - start.north) / (end.north - start.north);
    if (point.east < east) {
      inside = !inside;
    }
  }
  return inside;
}

double _clearance(List<LocalMeters> ring, LocalMeters point) {
  var nearest = double.infinity;
  for (var index = 0; index < ring.length; index++) {
    final start = ring[index];
    final end = ring[(index + 1) % ring.length];
    final distance = distanceToSegmentMeters(
      pointEast: point.east,
      pointNorth: point.north,
      startEast: start.east,
      startNorth: start.north,
      endEast: end.east,
      endNorth: end.north,
    );
    if (distance < nearest) {
      nearest = distance;
    }
  }
  return nearest;
}
