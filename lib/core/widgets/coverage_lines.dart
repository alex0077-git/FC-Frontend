import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const _lineColor = Color(0xFF22C55E);
const _inactiveLineColor = Color(0xFF94A3B8);
const _highlightedLineColor = Color(0xFFF59E0B);

/// Ground-width strokes so the same lines keep the same shape at every zoom.
const _lineWidthMeters = 0.35;
const _highlightedWidthMeters = 0.7;

List<Polyline> coveragePolylines(
  List<CoverageLine> lines, {
  int? highlightedIndex,
  int activeSplit = -1,
}) {
  if (lines.isEmpty) {
    return const [];
  }

  final polylines = <Polyline>[
    for (final route in _sectionRoutes(lines))
      Polyline(
        points: route.points,
        color: activeSplit < 0 || route.section == activeSplit
            ? _lineColor
            : _inactiveLineColor,
        strokeWidth: _lineWidthMeters,
        useStrokeWidthInMeter: true,
        strokeCap: StrokeCap.butt,
        strokeJoin: StrokeJoin.round,
      ),
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

class _SectionRoute {
  _SectionRoute(this.section);

  final int section;
  final List<LatLng> points = [];
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
