import 'dart:math';

import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:latlong2/latlong.dart';

enum ObstacleType { circle, polygon }

/// A no-fly zone. Both shapes are exclusion zones: coverage keeps the ground
/// outside the shape and drops anything [contains] reports as inside.
///
/// A future `bufferMeters` field can grow that blocked area without changing
/// callers. [contains] is the only place that decision needs to live: a circle
/// would test `radiusMeters + bufferMeters`, and a polygon would grow each edge
/// outward by that same distance.
class Obstacle {
  const Obstacle({
    required this.id,
    required this.type,
    this.center,
    this.radiusMeters,
    this.vertices = const [],
  });

  final String id;
  final ObstacleType type;
  final LatLng? center;
  final double? radiusMeters;

  /// Polygon corners in the order the user tapped them. The shape is closed
  /// from the last point back to the first. A circle leaves this empty.
  final List<LatLng> vertices;

  static const defaultRadiusMeters = 10.0;
  static const minSizeMeters = 1.0;
  static const maxSizeMeters = 500.0;

  LatLng get labelPoint => center ?? (vertices.isEmpty ? const LatLng(0, 0) : vertices.first);

  /// Average of the polygon corners, in local meters, so a move can shift
  /// every corner by the same offset.
  static LatLng centerOf(List<LatLng> vertices) {
    final origin = vertices.first;
    var east = 0.0;
    var north = 0.0;
    for (final vertex in vertices) {
      final local = toLocalMeters(vertex, origin);
      east += local.east;
      north += local.north;
    }
    final count = vertices.length;
    return fromLocalMeters(LocalMeters(east / count, north / count), origin);
  }

  /// Ring used to paint the zone. A circle is drawn as many sides so the red
  /// edge matches the meter check in [contains]. A polygon uses the tapped
  /// corners in order.
  List<LatLng> get outline {
    if (type == ObstacleType.circle && center != null && radiusMeters != null) {
      return _circleOutline(center!, radiusMeters!);
    }
    if (type == ObstacleType.polygon && vertices.length >= 3) {
      return vertices;
    }
    return const [];
  }

  /// True when [point] is inside this zone or on its border.
  /// Circle: distance from the center is at most the radius.
  /// Polygon: the point is inside the tapped ring or on one of its edges.
  bool contains(LatLng point) {
    if (type == ObstacleType.circle) {
      final zoneCenter = center;
      final radius = radiusMeters;
      if (zoneCenter == null || radius == null) {
        return false;
      }
      final local = _toXY(point, zoneCenter);
      return _length(local.x, local.y) <= radius;
    }
    final ring = _polygonLocal(this);
    if (ring == null) {
      return false;
    }
    final local = _toXY(point, ring.origin);
    if (_distanceToRing(local, ring.vertices) <= borderTouchMeters) {
      return true;
    }
    return _pointInRing(ring.vertices, local);
  }

  /// True when [point] is inside the painted zone, not merely touching its edge.
  /// The flight path may sit on the red boundary. It must not cross into this.
  bool enters(LatLng point) {
    if (type == ObstacleType.circle) {
      final zoneCenter = center;
      final radius = radiusMeters;
      if (zoneCenter == null || radius == null) {
        return false;
      }
      final local = _toXY(point, zoneCenter);
      return _length(local.x, local.y) < radius - borderTouchMeters;
    }
    final ring = _polygonLocal(this);
    if (ring == null) {
      return false;
    }
    final local = _toXY(point, ring.origin);
    if (_distanceToRing(local, ring.vertices) <= borderTouchMeters) {
      return false;
    }
    return _pointInRing(ring.vertices, local);
  }

  /// How close a path point may come to the painted edge and still count as
  /// touching it, rather than flying through the zone.
  static const borderTouchMeters = 0.02;

  /// No extra gap outside a circle. Straight sides may touch the red edge.
  /// Their corners stay outside so a side does not cut through the disk.
  /// The red circle drawn on the map is still [radiusMeters].
  static const circleBufferMeters = 0.0;

  /// Straight sides used only to route around a circle. This shape is not drawn.
  static const circleRouteSides = 12;

  /// A bend that replaces the straight stretch from [from] to [to].
  ///
  /// A circle is routed along the straight sides of a 12-sided polygon whose
  /// sides touch the red edge and whose corners stay outside it. The shorter
  /// way is used. That polygon is never drawn. A freeform polygon follows the
  /// shorter chain of its own corners between the entry and exit, so the path
  /// touches only the vertices it needs and does not trace the whole outline.
  /// The red circle drawn on the map stays round.
  List<LatLng> routeAround(
    LatLng from,
    LatLng to, {
    bool Function(LatLng point)? insideField,
  }) {
    final ring = _flightRing(this);
    if (ring == null) {
      return [from, to];
    }
    final hits = _ringHits(from, to, ring.center, ring.vertices);
    if (hits.length < 2) {
      return [from, to];
    }
    final entry = hits.first;
    final exit = hits.last;
    final start = _metersBetween(from, entry.point) <= 0.02 ? from : entry.point;
    final end = _metersBetween(to, exit.point) <= 0.02 ? to : exit.point;
    return _chooseDetour(
      [
        _walkRing(
          ring.center,
          ring.vertices,
          entry.edge,
          exit.edge,
          start,
          end,
          forward: true,
        ),
        _walkRing(
          ring.center,
          ring.vertices,
          entry.edge,
          exit.edge,
          start,
          end,
          forward: false,
        ),
      ],
      insideField,
      fallback: [from, to],
    );
  }

  /// Pieces of [start] → [end] that stay outside the flight ring. Endpoints
  /// are the exact crossings of that ring, so the pass meets the path outline
  /// with no gap and no extra stub.
  List<(LatLng, LatLng)> outsidePieces(LatLng start, LatLng end) {
    final ring = _flightRing(this);
    if (ring == null) {
      return _metersBetween(start, end) < 0.05 ? const [] : [(start, end)];
    }
    final cuts = _uniqueCuts([
      0.0,
      1.0,
      ..._ringCuts(start, end, ring.center, ring.vertices),
    ]);
    final kept = <(LatLng, LatLng)>[];
    for (var index = 0; index < cuts.length - 1; index++) {
      final fromT = cuts[index];
      final toT = cuts[index + 1];
      if (toT - fromT < 1e-5) {
        continue;
      }
      final middle = _lerp(start, end, (fromT + toT) / 2);
      if (_pointInRing(ring.vertices, _toXY(middle, ring.center))) {
        continue;
      }
      final pieceStart = _lerp(start, end, fromT);
      final pieceEnd = _lerp(start, end, toT);
      if (_metersBetween(pieceStart, pieceEnd) < 0.05) {
        continue;
      }
      kept.add((pieceStart, pieceEnd));
    }
    return kept;
  }
}

double _length(double x, double y) {
  return sqrt(x * x + y * y);
}

double _xySegmentDistance(_XY point, _XY start, _XY end) {
  return distanceToSegmentMeters(
    pointEast: point.x,
    pointNorth: point.y,
    startEast: start.x,
    startNorth: start.y,
    endEast: end.x,
    endNorth: end.y,
  );
}

class _XY {
  const _XY(this.x, this.y);

  final double x;
  final double y;
}

List<LatLng> _circleOutline(LatLng center, double radiusMeters) {
  const steps = 72;
  return [
    for (var index = 0; index < steps; index++)
      _fromXY(
        _XY(
          radiusMeters * cos(2 * pi * index / steps),
          radiusMeters * sin(2 * pi * index / steps),
        ),
        center,
      ),
  ];
}

List<LatLng> _chooseDetour(
  List<List<LatLng>> options,
  bool Function(LatLng point)? insideField, {
  required List<LatLng> fallback,
}) {
  List<LatLng>? shortestInside;
  var insideLength = double.infinity;
  List<LatLng>? shortest;
  var anyLength = double.infinity;
  for (final option in options) {
    if (option.length < 2) {
      continue;
    }
    final length = _polylineMeters(option);
    if (length < anyLength) {
      shortest = option;
      anyLength = length;
    }
    if (insideField != null && !option.every(insideField)) {
      continue;
    }
    if (length < insideLength) {
      shortestInside = option;
      insideLength = length;
    }
  }
  return shortestInside ?? shortest ?? fallback;
}

double _polylineMeters(List<LatLng> points) {
  var total = 0.0;
  for (var index = 1; index < points.length; index++) {
    total += _metersBetween(points[index - 1], points[index]);
  }
  return total;
}

/// Straight sides around a circle. Used only to build the flight route.

class _FlightRing {
  const _FlightRing(this.center, this.vertices);

  final LatLng center;
  final List<_XY> vertices;
}

_FlightRing? _flightRing(Obstacle obstacle) {
  if (obstacle.type == ObstacleType.circle &&
      obstacle.center != null &&
      obstacle.radiusMeters != null) {
    final zoneCenter = obstacle.center!;
    final step = 2 * pi / Obstacle.circleRouteSides;
    // Each side touches the red circle. Corners stay outside it, so the
    // straight side does not cross into the disk.
    final corner =
        (obstacle.radiusMeters! + Obstacle.circleBufferMeters) / cos(step / 2);
    return _FlightRing(zoneCenter, [
      for (var index = 0; index < Obstacle.circleRouteSides; index++)
        _XY(
          corner * cos(index * step),
          corner * sin(index * step),
        ),
    ]);
  }
  final polygon = _polygonLocal(obstacle);
  if (polygon == null) {
    return null;
  }
  return _FlightRing(polygon.origin, polygon.vertices);
}

class _PolygonLocal {
  const _PolygonLocal(this.origin, this.vertices);

  final LatLng origin;
  final List<_XY> vertices;
}

_PolygonLocal? _polygonLocal(Obstacle obstacle) {
  if (obstacle.type != ObstacleType.polygon || obstacle.vertices.length < 3) {
    return null;
  }
  final origin = obstacle.center ?? obstacle.vertices.first;
  return _PolygonLocal(origin, [
    for (final vertex in obstacle.vertices) _toXY(vertex, origin),
  ]);
}

bool _pointInRing(List<_XY> ring, _XY point) {
  var inside = false;
  for (var index = 0, previous = ring.length - 1; index < ring.length; previous = index++) {
    final start = ring[previous];
    final end = ring[index];
    final crosses = (start.y > point.y) != (end.y > point.y);
    if (!crosses) {
      continue;
    }
    final east = start.x +
        (point.y - start.y) / (end.y - start.y) * (end.x - start.x);
    if (point.x < east) {
      inside = !inside;
    }
  }
  return inside;
}

double _distanceToRing(_XY point, List<_XY> ring) {
  var nearest = double.infinity;
  for (var index = 0; index < ring.length; index++) {
    final distance = _xySegmentDistance(
      point,
      ring[index],
      ring[(index + 1) % ring.length],
    );
    if (distance < nearest) {
      nearest = distance;
    }
  }
  return nearest;
}

List<({double t, int edge, LatLng point})> _ringHits(
  LatLng from,
  LatLng to,
  LatLng center,
  List<_XY> vertices,
) {
  final origin = _toXY(from, center);
  final target = _toXY(to, center);
  final hits = <({double t, int edge, LatLng point})>[];
  for (var edge = 0; edge < vertices.length; edge++) {
    final hit = _edgeHit(
      origin,
      target,
      vertices[edge],
      vertices[(edge + 1) % vertices.length],
    );
    if (hit == null || hit < -1e-3 || hit > 1 + 1e-3) {
      continue;
    }
    hits.add((
      t: hit.clamp(0.0, 1.0),
      edge: edge,
      point: _lerp(from, to, hit.clamp(0.0, 1.0)),
    ));
  }
  hits.sort((a, b) {
    final byT = a.t.compareTo(b.t);
    return byT != 0 ? byT : a.edge.compareTo(b.edge);
  });
  final unique = <({double t, int edge, LatLng point})>[];
  for (final hit in hits) {
    if (unique.isNotEmpty && (hit.t - unique.last.t).abs() < 1e-4) {
      continue;
    }
    unique.add(hit);
  }
  return unique;
}

List<double> _ringCuts(
  LatLng start,
  LatLng end,
  LatLng center,
  List<_XY> vertices,
) {
  return [for (final hit in _ringHits(start, end, center, vertices)) hit.t];
}

List<LatLng> _walkRing(
  LatLng center,
  List<_XY> vertices,
  int entryEdge,
  int exitEdge,
  LatLng start,
  LatLng end, {
  required bool forward,
}) {
  final path = <LatLng>[start];
  void add(LatLng point) {
    if (_metersBetween(path.last, point) <= 0.02) {
      path[path.length - 1] = point;
      return;
    }
    path.add(point);
  }

  final count = vertices.length;
  if (entryEdge != exitEdge) {
    if (forward) {
      var vertex = (entryEdge + 1) % count;
      for (var guard = 0; guard < count; guard++) {
        add(_fromXY(vertices[vertex], center));
        if (vertex == exitEdge) {
          break;
        }
        vertex = (vertex + 1) % count;
      }
    } else {
      var vertex = entryEdge;
      for (var guard = 0; guard < count; guard++) {
        add(_fromXY(vertices[vertex], center));
        if (vertex == (exitEdge + 1) % count) {
          break;
        }
        vertex = (vertex - 1 + count) % count;
      }
    }
  }
  add(end);
  return path;
}

double? _edgeHit(_XY from, _XY to, _XY a, _XY b) {
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  final ex = b.x - a.x;
  final ey = b.y - a.y;
  final denom = dx * ey - dy * ex;
  if (denom.abs() < 1e-8) {
    return null;
  }
  final t = ((a.x - from.x) * ey - (a.y - from.y) * ex) / denom;
  final s = ((a.x - from.x) * dy - (a.y - from.y) * dx) / denom;
  if (s < -1e-4 || s > 1 + 1e-4) {
    return null;
  }
  return t;
}

List<double> _uniqueCuts(List<double> values) {
  final sorted = [...values]..sort();
  final unique = <double>[];
  for (final value in sorted) {
    if (unique.isEmpty || value - unique.last > 1e-5) {
      unique.add(value);
    }
  }
  return unique;
}

LatLng _lerp(LatLng start, LatLng end, double t) {
  final local = _toXY(end, start);
  return _fromXY(_XY(local.x * t, local.y * t), start);
}

double _metersBetween(LatLng start, LatLng end) {
  final local = _toXY(end, start);
  return _length(local.x, local.y);
}

_XY _toXY(LatLng point, LatLng origin) {
  final local = toLocalMeters(point, origin);
  return _XY(local.east, local.north);
}

LatLng _fromXY(_XY point, LatLng origin) {
  return fromLocalMeters(LocalMeters(point.x, point.y), origin);
}
