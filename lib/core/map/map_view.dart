import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum MapViewMode { street, satellite }

class MapViewController extends StateNotifier<MapViewMode> {
  MapViewController() : super(MapViewMode.street);

  void setMode(MapViewMode mode) {
    state = mode;
  }

  void toggle() {
    state = state == MapViewMode.street
        ? MapViewMode.satellite
        : MapViewMode.street;
  }
}

final mapViewModeProvider = StateNotifierProvider<MapViewController, MapViewMode>(
  (ref) => MapViewController(),
);

class MapTileLayer extends ConsumerWidget {
  const MapTileLayer({super.key});

  static const streetUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const satelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final satellite = ref.watch(mapViewModeProvider) == MapViewMode.satellite;
    if (satellite) {
      return TileLayer(
        urlTemplate: satelliteUrl,
        userAgentPackageName: 'fc_frontend',
      );
    }
    return TileLayer(
      urlTemplate: streetUrl,
      userAgentPackageName: 'fc_frontend',
    );
  }
}

class MapStyleButton extends ConsumerWidget {
  const MapStyleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final satellite = ref.watch(mapViewModeProvider) == MapViewMode.satellite;
    return Material(
      color: AppTheme.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: satellite ? 'Street map' : 'Satellite map',
        onPressed: () => ref.read(mapViewModeProvider.notifier).toggle(),
        icon: Icon(satellite ? Icons.map : Icons.satellite_alt),
      ),
    );
  }
}

class MapStyleToggle extends StatelessWidget {
  const MapStyleToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: MapStyleButton(),
      ),
    );
  }
}
