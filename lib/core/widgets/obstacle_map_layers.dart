import 'package:fc_frontend/core/geometry/area_math.dart';
import 'package:fc_frontend/data/models/obstacle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Red no-fly shapes for the plan map and the job map.
/// Each shape is labelled with its own area, with no filled background.
List<Widget> obstacleMapLayers({
  required List<Obstacle> obstacles,
  String? selectedId,
  AreaUnit unit = AreaUnit.hectare,
}) {
  final polygons = <Polygon>[
    for (final obstacle in obstacles)
      if (obstacle.outline.length >= 3)
        Polygon(
          points: obstacle.outline,
          color: Colors.red.withValues(alpha: 0.3),
          borderColor: Colors.red,
          borderStrokeWidth: obstacle.id == selectedId ? 4 : 2,
        ),
  ];

  final markers = <Marker>[
    for (final obstacle in obstacles)
      if (obstacle.outline.length >= 3 && _obstacleAreaLabel(obstacle, unit).isNotEmpty)
        Marker(
          point: obstacle.labelPoint,
          width: 96,
          height: 24,
          alignment: Alignment.center,
          child: Semantics(
            label: 'No-Fly Zone',
            child: IgnorePointer(
              child: AreaValueText(_obstacleAreaLabel(obstacle, unit)),
            ),
          ),
        ),
  ];

  return [
    if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
    if (markers.isNotEmpty) MarkerLayer(markers: markers),
  ];
}

String _obstacleAreaLabel(Obstacle obstacle, AreaUnit unit) {
  final meters = subjectSquareMeters(
    obstacle.type == ObstacleType.circle &&
            obstacle.center != null &&
            obstacle.radiusMeters != null
        ? AreaSubject.circle(
            center: obstacle.center!,
            radiusMeters: obstacle.radiusMeters!,
          )
        : AreaSubject.polygon(obstacle.vertices),
  );
  if (meters <= 0) {
    return '';
  }
  return formatArea(meters, unit);
}

/// Area text drawn directly on the map. The background stays transparent.
class AreaValueText extends StatelessWidget {
  const AreaValueText(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        shadows: [Shadow(blurRadius: 2, color: Color(0xCC000000))],
      ),
    );
  }
}
