import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/models/battery_settings.dart';
import 'package:fc_frontend/data/models/telemetry.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/data/repositories/telemetry_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

const _mapCenter = LatLng(12.9716, 77.5946);
const _landingPoint = LatLng(12.9700, 77.5930);

class MapFlightPage extends ConsumerStatefulWidget {
  const MapFlightPage({super.key});

  @override
  ConsumerState<MapFlightPage> createState() => _MapFlightPageState();
}

class _MapFlightPageState extends ConsumerState<MapFlightPage> {
  bool? _commandedArmed;

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryStreamProvider).asData?.value;
    final batterySettings = ref.watch(batterySettingsProvider);
    final armed = _commandedArmed ?? telemetry?.armed ?? false;

    return Scaffold(
      body: Column(
        children: [
          _StatusStrip(telemetry: telemetry, batterySettings: batterySettings),
          if (telemetry != null)
            _BatteryBanner(telemetry: telemetry, settings: batterySettings),
          Expanded(child: _FlightMap(telemetry: telemetry)),
          _TelemetryCards(telemetry: telemetry),
          _CommandRow(
            armed: armed,
            onArmDisarm: () => _onArmDisarm(armed),
            onTakeoff: _showCommandSent,
            onRtl: _onRtl,
            onLand: _showCommandSent,
          ),
        ],
      ),
    );
  }

  Future<void> _onArmDisarm(bool armed) async {
    final confirmed = await _confirm(
      title: armed ? 'Disarm' : 'Arm',
      message: armed ? 'Disarm the drone?' : 'Arm the drone?',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _commandedArmed = !armed);
    _showCommandSent();
  }

  Future<void> _onRtl() async {
    final confirmed = await _confirm(
      title: 'RTL',
      message: 'Command the drone to return to launch?',
    );
    if (!confirmed || !mounted) {
      return;
    }

    _showCommandSent();
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  void _showCommandSent() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Command sent (simulated)'),
        ),
      );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.telemetry, required this.batterySettings});

  final Telemetry? telemetry;
  final BatterySettings batterySettings;

  @override
  Widget build(BuildContext context) {
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;
    final battery = telemetry?.battery;
    return Material(
      color: AppTheme.surface,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: _StatusItem(
                icon: Icons.battery_std,
                label: battery == null
                    ? 'Battery --'
                    : 'Battery ${battery.toStringAsFixed(1)}%',
                color: _batteryColor(battery, batterySettings, statusColors),
              ),
            ),
            Expanded(
              child: _StatusItem(
                icon: Icons.satellite_alt,
                label: telemetry == null
                    ? 'GPS --'
                    : 'GPS ${telemetry!.gpsCount}',
              ),
            ),
            Expanded(
              child: _StatusItem(
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

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppTheme.text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: itemColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: itemColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _BatteryBanner extends StatelessWidget {
  const _BatteryBanner({required this.telemetry, required this.settings});

  final Telemetry telemetry;
  final BatterySettings settings;

  @override
  Widget build(BuildContext context) {
    final level = _batteryAlertLevel(telemetry.battery, settings);
    if (level == null) {
      return const SizedBox.shrink();
    }

    final statusColors = Theme.of(context).extension<AppStatusColors>()!;
    final critical = level == _BatteryAlertLevel.critical;
    final color = critical
        ? statusColors.statusCritical
        : statusColors.statusWarning;
    final message = critical ? 'Battery critical' : 'Battery low';

    return Material(
      color: color.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BatteryAlertLevel { warning, critical }

_BatteryAlertLevel? _batteryAlertLevel(double battery, BatterySettings settings) {
  if (battery < settings.secondWarningPercent) {
    return _BatteryAlertLevel.critical;
  }
  if (battery < settings.firstWarningPercent) {
    return _BatteryAlertLevel.warning;
  }
  return null;
}

Color _batteryColor(
  double? battery,
  BatterySettings settings,
  AppStatusColors statusColors,
) {
  final level = battery == null
      ? null
      : _batteryAlertLevel(battery, settings);
  return switch (level) {
    _BatteryAlertLevel.critical => statusColors.statusCritical,
    _BatteryAlertLevel.warning => statusColors.statusWarning,
    null => statusColors.statusGood,
  };
}

class _FlightMap extends StatelessWidget {
  const _FlightMap({required this.telemetry});

  final Telemetry? telemetry;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: const MapOptions(initialCenter: _mapCenter, initialZoom: 17),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'fc_frontend',
        ),
        if (telemetry != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(telemetry!.latitude, telemetry!.longitude),
                width: 36,
                height: 36,
                child: _DroneMarker(headingDegrees: telemetry!.heading),
              ),
            ],
          ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );
  }
}

class _DroneMarker extends StatelessWidget {
  const _DroneMarker({required this.headingDegrees});

  final double headingDegrees;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: Transform.rotate(
        angle: headingDegrees * pi / 180,
        child: const Icon(Icons.navigation, color: AppTheme.primary, size: 20),
      ),
    );
  }
}

class _TelemetryCards extends StatelessWidget {
  const _TelemetryCards({required this.telemetry});

  final Telemetry? telemetry;

  @override
  Widget build(BuildContext context) {
    final drone = telemetry == null
        ? null
        : LatLng(telemetry!.latitude, telemetry!.longitude);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _ReadingCard(
              label: 'Altitude',
              value: telemetry == null
                  ? '--'
                  : '${telemetry!.altitude.toStringAsFixed(1)} m',
            ),
          ),
          Expanded(
            child: _ReadingCard(
              label: 'Distance to Drone',
              value: drone == null ? '--' : _formatMeters(_mapCenter, drone),
            ),
          ),
          Expanded(
            child: _ReadingCard(
              label: 'Distance to Landing Point',
              value: drone == null
                  ? '--'
                  : _formatMeters(_landingPoint, drone),
            ),
          ),
          Expanded(
            child: _ReadingCard(
              label: 'Speed',
              value: telemetry == null
                  ? '--'
                  : '${telemetry!.speed.toStringAsFixed(1)} m/s',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.armed,
    required this.onArmDisarm,
    required this.onTakeoff,
    required this.onRtl,
    required this.onLand,
  });

  final bool armed;
  final VoidCallback onArmDisarm;
  final VoidCallback onTakeoff;
  final VoidCallback onRtl;
  final VoidCallback onLand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          _CommandButton(
            label: armed ? 'Disarm' : 'Arm',
            onPressed: onArmDisarm,
          ),
          _CommandButton(label: 'Takeoff', onPressed: onTakeoff),
          _CommandButton(label: 'RTL', onPressed: onRtl),
          _CommandButton(label: 'Land', onPressed: onLand),
        ],
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          onPressed: onPressed,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

String _formatMeters(LatLng from, LatLng to) {
  final meters = const Distance().as(LengthUnit.Meter, from, to);
  return '${meters.toStringAsFixed(0)} m';
}
