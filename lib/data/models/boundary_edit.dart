import 'package:fc_frontend/data/models/boundary_point.dart';

enum BoundaryEditKind { add, move, delete }

/// One planning change, stored as the boundary list before and after it.
class BoundaryEdit {
  const BoundaryEdit({
    required this.kind,
    required this.before,
    required this.after,
  });

  final BoundaryEditKind kind;
  final List<BoundaryPoint> before;
  final List<BoundaryPoint> after;
}
