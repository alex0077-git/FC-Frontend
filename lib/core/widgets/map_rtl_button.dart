import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/simulated_command.dart';
import 'package:flutter/material.dart';

/// Small map overlay that asks before sending return-to-launch.
class MapRtlButton extends StatefulWidget {
  const MapRtlButton({super.key});

  @override
  State<MapRtlButton> createState() => _MapRtlButtonState();
}

class _MapRtlButtonState extends State<MapRtlButton> {
  bool _confirming = false;

  void _toggle() {
    setState(() => _confirming = !_confirming);
  }

  void _cancel() {
    setState(() => _confirming = false);
  }

  void _confirm() {
    setState(() => _confirming = false);
    showSimulatedCommandSent(context);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_confirming) ...[
          _RtlConfirmCard(onCancel: _cancel, onConfirm: _confirm),
          const SizedBox(width: 8),
        ],
        Material(
          color: AppTheme.surface.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 2,
          child: IconButton(
            tooltip: 'Return to launch',
            onPressed: _toggle,
            style: IconButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.flight_land),
          ),
        ),
      ],
    );
  }
}

class _RtlConfirmCard extends StatelessWidget {
  const _RtlConfirmCard({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Material(
        color: AppTheme.surface,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Command the drone to return to launch?'),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onConfirm,
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
