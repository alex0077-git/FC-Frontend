import 'dart:async';

import 'package:fc_frontend/core/widgets/line_spacing_control.dart';
import 'package:fc_frontend/data/models/obstacle.dart';
import 'package:flutter/material.dart';

const _activeTabColor = Color(0xFF22C55E);

enum _AdjustTab { size, position }

/// Size and position controls for the obstacle that is selected on the map.
class ObstacleAdjustmentPanel extends StatefulWidget {
  const ObstacleAdjustmentPanel({
    super.key,
    required this.obstacle,
    required this.eastOffsetMeters,
    required this.northOffsetMeters,
    required this.onRadius,
    required this.onSide,
    required this.onSave,
    required this.onNudge,
    required this.onOk,
    required this.onCancel,
    required this.onRemove,
  });

  final Obstacle obstacle;
  final double eastOffsetMeters;
  final double northOffsetMeters;
  final ValueChanged<double> onRadius;
  final ValueChanged<double> onSide;
  final VoidCallback? onSave;
  final void Function(double eastMeters, double northMeters) onNudge;
  final VoidCallback onOk;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  @override
  State<ObstacleAdjustmentPanel> createState() => _ObstacleAdjustmentPanelState();
}

class _ObstacleAdjustmentPanelState extends State<ObstacleAdjustmentPanel> {
  final _tabsKey = GlobalKey();
  _AdjustTab _tab = _AdjustTab.size;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealTabs());
  }

  void _revealTabs() {
    final target = _tabsKey.currentContext;
    if (!mounted || target == null) {
      return;
    }
    Scrollable.ensureVisible(target, alignment: 0.15);
  }

  bool get _canEditSize {
    if (widget.obstacle.type == ObstacleType.circle) {
      return true;
    }
    return widget.obstacle.type == ObstacleType.square && !widget.obstacle.finalized;
  }

  String get _sizeLabel {
    return widget.obstacle.type == ObstacleType.square ? 'Side' : 'Radius';
  }

  @override
  Widget build(BuildContext context) {
    final tab = _canEditSize ? _tab : _AdjustTab.position;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Obstacle adjustment')),
            IconButton(
              tooltip: 'Remove zone',
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        Row(
          key: _tabsKey,
          children: [
            if (_canEditSize)
              Expanded(
                child: _TabButton(
                  label: _sizeLabel,
                  selected: tab == _AdjustTab.size,
                  onPressed: () => setState(() => _tab = _AdjustTab.size),
                ),
              ),
            if (_canEditSize) const SizedBox(width: 8),
            Expanded(
              child: _TabButton(
                label: 'Position',
                selected: tab == _AdjustTab.position,
                onPressed: () => setState(() => _tab = _AdjustTab.position),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tab == _AdjustTab.size) ...[
          if (widget.obstacle.type == ObstacleType.circle)
            LineSpacingControl(
              title: '',
              decreaseTooltip: 'Decrease radius',
              increaseTooltip: 'Increase radius',
              spacingMeters:
                  widget.obstacle.radiusMeters ?? Obstacle.defaultRadiusMeters,
              lowerMeters: Obstacle.minSizeMeters,
              upperMeters: Obstacle.maxSizeMeters,
              onChanged: widget.onRadius,
            ),
          if (widget.obstacle.type == ObstacleType.square &&
              !widget.obstacle.finalized) ...[
            LineSpacingControl(
              title: '',
              decreaseTooltip: 'Decrease side',
              increaseTooltip: 'Increase side',
              spacingMeters: widget.obstacle.sideMeters ?? Obstacle.defaultSideMeters,
              lowerMeters: Obstacle.minSizeMeters,
              upperMeters: Obstacle.maxSizeMeters,
              onChanged: widget.onSide,
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: widget.onSave,
              child: const Text('Save'),
            ),
          ],
        ] else
          _PositionPad(
            eastOffsetMeters: widget.eastOffsetMeters,
            northOffsetMeters: widget.northOffsetMeters,
            onNudge: widget.onNudge,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: _activeTabColor,
                  foregroundColor: Colors.black,
                ),
                onPressed: widget.onOk,
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(label);
    if (selected) {
      return FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          backgroundColor: _activeTabColor,
          foregroundColor: Colors.black,
        ),
        onPressed: onPressed,
        child: child,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
      onPressed: onPressed,
      child: child,
    );
  }
}

class _PositionPad extends StatelessWidget {
  const _PositionPad({
    required this.eastOffsetMeters,
    required this.northOffsetMeters,
    required this.onNudge,
  });

  final double eastOffsetMeters;
  final double northOffsetMeters;
  final void Function(double eastMeters, double northMeters) onNudge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: _HoldArrow(
                  tooltip: 'Move north',
                  icon: Icons.keyboard_arrow_up,
                  onStep: () => onNudge(0, _nudgeMeters),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _HoldArrow(
                  tooltip: 'Move south',
                  icon: Icons.keyboard_arrow_down,
                  onStep: () => onNudge(0, -_nudgeMeters),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _HoldArrow(
                  tooltip: 'Move west',
                  icon: Icons.keyboard_arrow_left,
                  onStep: () => onNudge(-_nudgeMeters, 0),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _HoldArrow(
                  tooltip: 'Move east',
                  icon: Icons.keyboard_arrow_right,
                  onStep: () => onNudge(_nudgeMeters, 0),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _OffsetReadout(
              icon: Icons.arrow_upward,
              meters: northOffsetMeters,
            ),
            const SizedBox(width: 16),
            _OffsetReadout(
              icon: Icons.arrow_forward,
              meters: eastOffsetMeters,
            ),
          ],
        ),
      ],
    );
  }
}

const _nudgeMeters = 0.5;

class _HoldArrow extends StatefulWidget {
  const _HoldArrow({
    required this.tooltip,
    required this.icon,
    required this.onStep,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onStep;

  @override
  State<_HoldArrow> createState() => _HoldArrowState();
}

class _HoldArrowState extends State<_HoldArrow> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _start() {
    widget.onStep();
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 120), (_) {
      widget.onStep();
    });
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: IconButton(
        tooltip: widget.tooltip,
        onPressed: () {},
        icon: Icon(widget.icon),
      ),
    );
  }
}

class _OffsetReadout extends StatelessWidget {
  const _OffsetReadout({
    required this.icon,
    required this.meters,
  });

  final IconData icon;
  final double meters;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text(meters.toStringAsFixed(1)),
      ],
    );
  }
}
