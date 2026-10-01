import 'package:fc_frontend/data/models/obstacle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Red no-fly shapes for the plan map and the job map.
List<Widget> obstacleMapLayers({
  required List<Obstacle> obstacles,
  String? selectedId,
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
      if (obstacle.outline.length >= 3)
        Marker(
          point: obstacle.labelPoint,
          width: 28,
          height: 28,
          child: Semantics(
            label: 'No-Fly Zone',
            child: IgnorePointer(
              child: Icon(Icons.block, color: Colors.red, size: 22),
            ),
          ),
        ),
  ];

  return [
    if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
    if (markers.isNotEmpty) MarkerLayer(markers: markers),
  ];
}
