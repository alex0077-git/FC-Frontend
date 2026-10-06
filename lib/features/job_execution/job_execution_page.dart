import 'package:fc_frontend/core/geometry/area_math.dart';
import 'package:fc_frontend/core/map/map_view.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/coverage_lines.dart';
import 'package:fc_frontend/core/widgets/obstacle_map_layers.dart';
import 'package:fc_frontend/features/ground_plan/area_readout.dart';
import 'package:fc_frontend/features/ground_plan/waypoint_path.dart';
import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class JobExecutionPage extends ConsumerStatefulWidget {
  const JobExecutionPage({super.key});

  @override
  ConsumerState<JobExecutionPage> createState() => _JobExecutionPageState();
}

class _JobExecutionPageState extends ConsumerState<JobExecutionPage> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final mission = ref.watch(missionRepositoryProvider);
    final areaUnit = ref.watch(areaUnitProvider);
    final lines = mission.coverageLines;
    final activeLine = lines.isEmpty ? null : lines.first;

    return Scaffold(
      body: _JobMap(
        controller: _mapController,
        mission: mission,
        activeIndex: 0,
        drone: _lineMidpoint(activeLine),
        areaUnit: areaUnit,
      ),
    );
  }
}

LatLng? _lineMidpoint(CoverageLine? line) {
  if (line == null) {
    return null;
  }
  final start = line.endpoints.first;
  final end = line.endpoints.last;
  return LatLng(
    (start.latitude + end.latitude) / 2,
    (start.longitude + end.longitude) / 2,
  );
}

class _JobMap extends StatelessWidget {
  const _JobMap({
    required this.controller,
    required this.mission,
    required this.activeIndex,
    required this.drone,
    required this.areaUnit,
  });

  final MapController controller;
  final MissionState mission;
  final int activeIndex;
  final LatLng? drone;
  final AreaUnit areaUnit;

  @override
  Widget build(BuildContext context) {
    final boundary = [
      for (final point in mission.boundaryPoints)
        LatLng(point.latitude, point.longitude),
    ];

    return MapModeStack(
      map: RepaintBoundary(
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter:
                drone ?? (boundary.isEmpty ? defaultMapCenter : boundary.first),
            initialZoom: 17,
            onMapReady: () => _frame(boundary),
            interactionOptions: mapGestureOptions(),
          ),
          children: [
            const MapTileLayer(),
            if (boundary.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: boundary,
                    color: AppTheme.primary.withValues(alpha: 0.16),
                    borderColor: AppTheme.primary,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (mission.coverageLines.isNotEmpty)
              PolylineLayer(
                polylines: coveragePolylines(
                  mission.coverageLines,
                  paths: mission.coveragePaths,
                  highlightedIndex: activeIndex,
                  activeSplit: mission.activeSplit,
                ),
                simplificationTolerance: 0,
              ),
            ...obstacleMapLayers(obstacles: mission.obstacles, unit: areaUnit),
            ...waypointPathMarkers(
              mission.waypoints,
              activeSplit: mission.activeSplit,
            ),
            if (drone != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: drone!,
                    width: 28,
                    height: 28,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      overlays: const [MapStyleToggle()],
    );
  }

  void _frame(List<LatLng> boundary) {
    if (boundary.length < 2) {
      return;
    }
    controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(boundary),
        padding: const EdgeInsets.all(32),
      ),
    );
  }
}
