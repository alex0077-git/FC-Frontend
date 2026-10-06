import 'dart:math';

import 'package:fc_frontend/core/geometry/area_math.dart';
import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final origin = const LatLng(12.97, 77.59);
  LatLng at(double east, double north) => shiftByMeters(origin, east, north);

  final square = [at(0, 0), at(100, 0), at(100, 100), at(0, 100)];

  test('a 100 m square is 1.00 ha', () {
    final area = measureFieldArea(boundary: square, obstacles: const []);
    expect(area.isValid, isTrue);
    expect(area.fieldSquareMeters, closeTo(10000, _slack(10000)));
    expect(area.netSquareMeters, closeTo(10000, _slack(10000)));
    expect(areaInUnit(area.fieldSquareMeters!, AreaUnit.hectare), closeTo(1, 0.01));
  });

  test('a circle fully inside the square reduces the net by its disk area', () {
    final area = measureFieldArea(
      boundary: square,
      obstacles: [
        AreaSubject.circle(center: at(50, 50), radiusMeters: 10),
      ],
    );
    final circle = area.obstacles.single;
    expect(circle.squareMeters, closeTo(314.159, _slack(314.159)));
    expect(circle.outsideField, isFalse);
    expect(areaInUnit(circle.squareMeters, AreaUnit.hectare), closeTo(0.0314, 0.0001));
    expect(area.netSquareMeters, closeTo(9685.841, _slack(9685.841)));
    expect(area.overlapCountedOnce, isFalse);
  });

  test('overlapping circles are subtracted once', () {
    final area = measureFieldArea(
      boundary: square,
      obstacles: [
        AreaSubject.circle(center: at(40, 50), radiusMeters: 10),
        AreaSubject.circle(center: at(50, 50), radiusMeters: 10),
      ],
    );
    expect(area.obstacles[0].squareMeters, closeTo(314.159, _slack(314.159)));
    expect(area.obstacles[1].squareMeters, closeTo(314.159, _slack(314.159)));
    expect(area.unionSquareMeters, closeTo(505.482, _slack(505.482)));
    expect(area.unionSquareMeters, isNot(closeTo(628.318, 1)));
    expect(area.netSquareMeters, closeTo(9494.518, _slack(9494.518)));
    expect(area.overlapCountedOnce, isTrue);
  });

  test('a circle centred on the field edge counts only its inside half', () {
    final area = measureFieldArea(
      boundary: square,
      obstacles: [
        AreaSubject.circle(center: at(0, 50), radiusMeters: 10),
      ],
    );
    final circle = area.obstacles.single;
    expect(circle.squareMeters, closeTo(314.159, _slack(314.159)));
    expect(circle.insideSquareMeters, closeTo(157.08, _slack(157.08)));
    expect(circle.outsideField, isFalse);
    expect(area.netSquareMeters, closeTo(9842.92, _slack(9842.92)));
  });

  test('a circle fully outside the field is not subtracted', () {
    final area = measureFieldArea(
      boundary: square,
      obstacles: [
        AreaSubject.circle(center: at(-30, 50), radiusMeters: 10),
      ],
    );
    final circle = area.obstacles.single;
    expect(circle.outsideField, isTrue);
    expect(circle.insideSquareMeters, closeTo(0, 0.05));
    expect(area.unionSquareMeters, closeTo(0, 0.05));
    expect(area.netSquareMeters, closeTo(10000, _slack(10000)));
  });

  test('a 20 m by 10 m polygon obstacle is 200 m2', () {
    final area = measureFieldArea(
      boundary: square,
      obstacles: [
        AreaSubject.polygon([
          at(30, 40),
          at(50, 40),
          at(50, 50),
          at(30, 50),
        ]),
      ],
    );
    expect(area.obstacles.single.squareMeters, closeTo(200, _slack(200)));
    expect(area.obstacles.single.outsideField, isFalse);
    expect(area.netSquareMeters, closeTo(9800, _slack(9800)));
  });

  test('an L-shaped field has its exact area and a label inside the shape', () {
    final ell = [
      at(0, 0),
      at(60, 0),
      at(60, 20),
      at(20, 20),
      at(20, 60),
      at(0, 60),
    ];
    final area = measureFieldArea(boundary: ell, obstacles: const []);
    expect(area.fieldSquareMeters, closeTo(2000, _slack(2000)));
    final label = _project(area.label!, _centroid(ell));
    expect(_ringContains(_projectAll(ell), label), isTrue);
    expect(label.east > 20 && label.north > 20, isFalse);
  });

  test('a self-crossing bow-tie returns an error and no number', () {
    final area = measureFieldArea(
      boundary: [at(0, 0), at(100, 0), at(0, 100), at(100, 100)],
      obstacles: [
        AreaSubject.circle(center: at(50, 50), radiusMeters: 10),
      ],
    );
    expect(area.problem, FieldAreaProblem.boundaryCrosses);
    expect(area.fieldSquareMeters, isNull);
    expect(area.netSquareMeters, isNull);
    expect(area.unionSquareMeters, isNull);
    expect(area.obstacles, isEmpty);
  });

  test('fewer than 3 points returns an error and no number', () {
    final area = measureFieldArea(
      boundary: [at(0, 0), at(10, 0)],
      obstacles: const [],
    );
    expect(area.problem, FieldAreaProblem.needsThreePoints);
    expect(area.fieldSquareMeters, isNull);
  });

  test('a 500 m square near Thiruvananthapuram matches a spherical area', () {
    const place = LatLng(8.5241, 76.9366);
    final field = [
      shiftByMeters(place, 0, 0),
      shiftByMeters(place, 500, 0),
      shiftByMeters(place, 500, 500),
      shiftByMeters(place, 0, 500),
    ];
    final measured = measureFieldArea(
      boundary: field,
      obstacles: const [],
    ).fieldSquareMeters!;
    final spherical = _sphericalArea(field);
    expect((measured - spherical).abs() / spherical, lessThan(0.005));
  });

  test('unit conversions use hectares, acres, and mu', () {
    expect(areaInUnit(10000, AreaUnit.hectare), 1);
    expect(areaInUnit(10000, AreaUnit.squareMeter), 10000);
    expect(areaInUnit(squareMetersPerAcre, AreaUnit.acre), closeTo(1, 1e-9));
    expect(areaInUnit(squareMetersPerMu, AreaUnit.mu), closeTo(1, 1e-9));
    expect(areaFractionDigits(AreaUnit.squareMeter), 0);
    expect(areaFractionDigits(AreaUnit.hectare), 2);
  });

  test('point samples match the net area for 200 layouts', () {
    final random = Random(20261006);
    for (var layout = 0; layout < 200; layout++) {
      final field = _randomField(random);
      final obstacles = _randomObstacles(random, layout);
      final area = measureFieldArea(boundary: field, obstacles: obstacles);
      expect(area.isValid, isTrue, reason: 'layout $layout');
      final estimate = _sampleNet(field, obstacles, Random(1000 + layout));
      final net = area.netSquareMeters!;
      final scale = max(net.abs(), 1.0);
      expect(
        (estimate - net).abs() / scale,
        lessThan(0.01),
        reason: 'layout $layout net $net sample $estimate',
      );
    }
  });
}

double _slack(double expected) => expected.abs() * 0.001;

List<LatLng> _randomField(Random random) {
  final center = _place(random.nextDouble() * 40 - 20, random.nextDouble() * 40 - 20);
  final sides = 5 + random.nextInt(4);
  final turn = random.nextDouble() * pi;
  return [
    for (var index = 0; index < sides; index++)
      shiftByMeters(
        center,
        (70 + random.nextDouble() * 50) * cos(turn + 2 * pi * index / sides),
        (70 + random.nextDouble() * 50) * sin(turn + 2 * pi * index / sides),
      ),
  ];
}

List<AreaSubject> _randomObstacles(Random random, int layout) {
  final subjects = <AreaSubject>[];
  if (layout % 5 == 0) {
    final east = random.nextDouble() * 40 - 20;
    final north = random.nextDouble() * 40 - 20;
    subjects.add(AreaSubject.circle(center: _place(east, north), radiusMeters: 12));
    subjects.add(
      AreaSubject.circle(center: _place(east + 8, north + 3), radiusMeters: 12),
    );
  } else if (layout % 5 == 1) {
    subjects.add(AreaSubject.circle(center: _place(160, 0), radiusMeters: 15));
  }
  final extra = 1 + random.nextInt(2);
  for (var index = 0; index < extra; index++) {
    if (random.nextBool()) {
      subjects.add(
        AreaSubject.circle(
          center: _place(random.nextDouble() * 80 - 40, random.nextDouble() * 80 - 40),
          radiusMeters: 6 + random.nextDouble() * 10,
        ),
      );
    } else {
      final east = random.nextDouble() * 60 - 30;
      final north = random.nextDouble() * 60 - 30;
      final width = 8 + random.nextDouble() * 14;
      final height = 8 + random.nextDouble() * 14;
      subjects.add(
        AreaSubject.polygon([
          _place(east, north),
          _place(east + width, north),
          _place(east + width, north + height),
          _place(east, north + height),
        ]),
      );
    }
  }
  return subjects;
}

LatLng _place(double east, double north) {
  return shiftByMeters(const LatLng(12.97, 77.59), east, north);
}

double _sampleNet(List<LatLng> field, List<AreaSubject> obstacles, Random random) {
  final origin = _centroid(field);
  final ring = _projectAll(field);
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
  final circles = <(double, double, double)>[];
  final polygons = <List<_Meters>>[];
  for (final obstacle in obstacles) {
    if (obstacle.isCircle) {
      final center = _project(obstacle.center!, origin);
      circles.add((center.east, center.north, obstacle.radiusMeters!));
    } else if (obstacle.vertices.length >= 3) {
      polygons.add([for (final vertex in obstacle.vertices) _project(vertex, origin)]);
    }
  }

  var hits = 0;
  const columns = 200;
  const rows = 100;
  const samples = columns * rows;
  final width = (east - west) / columns;
  final height = (north - south) / rows;
  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      final point = _Meters(
        west + (column + random.nextDouble()) * width,
        south + (row + random.nextDouble()) * height,
      );
      if (!_ringContains(ring, point) || _blocked(point, circles, polygons)) {
        continue;
      }
      hits++;
    }
  }
  return hits / samples * (east - west) * (north - south);
}

bool _blocked(
  _Meters point,
  List<(double, double, double)> circles,
  List<List<_Meters>> polygons,
) {
  for (final circle in circles) {
    final east = point.east - circle.$1;
    final north = point.north - circle.$2;
    if (east * east + north * north <= circle.$3 * circle.$3) {
      return true;
    }
  }
  for (final polygon in polygons) {
    if (_ringContains(polygon, point)) {
      return true;
    }
  }
  return false;
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

List<_Meters> _projectAll(List<LatLng> points) {
  final origin = _centroid(points);
  return [for (final point in points) _project(point, origin)];
}

_Meters _project(LatLng point, LatLng origin) {
  final scale = cos(origin.latitude * pi / 180).abs();
  return _Meters(
    (point.longitude - origin.longitude) * 111320 * scale,
    (point.latitude - origin.latitude) * 111320,
  );
}

bool _ringContains(List<_Meters> ring, _Meters point) {
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

double _sphericalArea(List<LatLng> ring) {
  const earthRadius = 6378137.0;
  var sum = 0.0;
  for (var index = 0; index < ring.length; index++) {
    final start = ring[index];
    final end = ring[(index + 1) % ring.length];
    final lon1 = start.longitude * pi / 180;
    final lon2 = end.longitude * pi / 180;
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    sum += (lon2 - lon1) * (sin(lat1) + sin(lat2));
  }
  return (sum * earthRadius * earthRadius / 2).abs();
}

class _Meters {
  const _Meters(this.east, this.north);

  final double east;
  final double north;
}
