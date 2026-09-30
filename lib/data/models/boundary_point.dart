class BoundaryPoint {
  const BoundaryPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.order,
  });

  final String id;
  final double latitude;
  final double longitude;
  final int order;
}
