import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/models/waypoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const waypointPathColor = Color(0xFFF59E0B);

enum WaypointPathRole { start, middle, end }

WaypointPathRole waypointPathRole(int index, int count) {
  if (index == 0) {
    return WaypointPathRole.start;
  }
  if (count > 1 && index == count - 1) {
    return WaypointPathRole.end;
  }
  return WaypointPathRole.middle;
}

String waypointPathLabel(int index, int count) {
  return switch (waypointPathRole(index, count)) {
    WaypointPathRole.start => 'Start',
    WaypointPathRole.end => 'End',
    WaypointPathRole.middle => 'Waypoint ${index + 1}',
  };
}

List<Widget> waypointPathLine(List<Waypoint> waypoints) {
  if (waypoints.length < 2) {
    return const [];
  }
  return [
    PolylineLayer(
      polylines: [
        Polyline(
          points: [
            for (final waypoint in waypoints)
              LatLng(waypoint.latitude, waypoint.longitude),
          ],
          color: waypointPathColor,
          strokeWidth: 3,
        ),
      ],
    ),
  ];
}

List<Widget> waypointPathMarkers(
  List<Waypoint> waypoints, {
  required int activeSplit,
}) {
  if (waypoints.isEmpty) {
    return const [];
  }
    final indexes = <int>[
      if (waypoints.isNotEmpty) 0,
      if (waypoints.length > 1) waypoints.length - 1,
    ];
    return [
      MarkerLayer(
        markers: [
          for (final index in indexes)
            Marker(
              key: ValueKey(waypoints[index].id),
              point: LatLng(waypoints[index].latitude, waypoints[index].longitude),
              width: 36,
              height: 36,
              child: _PathMarker(
                index: index,
                count: waypoints.length,
                dimmed: activeSplit >= 0 &&
                    waypoints[index].sectionIndex != activeSplit,
              ),
            ),
        ],
      ),
    ];
}

class _PathMarker extends StatelessWidget {
  const _PathMarker({
    required this.index,
    required this.count,
    required this.dimmed,
  });

  final int index;
  final int count;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final role = waypointPathRole(index, count);
    final label = switch (role) {
      WaypointPathRole.start => 'S',
      WaypointPathRole.end => 'E',
      WaypointPathRole.middle => '${index + 1}',
    };
    final color = dimmed ? const Color(0xFF94A3B8) : _roleColor(role);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

Color _roleColor(WaypointPathRole role) {
  return switch (role) {
    WaypointPathRole.start => const Color(0xFF16A34A),
    WaypointPathRole.end => const Color(0xFFDC2626),
    WaypointPathRole.middle => AppTheme.primary,
  };
}
