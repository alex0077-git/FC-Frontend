import 'dart:math';

import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class JoystickControl extends StatefulWidget {
  const JoystickControl({
    super.key,
    required this.label,
    required this.degrees,
    required this.onChanged,
    this.onDragStart,
    this.onDragEnd,
    this.size = 120,
  });

  final String label;
  final double degrees;
  final ValueChanged<double> onChanged;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final double size;

  @override
  State<JoystickControl> createState() => _JoystickControlState();
}

class _JoystickControlState extends State<JoystickControl> {
  static const double _handleSize = 36;

  /// The angle under the finger, and where the knob is drawn. Kept here so
  /// the knob can move without waiting for the coverage path to rebuild.
  double? _dragDegrees;
  double? _reportedDegrees;
  Offset? _knobFromCenter;
  bool _dragging = false;

  double get _shownDegrees => _dragDegrees ?? widget.degrees;

  @override
  void didUpdateWidget(JoystickControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clearDragIfParentCaughtUp();
  }

  @override
  Widget build(BuildContext context) {
    final degrees = _shownDegrees;
    final radians = degrees * pi / 180;
    final travel = (widget.size - _handleSize) / 2;
    final knob = _knobFromCenter ??
        Offset(cos(radians) * travel, sin(radians) * travel);
    final handleLeft = widget.size / 2 + knob.dx - _handleSize / 2;
    final handleTop = widget.size / 2 + knob.dy - _handleSize / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(widget.label),
          const SizedBox(height: 8),
        ],
        RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _EagerPanRecognizer:
                GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
              () => _EagerPanRecognizer(),
              (_EagerPanRecognizer instance) {
                instance
                  ..onStart = (details) {
                    _onPanStart(details.localPosition);
                  }
                  ..onUpdate = (details) {
                    _onPanUpdate(details.localPosition);
                  }
                  ..onEnd = (_) {
                    _onPanEnd();
                  }
                  ..onCancel = _onPanEnd;
              },
            ),
          },
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
        Text('${(degrees.round()) % 360}°'),
      ],
    );
  }

  void _onPanStart(Offset localPosition) {
    _dragging = true;
    widget.onDragStart?.call();
    _track(localPosition);
  }

  void _onPanUpdate(Offset localPosition) {
    _track(localPosition);
  }

  void _onPanEnd() {
    _finishDrag();
  }

  void _track(Offset localPosition) {
    final dx = localPosition.dx - widget.size / 2;
    final dy = localPosition.dy - widget.size / 2;
    final distance = sqrt(dx * dx + dy * dy);
    // The exact center has no direction. Anywhere else, the knob sits under
    // the finger and the heading is that direction.
    if (distance < 1) {
      _dragging = true;
      return;
    }

    final travel = (widget.size - _handleSize) / 2;
    final scale = distance > travel ? travel / distance : 1.0;
    final nextDegrees = (atan2(dy, dx) * 180 / pi + 360) % 360;
    if (_knobShouldMove(nextDegrees)) {
      setState(() {
        _dragDegrees = nextDegrees;
        _knobFromCenter = Offset(dx * scale, dy * scale);
      });
    }
    final reported = _reportedDegrees ?? widget.degrees;
    if (_sameAngle(nextDegrees, reported)) {
      _reportedDegrees = reported;
      return;
    }
    _reportedDegrees = nextDegrees;
    widget.onChanged(nextDegrees);
  }

  void _finishDrag() {
    final wasDragging = _dragging;
    _dragging = false;
    _reportedDegrees = null;
    _knobFromCenter = null;
    setState(_clearDragIfParentCaughtUp);
    if (wasDragging) {
      widget.onDragEnd?.call();
    }
  }

  void _clearDragIfParentCaughtUp() {
    final dragged = _dragDegrees;
    if (!_dragging && dragged != null && _sameAngle(widget.degrees, dragged)) {
      _dragDegrees = null;
    }
  }

  bool _knobShouldMove(double nextDegrees) {
    final current = _dragDegrees;
    if (current == null) {
      return !_sameAngle(nextDegrees, widget.degrees);
    }
    final gap = (nextDegrees - current).abs() % 360;
    return gap > 0.2 && gap < 359.8;
  }
}

/// A pan that starts on the first touch, including the empty middle of the
/// disc, so the parent scroll view cannot take the drag.
class _EagerPanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

bool _sameAngle(double a, double b) {
  final gap = (a - b).abs() % 360;
  return gap < 0.15 || gap > 359.85;
}
