import 'package:flutter/material.dart';

class LineSpacingControl extends StatelessWidget {
  const LineSpacingControl({
    super.key,
    required this.spacingMeters,
    required this.lowerMeters,
    required this.upperMeters,
    required this.onChanged,
  });

  final double spacingMeters;
  final double lowerMeters;
  final double upperMeters;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final atMin = spacingMeters <= lowerMeters + 0.001;
    final atMax = spacingMeters >= upperMeters - 0.001;
    return Column(
      children: [
        const Text('Line Spacing'),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Decrease spacing',
              onPressed: atMin
                  ? null
                  : () => onChanged(_step(spacingMeters - 1)),
              icon: const Text('-', style: TextStyle(fontSize: 22)),
            ),
            Text(_label(spacingMeters)),
            IconButton(
              tooltip: 'Increase spacing',
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
