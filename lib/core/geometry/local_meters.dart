import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Meters in one degree of latitude. Longitude is scaled by [longitudeMetersPerDegree].
const metersPerDegree = 111320.0;

/// East/north meters of [point] measured from [origin].
class LocalMeters {
  const LocalMeters(this.east, this.north);

  final double east;
  final double north;
}

double longitudeMetersPerDegree(double latitude) {
  final scale = cos(latitude * pi / 180).abs();
  return metersPerDegree * (scale < 1e-6 ? 1e-6 : scale);
}

LocalMeters toLocalMeters(LatLng point, LatLng origin) {
  return LocalMeters(
    (point.longitude - origin.longitude) * longitudeMetersPerDegree(origin.latitude),
    (point.latitude - origin.latitude) * metersPerDegree,
  );
}

LatLng fromLocalMeters(LocalMeters point, LatLng origin) {
  return LatLng(
    origin.latitude + point.north / metersPerDegree,
    origin.longitude + point.east / longitudeMetersPerDegree(origin.latitude),
  );
}

LatLng shiftByMeters(LatLng origin, double eastMeters, double northMeters) {
  return fromLocalMeters(LocalMeters(eastMeters, northMeters), origin);
}

(double, double) offsetMeters(LatLng origin, LatLng current) {
  final local = toLocalMeters(current, origin);
  return (local.east, local.north);
}

bool sameLatLng(LatLng a, LatLng b) {
  return (a.latitude - b.latitude).abs() <= 1e-9 &&
      (a.longitude - b.longitude).abs() <= 1e-9;
}

/// Shortest distance, in meters, from a point to a straight segment.
double distanceToSegmentMeters({
  required double pointEast,
  required double pointNorth,
  required double startEast,
  required double startNorth,
  required double endEast,
  required double endNorth,
}) {
  final dx = endEast - startEast;
  final dy = endNorth - startNorth;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared <= 1e-12) {
    final east = pointEast - startEast;
    final north = pointNorth - startNorth;
    return sqrt(east * east + north * north);
  }
  final t = (((pointEast - startEast) * dx + (pointNorth - startNorth) * dy) /
          lengthSquared)
      .clamp(0.0, 1.0);
  final east = pointEast - (startEast + t * dx);
  final north = pointNorth - (startNorth + t * dy);
  return sqrt(east * east + north * north);
}
