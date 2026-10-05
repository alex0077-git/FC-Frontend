import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/line_spacing_control.dart';
import 'package:fc_frontend/data/models/obstacle.dart';
import 'package:fc_frontend/features/ground_plan/obstacle_adjustment_panel.dart';
import 'package:fc_frontend/features/ground_plan/plan_history_button.dart';
import 'package:flutter/material.dart';

enum ObstacleTool { circle, polygon }

const _confirmColor = Color(0xFF22C55E);

/// Either the Circle/Polygon choice, or the controls for the shape being drawn.
/// The two are never on screen together.
class ObstacleMappingSection extends StatelessWidget {
  const ObstacleMappingSection({
    super.key,
    required this.tool,
    required this.polygonPoints,
    required this.radiusMeters,
    required this.canUndo,
    required this.canRedo,
    required this.eastOffsetMeters,
    required this.northOffsetMeters,
    required this.onCircle,
    required this.onPolygon,
    required this.onRadius,
    required this.onNudge,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
    required this.onOk,
  });

  final ObstacleTool? tool;
  final int polygonPoints;
  final double radiusMeters;
  final bool canUndo;
  final bool canRedo;
  final double eastOffsetMeters;
  final double northOffsetMeters;
  final VoidCallback onCircle;
  final VoidCallback onPolygon;
  final ValueChanged<double> onRadius;
  final void Function(double eastMeters, double northMeters) onNudge;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;
  final VoidCallback onOk;

  bool get _canConfirm =>
      tool == ObstacleTool.circle || polygonPoints >= 3;

  @override
  Widget build(BuildContext context) {
    if (tool == null) {
      return _ObstacleChooser(onCircle: onCircle, onPolygon: onPolygon);
    }
    return _ObstacleDraftControls(
      tool: tool!,
      polygonPoints: polygonPoints,
      radiusMeters: radiusMeters,
      canUndo: canUndo,
      canRedo: canRedo,
      canConfirm: _canConfirm,
      eastOffsetMeters: eastOffsetMeters,
      northOffsetMeters: northOffsetMeters,
      onRadius: onRadius,
      onNudge: onNudge,
      onUndo: onUndo,
      onRedo: onRedo,
      onReset: onReset,
      onOk: onOk,
    );
  }
}

class _ObstacleChooser extends StatelessWidget {
  const _ObstacleChooser({
    required this.onCircle,
    required this.onPolygon,
  });

  final VoidCallback onCircle;
  final VoidCallback onPolygon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShapeChoice(
          label: 'Circle',
          shape: _ShapeKind.circle,
          onPressed: onCircle,
        ),
        const SizedBox(height: 8),
        _ShapeChoice(
          label: 'Polygon',
          shape: _ShapeKind.polygon,
          onPressed: onPolygon,
        ),
      ],
    );
  }
}

enum _ShapeKind { circle, polygon }

class _ShapeChoice extends StatelessWidget {
  const _ShapeChoice({
    required this.label,
    required this.shape,
    required this.onPressed,
  });

  final String label;
  final _ShapeKind shape;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _ShapePainter(shape),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter(this.kind);

  final _ShapeKind kind;

  static const _fill = Color(0x4DEF4444);
  static const _stroke = Color(0xFFEF4444);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _fill;
    final stroke = Paint()
      ..color = _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    if (kind == _ShapeKind.circle) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.shortestSide / 2 - 3;
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, stroke);
      return;
    }
    final path = Path()
      ..moveTo(size.width * 0.50, 4)
      ..lineTo(size.width - 4, size.height * 0.38)
      ..lineTo(size.width * 0.78, size.height - 4)
      ..lineTo(size.width * 0.22, size.height * 0.82)
      ..lineTo(4, size.height * 0.42)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}

class _ObstacleDraftControls extends StatelessWidget {
  const _ObstacleDraftControls({
    required this.tool,
    required this.polygonPoints,
    required this.radiusMeters,
    required this.canUndo,
    required this.canRedo,
    required this.canConfirm,
    required this.eastOffsetMeters,
    required this.northOffsetMeters,
    required this.onRadius,
    required this.onNudge,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
    required this.onOk,
  });

  final ObstacleTool tool;
  final int polygonPoints;
  final double radiusMeters;
  final bool canUndo;
  final bool canRedo;
  final bool canConfirm;
  final double eastOffsetMeters;
  final double northOffsetMeters;
  final ValueChanged<double> onRadius;
  final void Function(double eastMeters, double northMeters) onNudge;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final circle = tool == ObstacleTool.circle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!circle && polygonPoints < 3)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Tap the map to place each corner, in order.'),
          ),
        if (circle)
          LineSpacingControl(
            title: 'Radius',
            decreaseTooltip: 'Decrease radius',
            increaseTooltip: 'Increase radius',
            spacingMeters: radiusMeters,
            lowerMeters: Obstacle.minSizeMeters,
            upperMeters: Obstacle.maxSizeMeters,
            onChanged: onRadius,
          ),
        if (circle) const SizedBox(height: 8),
        Row(
          children: [
            PlanHistoryButton(
              label: 'Undo',
              icon: Icons.undo,
              onPressed: canUndo ? onUndo : null,
            ),
            PlanHistoryButton(
              label: 'Redo',
              icon: Icons.redo,
              onPressed: canRedo ? onRedo : null,
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.red.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: onReset,
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: _confirmColor,
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFF1E3A2A),
            disabledForegroundColor: Colors.white70,
          ),
          onPressed: canConfirm ? onOk : null,
          child: const Text('OK'),
        ),
        const SizedBox(height: 8),
        const Text('Position'),
        const SizedBox(height: 4),
        ObstaclePositionPad(
          eastOffsetMeters: eastOffsetMeters,
          northOffsetMeters: northOffsetMeters,
          onNudge: onNudge,
        ),
      ],
    );
  }
}
