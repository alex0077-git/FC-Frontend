import 'package:flutter/material.dart';

class LineSpacingControl extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final atMin = spacingMeters <= lowerMeters + 0.001;
    final atMax = spacingMeters >= upperMeters - 0.001;
    return Column(
      children: [
        Text(title),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: decreaseTooltip,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: atMin
                  ? null
                  : () => onChanged(_step(spacingMeters - 1)),
              icon: const Text('-', style: TextStyle(fontSize: 22)),
            ),
            Text(_label(spacingMeters), style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              tooltip: increaseTooltip,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: atMax
                  ? null
                  : () => onChanged(_step(spacingMeters + 1)),
              icon: const Text('+', style: TextStyle(fontSize: 22)),
            ),
          ],
        ),
      ],
    );
  }

  double _step(double meters) {
    return meters.roundToDouble().clamp(lowerMeters, upperMeters).toDouble();
  }

  String _label(double meters) {
    final whole = meters.roundToDouble();
    if ((meters - whole).abs() < 0.05) {
      return '${whole.toInt()} m';
    }
    return '${meters.toStringAsFixed(1)} m';
  }
}
