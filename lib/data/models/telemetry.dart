class Telemetry {
  const Telemetry({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.heading,
    required this.roll,
    required this.pitch,
    required this.battery,
    required this.gpsCount,
    required this.mode,
    required this.armed,
  });

  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double heading;
  final double roll;
  final double pitch;
  final double battery;
  final int gpsCount;
  final String mode;
  final bool armed;
}
