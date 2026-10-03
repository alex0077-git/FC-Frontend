import 'package:fc_frontend/core/map/map_view.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/coverage_lines.dart';
import 'package:fc_frontend/core/widgets/obstacle_map_layers.dart';
import 'package:fc_frontend/features/ground_plan/waypoint_path.dart';
import 'package:fc_frontend/core/widgets/coverage_adjust_controls.dart';
import 'package:fc_frontend/core/widgets/responsive.dart';
import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';


class JobExecutionPage extends ConsumerStatefulWidget {
  const JobExecutionPage({super.key});

  @override
  ConsumerState<JobExecutionPage> createState() => _JobExecutionPageState();
}

class _JobExecutionPageState extends ConsumerState<JobExecutionPage> {
  final MapController _mapController = MapController();
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final mission = ref.watch(missionRepositoryProvider);
    final lines = mission.coverageLines;
    final lineCount = lines.length;
    final activeIndex = lineCount == 0 ? 0 : _activeIndex.clamp(0, lineCount - 1);
    final activeLine = lineCount == 0 ? null : lines[activeIndex];

    final map = _JobMap(
      controller: _mapController,
      mission: mission,
      activeIndex: activeIndex,
      drone: _lineMidpoint(activeLine),
    );

    return Scaffold(
      body: Row(
        children: [
          Expanded(flex: 3, child: map),
          SizedBox(
            width: Responsive.sidePanelWidth(context, desktopWidth: 300),
            child: Material(
              color: AppTheme.surface,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _Guidelines(),
                  const SizedBox(height: 20),
                  const CoverageAdjustControls(gap: 12),
                  const SizedBox(height: 16),
                  Text(
                    lineCount == 0
                        ? 'Line 0 of 0'
                        : 'Line ${activeIndex + 1} of $lineCount',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: lineCount < 2 ? null : () => _nextLine(lineCount),
                    child: const Text('Next Line'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => context.go('/ground-plan'),
                    child: const Text('Back to Ground Plan'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextLine(int lineCount) {
    setState(() => _activeIndex = (_activeIndex + 1) % lineCount);
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

class _Guidelines extends StatelessWidget {
  const _Guidelines();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Guidelines'),
        SizedBox(height: 8),
        Text('Follow the highlighted line'),
        SizedBox(height: 4),
        Text('Use the joystick to rotate the lines'),
        SizedBox(height: 4),
        Text('Maintain steady altitude'),
      ],
    );
  }
}

class _JobMap extends StatelessWidget {
  const _JobMap({
    required this.controller,
    required this.mission,
    required this.activeIndex,
    required this.drone,
  });

  final MapController controller;
  final MissionState mission;
  final int activeIndex;
  final LatLng? drone;

  @override
  Widget build(BuildContext context) {
    final boundary = [
      for (final point in mission.boundaryPoints)
        LatLng(point.latitude, point.longitude),
    ];

    return RepaintBoundary(
      child: FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: drone ?? (boundary.isEmpty ? defaultMapCenter : boundary.first),
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
        ...obstacleMapLayers(obstacles: mission.obstacles),
        ...waypointPathMarkers(
          mission.waypoints,
          activeSplit: mission.activeSplit,
        ),
        const MapStyleToggle(),
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
