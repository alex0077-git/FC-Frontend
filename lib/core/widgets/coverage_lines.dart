import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const _lineColor = Color(0xFFFACC15);
const _inactiveLineColor = Color(0xFF94A3B8);
const _highlightedLineColor = Color(0xFFF59E0B);

/// Ground-width strokes so the same lines keep the same shape at every zoom.
const _lineWidthMeters = 0.35;
const _highlightedWidthMeters = 0.7;

List<Polyline> coveragePolylines(
  List<CoverageLine> lines, {
  List<CoveragePath> paths = const [],
  int? highlightedIndex,
  int activeSplit = -1,
}) {
  if (lines.isEmpty && paths.isEmpty) {
    return const [];
  }

  final polylines = <Polyline>[
    for (final route in paths.isNotEmpty ? _pathRoutes(paths) : _sectionRoutes(lines))
      ..._routePolylines(route, activeSplit: activeSplit),
  ];
  if (highlightedIndex != null &&
      highlightedIndex >= 0 &&
      highlightedIndex < lines.length) {
    polylines.add(
      Polyline(
        points: lines[highlightedIndex].endpoints,
        color: _highlightedLineColor,
        strokeWidth: _highlightedWidthMeters,
        useStrokeWidthInMeter: true,
        strokeCap: StrokeCap.butt,
        strokeJoin: StrokeJoin.round,
      ),
    );
  }
  return polylines;
}

const _pumpOffWidthMeters = 0.18;
final _pumpOffPattern = StrokePattern.dashed(segments: [16, 10]);

class _SectionRoute {
  _SectionRoute(this.section);

  final int section;
  final List<LatLng> points = [];
  final List<bool> pumpOn = [];
}

List<Polyline> _routePolylines(
  _SectionRoute route, {
  required int activeSplit,
}) {
  if (route.points.length < 2) {
    return const [];
  }
  final active = activeSplit < 0 || route.section == activeSplit;
  final polylines = <Polyline>[];
  var runStart = 0;
  var runPump = _segmentSprays(route, 0);
  for (var segment = 1; segment < route.points.length - 1; segment++) {
    final sprays = _segmentSprays(route, segment);
    if (sprays == runPump) {
      continue;
    }
    polylines.add(_runPolyline(route, runStart, segment + 1, runPump, active));
    runStart = segment;
    runPump = sprays;
  }
  polylines.add(
    _runPolyline(route, runStart, route.points.length, runPump, active),
  );
  return polylines;
}

bool _segmentSprays(_SectionRoute route, int segment) {
  if (segment < 0 || segment >= route.pumpOn.length) {
    return true;
  }
  return route.pumpOn[segment];
}

Polyline _runPolyline(
  _SectionRoute route,
  int start,
  int end,
  bool sprays,
  bool active,
) {
  final pumpOff = active && !sprays;
  return Polyline(
    points: route.points.sublist(start, end),
    color: active ? _lineColor : _inactiveLineColor,
    strokeWidth: pumpOff ? _pumpOffWidthMeters : _lineWidthMeters,
    pattern: pumpOff ? _pumpOffPattern : const StrokePattern.solid(),
    useStrokeWidthInMeter: true,
    strokeCap: StrokeCap.butt,
    strokeJoin: StrokeJoin.miter,
  );
}

List<_SectionRoute> _pathRoutes(List<CoveragePath> paths) {
  return [
    for (final path in paths)
      _SectionRoute(path.sectionIndex)
        ..points.addAll(path.points)
        ..pumpOn.addAll(
          path.pumpOn.length == path.points.length - 1
              ? path.pumpOn
              : List<bool>.filled(
                  path.points.length < 2 ? 0 : path.points.length - 1,
                  true,
                ),
        ),
  ];
}

List<_SectionRoute> _sectionRoutes(List<CoverageLine> lines) {
  final routes = <_SectionRoute>[];
  for (final line in lines) {
    final startsNew = routes.isEmpty ||
        line.sectionIndex != routes.last.section ||
        (line.startsRoute && routes.last.points.isNotEmpty);
    if (startsNew) {
      routes.add(_SectionRoute(line.sectionIndex));
    }
    routes.last.points.addAll(line.endpoints);
  }
  return routes;
}
