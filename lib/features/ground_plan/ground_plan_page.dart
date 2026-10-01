import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/coverage_lines.dart';
import 'package:fc_frontend/core/widgets/line_spacing_control.dart';
import 'package:fc_frontend/data/models/flight_log.dart';
import 'package:fc_frontend/data/models/job_config.dart';
import 'package:fc_frontend/data/models/mission.dart';
import 'package:fc_frontend/data/models/waypoint.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/data/repositories/telemetry_repository.dart';
import 'package:fc_frontend/core/widgets/joystick_control.dart';
import 'package:fc_frontend/core/widgets/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

const _mapCenter = LatLng(12.9716, 77.5946);

enum _MapPlacement { boundary, pointA, pointB }

class GroundPlanPage extends ConsumerStatefulWidget {
  const GroundPlanPage({super.key});

  @override
  ConsumerState<GroundPlanPage> createState() => _GroundPlanPageState();
}

class _GroundPlanPageState extends ConsumerState<GroundPlanPage> {
  final MapController _mapController = MapController();
  final TextEditingController _altitudeController = TextEditingController();
  final TextEditingController _speedController = TextEditingController();

  _MapPlacement _placement = _MapPlacement.boundary;
  LatLng? _pointA;
  LatLng? _pointB;
  String _operationMode = 'Spray';
  String? _selectedWaypointId;

  @override
  void dispose() {
    _altitudeController.dispose();
    _speedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mission = ref.watch(missionRepositoryProvider);
    final boundary = [
      for (final point in mission.boundaryPoints)
        LatLng(point.latitude, point.longitude),
    ];
    final selected = _waypointById(mission.waypoints, _selectedWaypointId);
    final hasCoverage = mission.coverageLines.isNotEmpty;

    final compact = Responsive.useCompactMapLayout(context);

    return Scaffold(
      body: compact
          ? _CompactPlan(
              map: _planMap(boundary),
              hasCoverage: hasCoverage,
              mission: mission,
              onCallForJob: _callForJob,
              canCallForJob: mission.boundaryPoints.length >= 3,
              onOrientation: _setOrientation,
              onSpacing: _setSpacing,
              onOpenDetails: () => _openPlanDetails(
                mission: mission,
                selected: selected,
                hasCoverage: hasCoverage,
              ),
            )
          : Row(
              children: [
                Expanded(flex: 3, child: _planMap(boundary)),
                SizedBox(
                  width: Responsive.sidePanelWidth(context, desktopWidth: 340),
                  child: Material(
                    color: AppTheme.surface,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      children: _planPanelChildren(
                        mission: mission,
                        selected: selected,
                        hasCoverage: hasCoverage,
                        includeControls: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _planMap(List<LatLng> boundary) {
    return _PlanMap(
      controller: _mapController,
      boundary: boundary,
      mission: ref.watch(missionRepositoryProvider),
      pointA: _pointA,
      pointB: _pointB,
      placement: _placement,
      onTap: _onMapTap,
      onMapReady: _frameBoundary,
    );
  }

  void _openPlanDetails({
    required MissionState mission,
    required Waypoint? selected,
    required bool hasCoverage,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: _planPanelChildren(
              mission: mission,
              selected: selected,
              hasCoverage: hasCoverage,
              includeControls: false,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _planPanelChildren({
    required MissionState mission,
    required Waypoint? selected,
    required bool hasCoverage,
    required bool includeControls,
  }) {
    return [
      _BoundaryActions(
        canCallForJob: mission.boundaryPoints.length >= 3,
        onReset: _resetBoundary,
        onCallForJob: _callForJob,
      ),
      if (includeControls && hasCoverage) ...[
        const SizedBox(height: 16),
        JoystickControl(
          label: 'Orientation',
          degrees: mission.orientationDegrees,
          onChanged: _setOrientation,
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
          onChanged: _setSpacing,
        ),
      ],
      const SizedBox(height: 16),
      _PointPairSection(
        pointA: _pointA,
        pointB: _pointB,
        placement: _placement,
        operationMode: _operationMode,
        onSetA: () => _togglePlacement(_MapPlacement.pointA),
        onSetB: () => _togglePlacement(_MapPlacement.pointB),
        onModeChanged: (mode) => setState(() => _operationMode = mode),
      ),
      const SizedBox(height: 16),
      _WaypointList(
        waypoints: mission.waypoints,
        selectedId: selected?.id,
        onSelect: _selectWaypoint,
        onDelete: _deleteWaypoint,
      ),
      const SizedBox(height: 8),
      _WaypointDetail(
        waypoint: selected,
        altitudeController: _altitudeController,
        speedController: _speedController,
        onAltitudeChanged: (altitude) => _updateSelected(altitude: altitude),
        onSpeedChanged: (speed) => _updateSelected(speed: speed),
        onActionChanged: (action) => _updateSelected(action: action),
      ),
      const SizedBox(height: 8),
      _FlightHistory(
        logs: ref.read(missionRepositoryProvider.notifier).listFlightLogs(),
      ),
      const SizedBox(height: 12),
      _MissionActions(
        onSave: _saveMission,
        onLoad: _loadMission,
        onUpload: _uploadMission,
      ),
    ];
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    switch (_placement) {
      case _MapPlacement.pointA:
        setState(() {
          _pointA = point;
          _placement = _MapPlacement.boundary;
        });
      case _MapPlacement.pointB:
        setState(() {
          _pointB = point;
          _placement = _MapPlacement.boundary;
        });
      case _MapPlacement.boundary:
        ref.read(missionRepositoryProvider.notifier).addBoundaryPoint(
          latitude: point.latitude,
          longitude: point.longitude,
        );
    }
  }

  void _togglePlacement(_MapPlacement target) {
    setState(() {
      _placement = _placement == target ? _MapPlacement.boundary : target;
    });
  }

  void _resetBoundary() {
    ref.read(missionRepositoryProvider.notifier).resetBoundary();
    setState(() => _selectedWaypointId = null);
  }

  Future<void> _callForJob() async {
    if (!ref.read(telemetryConnectionProvider)) {
      await _showServerError();
      return;
    }

    final config = await showDialog<JobConfig>(
      context: context,
      builder: (context) => const _CallForJobDialog(),
    );
    if (config == null || !mounted) {
      return;
    }

    // Confirm already popped the dialog. Let that frame remove the modal
    // barrier before coverage generation publishes new map data.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    await ref.read(missionRepositoryProvider.notifier).generateCoverage(
      spacingMeters: minLineSpacingMeters,
      orientationDegrees: 0,
    );
    if (!mounted) {
      return;
    }
    context.go('/job-execution');
  }

  Future<void> _showServerError() {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Server Error'),
          content: const Text(
            'Unable to reach server. Please connect and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _setOrientation(double degrees) {
    final mission = ref.read(missionRepositoryProvider);
    ref.read(missionRepositoryProvider.notifier).scheduleCoverage(
      spacingMeters: mission.spacingMeters,
      orientationDegrees: degrees,
    );
  }

  void _setSpacing(double spacingMeters) {
    final mission = ref.read(missionRepositoryProvider);
    ref.read(missionRepositoryProvider.notifier).scheduleCoverage(
      spacingMeters: spacingMeters,
      orientationDegrees: mission.orientationDegrees,
    );
  }

  void _frameBoundary() {
    final points = ref.read(missionRepositoryProvider).boundaryPoints;
    if (points.length < 2) {
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          for (final point in points)
            LatLng(point.latitude, point.longitude),
        ]),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  void _selectWaypoint(Waypoint waypoint) {
    setState(() => _selectedWaypointId = waypoint.id);
    _altitudeController.text = waypoint.altitude.toStringAsFixed(1);
    _speedController.text = waypoint.speed.toStringAsFixed(1);
  }

  void _deleteWaypoint(String id) {
    ref.read(missionRepositoryProvider.notifier).deleteWaypoint(id);
    if (_selectedWaypointId == id) {
      setState(() => _selectedWaypointId = null);
    }
  }

  void _updateSelected({
    double? altitude,
    double? speed,
    WaypointAction? action,
  }) {
    final mission = ref.read(missionRepositoryProvider);
    final waypoint = _waypointById(mission.waypoints, _selectedWaypointId);
    if (waypoint == null) {
      return;
    }
    ref.read(missionRepositoryProvider.notifier).updateWaypoint(
      waypoint.copyWith(altitude: altitude, speed: speed, action: action),
    );
  }

  Future<void> _saveMission() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _SaveMissionDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) {
      return;
    }
    ref.read(missionRepositoryProvider.notifier).saveMission(name.trim());
    _showMessage('Mission saved');
  }

  Future<void> _loadMission() async {
    final missions = ref.read(missionRepositoryProvider).savedMissions;
    if (missions.isEmpty) {
      _showMessage('No saved missions');
      return;
    }

    final id = await showDialog<String>(
      context: context,
      builder: (context) => _LoadMissionDialog(missions: missions),
    );
    if (id == null || !mounted) {
      return;
    }
    ref.read(missionRepositoryProvider.notifier).loadMission(id);
    setState(() => _selectedWaypointId = null);
  }

  void _uploadMission() {
    final waypoints = ref.read(missionRepositoryProvider).waypoints;
    if (waypoints.isEmpty) {
      _showMessage('Validation error: no waypoints to upload');
      return;
    }
    _showMessage('Mission uploaded (simulated)');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }
}

Waypoint? _waypointById(List<Waypoint> waypoints, String? id) {
  if (id == null) {
    return null;
  }
  for (final waypoint in waypoints) {
    if (waypoint.id == id) {
      return waypoint;
    }
  }
  return null;
}

class _CompactPlan extends StatelessWidget {
  const _CompactPlan({
    required this.map,
    required this.hasCoverage,
    required this.mission,
    required this.canCallForJob,
    required this.onCallForJob,
    required this.onOrientation,
    required this.onSpacing,
    required this.onOpenDetails,
  });

  final Widget map;
  final bool hasCoverage;
  final MissionState mission;
  final bool canCallForJob;
  final VoidCallback onCallForJob;
  final ValueChanged<double> onOrientation;
  final ValueChanged<double> onSpacing;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: map),
        Material(
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasCoverage)
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
                      if (hasCoverage)
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
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              onPressed: canCallForJob ? onCallForJob : null,
                              child: const Text('Call for Job'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              onPressed: onOpenDetails,
                              child: const Text('Plan details'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanMap extends StatelessWidget {
  const _PlanMap({
    required this.controller,
    required this.boundary,
    required this.mission,
    required this.pointA,
    required this.pointB,
    required this.placement,
    required this.onTap,
    required this.onMapReady,
  });

  final MapController controller;
  final List<LatLng> boundary;
  final MissionState mission;
  final LatLng? pointA;
  final LatLng? pointB;
  final _MapPlacement placement;
  final void Function(TapPosition tapPosition, LatLng point) onTap;
  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    final hint = switch (placement) {
      _MapPlacement.pointA => 'Tap the map to place point A',
      _MapPlacement.pointB => 'Tap the map to place point B',
      _MapPlacement.boundary => 'Tap the map to add a boundary point',
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: 16,
            onTap: onTap,
            onMapReady: onMapReady,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              cursorKeyboardRotationOptions:
                  CursorKeyboardRotationOptions.disabled(),
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
                    color: AppTheme.primary.withValues(alpha: 0.22),
                    borderColor: AppTheme.primary,
                    borderStrokeWidth: 2,
                  ),
                ],
              )
            else if (boundary.length == 2)
              PolylineLayer(
                polylines: [
                  Polyline(points: boundary, color: AppTheme.primary, strokeWidth: 2),
                ],
              ),
            if (mission.coverageLines.isNotEmpty)
              PolylineLayer(
                polylines: coveragePolylines(mission.coverageLines),
                simplificationTolerance: 0,
                cullingMargin: null,
              ),
            MarkerLayer(
              markers: [
                for (final point in mission.boundaryPoints)
                  Marker(
                    point: LatLng(point.latitude, point.longitude),
                    width: 28,
                    height: 28,
                    child: _IndexMarker(label: '${point.order + 1}'),
                  ),
                if (pointA != null)
                  Marker(
                    point: pointA!,
                    width: 28,
                    height: 28,
                    child: const _IndexMarker(label: 'A'),
                  ),
                if (pointB != null)
                  Marker(
                    point: pointB!,
                    width: 28,
                    height: 28,
                    child: const _IndexMarker(label: 'B'),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 12,
          top: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(hint),
            ),
          ),
        ),
      ],
    );
  }
}

class _IndexMarker extends StatelessWidget {
  const _IndexMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}

class _BoundaryActions extends StatelessWidget {
  const _BoundaryActions({
    required this.canCallForJob,
    required this.onReset,
    required this.onCallForJob,
  });

  final bool canCallForJob;
  final VoidCallback onReset;
  final VoidCallback onCallForJob;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onReset,
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: canCallForJob ? onCallForJob : null,
            child: const Text('Call for Job'),
          ),
        ),
      ],
    );
  }
}

class _PointPairSection extends StatelessWidget {
  const _PointPairSection({
    required this.pointA,
    required this.pointB,
    required this.placement,
    required this.operationMode,
    required this.onSetA,
    required this.onSetB,
    required this.onModeChanged,
  });

  final LatLng? pointA;
  final LatLng? pointB;
  final _MapPlacement placement;
  final String operationMode;
  final VoidCallback onSetA;
  final VoidCallback onSetB;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('A/B points'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PlaceButton(
                label: 'Set A',
                selected: placement == _MapPlacement.pointA,
                placed: pointA != null,
                onPressed: onSetA,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PlaceButton(
                label: 'Set B',
                selected: placement == _MapPlacement.pointB,
                placed: pointB != null,
                onPressed: onSetB,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: operationMode,
          decoration: const InputDecoration(
            labelText: 'Operation Mode',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'Spray', child: Text('Spray')),
            DropdownMenuItem(value: 'Survey', child: Text('Survey')),
            DropdownMenuItem(value: 'Manual', child: Text('Manual')),
          ],
          onChanged: (value) {
            if (value != null) {
              onModeChanged(value);
            }
          },
        ),
      ],
    );
  }
}

class _PlaceButton extends StatelessWidget {
  const _PlaceButton({
    required this.label,
    required this.selected,
    required this.placed,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool placed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = placed ? '$label placed' : label;
    if (selected) {
      return FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: onPressed,
        child: Text(text),
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: onPressed,
      child: Text(text),
    );
  }
}

class _WaypointList extends StatelessWidget {
  const _WaypointList({
    required this.waypoints,
    required this.selectedId,
    required this.onSelect,
    required this.onDelete,
  });

  final List<Waypoint> waypoints;
  final String? selectedId;
  final ValueChanged<Waypoint> onSelect;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Waypoints (${waypoints.length})'),
        const SizedBox(height: 4),
        if (waypoints.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No waypoints yet'),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              primary: false,
              itemCount: waypoints.length,
              itemBuilder: (context, index) {
                final waypoint = waypoints[index];
                return _WaypointRow(
                  index: index,
                  waypoint: waypoint,
                  selected: waypoint.id == selectedId,
                  onSelect: () => onSelect(waypoint),
                  onDelete: () => onDelete(waypoint.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _WaypointRow extends StatelessWidget {
  const _WaypointRow({
    required this.index,
    required this.waypoint,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final int index;
  final Waypoint waypoint;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      contentPadding: EdgeInsets.zero,
      title: Text('Waypoint ${index + 1}'),
      subtitle: Text(
        '${waypoint.altitude.toStringAsFixed(1)} m · '
        '${waypoint.speed.toStringAsFixed(1)} m/s',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit waypoint ${index + 1}',
            onPressed: onSelect,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete waypoint ${index + 1}',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _WaypointDetail extends StatelessWidget {
  const _WaypointDetail({
    required this.waypoint,
    required this.altitudeController,
    required this.speedController,
    required this.onAltitudeChanged,
    required this.onSpeedChanged,
    required this.onActionChanged,
  });

  final Waypoint? waypoint;
  final TextEditingController altitudeController;
  final TextEditingController speedController;
  final ValueChanged<double> onAltitudeChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<WaypointAction> onActionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Waypoint detail'),
        const SizedBox(height: 8),
        if (waypoint == null)
          const Text('Select a waypoint')
        else ...[
          TextField(
            controller: altitudeController,
            decoration: const InputDecoration(
              labelText: 'Altitude',
              suffixText: 'm',
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              final altitude = double.tryParse(value);
              if (altitude != null) {
                onAltitudeChanged(altitude);
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: speedController,
            decoration: const InputDecoration(
              labelText: 'Speed',
              suffixText: 'm/s',
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              final speed = double.tryParse(value);
              if (speed != null) {
                onSpeedChanged(speed);
              }
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<WaypointAction>(
            initialValue: waypoint!.action,
            decoration: const InputDecoration(
              labelText: 'Action',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: WaypointAction.waypoint,
                child: Text('Waypoint'),
              ),
              DropdownMenuItem(
                value: WaypointAction.loiter,
                child: Text('Loiter'),
              ),
              DropdownMenuItem(
                value: WaypointAction.land,
                child: Text('Land'),
              ),
            ],
            onChanged: (action) {
              if (action != null) {
                onActionChanged(action);
              }
            },
          ),
        ],
      ],
    );
  }
}

class _FlightHistory extends StatelessWidget {
  const _FlightHistory({required this.logs});

  final List<FlightLog> logs;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Flight History'),
      tilePadding: EdgeInsets.zero,
      children: [
        for (final log in logs)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(_formatLogDate(log.date)),
            subtitle: Text(_formatDuration(log.durationSeconds)),
            trailing: Text(log.status),
          ),
      ],
    );
  }
}

String _formatLogDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes}m ${remainder.toString().padLeft(2, '0')}s';
}

class _MissionActions extends StatelessWidget {
  const _MissionActions({
    required this.onSave,
    required this.onLoad,
    required this.onUpload,
  });

  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    );
    final filled = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          style: style,
          onPressed: onSave,
          child: const Text('Save Mission'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: style,
          onPressed: onLoad,
          child: const Text('Load Mission'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: filled,
          onPressed: onUpload,
          child: const Text('Upload Mission'),
        ),
      ],
    );
  }
}

class _CallForJobDialog extends StatefulWidget {
  const _CallForJobDialog();

  @override
  State<_CallForJobDialog> createState() => _CallForJobDialogState();
}

class _CallForJobDialogState extends State<_CallForJobDialog> {
  String _crop = 'Rice';
  final TextEditingController _sprayRateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _sprayRateError;

  @override
  void dispose() {
    _sprayRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _confirm() {
    final sprayText = _sprayRateController.text.trim();
    double? sprayRate;
    if (sprayText.isNotEmpty) {
      sprayRate = double.tryParse(sprayText);
      if (sprayRate == null) {
        setState(() => _sprayRateError = 'Enter a number');
        return;
      }
    }

    final notes = _notesController.text.trim();
    Navigator.of(context).pop(
      JobConfig(
        crop: _crop,
        sprayRate: sprayRate,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Call for Job'),
      content: SizedBox(
          width: Responsive.dialogWidth(context, 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _crop,
              decoration: const InputDecoration(labelText: 'Select Crop'),
              items: const [
                DropdownMenuItem(value: 'Rice', child: Text('Rice')),
                DropdownMenuItem(value: 'Wheat', child: Text('Wheat')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _crop = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sprayRateController,
              decoration: InputDecoration(
                labelText: 'Spray Rate',
                errorText: _sprayRateError,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Confirm')),
      ],
    );
  }
}

class _SaveMissionDialog extends StatefulWidget {
  const _SaveMissionDialog();

  @override
  State<_SaveMissionDialog> createState() => _SaveMissionDialogState();
}

class _SaveMissionDialogState extends State<_SaveMissionDialog> {
  final TextEditingController _nameController = TextEditingController(
    text: 'Mission',
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Mission'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_nameController.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _LoadMissionDialog extends StatelessWidget {
  const _LoadMissionDialog({required this.missions});

  final List<Mission> missions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Load Mission'),
      content: SizedBox(
        width: Responsive.dialogWidth(context, 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mission in missions)
              ListTile(
                title: Text(mission.name),
                onTap: () => Navigator.of(context).pop(mission.id),
              ),
          ],
        ),
      ),
    );
  }
}
