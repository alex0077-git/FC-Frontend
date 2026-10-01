import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/coverage_lines.dart';
import 'package:fc_frontend/core/widgets/joystick_control.dart';
import 'package:fc_frontend/core/widgets/line_spacing_control.dart';
import 'package:fc_frontend/core/widgets/responsive.dart';
import 'package:fc_frontend/data/models/coverage_line.dart';
import 'package:fc_frontend/data/models/telemetry.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/data/repositories/telemetry_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

const _mapCenter = LatLng(12.9716, 77.5946);

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
    final telemetry = ref.watch(telemetryStreamProvider).asData?.value;
    final lines = mission.coverageLines;
    final lineCount = lines.length;
    final activeIndex = lineCount == 0 ? 0 : _activeIndex.clamp(0, lineCount - 1);
    final activeLine = lineCount == 0 ? null : lines[activeIndex];

    final compact = Responsive.useCompactMapLayout(context);
    final map = _JobMap(
      controller: _mapController,
      mission: mission,
      activeIndex: activeIndex,
      drone: _lineMidpoint(activeLine),
    );

    return Scaffold(
      body: Column(
        children: [
          _JobStatusStrip(telemetry: telemetry),
          if (compact)
            Expanded(
              child: Column(
                children: [
                  Expanded(child: map),
                  _CompactJobControls(
                    mission: mission,
                    lineCount: lineCount,
                    activeIndex: activeIndex,
                    onOrientation: (degrees) => _setOrientation(
                      degrees,
                      mission.spacingMeters,
                    ),
                    onSpacing: (spacing) => _setSpacing(
                      spacing,
                      mission.orientationDegrees,
                    ),
                    onNextLine: lineCount < 2 ? null : () => _nextLine(lineCount),
                    onBack: () => context.go('/ground-plan'),
                    onGuidelines: () => _openGuidelines(context),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Row(
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
                          JoystickControl(
                            label: 'Orientation',
                            degrees: mission.orientationDegrees,
                            onChanged: (degrees) => _setOrientation(
                              degrees,
                              mission.spacingMeters,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LineSpacingControl(
                            spacingMeters: mission.spacingMeters,
                            lowerMeters: MissionRepository.lineSpacingLowerBound(
                              mission.boundaryPoints,
                            ),
                            upperMeters: MissionRepository.lineSpacingUpperBound(
                              mission.boundaryPoints,
                            ),
                            onChanged: (spacing) => _setSpacing(
                              spacing,
                              mission.orientationDegrees,
                            ),
                          ),
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
                            onPressed: lineCount < 2
                                ? null
                                : () => _nextLine(lineCount),
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
            ),
        ],
      ),
    );
  }

  void _openGuidelines(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (context) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _Guidelines(),
        );
      },
    );
  }

  void _setOrientation(double degrees, double spacingMeters) {
    ref.read(missionRepositoryProvider.notifier).scheduleCoverage(
      spacingMeters: spacingMeters,
      orientationDegrees: degrees,
    );
  }

  void _setSpacing(double spacingMeters, double orientationDegrees) {
    ref.read(missionRepositoryProvider.notifier).scheduleCoverage(
      spacingMeters: spacingMeters,
      orientationDegrees: orientationDegrees,
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

class _CompactJobControls extends StatelessWidget {
  const _CompactJobControls({
    required this.mission,
    required this.lineCount,
    required this.activeIndex,
    required this.onOrientation,
    required this.onSpacing,
    required this.onNextLine,
    required this.onBack,
    required this.onGuidelines,
  });

  final MissionState mission;
  final int lineCount;
  final int activeIndex;
  final ValueChanged<double> onOrientation;
  final ValueChanged<double> onSpacing;
  final VoidCallback? onNextLine;
  final VoidCallback onBack;
  final VoidCallback onGuidelines;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            JoystickControl(
              label: '',
              degrees: mission.orientationDegrees,
              size: 88,
              onChanged: onOrientation,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LineSpacingControl(
                    spacingMeters: mission.spacingMeters,
                    lowerMeters: MissionRepository.lineSpacingLowerBound(
                      mission.boundaryPoints,
                    ),
                    upperMeters: MissionRepository.lineSpacingUpperBound(
                      mission.boundaryPoints,
                    ),
                    onChanged: onSpacing,
                  ),
                  Text(
                    lineCount == 0
                        ? 'Line 0 of 0'
                        : 'Line ${activeIndex + 1} of $lineCount',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: onNextLine,
                          child: const Text('Next Line'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: onGuidelines,
                          child: const Text('Guidelines'),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Back to Ground Plan',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobStatusStrip extends StatelessWidget {
  const _JobStatusStrip({required this.telemetry});

  final Telemetry? telemetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: _JobStatusItem(
                icon: Icons.battery_std,
                label: telemetry == null
                    ? 'Battery --'
                    : 'Battery ${telemetry!.battery.toStringAsFixed(1)}%',
              ),
            ),
            Expanded(
              child: _JobStatusItem(
                icon: Icons.satellite_alt,
                label: telemetry == null ? 'GPS --' : 'GPS ${telemetry!.gpsCount}',
              ),
            ),
            Expanded(
              child: _JobStatusItem(
                icon: Icons.flight,
                label: telemetry == null ? 'Mode --' : telemetry!.mode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobStatusItem extends StatelessWidget {
  const _JobStatusItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppTheme.text),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
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

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: drone ?? (boundary.isEmpty ? _mapCenter : boundary.first),
        initialZoom: 17,
        onMapReady: () => _frame(boundary),
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          cursorKeyboardRotationOptions: CursorKeyboardRotationOptions.disabled(),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'fc_frontend',
        ),
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
              highlightedIndex: activeIndex,
            ),
            simplificationTolerance: 0,
            cullingMargin: null,
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
