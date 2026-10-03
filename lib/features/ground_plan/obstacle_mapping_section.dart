import 'package:fc_frontend/data/models/obstacle.dart';
import 'package:fc_frontend/features/ground_plan/obstacle_adjustment_panel.dart';
import 'package:flutter/material.dart';

enum ObstacleTool { circle, square }

/// Circle and square choices, plus the live size controls for a selected zone.
class ObstacleMappingSection extends StatelessWidget {
  const ObstacleMappingSection({
    super.key,
    required this.choosing,
    required this.tool,
    required this.obstacles,
    required this.selectedId,
    required this.onCircle,
    required this.onSquare,
    required this.onSelect,
    required this.onRadius,
    required this.onSide,
    required this.onSave,
    required this.onRemove,
    required this.eastOffsetMeters,
    required this.northOffsetMeters,
    required this.onNudge,
    required this.onOk,
    required this.onCancel,
  });

  final bool choosing;
  final ObstacleTool? tool;
  final List<Obstacle> obstacles;
  final String? selectedId;
  final VoidCallback onCircle;
  final VoidCallback onSquare;
  final ValueChanged<String> onSelect;
  final ValueChanged<double> onRadius;
  final ValueChanged<double> onSide;
  final VoidCallback onSave;
  final VoidCallback onRemove;
  final double eastOffsetMeters;
  final double northOffsetMeters;
  final void Function(double eastMeters, double northMeters) onNudge;
  final VoidCallback onOk;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final selected = _selected();
    final editingSquare = selected != null &&
        selected.type == ObstacleType.square &&
        !selected.finalized;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (choosing) ...[
          Text(_hint()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ToolButton(
                  label: 'Circle',
                  selected: tool == ObstacleTool.circle,
                  onPressed: onCircle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToolButton(
                  label: 'Square',
                  selected: tool == ObstacleTool.square,
                  onPressed: onSquare,
                ),
              ),
            ],
          ),
        ],
        if (obstacles.isEmpty && !choosing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No obstacles yet'),
          ),
        for (final obstacle in obstacles) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              backgroundColor: obstacle.id == selectedId
                  ? Colors.red.withValues(alpha: 0.12)
                  : null,
            ),
            onPressed: () => onSelect(obstacle.id),
            child: Text(
              obstacle.type == ObstacleType.circle ? 'Circle zone' : 'Square zone',
            ),
          ),
          if (selected != null && obstacle.id == selected.id)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ObstacleAdjustmentPanel(
                key: ValueKey(selected.id),
                obstacle: selected,
                eastOffsetMeters: eastOffsetMeters,
                northOffsetMeters: northOffsetMeters,
                onRadius: onRadius,
                onSide: onSide,
                onSave: editingSquare ? onSave : null,
                onNudge: onNudge,
                onOk: onOk,
                onCancel: onCancel,
                onRemove: onRemove,
              ),
            ),
        ],
      ],
    );
  }

  Obstacle? _selected() {
    for (final obstacle in obstacles) {
      if (obstacle.id == selectedId) {
        return obstacle;
      }
    }
    return null;
  }

  String _hint() {
    return switch (tool) {
      ObstacleTool.circle =>
        'Tap the map to place a circle. Tap a red zone to resize it.',
      ObstacleTool.square =>
        'Tap the map to place a square, set its side, then press Save.',
      null => 'Choose Circle or Square, then tap the map.',
    };
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        backgroundColor: selected ? Colors.red.withValues(alpha: 0.12) : null,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
