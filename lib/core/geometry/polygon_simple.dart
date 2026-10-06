import 'dart:math';

import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:latlong2/latlong.dart';

const boundaryCrossesMessage =
    'This point would cross an existing boundary line -- try a different spot';

const obstacleCrossesMessage =
    'This point would cross an existing obstacle line -- try a different spot';

const closedShapeCrossesMessage =
    'This shape crosses itself -- move a corner before keeping it';

/// True when [points], in order, never cross themselves.
///
/// Only edges that do not share a corner are compared. [closed] also checks
/// the edge from the last point back to the first.
bool polygonIsSimple(List<LatLng> points, {required bool closed}) {
  final count = points.length;
  final edgeCount = closed ? count : count - 1;
  if (count < 4 || edgeCount < 3) {
    return true;
  }

  final origin = points.first;
  final meters = [
    for (final point in points) toLocalMeters(point, origin),
  ];
  for (var first = 0; first < edgeCount; first++) {
    for (var second = first + 1; second < edgeCount; second++) {
      if (_sharesCorner(first, second, edgeCount, closed)) {
        continue;
      }
      if (_segmentsCross(
        meters[first],
        meters[(first + 1) % count],
        meters[second],
        meters[(second + 1) % count],
      )) {
        return false;
      }
    }
  }
  return true;
}

bool _sharesCorner(int first, int second, int edgeCount, bool closed) {
  if (second == first + 1) {
    return true;
  }
  return closed && first == 0 && second == edgeCount - 1;
}

/// True when the two segments meet, including an endpoint lying on the other
/// segment or two collinear segments that overlap.
bool _segmentsCross(
  LocalMeters a,
  LocalMeters b,
  LocalMeters c,
  LocalMeters d,
) {
  final abTowardC = _turn(a, b, c);
  final abTowardD = _turn(a, b, d);
  final cdTowardA = _turn(c, d, a);
  final cdTowardB = _turn(c, d, b);
  final crossesAb = abTowardC != 0 && abTowardD != 0 && abTowardC != abTowardD;
  final crossesCd = cdTowardA != 0 && cdTowardB != 0 && cdTowardA != cdTowardB;
  if (crossesAb && crossesCd) {
    return true;
  }
  if (abTowardC == 0 && _onSegment(a, b, c)) {
    return true;
  }
  if (abTowardD == 0 && _onSegment(a, b, d)) {
    return true;
  }
  if (cdTowardA == 0 && _onSegment(c, d, a)) {
    return true;
  }
  if (cdTowardB == 0 && _onSegment(c, d, b)) {
    return true;
  }
  return false;
}

/// 1 when [point] is left of [start] to [end], -1 when it is right, 0 on the line.
int _turn(LocalMeters start, LocalMeters end, LocalMeters point) {
  final cross = (end.east - start.east) * (point.north - start.north) -
      (end.north - start.north) * (point.east - start.east);
  if (cross.abs() <= 1e-4) {
    return 0;
  }
  return cross > 0 ? 1 : -1;
}

bool _onSegment(LocalMeters start, LocalMeters end, LocalMeters point) {
  const slack = 1e-6;
  return point.east <= max(start.east, end.east) + slack &&
      point.east >= min(start.east, end.east) - slack &&
      point.north <= max(start.north, end.north) + slack &&
      point.north >= min(start.north, end.north) - slack;
}
