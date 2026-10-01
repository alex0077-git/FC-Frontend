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

  /// Pieces of [start] → [end] that stay outside this zone. The same rule
  /// applies to a circle and a square: a midpoint [contains] reports as inside
  /// is dropped, and the parts on either side are kept.
  List<(LatLng, LatLng)> outsidePieces(LatLng start, LatLng end) {
    final cuts = _uniqueCuts([0.0, 1.0, ..._boundaryCuts(start, end)]);
    final kept = <(LatLng, LatLng)>[];
    for (var index = 0; index < cuts.length - 1; index++) {
      final fromT = cuts[index];
      final toT = cuts[index + 1];
      if (toT - fromT < 1e-5) {
        continue;
      }
      final length = _metersBetween(start, end);
      final pad = length < 1e-6 ? 0.0 : 0.25 / length;
      var safeFrom = fromT;
      var safeTo = toT;
      if (contains(_lerp(start, end, fromT))) {
        safeFrom = min(fromT + pad, (fromT + toT) / 2);
      }
      if (contains(_lerp(start, end, toT))) {
        safeTo = max(toT - pad, (fromT + toT) / 2);
      }
      if (safeTo - safeFrom < 1e-5) {
        continue;
      }
      final middle = _lerp(start, end, (safeFrom + safeTo) / 2);
      if (contains(middle)) {
        continue;
      }
      final pieceStart = _lerp(start, end, safeFrom);
      final pieceEnd = _lerp(start, end, safeTo);
      if (_metersBetween(pieceStart, pieceEnd) < 0.05) {
        continue;
      }
      kept.add((pieceStart, pieceEnd));
    }
    return kept;
  }

  List<double> _boundaryCuts(LatLng start, LatLng end) {
    final zoneCenter = center;
    if (zoneCenter == null) {
      return const [];
    }
    if (type == ObstacleType.circle && radiusMeters != null) {
      return _circleCuts(start, end, zoneCenter, radiusMeters!);
    }
    if (type == ObstacleType.square && sideMeters != null) {
      return _squareCuts(start, end, zoneCenter, sideMeters! / 2);
    }
    return const [];
  }
}

double _length(double x, double y) {
  return sqrt(x * x + y * y);
}

const _metersPerDegree = 111320.0;

class _XY {
  const _XY(this.x, this.y);

  final double x;
  final double y;
}

List<LatLng> _circleOutline(LatLng center, double radiusMeters) {
  const steps = 64;
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

List<double> _circleCuts(LatLng start, LatLng end, LatLng center, double radius) {
  final from = _toXY(start, center);
  final to = _toXY(end, center);
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  final a = dx * dx + dy * dy;
  if (a < 1e-8) {
    return const [];
  }
  final b = 2 * (from.x * dx + from.y * dy);
  final c = from.x * from.x + from.y * from.y - radius * radius;
  final discriminant = b * b - 4 * a * c;
  if (discriminant < 0) {
    return const [];
  }
  final root = sqrt(discriminant);
  return [
    for (final t in [(-b - root) / (2 * a), (-b + root) / (2 * a)])
      if (t >= -1e-6 && t <= 1 + 1e-6) t.clamp(0.0, 1.0),
  ];
}

List<double> _squareCuts(LatLng start, LatLng end, LatLng center, double half) {
  final from = _toXY(start, center);
  final to = _toXY(end, center);
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  final cuts = <double>[];
  if (dx.abs() > 1e-9) {
    for (final edge in [-half, half]) {
      final t = (edge - from.x) / dx;
      final y = from.y + t * dy;
      if (t >= -1e-6 && t <= 1 + 1e-6 && y >= -half - 1e-4 && y <= half + 1e-4) {
        cuts.add(t.clamp(0.0, 1.0));
      }
    }
  }
  if (dy.abs() > 1e-9) {
    for (final edge in [-half, half]) {
      final t = (edge - from.y) / dy;
      final x = from.x + t * dx;
      if (t >= -1e-6 && t <= 1 + 1e-6 && x >= -half - 1e-4 && x <= half + 1e-4) {
        cuts.add(t.clamp(0.0, 1.0));
      }
    }
  }
  return cuts;
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
