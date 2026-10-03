import 'dart:math';

import 'package:latlong2/latlong.dart';

enum ObstacleType { circle, square }

/// A no-fly zone. Both shapes are exclusion zones: coverage keeps the ground
/// outside the shape and drops anything [contains] reports as inside.
///
/// A future `bufferMeters` field can grow that blocked area without changing
/// callers. [contains] is the only place that decision needs to live: a circle
/// would test `radiusMeters + bufferMeters`, and a square would test
/// `sideMeters / 2 + bufferMeters`.
class Obstacle {
  const Obstacle({
    required this.id,
    required this.type,
    this.center,
    this.radiusMeters,
    this.sideMeters,
    this.finalized = true,
  });

  final String id;
  final ObstacleType type;
  final LatLng? center;
  final double? radiusMeters;
  final double? sideMeters;

  /// Saved squares keep their side length. A new square stays editable until
  /// the user presses Save.
  final bool finalized;

  static const defaultRadiusMeters = 10.0;
  static const defaultSideMeters = 10.0;
  static const minSizeMeters = 1.0;
  static const maxSizeMeters = 500.0;

  LatLng get labelPoint => center ?? const LatLng(0, 0);

  /// Ring used to paint the zone. A circle is drawn as many sides so the red
  /// edge matches the meter check in [contains]. A square is axis-aligned
  /// on the ground (east-north), not on the screen.
  List<LatLng> get outline {
    final zoneCenter = center;
    if (zoneCenter == null) {
      return const [];
    }
    if (type == ObstacleType.circle && radiusMeters != null) {
      return _circleOutline(zoneCenter, radiusMeters!);
    }
    if (type == ObstacleType.square && sideMeters != null) {
      return _squareOutline(zoneCenter, sideMeters!);
    }
    return const [];
  }

  /// True when [point] is inside this zone or on its border.
  /// Circle: distance from the center is at most the radius.
  /// Square: the point is within half the side length on both axes.
  bool contains(LatLng point) {
    final zoneCenter = center;
    if (zoneCenter == null) {
      return false;
    }
    final local = _toXY(point, zoneCenter);
    if (type == ObstacleType.circle) {
      final radius = radiusMeters;
      if (radius == null) {
        return false;
      }
      return _length(local.x, local.y) <= radius;
    }
    final side = sideMeters;
    if (side == null) {
      return false;
    }
    final half = side / 2;
    return local.x.abs() <= half && local.y.abs() <= half;
  }

  /// True when [point] is inside the painted zone, not merely touching its edge.
  /// The flight path may sit on the red boundary. It must not cross into this.
  bool enters(LatLng point) {
    final zoneCenter = center;
    if (zoneCenter == null) {
      return false;
    }
    final local = _toXY(point, zoneCenter);
    if (type == ObstacleType.circle) {
      final radius = radiusMeters;
      if (radius == null) {
        return false;
      }
      return _length(local.x, local.y) < radius - borderTouchMeters;
    }
    final side = sideMeters;
    if (side == null) {
      return false;
    }
    final half = side / 2 - borderTouchMeters;
    return local.x.abs() < half && local.y.abs() < half;
  }

  /// How close a path point may come to the painted edge and still count as
  /// touching it, rather than flying through the zone.
  static const borderTouchMeters = 0.02;

  /// Kept so a square route can sit on the painted edge. The drawn square
  /// does not grow by this amount.
  static const avoidanceMarginMeters = 0.0;

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
  /// way is used. That polygon is never drawn. A square follows its own sides.
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

  /// Corners of the flight outline. A circle has eight, with one pointing north.
  /// A square has its own four corners.
  List<LatLng> get routeCorners {
    final ring = _flightRing(this);
    if (ring == null) {
      return const [];
    }
    return [
      for (final vertex in ring.vertices) _fromXY(vertex, ring.center),
    ];
  }

  /// The whole flight outline, starting and ending at [entry], so the pass
  /// that meets the obstacle draws every side once.
  List<LatLng> routeLoop(LatLng entry) {
    final ring = _flightRing(this);
    if (ring == null || ring.vertices.length < 3) {
      return const [];
    }
    final local = _toXY(entry, ring.center);
    var edge = 0;
    var nearest = double.infinity;
    for (var index = 0; index < ring.vertices.length; index++) {
      final distance = _xySegmentDistance(
        local,
        ring.vertices[index],
        ring.vertices[(index + 1) % ring.vertices.length],
      );
      if (distance < nearest) {
        nearest = distance;
        edge = index;
      }
    }
    final count = ring.vertices.length;
    final loop = <LatLng>[entry];
    var vertex = (edge + 1) % count;
    for (var guard = 0; guard < count; guard++) {
      final point = _fromXY(ring.vertices[vertex], ring.center);
      if (_metersBetween(loop.last, point) > 0.02) {
        loop.add(point);
      }
      vertex = (vertex + 1) % count;
      if (vertex == (edge + 1) % count) {
        break;
      }
    }
    if (_metersBetween(loop.last, entry) > 0.02) {
      loop.add(entry);
    }
    return loop;
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
      if (_insideConvex(ring.vertices, _toXY(middle, ring.center))) {
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
  final dx = end.x - start.x;
  final dy = end.y - start.y;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared < 1e-8) {
    return _length(point.x - start.x, point.y - start.y);
  }
  final t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared;
  final clamped = t.clamp(0.0, 1.0);
  return _length(
    point.x - (start.x + clamped * dx),
    point.y - (start.y + clamped * dy),
  );
}

const _metersPerDegree = 111320.0;

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

List<LatLng> _squareOutline(LatLng center, double sideMeters) {
  final half = sideMeters / 2;
  return [
    _fromXY(_XY(-half, -half), center),
    _fromXY(_XY(half, -half), center),
    _fromXY(_XY(half, half), center),
    _fromXY(_XY(-half, half), center),
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
  final zoneCenter = obstacle.center;
  if (zoneCenter == null) {
    return null;
  }
  if (obstacle.type == ObstacleType.circle && obstacle.radiusMeters != null) {
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
  if (obstacle.type == ObstacleType.square && obstacle.sideMeters != null) {
    final half = obstacle.sideMeters! / 2 + Obstacle.avoidanceMarginMeters;
    return _FlightRing(zoneCenter, [
      _XY(-half, -half),
      _XY(half, -half),
      _XY(half, half),
      _XY(-half, half),
    ]);
  }
  return null;
}

bool _insideConvex(List<_XY> ring, _XY point) {
  for (var index = 0; index < ring.length; index++) {
    final start = ring[index];
    final end = ring[(index + 1) % ring.length];
    final cross = (end.x - start.x) * (point.y - start.y) -
        (end.y - start.y) * (point.x - start.x);
    if (cross < -0.02) {
      return false;
    }
  }
  return true;
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
  final scale = _metersPerDegree * cos(origin.latitude * pi / 180);
  return _XY(
    (point.longitude - origin.longitude) * scale,
    (point.latitude - origin.latitude) * _metersPerDegree,
  );
}

LatLng _fromXY(_XY point, LatLng origin) {
  final scale = _metersPerDegree * cos(origin.latitude * pi / 180);
  return LatLng(
    origin.latitude + point.y / _metersPerDegree,
    origin.longitude + point.x / scale,
  );
}
