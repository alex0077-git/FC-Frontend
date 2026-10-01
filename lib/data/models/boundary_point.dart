class BoundaryPoint {
  const BoundaryPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.order,
    this.altitude = defaultAltitude,
    this.speed = defaultSpeed,
  });

  static const defaultAltitude = 30.0;
  static const defaultSpeed = 5.0;

  final String id;
  final double latitude;
  final double longitude;
  final int order;
  final double altitude;
  final double speed;

  BoundaryPoint copyWith({
    double? latitude,
    double? longitude,
    int? order,
    double? altitude,
    double? speed,
  }) {
    return BoundaryPoint(
      id: id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      order: order ?? this.order,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
    );
  }
}
