import 'dart:math';

import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:latlong2/latlong.dart';

/// Angle, in the same degrees the orientation joystick uses, of the longest
/// boundary edge. Coverage lines at this angle run parallel to that edge.
double longestEdgeOrientationDegrees(List<LatLng> ring) {
  if (ring.length < 2) {
    return 0;
  }
  final origin = _centroid(ring);
  var bestLength = -1.0;
  var bestDegrees = 0.0;
  for (var index = 0; index < ring.length; index++) {
    final start = toLocalMeters(ring[index], origin);
    final end = toLocalMeters(ring[(index + 1) % ring.length], origin);
    final east = end.east - start.east;
    final north = end.north - start.north;
    final length = sqrt(east * east + north * north);
    if (length <= bestLength) {
      continue;
    }
    bestLength = length;
    bestDegrees = _orientationDegrees(east, north);
  }
  return bestDegrees;
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

/// Sweep direction for orientation θ is (cos θ, −sin θ) in east/north meters.
/// Folding into 0–180 keeps an edge and its reverse on the same setting.
double _orientationDegrees(double east, double north) {
  var degrees = atan2(-north, east) * 180 / pi;
  degrees = (degrees % 360 + 360) % 360;
  if (degrees >= 180) {
    degrees -= 180;
  }
  return degrees;
}
