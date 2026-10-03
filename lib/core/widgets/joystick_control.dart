import 'dart:math';

import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class JoystickControl extends StatefulWidget {
  const JoystickControl({
    super.key,
    required this.label,
    required this.degrees,
    required this.onChanged,
    this.size = 120,
  });

  final String label;
  final double degrees;
  final ValueChanged<double> onChanged;
  final double size;

  @override
  State<JoystickControl> createState() => _JoystickControlState();
}

class _JoystickControlState extends State<JoystickControl> {
  static const double _handleSize = 36;

  /// The angle under the finger. Kept here so the knob can move without
  /// waiting for the coverage path and waypoint list to rebuild.
  double? _dragDegrees;
  bool _dragging = false;

  double get _shownDegrees => _dragDegrees ?? widget.degrees;

  @override
  void didUpdateWidget(JoystickControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dragged = _dragDegrees;
    if (!_dragging && dragged != null && _sameAngle(widget.degrees, dragged)) {
      _dragDegrees = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final degrees = _shownDegrees;
    final radians = degrees * pi / 180;
    final travel = (widget.size - _handleSize) / 2;
    final handleLeft = widget.size / 2 + cos(radians) * travel - _handleSize / 2;
    final handleTop = widget.size / 2 + sin(radians) * travel - _handleSize / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(widget.label),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onPanStart: (details) => _update(details.localPosition),
          onPanUpdate: (details) => _update(details.localPosition),
          onPanEnd: (_) => _finishDrag(),
          onPanCancel: _finishDrag,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.background,
                border: Border.all(color: AppTheme.primary),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: handleLeft,
                    top: handleTop,
                    child: Container(
                      width: _handleSize,
                      height: _handleSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('${degrees.round()}°'),
      ],
    );
  }

  void _update(Offset localPosition) {
    final dx = localPosition.dx - widget.size / 2;
    final dy = localPosition.dy - widget.size / 2;
    if (dx == 0 && dy == 0) {
      return;
    }

    final nextDegrees = (atan2(dy, dx) * 180 / pi + 360) % 360;
    final rounded = nextDegrees.roundToDouble() % 360;
    if (_sameAngle(rounded, _shownDegrees)) {
      return;
    }
    _dragging = true;
    setState(() => _dragDegrees = rounded);
    widget.onChanged(rounded);
  }

  void _finishDrag() {
    _dragging = false;
    final dragged = _dragDegrees;
    if (dragged != null && _sameAngle(widget.degrees, dragged)) {
      setState(() => _dragDegrees = null);
    }
  }
}

bool _sameAngle(double a, double b) {
  final gap = (a - b).abs() % 360;
  return gap < 0.5 || gap > 359.5;
}
