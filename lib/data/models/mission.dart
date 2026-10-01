import 'package:fc_frontend/data/models/waypoint.dart';

class Mission {
  const Mission({
    required this.id,
    required this.name,
    required this.waypoints,
  });

  final String id;
  final String name;
  final List<Waypoint> waypoints;
}
