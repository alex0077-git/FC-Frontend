import 'dart:async';

import 'package:flutter/material.dart';

class LineSpacingControl extends StatefulWidget {
  const LineSpacingControl({
    super.key,
    required this.spacingMeters,
    required this.lowerMeters,
    required this.upperMeters,
    required this.onChanged,
    this.title = 'Line Spacing',
    this.decreaseTooltip = 'Decrease spacing',
    this.increaseTooltip = 'Increase spacing',
  });

  final double spacingMeters;
  final double lowerMeters;
  final double upperMeters;
  final ValueChanged<double> onChanged;
  final String title;
  final String decreaseTooltip;
  final String increaseTooltip;

  @override
  State<LineSpacingControl> createState() => _LineSpacingControlState();
}

class _LineSpacingControlState extends State<LineSpacingControl> {
  static const _holdInterval = Duration(milliseconds: 120);

  Timer? _hold;

  /// The number under the finger. Shown at once so the label does not wait
  /// for the spray path to be rebuilt.
  double? _shown;

  double get _value => _shown ?? widget.spacingMeters;

  @override
  void didUpdateWidget(LineSpacingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shown = _shown;
    if (shown != null && (widget.spacingMeters - shown).abs() < 0.05) {
      _shown = null;
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final atMin = value <= widget.lowerMeters + 0.001;
    final atMax = value >= widget.upperMeters - 0.001;
    return Row(
      children: [
        if (widget.title.isNotEmpty)
          Expanded(child: Text(widget.title))
        else
          const Spacer(),
        _stepButton(
          tooltip: widget.decreaseTooltip,
          enabled: !atMin,
          delta: -1,
          icon: const Text('-', style: TextStyle(fontSize: 22)),
        ),
        SizedBox(
          width: 52,
          child: Text(
            _label(value),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        _stepButton(
          tooltip: widget.increaseTooltip,
          enabled: !atMax,
          delta: 1,
          icon: const Text('+', style: TextStyle(fontSize: 22)),
        ),
      ],
    );
  }

  Widget _stepButton({
    required String tooltip,
    required bool enabled,
    required double delta,
    required Widget icon,
  }) {
    return Listener(
      onPointerDown: enabled ? (_) => _start(delta) : null,
      onPointerUp: enabled ? (_) => _stop() : null,
      onPointerCancel: enabled ? (_) => _stop() : null,
      child: IconButton(
        tooltip: tooltip,
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: enabled ? () {} : null,
        icon: icon,
      ),
    );
  }

  void _start(double delta) {
    _apply(delta);
    _hold?.cancel();
    _hold = Timer.periodic(_holdInterval, (_) => _apply(delta));
  }

  void _stop() {
    _hold?.cancel();
    _hold = null;
  }

  void _apply(double delta) {
    final next = _step(_value + delta);
    if ((next - _value).abs() < 0.001) {
      _stop();
      return;
    }
    setState(() => _shown = next);
    widget.onChanged(next);
  }

  double _step(double meters) {
    return meters.roundToDouble().clamp(widget.lowerMeters, widget.upperMeters).toDouble();
  }

  String _label(double meters) {
    final whole = meters.roundToDouble();
    if ((meters - whole).abs() < 0.05) {
      return '${whole.toInt()} m';
    }
    return '${meters.toStringAsFixed(1)} m';
  }
}
