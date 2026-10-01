import 'dart:math';

import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class JoystickControl extends StatelessWidget {
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

  static const double _handleSize = 36;

  @override
  Widget build(BuildContext context) {
    final radians = degrees * pi / 180;
    final travel = (size - _handleSize) / 2;
    final handleLeft = size / 2 + cos(radians) * travel - _handleSize / 2;
    final handleTop = size / 2 + sin(radians) * travel - _handleSize / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(label),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onPanStart: (details) => _update(details.localPosition),
          onPanUpdate: (details) => _update(details.localPosition),
          child: SizedBox(
            width: size,
            height: size,
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
    final dx = localPosition.dx - size / 2;
    final dy = localPosition.dy - size / 2;
    if (dx == 0 && dy == 0) {
      return;
    }

    final nextDegrees = (atan2(dy, dx) * 180 / pi + 360) % 360;
    final rounded = nextDegrees.roundToDouble() % 360;
    if (rounded == degrees.roundToDouble()) {
      return;
    }
    onChanged(rounded);
  }
}
