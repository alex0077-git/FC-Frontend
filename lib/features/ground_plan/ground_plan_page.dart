import 'package:fc_frontend/core/geometry/boundary_split.dart';
import 'package:fc_frontend/core/geometry/local_meters.dart';
import 'package:fc_frontend/core/map/map_view.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/coverage_adjust_controls.dart';
import 'package:fc_frontend/core/widgets/coverage_lines.dart';
import 'package:fc_frontend/core/widgets/obstacle_map_layers.dart';
import 'package:fc_frontend/data/models/boundary_point.dart';
import 'package:fc_frontend/data/models/flight_log.dart';
import 'package:fc_frontend/data/models/job_config.dart';
import 'package:fc_frontend/data/models/mission.dart';
import 'package:fc_frontend/data/models/waypoint.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/data/repositories/telemetry_repository.dart';
import 'package:fc_frontend/core/widgets/responsive.dart';
import 'package:fc_frontend/features/ground_plan/boundary_point_dialog.dart';
import 'package:fc_frontend/features/ground_plan/boundary_point_marker.dart';
import 'package:fc_frontend/features/ground_plan/obstacle_mapping_section.dart';
import 'package:fc_frontend/features/ground_plan/waypoint_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';


List<LatLng> _boundaryRing(MissionState mission) {
  final ordered = [...mission.boundaryPoints]
    ..sort((a, b) => a.order.compareTo(b.order));
  return [
    for (final point in ordered) LatLng(point.latitude, point.longitude),
  ];
}

enum _MapPlacement { boundary, pointA, pointB, split }

enum _SplitSlot { first, end }

enum _SidebarSection { boundary, split, obstacles, waypoints, history }

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
  _SplitSlot? _splitSlot;
  LatLng? _splitFirst;
  LatLng? _splitEnd;
  String _operationMode = 'Spray';
  String? _selectedWaypointId;
  bool _mappingObstacles = false;
  ObstacleTool? _obstacleTool;
  String? _selectedObstacleId;
  LatLng? _obstacleMoveOrigin;
  _SidebarSection? _openSection = _SidebarSection.boundary;

  @override
  void dispose() {
    _altitudeController.dispose();
    _speedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mission = ref.watch(missionRepositoryProvider);
    final selected = _waypointById(mission.waypoints, _selectedWaypointId);
    final hasCoverage = mission.coverageLines.isNotEmpty;
    final canUndo =
        !mission.boundaryEditingLocked && mission.undoHistory.isNotEmpty;
    final canRedo =
        !mission.boundaryEditingLocked && mission.redoHistory.isNotEmpty;
    ref.listen(missionRepositoryProvider, (previous, next) {
      final becameBlocked = next.coverageBlockedByObstacle &&
          previous?.coverageBlockedByObstacle != true;
      if (!becameBlocked) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage(
            'Coverage path intersects a no-fly zone -- review manually',
          );
        }
      });
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            _redoBoundary,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _redoBoundary,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redoBoundary,
        const SingleActivator(LogicalKeyboardKey.keyY, meta: true): _redoBoundary,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undoBoundary,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undoBoundary,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              Expanded(flex: 3, child: _planMap(mission)),
              SizedBox(
                width: Responsive.sidePanelWidth(context, desktopWidth: 340),
                child: Material(
                  color: AppTheme.surface,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          children: _planPanelChildren(
                            mission: mission,
                            selected: selected,
                            canUndo: canUndo,
                            canRedo: canRedo,
                          ),
                        ),
                      ),
                      if (hasCoverage)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: CoverageAdjustControls(),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: !mission.boundaryEditingLocked &&
                                  mission.boundaryPoints.length >= 3
                              ? _callForJob
                              : null,
                          child: const Text('Call for Job'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planMap(MissionState mission) {
    final savedSplit = mission.splits.isEmpty ? null : mission.splits.last;
    return _PlanMap(
      controller: _mapController,
      mission: mission,
      pointA: _pointA,
      pointB: _pointB,
      placement: _placement,
      splitFirst: _placement == _MapPlacement.split
          ? _splitFirst
          : savedSplit?.start,
      splitEnd: _placement == _MapPlacement.split ? _splitEnd : savedSplit?.end,
      obstacleMapping: _mappingObstacles,
      obstacleTool: _obstacleTool,
      selectedObstacleId: _selectedObstacleId,
      onMarkSplit: _markSplit,
      editingEnabled: !mission.boundaryEditingLocked,
      onTap: _onMapTap,
      onMapReady: _frameBoundary,
      onEditPoint: _editBoundaryPoint,
      onMovePoint: _moveBoundaryPoint,
    );
  }

  List<Widget> _planPanelChildren({
    required MissionState mission,
    required Waypoint? selected,
    required bool canUndo,
    required bool canRedo,
  }) {
    return [
      _SidebarSectionTile(
        icon: Icons.polyline_outlined,
        label: 'Boundary',
        expanded: _openSection == _SidebarSection.boundary,
        onTap: () => _toggleSidebar(_SidebarSection.boundary),
        child: _BoundaryActions(
          canUndo: canUndo,
          canRedo: canRedo,
          onUndo: _undoBoundary,
          onRedo: _redoBoundary,
          onReset: _resetBoundary,
        ),
      ),
      _SidebarSectionTile(
        icon: Icons.call_split,
        label: 'Split (A/B)',
        expanded: _openSection == _SidebarSection.split,
        onTap: () => _toggleSidebar(_SidebarSection.split),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldSplitControls(
              canSplit: mission.boundaryPoints.length >= 3,
              splitting: _placement == _MapPlacement.split,
              splitSlot: _splitSlot,
              firstPlaced: _splitFirst != null,
              endPlaced: _splitEnd != null,
              canUndoSplit: mission.splits.isNotEmpty,
              activeSplit: mission.activeSplit,
              sectionCount: _sectionCount(mission),
              onSplit: _toggleSplit,
              onUndoSplit: _undoSplit,
              onChooseFirst: () => _chooseSplitSlot(_SplitSlot.first),
              onChooseEnd: () => _chooseSplitSlot(_SplitSlot.end),
              onSelectSplitA: () => _selectSplit(0),
              onSelectSplitB: () => _selectSplit(1),
            ),
            const SizedBox(height: 12),
            _PointPairSection(
              pointA: _pointA,
              pointB: _pointB,
              placement: _placement,
              operationMode: _operationMode,
              onSetA: () => _togglePlacement(_MapPlacement.pointA),
              onSetB: () => _togglePlacement(_MapPlacement.pointB),
              onModeChanged: (mode) => setState(() => _operationMode = mode),
            ),
          ],
        ),
      ),
      _SidebarSectionTile(
        icon: Icons.block,
        label: 'Obstacles',
        expanded: _openSection == _SidebarSection.obstacles,
        onTap: () => _toggleSidebar(_SidebarSection.obstacles),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: _mappingObstacles
                    ? Colors.red.withValues(alpha: 0.12)
                    : null,
              ),
              onPressed: _toggleObstacleMapping,
              child: const Text('Add Obstacle'),
            ),
            const SizedBox(height: 8),
            ObstacleMappingSection(
              choosing: _mappingObstacles,
              tool: _obstacleTool,
              obstacles: mission.obstacles,
              selectedId: _selectedObstacleId,
              onCircle: () => _chooseObstacleTool(ObstacleTool.circle),
              onSquare: () => _chooseObstacleTool(ObstacleTool.square),
              onSelect: (id) => _selectObstacle(id, mission),
              onRadius: _setObstacleRadius,
              onSide: _setObstacleSide,
              onSave: _saveSelectedObstacle,
              onRemove: _removeSelectedObstacle,
              eastOffsetMeters: _obstacleOffset(mission).$1,
              northOffsetMeters: _obstacleOffset(mission).$2,
              onNudge: _nudgeSelectedObstacle,
              onOk: () => _commitObstacleMove(mission),
              onCancel: _cancelObstacleMove,
            ),
          ],
        ),
      ),
      _SidebarSectionTile(
        icon: Icons.place_outlined,
        label: 'Waypoints',
        expanded: _openSection == _SidebarSection.waypoints,
        onTap: () => _toggleSidebar(_SidebarSection.waypoints),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WaypointList(
              waypoints: mission.waypoints,
              selectedId: selected?.id,
              canEdit: !mission.boundaryEditingLocked,
              activeSplit: mission.activeSplit,
              onSelect: _selectWaypoint,
              onDelete: _deleteWaypoint,
            ),
            const SizedBox(height: 8),
            _WaypointDetail(
              waypoint: selected,
              canEdit: !mission.boundaryEditingLocked,
              altitudeController: _altitudeController,
              speedController: _speedController,
              onAltitudeChanged: (altitude) => _updateSelected(altitude: altitude),
              onSpeedChanged: (speed) => _updateSelected(speed: speed),
              onActionChanged: (action) => _updateSelected(action: action),
            ),
          ],
        ),
      ),
      _SidebarSectionTile(
        icon: Icons.history,
        label: 'History',
        expanded: _openSection == _SidebarSection.history,
        onTap: () => _toggleSidebar(_SidebarSection.history),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FlightHistory(
              logs: ref.read(missionRepositoryProvider.notifier).listFlightLogs(),
            ),
            const SizedBox(height: 12),
            _MissionActions(
              onSave: _saveMission,
              onLoad: _loadMission,
              onUpload: _uploadMission,
            ),
          ],
        ),
      ),
    ];
  }

  void _toggleSidebar(_SidebarSection section) {
    setState(() {
      _openSection = _openSection == section ? null : section;
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_mappingObstacles) {
      _onObstacleTap(point);
      return;
    }
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
        _placeBoundaryPoint(point);
      case _MapPlacement.split:
        _markSplit(point, onBoundary: false);
    }
  }

  void _toggleSplit() {
    setState(() {
      _clearObstacleMapping();
      _clearSplitDraft();
      if (_placement == _MapPlacement.split) {
        _placement = _MapPlacement.boundary;
      } else {
        _placement = _MapPlacement.split;
        _splitSlot = _SplitSlot.first;
      }
    });
  }

  void _toggleObstacleMapping() {
    setState(() {
      if (_mappingObstacles) {
        _clearObstacleMapping();
      } else {
        _clearSplitDraft();
        _placement = _MapPlacement.boundary;
        _mappingObstacles = true;
      }
    });
  }

  void _chooseObstacleTool(ObstacleTool tool) {
    setState(() {
      _clearSplitDraft();
      _placement = _MapPlacement.boundary;
      _mappingObstacles = true;
      _obstacleTool = tool;
      _selectedObstacleId = null;
      _obstacleMoveOrigin = null;
    });
  }

  void _clearObstacleMapping() {
    _mappingObstacles = false;
    _obstacleTool = null;
    _selectedObstacleId = null;
    _obstacleMoveOrigin = null;
  }

  void _selectObstacle(String id, MissionState mission) {
    setState(() {
      _selectedObstacleId = id;
      _obstacleMoveOrigin = _centerOf(mission, id);
    });
  }

  void _onObstacleTap(LatLng point) {
    final repository = ref.read(missionRepositoryProvider.notifier);
    final hit = repository.obstacleAt(point);
    if (_obstacleTool == ObstacleTool.circle) {
      if (hit != null) {
        _selectObstacle(hit.id, ref.read(missionRepositoryProvider));
        return;
      }
      final id = repository.addCircleObstacle(point);
      setState(() {
        _selectedObstacleId = id;
        _obstacleMoveOrigin = point;
      });
      return;
    }
    if (_obstacleTool == ObstacleTool.square) {
      if (hit != null) {
        _selectObstacle(hit.id, ref.read(missionRepositoryProvider));
        return;
      }
      final id = repository.addSquareObstacle(point);
      setState(() {
        _selectedObstacleId = id;
        _obstacleMoveOrigin = point;
      });
      return;
    }
    if (hit != null) {
      _selectObstacle(hit.id, ref.read(missionRepositoryProvider));
      return;
    }
    _showMessage('Choose Circle or Square first.');
  }

  void _setObstacleRadius(double meters) {
    final id = _selectedObstacleId;
    if (id == null) {
      return;
    }
    ref.read(missionRepositoryProvider.notifier).updateObstacleRadius(id, meters);
  }

  void _setObstacleSide(double meters) {
    final id = _selectedObstacleId;
    if (id == null) {
      return;
    }
    ref.read(missionRepositoryProvider.notifier).updateObstacleSide(id, meters);
  }

  void _saveSelectedObstacle() {
    final id = _selectedObstacleId;
    if (id == null) {
      return;
    }
    ref.read(missionRepositoryProvider.notifier).saveObstacle(id);
  }

  void _removeSelectedObstacle() {
    final id = _selectedObstacleId;
    if (id == null) {
      return;
    }
    ref.read(missionRepositoryProvider.notifier).removeObstacle(id);
    setState(() {
      _selectedObstacleId = null;
      _obstacleMoveOrigin = null;
    });
  }

  void _nudgeSelectedObstacle(double eastMeters, double northMeters) {
    final id = _selectedObstacleId;
    if (id == null) {
      return;
    }
    ref.read(missionRepositoryProvider.notifier).moveObstacle(
          id,
          eastMeters: eastMeters,
          northMeters: northMeters,
        );
  }

  void _commitObstacleMove(MissionState mission) {
    final id = _selectedObstacleId;
    if (id == null) {
      return;
    }
    setState(() => _obstacleMoveOrigin = _centerOf(mission, id));
  }

  void _cancelObstacleMove() {
    final id = _selectedObstacleId;
    final origin = _obstacleMoveOrigin;
    if (id == null || origin == null) {
      return;
    }
    ref.read(missionRepositoryProvider.notifier).placeObstacle(id, origin);
  }

  (double, double) _obstacleOffset(MissionState mission) {
    final id = _selectedObstacleId;
    final origin = _obstacleMoveOrigin;
    final center = id == null ? null : _centerOf(mission, id);
    if (origin == null || center == null) {
      return (0, 0);
    }
    return offsetMeters(origin, center);
  }

  LatLng? _centerOf(MissionState mission, String id) {
    for (final obstacle in mission.obstacles) {
      if (obstacle.id == id) {
        return obstacle.center;
      }
    }
    return null;
  }

  void _placeBoundaryPoint(LatLng point) {
    final repository = ref.read(missionRepositoryProvider.notifier);
    if (repository.isPointInsideAnyObstacle(point)) {
      _showMessage('Cannot place a waypoint inside a no-fly zone');
      return;
    }
    repository.addBoundaryPoint(
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  void _chooseSplitSlot(_SplitSlot slot) {
    setState(() {
      _clearObstacleMapping();
      _placement = _MapPlacement.split;
      _splitSlot = slot;
    });
  }

  void _markSplit(LatLng point, {required bool onBoundary}) {
    final slot = _splitSlot;
    if (_placement != _MapPlacement.split || slot == null) {
      _showMessage('Choose First Point or End Point first.');
      return;
    }
    final ring = _boundaryRing(ref.read(missionRepositoryProvider));
    final snapped = onBoundary ? point : snapToBoundary(ring, point);
    if (snapped == null) {
      _showMessage('Place the point on the boundary.');
      return;
    }
    setState(() {
      if (slot == _SplitSlot.first) {
        _splitFirst = snapped;
        _splitSlot = _SplitSlot.end;
      } else {
        _splitEnd = snapped;
      }
    });
    _commitSplitIfReady();
  }

  void _commitSplitIfReady() {
    final first = _splitFirst;
    final end = _splitEnd;
    if (first == null || end == null) {
      return;
    }
    final split = ref.read(missionRepositoryProvider.notifier).splitBoundary(
      startLatitude: first.latitude,
      startLongitude: first.longitude,
      endLatitude: end.latitude,
      endLongitude: end.longitude,
    );
    if (!split) {
      _showMessage('Those two points do not separate the field. Choose another point.');
    }
  }

  void _selectSplit(int section) {
    ref.read(missionRepositoryProvider.notifier).selectSplit(section);
  }

  void _clearSplitDraft() {
    _splitSlot = null;
    _splitFirst = null;
    _splitEnd = null;
  }

  void _undoSplit() {
    ref.read(missionRepositoryProvider.notifier).undoSplit();
    setState(() {
      _clearSplitDraft();
      _placement = _MapPlacement.boundary;
    });
  }

  int _sectionCount(MissionState mission) {
    if (mission.boundaryPoints.length < 3 || mission.splits.isEmpty) {
      return 1;
    }
    return boundarySections(_boundaryRing(mission), mission.splits).length;
  }

  void _togglePlacement(_MapPlacement target) {
    setState(() {
      _clearObstacleMapping();
      _placement = _placement == target ? _MapPlacement.boundary : target;
    });
  }

  void _undoBoundary() {
    ref.read(missionRepositoryProvider.notifier).undoBoundaryEdit();
  }

  void _redoBoundary() {
    ref.read(missionRepositoryProvider.notifier).redoBoundaryEdit();
  }

  void _moveBoundaryPoint(BoundaryPoint point, LatLng next) {
    final repository = ref.read(missionRepositoryProvider.notifier);
    if (repository.isPointInsideAnyObstacle(next)) {
      _showMessage('Cannot place a waypoint inside a no-fly zone');
      return;
    }
    repository.updateBoundaryPoint(
      id: point.id,
      latitude: next.latitude,
      longitude: next.longitude,
      altitude: point.altitude,
      speed: point.speed,
    );
  }

  Future<void> _editBoundaryPoint(BoundaryPoint point) async {
    if (ref.read(missionRepositoryProvider).boundaryEditingLocked) {
      return;
    }

    final result = await showDialog<BoundaryDialogResult>(
      context: context,
      builder: (context) => BoundaryPointDialog(point: point),
    );
    if (result == null || !mounted) {
      return;
    }

    final repository = ref.read(missionRepositoryProvider.notifier);
    if (result.deleted) {
      repository.deleteBoundaryPoint(point.id);
      return;
    }

    final draft = result.draft;
    if (draft == null) {
      return;
    }
    if (repository.isPointInsideAnyObstacle(
      LatLng(draft.latitude, draft.longitude),
    )) {
      _showMessage('Cannot place a waypoint inside a no-fly zone');
      return;
    }
    repository.updateBoundaryPoint(
      id: point.id,
      latitude: draft.latitude,
      longitude: draft.longitude,
      altitude: draft.altitude,
      speed: draft.speed,
    );
  }

  void _resetBoundary() {
    ref.read(missionRepositoryProvider.notifier).resetBoundary();
    setState(() {
      _selectedWaypointId = null;
      _clearSplitDraft();
      _clearObstacleMapping();
      _placement = _MapPlacement.boundary;
    });
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
    setState(() {
      _selectedWaypointId = waypoint.id;
      _openSection = _SidebarSection.waypoints;
    });
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

class _PlanMap extends StatefulWidget {
  const _PlanMap({
    required this.controller,
    required this.mission,
    required this.pointA,
    required this.pointB,
    required this.placement,
    required this.splitFirst,
    required this.splitEnd,
    required this.obstacleMapping,
    required this.obstacleTool,
    required this.selectedObstacleId,
    required this.editingEnabled,
    required this.onTap,
    required this.onMapReady,
    required this.onEditPoint,
    required this.onMovePoint,
    required this.onMarkSplit,
  });

  final MapController controller;
  final MissionState mission;
  final LatLng? pointA;
  final LatLng? pointB;
  final _MapPlacement placement;
  final LatLng? splitFirst;
  final LatLng? splitEnd;
  final bool obstacleMapping;
  final ObstacleTool? obstacleTool;
  final String? selectedObstacleId;
  final bool editingEnabled;
  final void Function(TapPosition tapPosition, LatLng point) onTap;
  final VoidCallback onMapReady;
  final ValueChanged<BoundaryPoint> onEditPoint;
  final void Function(BoundaryPoint point, LatLng next) onMovePoint;
  final void Function(LatLng point, {required bool onBoundary}) onMarkSplit;

  @override
  State<_PlanMap> createState() => _PlanMapState();
}

class _PlanMapState extends State<_PlanMap> {
  String? _previewId;
  LatLng? _preview;

  @override
  Widget build(BuildContext context) {
    final hint = widget.obstacleMapping
        ? switch (widget.obstacleTool) {
            ObstacleTool.circle => 'Tap the map to place a circle no-fly zone',
            ObstacleTool.square => 'Tap the map to place a square no-fly zone',
            null => 'Choose Circle or Square',
          }
        : switch (widget.placement) {
            _MapPlacement.pointA => 'Tap the map to place point A',
            _MapPlacement.pointB => 'Tap the map to place point B',
            _MapPlacement.split => 'Tap the boundary for the selected point',
            _MapPlacement.boundary => 'Tap the map to add a boundary point',
          };
    final points = _displayPoints();

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: defaultMapCenter,
            initialZoom: 16,
            onTap: widget.onTap,
            onMapReady: widget.onMapReady,
            interactionOptions: mapGestureOptions(),
          ),
          children: [
            const MapTileLayer(),
            if (points.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: points,
                    color: AppTheme.primary.withValues(alpha: 0.22),
                    borderColor: AppTheme.primary,
                    borderStrokeWidth: 2,
                  ),
                ],
              )
            else if (points.length == 2)
              PolylineLayer(
                polylines: [
                  Polyline(points: points, color: AppTheme.primary, strokeWidth: 2),
                ],
              ),
            if (widget.mission.coverageLines.isNotEmpty)
              PolylineLayer(
                polylines: coveragePolylines(
                  widget.mission.coverageLines,
                  paths: widget.mission.coveragePaths,
                  activeSplit: widget.mission.activeSplit,
                ),
                simplificationTolerance: 0,
              ),
            if (widget.mission.coverageLines.isEmpty)
              ...waypointPathLine(widget.mission.waypoints),
            ...obstacleMapLayers(
              obstacles: widget.mission.obstacles,
              selectedId: widget.selectedObstacleId,
            ),
            MarkerLayer(
              markers: [
                for (final point in widget.mission.boundaryPoints)
                  Marker(
                    key: ValueKey(point.id),
                    point: LatLng(point.latitude, point.longitude),
                    width: 44,
                    height: 44,
                    child: BoundaryPointMarker(
                      key: ValueKey(point.id),
                      point: LatLng(point.latitude, point.longitude),
                      label: '${point.order + 1}',
                      dimmed: _boundaryDimmed(
                        LatLng(point.latitude, point.longitude),
                      ),
                      enabled: widget.editingEnabled &&
                          widget.placement != _MapPlacement.split &&
                          !_boundaryDimmed(
                            LatLng(point.latitude, point.longitude),
                          ),
                      onTap: () {
                        final here = LatLng(point.latitude, point.longitude);
                        if (_boundaryDimmed(here)) {
                          return;
                        }
                        if (widget.placement == _MapPlacement.split) {
                          widget.onMarkSplit(here, onBoundary: true);
                          return;
                        }
                        widget.onEditPoint(point);
                      },
                      onPreview: (next) => setState(() {
                        _previewId = point.id;
                        _preview = next;
                      }),
                      onCommit: (next) {
                        widget.onMovePoint(point, next);
                        setState(() {
                          _previewId = null;
                          _preview = null;
                        });
                      },
                    ),
                  ),
                if (widget.pointA != null)
                  Marker(
                    point: widget.pointA!,
                    width: 28,
                    height: 28,
                    child: const _IndexMarker(label: 'A'),
                  ),
                if (widget.pointB != null)
                  Marker(
                    point: widget.pointB!,
                    width: 28,
                    height: 28,
                    child: const _IndexMarker(label: 'B'),
                  ),
                if (widget.splitFirst != null)
                  Marker(
                    point: widget.splitFirst!,
                    width: 36,
                    height: 36,
                    child: const _IndexMarker(label: 'F'),
                  ),
                if (widget.splitEnd != null)
                  Marker(
                    point: widget.splitEnd!,
                    width: 36,
                    height: 36,
                    child: const _IndexMarker(label: 'E'),
                  ),
              ],
            ),
            ...waypointPathMarkers(
              widget.mission.waypoints,
              activeSplit: widget.mission.activeSplit,
            ),
          ],
          ),
        ),
        const MapStyleToggle(),
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

  bool _boundaryDimmed(LatLng point) {
    final mission = widget.mission;
    if (mission.activeSplit < 0 || mission.splits.isEmpty) {
      return false;
    }
    final side = exclusiveSplitSide(
      _boundaryRing(mission),
      mission.splits,
      point,
    );
    return side != null && side != mission.activeSplit;
  }

  List<LatLng> _displayPoints() {
    return [
      for (final point in widget.mission.boundaryPoints)
        if (point.id == _previewId && _preview != null)
          _preview!
        else
          LatLng(point.latitude, point.longitude),
    ];
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

class _SidebarSectionTile extends StatelessWidget {
  const _SidebarSectionTile({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: Theme.of(context).textTheme.titleSmall),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: child,
          ),
        const Divider(height: 1),
      ],
    );
  }
}

class _BoundaryActions extends StatelessWidget {
  const _BoundaryActions({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HistoryButton(
          tooltip: 'Undo',
          icon: Icons.undo,
          onPressed: canUndo ? onUndo : null,
        ),
        _HistoryButton(
          tooltip: 'Redo',
          icon: Icons.redo,
          onPressed: canRedo ? onRedo : null,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onReset,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Reset'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldSplitControls extends StatelessWidget {
  const _FieldSplitControls({
    required this.canSplit,
    required this.splitting,
    required this.splitSlot,
    required this.firstPlaced,
    required this.endPlaced,
    required this.canUndoSplit,
    required this.activeSplit,
    required this.sectionCount,
    required this.onSplit,
    required this.onUndoSplit,
    required this.onChooseFirst,
    required this.onChooseEnd,
    required this.onSelectSplitA,
    required this.onSelectSplitB,
  });

  final bool canSplit;
  final bool splitting;
  final _SplitSlot? splitSlot;
  final bool firstPlaced;
  final bool endPlaced;
  final bool canUndoSplit;
  final int activeSplit;
  final int sectionCount;
  final VoidCallback onSplit;
  final VoidCallback onUndoSplit;
  final VoidCallback onChooseFirst;
  final VoidCallback onChooseEnd;
  final VoidCallback onSelectSplitA;
  final VoidCallback onSelectSplitB;

  @override
  Widget build(BuildContext context) {
    if (!canSplit) {
      return const Text('Draw at least three boundary points before splitting.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (splitting) ...[
          const Text(
            'Choose First Point or End Point, then tap a boundary point or anywhere along the boundary.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PlaceButton(
                  label: 'First Point',
                  selected: splitSlot == _SplitSlot.first,
                  placed: firstPlaced,
                  onPressed: onChooseFirst,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlaceButton(
                  label: 'End Point',
                  selected: splitSlot == _SplitSlot.end,
                  placed: endPlaced,
                  onPressed: onChooseEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
          ),
          onPressed: onSplit,
          child: Text(splitting ? 'Cancel' : 'Split'),
        ),
        if (canUndoSplit) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            onPressed: onUndoSplit,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Undo split'),
            ),
          ),
        ],
        if (sectionCount > 1) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PlaceButton(
                  label: 'Select Split A',
                  selected: activeSplit == 0,
                  placed: false,
                  onPressed: onSelectSplitA,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlaceButton(
                  label: 'Select Split B',
                  selected: activeSplit == 1,
                  placed: false,
                  onPressed: onSelectSplitB,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 40),
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
    required this.canEdit,
    required this.activeSplit,
    required this.onSelect,
    required this.onDelete,
  });

  final List<Waypoint> waypoints;
  final String? selectedId;
  final bool canEdit;
  final int activeSplit;
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
                final dimmed = activeSplit >= 0 && waypoint.sectionIndex != activeSplit;
                return _WaypointRow(
                  index: index,
                  label: waypointPathLabel(index, waypoints.length),
                  waypoint: waypoint,
                  selected: waypoint.id == selectedId && !dimmed,
                  dimmed: dimmed,
                  canEdit: canEdit && !dimmed,
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
    required this.label,
    required this.waypoint,
    required this.selected,
    required this.dimmed,
    required this.canEdit,
    required this.onSelect,
    required this.onDelete,
  });

  final int index;
  final String label;
  final Waypoint waypoint;
  final bool selected;
  final bool dimmed;
  final bool canEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final muted = dimmed ? const Color(0xFF94A3B8) : null;
    return ListTile(
      dense: true,
      selected: selected,
      enabled: !dimmed,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(color: muted),
      ),
      subtitle: Text(
        '${waypoint.altitude.toStringAsFixed(1)} m · '
        '${waypoint.speed.toStringAsFixed(1)} m/s · '
        '${waypoint.pumpOn ? 'Spray on' : 'Spray off'}',
        style: TextStyle(color: muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit $label',
            onPressed: canEdit ? onSelect : null,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete $label',
            onPressed: canEdit ? onDelete : null,
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
    required this.canEdit,
    required this.altitudeController,
    required this.speedController,
    required this.onAltitudeChanged,
    required this.onSpeedChanged,
    required this.onActionChanged,
  });

  final Waypoint? waypoint;
  final bool canEdit;
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
        if (waypoint != null)
          Text(waypoint!.pumpOn ? 'Spray on' : 'Spray off'),
        const SizedBox(height: 8),
        if (waypoint == null)
          const Text('Select a waypoint')
        else ...[
          TextField(
            controller: altitudeController,
            readOnly: !canEdit,
            decoration: const InputDecoration(
              labelText: 'Altitude',
              suffixText: 'm',
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: canEdit
                ? (value) {
                    final altitude = double.tryParse(value);
                    if (altitude != null) {
                      onAltitudeChanged(altitude);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: speedController,
            readOnly: !canEdit,
            decoration: const InputDecoration(
              labelText: 'Speed',
              suffixText: 'm/s',
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: canEdit
                ? (value) {
                    final speed = double.tryParse(value);
                    if (speed != null) {
                      onSpeedChanged(speed);
                    }
                  }
                : null,
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
            onChanged: canEdit
                ? (action) {
                    if (action != null) {
                      onActionChanged(action);
                    }
                  }
                : null,
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
    return Column(
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
