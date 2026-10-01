import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A boundary marker that can be tapped, or dragged without moving the map.
class BoundaryPointMarker extends StatefulWidget {
  const BoundaryPointMarker({
    super.key,
    required this.point,
    required this.label,
    required this.enabled,
    this.dimmed = false,
    required this.onTap,
    required this.onPreview,
    required this.onCommit,
  });

  final LatLng point;
  final String label;
  final bool enabled;
  final bool dimmed;
  final VoidCallback onTap;
  final ValueChanged<LatLng> onPreview;
  final ValueChanged<LatLng> onCommit;

  @override
  State<BoundaryPointMarker> createState() => _BoundaryPointMarkerState();
}

class _BoundaryPointMarkerState extends State<BoundaryPointMarker> {
  Offset _shift = Offset.zero;
  bool _dragging = false;
  LatLng? _start;

  @override
  void didUpdateWidget(BoundaryPointMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point != widget.point) {
      _shift = Offset.zero;
      _dragging = false;
      _start = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disc = Transform.translate(
      offset: _shift,
      child: _PointDisc(
        label: widget.label,
        highlighted: _dragging,
        dimmed: widget.dimmed,
      ),
    );
    if (!widget.enabled) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: disc,
      );
    }
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: _gestures(),
      child: disc,
    );
  }

  Map<Type, GestureRecognizerFactory> _gestures() {
    return {
      _MousePointRecognizer:
          GestureRecognizerFactoryWithHandlers<_MousePointRecognizer>(
        () => _MousePointRecognizer(),
        (recognizer) {
          recognizer
            ..onTap = widget.onTap
            ..onStart = _beginDrag
            ..onUpdate = _shiftBy
            ..onEnd = _finishDrag;
        },
      ),
      _TouchTapRecognizer:
          GestureRecognizerFactoryWithHandlers<_TouchTapRecognizer>(
        () => _TouchTapRecognizer(),
        (recognizer) => recognizer.onTap = widget.onTap,
      ),
      _TouchHoldRecognizer:
          GestureRecognizerFactoryWithHandlers<_TouchHoldRecognizer>(
        () => _TouchHoldRecognizer(),
        (recognizer) {
          recognizer.onLongPressStart = (_) {
            _beginDrag();
          };
          recognizer.onLongPressMoveUpdate = (details) {
            _shiftBy(details.offsetFromOrigin - _shift);
          };
          recognizer.onLongPressEnd = (_) {
            _finishDrag();
          };
        },
      ),
    };
  }

  void _beginDrag() {
    _start = widget.point;
    _shift = Offset.zero;
    setState(() => _dragging = true);
  }

  void _shiftBy(Offset delta) {
    final start = _start;
    if (start == null || !mounted) {
      return;
    }

    _shift += delta;
    setState(() => _dragging = true);
    final camera = MapCamera.of(context);
    final next = camera.screenOffsetToLatLng(
      camera.latLngToScreenOffset(start) + _shift,
    );
    widget.onPreview(next);
  }

  void _finishDrag() {
    final start = _start;
    if (start == null || !mounted) {
      return;
    }

    final camera = MapCamera.of(context);
    final next = camera.screenOffsetToLatLng(
      camera.latLngToScreenOffset(start) + _shift,
    );
    widget.onCommit(next);
    final unchanged = start.latitude == next.latitude && start.longitude == next.longitude;
    if (unchanged && mounted) {
      setState(() {
        _shift = Offset.zero;
        _dragging = false;
        _start = null;
      });
    }
  }
}

class _PointDisc extends StatelessWidget {
  const _PointDisc({
    required this.label,
    required this.highlighted,
    required this.dimmed,
  });

  final String label;
  final bool highlighted;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: highlighted ? 36 : 28,
          height: highlighted ? 36 : 28,
          decoration: BoxDecoration(
            color: dimmed ? const Color(0xFF94A3B8) : AppTheme.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: highlighted ? 3 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}

class _MousePointRecognizer extends OneSequenceGestureRecognizer {
  VoidCallback? onTap;
  VoidCallback? onStart;
  ValueChanged<Offset>? onUpdate;
  VoidCallback? onEnd;

  Offset? _origin;
  bool _dragging = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return;
    }
    _origin = event.position;
    _dragging = false;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      final origin = _origin;
      if (origin == null) {
        return;
      }
      if (!_dragging && (event.position - origin).distance > 6) {
        _dragging = true;
        onStart?.call();
        onUpdate?.call(event.position - origin);
        return;
      }
      if (_dragging) {
        onUpdate?.call(event.delta);
      }
      return;
    }

    if (event is PointerUpEvent) {
      if (_dragging) {
        onEnd?.call();
      } else {
        onTap?.call();
      }
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
      _origin = null;
      _dragging = false;
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'mousePoint';
}

class _TouchTapRecognizer extends TapGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) {
      return;
    }
    super.addAllowedPointer(event);
  }
}

class _TouchHoldRecognizer extends LongPressGestureRecognizer {
  _TouchHoldRecognizer() : super(duration: const Duration(milliseconds: 300));

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) {
      return;
    }
    super.addAllowedPointer(event);
  }
}
