import 'dart:math';

import 'package:fc_frontend/core/geometry/boundary_split.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a cut across a field divides it into two sections', () {
    final field = _rectangle();
    final sections = boundarySections(field, [
      SplitCut(_at(0, 0), _at(0, 40)),
    ]);

    expect(sections, hasLength(2));
    expect(_owners(sections, _at(-15, 20)), 1);
    expect(_owners(sections, _at(15, 20)), 1);
    expect(_owners(sections, _at(-15, 20)) + _owners(sections, _at(15, 20)), 2);
  });

  test('a second cut divides one section again', () {
    final field = _rectangle();
    final sections = boundarySections(field, [
      SplitCut(_at(0, 0), _at(0, 40)),
      SplitCut(_at(-20, 20), _at(0, 20)),
    ]);

    expect(sections, hasLength(3));
    expect(_owners(sections, _at(-15, 10)), 1);
    expect(_owners(sections, _at(15, 10)), 1);
    expect(_owners(sections, _at(-15, 30)), 1);
    expect(_owners(sections, _at(15, 30)), 1);
  });

  test('points anywhere along the boundary can separate the field', () {
    final field = _rectangle();
    final sections = boundarySections(field, [
      SplitCut(_at(0, 0), _at(-20, 20)),
    ]);

    expect(sections, hasLength(2));
    expect(_owners(sections, _at(-15, 5)), 1);
    expect(_owners(sections, _at(10, 20)), 1);
  });

  test('the first point can sit on any boundary point, including the last', () {
    final field = [
      _at(-20, 0),
      _at(20, 0),
      _at(24, 18),
      _at(0, 40),
      _at(-24, 18),
    ];

    for (var index = 0; index < field.length; index++) {
      final start = field[index];
      final end = field[(index + 2) % field.length];
      final sections = boundarySections(field, [SplitCut(start, end)]);
      expect(sections, hasLength(2));
      expect(exclusiveSplitSide(field, [SplitCut(start, end)], start), isNull);
      expect(
        exclusiveSplitSide(field, [SplitCut(start, end)], field[(index + 1) % field.length]),
        isNotNull,
      );
    }
  });

  test('a cut that misses the field does not split it', () {
    final field = _rectangle();
    final sections = boundarySections(field, [
      SplitCut(_at(-10, -30), _at(10, -30)),
    ]);

    expect(sections, hasLength(1));
  });

  test('two boundary points divide a concave field into two sides', () {
    final shape = [
      _at(-25, 0),
      _at(25, 0),
      _at(25, 40),
      _at(10, 40),
      _at(10, 15),
      _at(-10, 15),
      _at(-10, 40),
      _at(-25, 40),
    ];
    final sections = boundarySections(shape, [
      SplitCut(_at(-25, 10), _at(25, 10)),
    ]);

    expect(sections, hasLength(2));
    expect(_owners(sections, _at(-18, 35)), 1);
    expect(_owners(sections, _at(18, 35)), 1);
    expect(_owners(sections, _at(0, 5)), 1);
    expect(_owners(sections, _at(0, 30)), 0);
  });

  test('coverage lines stay inside their own section', () async {
    final repo = MissionRepository();
    for (final point in _rectangle()) {
      repo.addBoundaryPoint(latitude: point.latitude, longitude: point.longitude);
    }
    await repo.generateCoverage(spacingMeters: 8, orientationDegrees: 0);

    final split = repo.splitBoundary(
      startLatitude: _at(0, 0).latitude,
      startLongitude: _at(0, 0).longitude,
      endLatitude: _at(0, 40).latitude,
      endLongitude: _at(0, 40).longitude,
    );
    expect(split, isTrue);

    final sections = boundarySections(_rectangle(), repo.state.splits);
    expect(sections, hasLength(2));
    expect(repo.state.coverageLines, isNotEmpty);

    final seen = <int>{};
    for (final line in repo.state.coverageLines) {
      seen.add(line.sectionIndex);
      for (final sample in _samples(line.endpoints.first, line.endpoints.last)) {
        final owners = [
          for (var index = 0; index < sections.length; index++)
            if (boundaryContains(sections[index], sample)) index,
        ];
        expect(owners, [line.sectionIndex]);
      }
    }
    expect(seen, {0, 1});

    repo.undoSplit();
    expect(repo.state.splits, isEmpty);
    final restored = boundarySections(_rectangle(), repo.state.splits);
    expect(restored, hasLength(1));
    expect(
      repo.state.coverageLines.every((line) => line.sectionIndex == 0),
      isTrue,
    );
  });

  test('lines parallel to the split do not sit on the shared edge', () async {
    final repo = MissionRepository();
    for (final point in _rectangle()) {
      repo.addBoundaryPoint(latitude: point.latitude, longitude: point.longitude);
    }
    await repo.generateCoverage(spacingMeters: 8, orientationDegrees: 90);
    expect(
      repo.splitBoundary(
        startLatitude: _at(0, 0).latitude,
        startLongitude: _at(0, 0).longitude,
        endLatitude: _at(0, 40).latitude,
        endLongitude: _at(0, 40).longitude,
      ),
      isTrue,
    );

    for (final line in repo.state.coverageLines) {
      final along = line.endpoints.every(
        (point) => (_toMeters(point).x).abs() < 0.5,
      );
      expect(along, isFalse);
    }
  });

  testWidgets('Split appears after the boundary is drawn', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const GroundPlanPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Split'), findsNothing);

    final repo = ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    ).read(missionRepositoryProvider.notifier);
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.590);
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.595);
    await tester.pump();
    expect(find.text('Split'), findsNothing);

    repo.addBoundaryPoint(latitude: 12.974, longitude: 77.595);
    await tester.pump();
    await tester.tap(find.text('Split'));
    await tester.pump();
    expect(find.text('First Point'), findsOneWidget);
    expect(find.text('End Point'), findsOneWidget);
    expect(
      find.text(
        'Choose First Point or End Point, then tap a boundary point or anywhere along the boundary.',
      ),
      findsOneWidget,
    );

    repo.addBoundaryPoint(latitude: 12.974, longitude: 77.592);
    repo.addBoundaryPoint(latitude: 12.972, longitude: 77.591);
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.text('Waypoint 5'), findsNothing);
    expect(find.text('First Point placed'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Tap the map to add a boundary point'), findsOneWidget);
  });
}

int _owners(List<List<LatLng>> sections, LatLng point) {
  return sections.where((section) => boundaryContains(section, point)).length;
}

List<LatLng> _samples(LatLng start, LatLng end) {
  return [
    for (var step = 1; step <= 4; step++)
      LatLng(
        start.latitude + (end.latitude - start.latitude) * step / 5,
        start.longitude + (end.longitude - start.longitude) * step / 5,
      ),
  ];
}

List<LatLng> _rectangle() {
  return [
    _at(-20, 0),
    _at(20, 0),
    _at(20, 40),
    _at(-20, 40),
  ];
}

const _originLatitude = 12.97;
const _originLongitude = 77.59;
const _metersPerDegree = 111320.0;

LatLng _at(double east, double north) {
  final scale = _metersPerDegree * cos(_originLatitude * pi / 180);
  return LatLng(
    _originLatitude + north / _metersPerDegree,
    _originLongitude + east / scale,
  );
}

_Meters _toMeters(LatLng point) {
  final scale = _metersPerDegree * cos(_originLatitude * pi / 180);
  return _Meters(
    (point.longitude - _originLongitude) * scale,
    (point.latitude - _originLatitude) * _metersPerDegree,
  );
}

class _Meters {
  const _Meters(this.x, this.y);

  final double x;
  final double y;
}
