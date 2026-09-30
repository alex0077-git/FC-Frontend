class FlightParameters {
  const FlightParameters({
    this.maxYawRate = 90,
    this.maxRollAngle = 30,
    this.maxPitchAngle = 20,
    this.maxSpeed = 12,
    this.cruiseSpeed = 8,
  });

  final double maxYawRate;
  final double maxRollAngle;
  final double maxPitchAngle;
  final double maxSpeed;
  final double cruiseSpeed;

  FlightParameters copyWith({
    double? maxYawRate,
    double? maxRollAngle,
    double? maxPitchAngle,
    double? maxSpeed,
    double? cruiseSpeed,
  }) {
    return FlightParameters(
      maxYawRate: maxYawRate ?? this.maxYawRate,
      maxRollAngle: maxRollAngle ?? this.maxRollAngle,
      maxPitchAngle: maxPitchAngle ?? this.maxPitchAngle,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      cruiseSpeed: cruiseSpeed ?? this.cruiseSpeed,
    );
  }
}
