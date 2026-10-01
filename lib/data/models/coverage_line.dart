import 'package:latlong2/latlong.dart';

class CoverageLine {
  const CoverageLine({
    required this.endpoints,
    this.sectionIndex = 0,
    this.startsRoute = false,
  }) : assert(endpoints.length == 2, 'A coverage line has two endpoints');

  final List<LatLng> endpoints;

  /// Which split section this pass belongs to. Passes in one section stay
  /// out of every other section.
  final int sectionIndex;

  /// When true, this pass starts its own path so the map does not draw a
  /// connector through a gap, such as a no-fly zone that removed a pass.
  final bool startsRoute;
}
