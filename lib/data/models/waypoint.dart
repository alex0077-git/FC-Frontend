enum WaypointAction { waypoint, loiter, land }

class Waypoint {
  const Waypoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.action,
    this.sectionIndex = 0,
    this.pumpOn = true,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final WaypointAction action;
  final int sectionIndex;

  /// False while this point is on the straight detour around a no-fly zone.
  /// The sprayer stays on for ordinary coverage.
  final bool pumpOn;

  Waypoint copyWith({
    double? altitude,
    double? speed,
    WaypointAction? action,
    bool? pumpOn,
  }) {
    return Waypoint(
      id: id,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      action: action ?? this.action,
      sectionIndex: sectionIndex,
      pumpOn: pumpOn ?? this.pumpOn,
    );
  }
}
