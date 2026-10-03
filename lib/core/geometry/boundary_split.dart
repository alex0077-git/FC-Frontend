import 'dart:math';

import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:latlong2/latlong.dart';

/// The two boundary positions that separate a field into Split A and Split B.
class SplitCut {
  const SplitCut(this.start, this.end);

  final LatLng start;
  final LatLng end;
}

/// The closest point on the boundary to [point], when the tap is near the edge.
LatLng? snapToBoundary(List<LatLng> boundary, LatLng point) {
  if (boundary.length < 3) {
    return null;
  }
  final origin = _centroid(boundary);
  final place = _project(
    _ring(boundary, origin),
    _toMeter(point, origin),
    maxDistance: 25,
  );
  if (place == null) {
    return null;
  }
  return _fromMeter(place.point, origin);
}

/// 0 when [point] lies only on Split A, 1 when it lies only on Split B.
///
/// The two chosen points belong to both sides, so this returns null for them.
int? exclusiveSplitSide(
  List<LatLng> boundary,
  List<SplitCut> cuts,
  LatLng point,
) {
  final sections = boundarySections(boundary, cuts);
  if (sections.length < 2) {
    return null;
  }
  final onA = _nearVertex(sections[0], point);
  final onB = _nearVertex(sections[1], point);
  if (onA == onB) {
    return null;
  }
  return onA ? 0 : 1;
}

/// The original boundary divided by [cuts]. With no cuts, the boundary is the
/// only section.
///
/// Each cut is two positions on the boundary. Split A follows the boundary one
/// way between them, and Split B follows the boundary the other way.
List<List<LatLng>> boundarySections(List<LatLng> boundary, List<SplitCut> cuts) {
  if (boundary.length < 3) {
    return const [];
  }

  final origin = _centroid(boundary);
  var pieces = [_ring(boundary, origin)];
  for (final cut in cuts) {
    final start = _toMeter(cut.start, origin);
    final end = _toMeter(cut.end, origin);
    pieces = [
      for (final piece in pieces) ..._splitPieceAt(piece, start, end),
    ];
  }
  return [
    for (final piece in pieces)
      [for (final point in piece) _fromMeter(point, origin)],
  ];
}

/// The same route with every stretch that would leave [polygon] replaced by
/// the shorter walk along the boundary. Touching the edge is allowed.
List<LatLng> pathInsideBoundary(List<LatLng> path, List<LatLng> polygon) {
  if (path.length < 2 || polygon.length < 3) {
    return List<LatLng>.of(path);
  }
  final origin = _centroid(polygon);
  final ring = _ring(polygon, origin);
  final kept = <_M>[];

  void add(_M point) {
    // A point that only barely clears the edge can fall just outside after it
    // is converted back to latitude and longitude. Sit those on the edge.
    final placed = _distanceToBoundary(ring, point) <= 0.3
        ? _nearestPlace(ring, point).point
        : point;
    if (kept.isEmpty || _distance(kept.last, placed) > 0.02) {
      kept.add(placed);
    }
  }

  _M? leftAt;

  void rejoin(_M entry) {
    final exit = leftAt;
    leftAt = null;
    if (exit == null) {
      add(entry);
      return;
    }
    final from = _nearestPlace(ring, exit);
    final to = _nearestPlace(ring, entry);
    for (final point in _shorterWalk(ring, from, to)) {
      add(point);
    }
    add(entry);
  }

  final first = _toMeter(path.first, origin);
  if (_inside(ring, first)) {
    add(first);
  } else {
    leftAt = first;
  }

  for (var index = 0; index < path.length - 1; index++) {
    final start = _toMeter(path[index], origin);
    final end = _toMeter(path[index + 1], origin);
    final marks = _insideCuts(ring, start, end);
    for (var span = 0; span < marks.length - 1; span++) {
      final fromT = marks[span];
      final toT = marks[span + 1];
      if (toT - fromT < 1e-6) {
        continue;
      }
      final mid = _lerpMeter(start, end, (fromT + toT) / 2);
      final spanStart = _lerpMeter(start, end, fromT);
      final spanEnd = _lerpMeter(start, end, toT);
      if (_inside(ring, mid)) {
        if (leftAt != null) {
          rejoin(spanStart);
        }
        add(spanEnd);
      } else {
        leftAt ??= spanStart;
      }
    }
  }

  if (kept.isEmpty && leftAt != null) {
    add(_nearestPlace(ring, leftAt!).point);
  }
  if (kept.length < 2) {
    return const [];
  }
  return [for (final point in kept) _fromMeter(point, origin)];
}

/// True when [point] is inside [polygon] or within a few centimetres of its edge.
bool boundaryContains(List<LatLng> polygon, LatLng point) {
  if (polygon.length < 3) {
    return false;
  }
  final origin = _centroid(polygon);
  return _inside(
    _ring(polygon, origin),
    _toMeter(point, origin),
  );
}

/// True when the whole line sits on the border between the two chosen points.
bool lineRunsAlongCut(
  LatLng start,
  LatLng end,
  List<LatLng> boundary,
  List<SplitCut> cuts,
) {
  if (cuts.isEmpty || boundary.length < 3) {
    return false;
  }
  final origin = _centroid(boundary);
  final from = _toMeter(start, origin);
  final to = _toMeter(end, origin);
  for (final cut in cuts) {
    final cutStart = _toMeter(cut.start, origin);
    final cutEnd = _toMeter(cut.end, origin);
    if (_distance(cutStart, cutEnd) < 0.3) {
      continue;
    }
    if (_distanceToSegment(from, cutStart, cutEnd) <= 0.35 &&
        _distanceToSegment(to, cutStart, cutEnd) <= 0.35) {
      return true;
    }
  }
  return false;
}

bool _nearVertex(List<LatLng> chain, LatLng point) {
  if (chain.isEmpty) {
    return false;
  }
  final origin = _centroid(chain);
  final target = _toMeter(point, origin);
  for (final vertex in _ring(chain, origin)) {
    if (_distance(vertex, target) <= 0.75) {
      return true;
    }
  }
  return false;
}

List<List<_M>> _splitPieceAt(List<_M> piece, _M start, _M end) {
  final from = _project(piece, start, maxDistance: 1.5);
  final to = _project(piece, end, maxDistance: 1.5);
  if (from == null || to == null || _distance(from.point, to.point) < 0.3) {
    return [piece];
  }
  if (!_chordInside(piece, from.point, to.point)) {
    return [piece];
  }
  final sideA = _clean(_forward(piece, from, to));
  final sideB = _clean(_forward(piece, to, from));
  if (sideA.length < 3 || sideB.length < 3) {
    return [piece];
  }
  if (_area(sideA) < 0.5 || _area(sideB) < 0.5) {
    return [piece];
  }
  return [sideA, sideB];
}

bool _chordInside(List<_M> piece, _M start, _M end) {
  final middle = _M((start.x + end.x) / 2, (start.y + end.y) / 2);
  if (!_inside(piece, middle)) {
    return false;
  }
  return _hits(piece, start, end).length == 2;
}

_Place? _project(List<_M> ring, _M target, {required double maxDistance}) {
  _Place? best;
  var bestDistance = maxDistance;
  for (var index = 0; index < ring.length; index++) {
    final start = ring[index];
    final end = ring[(index + 1) % ring.length];
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared <= 1e-12) {
      continue;
    }
    final t = (((target.x - start.x) * dx + (target.y - start.y) * dy) /
            lengthSquared)
        .clamp(0.0, 1.0);
    final point = _M(start.x + t * dx, start.y + t * dy);
    final distance = _distance(point, target);
    if (distance < bestDistance) {
      bestDistance = distance;
      best = _Place(point, index, t);
    }
  }
  return best;
}

/// Parameters along [start] → [end] where the segment crosses the boundary.
///
/// A pass that stays inside is returned immediately. Exact edge hits are kept,
/// and a coarse probe fills in a crossing the edge test misses, such as a
/// pass through a corner.
List<double> _insideCuts(List<_M> ring, _M start, _M end) {
  final marks = <double>[0, 1];
  for (final hit in _hits(ring, start, end)) {
    final t = hit.cutT.clamp(0.0, 1.0);
    if (t > 1e-4 && t < 1 - 1e-4) {
      marks.add(t);
    }
  }
  final startInside = _inside(ring, start);
  final endInside = _inside(ring, end);
  final length = _distance(start, end);
  final staysInside = marks.length == 2 &&
      startInside &&
      endInside &&
      _inside(ring, _lerpMeter(start, end, 0.5)) &&
      (length <= 8 || _samplesStayInside(ring, start, end, length));
  if (!staysInside) {
    _probeStateChanges(ring, start, end, marks);
  }
  marks.sort();
  final unique = <double>[marks.first];
  for (final mark in marks.skip(1)) {
    if (mark - unique.last > 1e-5) {
      unique.add(mark);
    }
  }
  if (unique.last < 1) {
    unique.add(1);
  }
  return unique;
}

bool _samplesStayInside(List<_M> ring, _M start, _M end, double length) {
  final steps = max(2, (length / 8).ceil());
  for (var step = 1; step < steps; step++) {
    if (!_inside(ring, _lerpMeter(start, end, step / steps))) {
      return false;
    }
  }
  return true;
}

void _probeStateChanges(List<_M> ring, _M start, _M end, List<double> marks) {
  final length = _distance(start, end);
  final steps = max(1, (length / 4).ceil());
  var previousInside = _inside(ring, start);
  for (var step = 1; step <= steps; step++) {
    final t = step / steps;
    final inside = _inside(ring, _lerpMeter(start, end, t));
    if (inside == previousInside) {
      continue;
    }
    var low = (step - 1) / steps;
    var high = t;
    for (var refine = 0; refine < 12; refine++) {
      final mid = (low + high) / 2;
      if (_inside(ring, _lerpMeter(start, end, mid)) == previousInside) {
        low = mid;
      } else {
        high = mid;
      }
    }
    marks.add((low + high) / 2);
    previousInside = inside;
  }
}

_M _lerpMeter(_M start, _M end, double t) {
  return _M(start.x + (end.x - start.x) * t, start.y + (end.y - start.y) * t);
}

_Place _nearestPlace(List<_M> ring, _M target) {
  return _project(ring, target, maxDistance: double.infinity)!;
}

List<_M> _shorterWalk(List<_M> ring, _Place from, _Place to) {
  final forward = _forward(ring, from, to);
  final backward = _forward(ring, to, from).reversed.toList();
  if (forward.isEmpty) {
    return backward;
  }
  if (backward.isEmpty) {
    return forward;
  }
  return _chainLength(forward) <= _chainLength(backward) ? forward : backward;
}

double _chainLength(List<_M> points) {
  var total = 0.0;
  for (var index = 1; index < points.length; index++) {
    total += _distance(points[index - 1], points[index]);
  }
  return total;
}

List<_M> _forward(List<_M> ring, _Place from, _Place to) {
  if (_distance(from.point, to.point) <= 0.05) {
    return [from.point];
  }
  if (from.edge == to.edge && to.t >= from.t - 1e-9) {
    return [from.point, to.point];
  }

  final path = <_M>[from.point];
  var edge = from.edge;
  for (var guard = 0; guard <= ring.length; guard++) {
    if (guard > 0 && edge == to.edge) {
      path.add(to.point);
      return path;
    }
    path.add(ring[(edge + 1) % ring.length]);
    edge = (edge + 1) % ring.length;
  }
  return const [];
}

List<_Hit> _hits(List<_M> polygon, _M start, _M end) {
  final hits = <_Hit>[];
  for (var index = 0; index < polygon.length; index++) {
    final hit = _edgeHit(
      start,
      end,
      polygon[index],
      polygon[(index + 1) % polygon.length],
      index,
    );
    if (hit != null) {
      hits.add(hit);
    }
  }
  if (hits.isEmpty) {
    return hits;
  }
  hits.sort((a, b) => a.cutT.compareTo(b.cutT));
  final unique = <_Hit>[hits.first];
  for (final hit in hits.skip(1)) {
    if (_distance(hit.point, unique.last.point) > 0.05) {
      unique.add(hit);
    }
  }
  return unique;
}

_Hit? _edgeHit(_M start, _M end, _M edgeStart, _M edgeEnd, int edge) {
  final rx = end.x - start.x;
  final ry = end.y - start.y;
  final sx = edgeEnd.x - edgeStart.x;
  final sy = edgeEnd.y - edgeStart.y;
  final den = rx * sy - ry * sx;
  if (den.abs() <= 1e-9) {
    return null;
  }

  final qpx = edgeStart.x - start.x;
  final qpy = edgeStart.y - start.y;
  final cutT = (qpx * sy - qpy * sx) / den;
  final edgeT = (qpx * ry - qpy * rx) / den;
  const epsilon = 1e-8;
  // The edge includes its start and excludes its end, so a corner shared by
  // two edges is counted once. That keeps a split that starts on any boundary
  // point, including the last one.
  if (cutT < -epsilon ||
      cutT > 1 + epsilon ||
      edgeT < -epsilon ||
      edgeT >= 1 - epsilon) {
    return null;
  }

  final clampedCut = cutT.clamp(0.0, 1.0);
  return _Hit(
    _M(start.x + rx * clampedCut, start.y + ry * clampedCut),
    edge,
    clampedCut,
  );
}

List<_M> _clean(List<_M> points) {
  final cleaned = <_M>[];
  for (final point in points) {
    if (cleaned.isEmpty || _distance(cleaned.last, point) > 0.05) {
      cleaned.add(point);
    }
  }
  if (cleaned.length > 1 && _distance(cleaned.first, cleaned.last) <= 0.05) {
    cleaned.removeLast();
  }
  return cleaned;
}

double _area(List<_M> polygon) {
  var sum = 0.0;
  for (var index = 0; index < polygon.length; index++) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    sum += start.x * end.y - end.x * start.y;
  }
  return sum.abs() / 2;
}

bool _inside(List<_M> polygon, _M point) {
  if (_distanceToBoundary(polygon, point) <= 0.05) {
    return true;
  }

  var inside = false;
  for (var index = 0; index < polygon.length; index++) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    final crosses = (start.y > point.y) != (end.y > point.y);
    if (!crosses) {
      continue;
    }
    final x = start.x +
        (end.x - start.x) * (point.y - start.y) / (end.y - start.y);
    if (point.x < x) {
      inside = !inside;
    }
  }
  return inside;
}

double _distanceToBoundary(List<_M> polygon, _M point) {
  var nearest = double.infinity;
  for (var index = 0; index < polygon.length; index++) {
    nearest = min(
      nearest,
      _distanceToSegment(
        point,
        polygon[index],
        polygon[(index + 1) % polygon.length],
      ),
    );
  }
  return nearest;
}

double _distanceToSegment(_M point, _M start, _M end) {
  return distanceToSegmentMeters(
    pointEast: point.x,
    pointNorth: point.y,
    startEast: start.x,
    startNorth: start.y,
    endEast: end.x,
    endNorth: end.y,
  );
}

double _distance(_M a, _M b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return sqrt(dx * dx + dy * dy);
}

List<_M> _ring(List<LatLng> points, LatLng origin) {
  return [for (final point in points) _toMeter(point, origin)];
}

LatLng _centroid(List<LatLng> points) {
  var latitude = 0.0;
  var longitude = 0.0;
  for (final point in points) {
    latitude += point.latitude;
    longitude += point.longitude;
  }
  return LatLng(latitude / points.length, longitude / points.length);
}

_M _toMeter(LatLng point, LatLng origin) {
  final local = toLocalMeters(point, origin);
  return _M(local.east, local.north);
}

LatLng _fromMeter(_M point, LatLng origin) {
  return fromLocalMeters(LocalMeters(point.x, point.y), origin);
}

class _Place {
  const _Place(this.point, this.edge, this.t);

  final _M point;
  final int edge;
  final double t;
}

class _Hit {
  const _Hit(this.point, this.edge, this.cutT);

  final _M point;
  final int edge;
  final double cutT;
}

class _M {
  const _M(this.x, this.y);

  final double x;
  final double y;
}
