enum WaypointAction { waypoint, loiter, land }

class Waypoint {
  const Waypoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.action,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final WaypointAction action;

  Waypoint copyWith({
    double? altitude,
    double? speed,
    WaypointAction? action,
  }) {
    return Waypoint(
      id: id,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      action: action ?? this.action,
    );
  }
}
