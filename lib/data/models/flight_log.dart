class FlightLog {
  const FlightLog({
    required this.date,
    required this.durationSeconds,
    required this.status,
  });

  final DateTime date;
  final int durationSeconds;
  final String status;
}
