import 'dart:math';

import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class OrientationJoystick extends StatelessWidget {
  const OrientationJoystick({
    super.key,
    required this.degrees,
    required this.onChanged,
  });

  final double degrees;
  final ValueChanged<double> onChanged;

  static const double _size = 120;
  static const double _handleSize = 28;

  @override
  Widget build(BuildContext context) {
    final radians = degrees * pi / 180;
    final travel = (_size - _handleSize) / 2;
    final handleLeft = _size / 2 + cos(radians) * travel - _handleSize / 2;
    final handleTop = _size / 2 + sin(radians) * travel - _handleSize / 2;

    return Column(
      children: [
        const Text('Orientation'),
        const SizedBox(height: 8),
        GestureDetector(
          onPanStart: (details) => _update(context, details.localPosition),
          onPanUpdate: (details) => _update(context, details.localPosition),
          child: SizedBox(
            width: _size,
            height: _size,
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

  void _update(BuildContext context, Offset localPosition) {
    final dx = localPosition.dx - _size / 2;
    final dy = localPosition.dy - _size / 2;
    if (dx == 0 && dy == 0) {
      return;
    }

    final degrees = (atan2(dy, dx) * 180 / pi + 360) % 360;
    final rounded = degrees.roundToDouble() % 360;
    if (rounded == this.degrees.roundToDouble()) {
      return;
    }
    onChanged(rounded);
  }
}
