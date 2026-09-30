import 'package:latlong2/latlong.dart';

class CoverageLine {
  const CoverageLine({
    required this.id,
    required this.endpoints,
    required this.lineIndex,
  }) : assert(endpoints.length == 2, 'A coverage line has two endpoints');

  final String id;
  final List<LatLng> endpoints;
  final int lineIndex;
}
