import 'dart:async';

import 'package:flutter/material.dart';

/// The four-direction pad that slides a no-fly zone by half a meter per tap.
class ObstaclePositionPad extends StatelessWidget {
  const ObstaclePositionPad({
    super.key,
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
