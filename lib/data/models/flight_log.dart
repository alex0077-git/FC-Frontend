class FlightLog {
  const FlightLog({
    required this.id,
    required this.date,
    required this.durationSeconds,
    required this.status,
  });

  final String id;
  final DateTime date;
  final int durationSeconds;
  final String status;
}
