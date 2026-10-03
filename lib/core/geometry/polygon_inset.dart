import 'dart:math';

import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:latlong2/latlong.dart';

/// Moves every edge of [ring] inward by [marginMeters] and joins the corners.
///
/// The ring the user drew is not changed. This is only the smaller polygon
/// coverage is allowed to plan inside. An empty list means the margin is
/// larger than the field, so there is no room left to spray.
List<LatLng> insetPolygon(List<LatLng> ring, double marginMeters) {
  if (ring.length < 3 || !marginMeters.isFinite || marginMeters <= 0) {
    return ring;
  }

  final origin = _centroid(ring);
  final local = _clean([
    for (final point in ring) toLocalMeters(point, origin),
  ]);
  if (local.length < 3) {
    return const [];
  }

  final inset = _inset(local, marginMeters);
  if (inset.length < 3) {
    return const [];
  }
  return [
    for (final point in inset) fromLocalMeters(point, origin),
  ];
}

LatLng _centroid(List<LatLng> ring) {
  var latitude = 0.0;
  var longitude = 0.0;
  for (final point in ring) {
    latitude += point.latitude;
    longitude += point.longitude;
  }
  return LatLng(latitude / ring.length, longitude / ring.length);
}

List<LocalMeters> _clean(List<LocalMeters> points) {
  final cleaned = <LocalMeters>[];
  for (final point in points) {
    if (cleaned.isEmpty || _gap(cleaned.last, point) > 0.05) {
      cleaned.add(point);
    }
  }
  if (cleaned.length >= 2 && _gap(cleaned.first, cleaned.last) <= 0.05) {
    cleaned.removeLast();
  }
  return cleaned;
}

double _gap(LocalMeters a, LocalMeters b) {
  final east = a.east - b.east;
  final north = a.north - b.north;
  return sqrt(east * east + north * north);
}

List<LocalMeters> _inset(List<LocalMeters> polygon, double margin) {
  final area = _signedArea(polygon);
  if (area.abs() < 1) {
    return const [];
  }
  final counterClockwise = area > 0;
  final edges = <_OffsetEdge>[];
  for (var index = 0; index < polygon.length; index++) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    final east = end.east - start.east;
    final north = end.north - start.north;
    final length = sqrt(east * east + north * north);
    if (length < 1e-6) {
      continue;
    }
    final inwardEast = (counterClockwise ? -north : north) / length;
    final inwardNorth = (counterClockwise ? east : -east) / length;
    edges.add(
      _OffsetEdge(
        LocalMeters(
          start.east + inwardEast * margin,
          start.north + inwardNorth * margin,
        ),
        LocalMeters(
          end.east + inwardEast * margin,
          end.north + inwardNorth * margin,
        ),
      ),
    );
  }
  if (edges.length < 3) {
    return const [];
  }

  final corners = <LocalMeters>[];
  for (var index = 0; index < edges.length; index++) {
    final previous = edges[(index - 1 + edges.length) % edges.length];
    final current = edges[index];
    final joined = _join(previous, current);
    if (joined == null) {
      return const [];
    }
    corners.add(joined);
  }

  final cleaned = _clean(corners);
  if (cleaned.length < 3) {
    return const [];
  }
  final insetArea = _signedArea(cleaned);
  if (insetArea.abs() < 1 || insetArea.sign != area.sign) {
    return const [];
  }
  for (final corner in cleaned) {
    if (!_insideOrOn(polygon, corner)) {
      return const [];
    }
  }
  return cleaned;
}

LocalMeters? _join(_OffsetEdge previous, _OffsetEdge current) {
  return _intersect(previous, current) ?? previous.end;
}

LocalMeters? _intersect(_OffsetEdge a, _OffsetEdge b) {
  final aEast = a.end.east - a.start.east;
  final aNorth = a.end.north - a.start.north;
  final bEast = b.end.east - b.start.east;
  final bNorth = b.end.north - b.start.north;
  final denom = aEast * bNorth - aNorth * bEast;
  if (denom.abs() < 1e-8) {
    return null;
  }
  final t = ((b.start.east - a.start.east) * bNorth -
          (b.start.north - a.start.north) * bEast) /
      denom;
  return LocalMeters(a.start.east + t * aEast, a.start.north + t * aNorth);
}

double _signedArea(List<LocalMeters> polygon) {
  var sum = 0.0;
  for (var index = 0; index < polygon.length; index++) {
    final a = polygon[index];
    final b = polygon[(index + 1) % polygon.length];
    sum += a.east * b.north - b.east * a.north;
  }
  return sum / 2;
}

bool _insideOrOn(List<LocalMeters> polygon, LocalMeters point) {
  if (_rayContains(polygon, point)) {
    return true;
  }
  for (var index = 0; index < polygon.length; index++) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    final distance = distanceToSegmentMeters(
      pointEast: point.east,
      pointNorth: point.north,
      startEast: start.east,
      startNorth: start.north,
      endEast: end.east,
      endNorth: end.north,
    );
    if (distance <= 0.05) {
      return true;
    }
  }
  return false;
}

bool _rayContains(List<LocalMeters> polygon, LocalMeters point) {
  var inside = false;
  for (var index = 0, previous = polygon.length - 1;
      index < polygon.length;
      previous = index++) {
    final start = polygon[previous];
    final end = polygon[index];
    final crosses = (start.north > point.north) != (end.north > point.north);
    if (!crosses || (end.north - start.north).abs() < 1e-12) {
      continue;
    }
    final east = start.east +
        (point.north - start.north) *
            (end.east - start.east) /
            (end.north - start.north);
    if (point.east < east) {
      inside = !inside;
    }
  }
  return inside;
}

class _OffsetEdge {
  const _OffsetEdge(this.start, this.end);

  final LocalMeters start;
  final LocalMeters end;
}
