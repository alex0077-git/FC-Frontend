import 'package:flutter/material.dart';

class CalibrationPage extends StatelessWidget {
  const CalibrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Calibration', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        const _CalibrationCard(title: 'Radio', rowLabels: ['Radio']),
        const SizedBox(height: 12),
        const _CalibrationCard(title: 'IMU', rowLabels: ['IMU 1', 'IMU 2']),
        const SizedBox(height: 12),
        const _CalibrationCard(title: 'Compass', rowLabels: ['Compass']),
      ],
    );
  }
}

class _CalibrationCard extends StatefulWidget {
  const _CalibrationCard({required this.title, required this.rowLabels});

  final String title;
  final List<String> rowLabels;

  @override
  State<_CalibrationCard> createState() => _CalibrationCardState();
}

class _CalibrationCardState extends State<_CalibrationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  var _running = false;
  var _calibrated = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _progress.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) {
        return;
      }
      setState(() {
        _running = false;
        _calibrated = true;
      });
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _calibrated = false;
    });
    _progress.forward(from: 0);
  }

  String get _statusLabel {
    if (_running) {
      return 'Calibrating...';
    }
    if (_calibrated) {
      return 'Calibrated';
    }
    return 'Not calibrated';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final label in widget.rowLabels)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(_statusLabel),
                  ],
                ),
              ),
            if (_running) ...[
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: _progress,
                builder: (context, child) {
                  return LinearProgressIndicator(value: _progress.value);
                },
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _running ? null : _start,
              child: const Text('Start Calibration'),
            ),
          ],
        ),
      ),
    );
  }
}
