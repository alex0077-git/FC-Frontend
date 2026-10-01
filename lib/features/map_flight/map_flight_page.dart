import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/responsive.dart';
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

    final sideBySide = Responsive.useCompactMapLayout(context);
    final commands = _CommandRow(
      armed: armed,
      stacked: sideBySide,
      onArmDisarm: () => _onArmDisarm(armed),
      onTakeoff: _showCommandSent,
      onRtl: _onRtl,
      onLand: _showCommandSent,
    );
    final map = _FlightMap(telemetry: telemetry);

    return Scaffold(
      body: Column(
        children: [
          if (telemetry != null)
            _BatteryBanner(telemetry: telemetry, settings: batterySettings),
          if (sideBySide)
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 3, child: map),
                  SizedBox(
                    width: Responsive.sidePanelWidth(context, desktopWidth: 260),
                    child: Material(
                      color: AppTheme.surface,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                        children: [
                          _TelemetryCards(
                            telemetry: telemetry,
                            stacked: true,
                          ),
                          commands,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Expanded(child: map),
            _TelemetryCards(telemetry: telemetry),
            commands,
          ],
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
      child: SizedBox(
        height: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                message,
                style: TextStyle(fontSize: 11, height: 1.1, color: color),
              ),
            ],
          ),
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
        const Align(
          alignment: Alignment.bottomRight,
          child: ColoredBox(
            color: Color(0xCC121A2B),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                '© OpenStreetMap contributors',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
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
  const _TelemetryCards({required this.telemetry, this.stacked = false});

  final Telemetry? telemetry;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final drone = telemetry == null
        ? null
        : LatLng(telemetry!.latitude, telemetry!.longitude);
    final readings = [
      (
        label: 'Altitude',
        value: telemetry == null
            ? '--'
            : '${telemetry!.altitude.toStringAsFixed(1)} m',
      ),
      (
        label: 'Distance to Drone',
        value: drone == null ? '--' : _formatMeters(_mapCenter, drone),
      ),
      (
        label: 'Distance to Landing Point',
        value: drone == null ? '--' : _formatMeters(_landingPoint, drone),
      ),
      (
        label: 'Speed',
        value: telemetry == null
            ? '--'
            : '${telemetry!.speed.toStringAsFixed(1)} m/s',
      ),
    ];
    if (stacked) {
      return Column(
        children: [
          for (final reading in readings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      reading.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: Color(0xFFC5CEDB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    reading.value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    final cards = [
      for (final reading in readings)
        _ReadingCard(label: reading.label, value: reading.value),
    ];
    final width = Responsive.widthOf(context);
    if (width < Responsive.desktopMinWidth) {
      return SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          itemCount: cards.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            return SizedBox(width: 220, child: cards[index]);
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final card in cards) Expanded(child: card)],
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.2, color: Color(0xFFC5CEDB)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
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
    required this.stacked,
    required this.onArmDisarm,
    required this.onTakeoff,
    required this.onRtl,
    required this.onLand,
  });

  final bool armed;
  final bool stacked;
  final VoidCallback onArmDisarm;
  final VoidCallback onTakeoff;
  final VoidCallback onRtl;
  final VoidCallback onLand;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _CommandButton(label: armed ? 'Disarm' : 'Arm', onPressed: onArmDisarm),
      _CommandButton(label: 'Takeoff', onPressed: onTakeoff),
      _CommandButton(label: 'RTL', onPressed: onRtl),
      _CommandButton(label: 'Land', onPressed: onLand),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: stacked
          ? Column(
              children: [
                Row(children: [buttons[0], buttons[1]]),
                const SizedBox(height: 8),
                Row(children: [buttons[2], buttons[3]]),
              ],
            )
          : Row(children: buttons),
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
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
