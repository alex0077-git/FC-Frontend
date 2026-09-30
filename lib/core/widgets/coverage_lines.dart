import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

const _lineColor = Color(0xFF22C55E);
const _highlightedLineColor = Color(0xFFF59E0B);

/// Ground-width strokes so the same lines keep the same shape at every zoom.
const _lineWidthMeters = 0.35;
const _highlightedWidthMeters = 0.7;

List<Polyline> coveragePolylines(
  List<CoverageLine> lines, {
  int? highlightedIndex,
}) {
  if (lines.isEmpty) {
    return const [];
  }

  final route = [
    for (final line in lines) ...line.endpoints,
  ];
  final polylines = <Polyline>[
    Polyline(
      points: route,
      color: _lineColor,
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
