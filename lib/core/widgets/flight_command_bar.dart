import 'package:fc_frontend/core/widgets/home_button.dart';
import 'package:fc_frontend/core/widgets/simulated_command.dart';
import 'package:fc_frontend/data/repositories/telemetry_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlightCommandBar extends ConsumerStatefulWidget {
  const FlightCommandBar({super.key});

  @override
  ConsumerState<FlightCommandBar> createState() => _FlightCommandBarState();
}

class _FlightCommandBarState extends ConsumerState<FlightCommandBar> {
  bool? _commandedArmed;

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryStreamProvider).asData?.value;
    final armed = _commandedArmed ?? telemetry?.armed ?? false;

    return Row(
      children: [
        const Expanded(child: HomeButton()),
        Expanded(
          child: _FlightCommandButton(
            label: 'Takeoff',
            onPressed: _showCommandSent,
          ),
        ),
        Expanded(
          child: _FlightCommandButton(
            label: armed ? 'Disarm' : 'Arm',
            onPressed: () => _onArmDisarm(armed),
          ),
        ),
        Expanded(
          child: _FlightCommandButton(label: 'RTL', onPressed: _onRtl),
        ),
        Expanded(
          child: _FlightCommandButton(label: 'Land', onPressed: _showCommandSent),
        ),
      ],
    );
  }

  Future<void> _onArmDisarm(bool armed) async {
    final confirmed = await _confirm(
      title: armed ? 'Disarm' : 'Arm',
      message: armed ? 'Disarm the drone?' : 'Arm the drone?',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _commandedArmed = !armed);
    _showCommandSent();
  }

  Future<void> _onRtl() async {
    final confirmed = await _confirm(
      title: 'RTL',
      message: 'Command the drone to return to launch?',
    );
    if (!confirmed || !mounted) {
      return;
    }

    _showCommandSent();
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  void _showCommandSent() {
    showSimulatedCommandSent(context);
  }
}

class _FlightCommandButton extends StatelessWidget {
  const _FlightCommandButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: onPressed,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
