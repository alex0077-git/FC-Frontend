import 'package:fc_frontend/core/map/map_view.dart';
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

const _landingPoint = LatLng(12.9700, 77.5930);

class MapFlightPage extends ConsumerStatefulWidget {
  const MapFlightPage({super.key});

  @override
  ConsumerState<MapFlightPage> createState() => _MapFlightPageState();
}

class _MapFlightPageState extends ConsumerState<MapFlightPage> {
  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryStreamProvider).asData?.value;
    final batterySettings = ref.watch(batterySettingsProvider);

    final sideBySide = Responsive.useCompactMapLayout(context);
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
          ],
        ],
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

class _FlightMap extends ConsumerWidget {
  const _FlightMap({required this.telemetry});

  final Telemetry? telemetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final satellite = ref.watch(mapViewModeProvider) == MapViewMode.satellite;
    return MapModeStack(
      map: FlutterMap(
        options: const MapOptions(
          initialCenter: defaultMapCenter,
          initialZoom: 17,
        ),
        children: [
          const MapTileLayer(),
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
          Align(
            alignment: Alignment.bottomRight,
            child: ColoredBox(
              color: const Color(0xCC121A2B),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  satellite ? 'Tiles © Esri' : '© OpenStreetMap contributors',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      overlays: const [MapStyleToggle()],
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
        value: drone == null ? '--' : _formatMeters(defaultMapCenter, drone),
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

String _formatMeters(LatLng from, LatLng to) {
  final meters = const Distance().as(LengthUnit.Meter, from, to);
  return '${meters.toStringAsFixed(0)} m';
}
