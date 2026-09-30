import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/repositories/telemetry_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectPanel extends ConsumerStatefulWidget {
  const ConnectPanel({super.key});

  @override
  ConsumerState<ConnectPanel> createState() => _ConnectPanelState();
}

class _ConnectPanelState extends ConsumerState<ConnectPanel> {
  String? _selected;

  void _toggle(String name) {
    final repository = ref.read(telemetryRepositoryProvider.notifier);
    final connected = ref.read(telemetryConnectionProvider);
    if (connected) {
      repository.disconnect();
      setState(() => _selected = null);
      return;
    }

    repository.connect();
    setState(() => _selected = name);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Connect', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var index = 0; index < _options.length; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(
                  child: _TransportCard(
                    label: _options[index].label,
                    icon: _options[index].icon,
                    selected: _selected == _options[index].label,
                    onTap: () => _toggle(_options[index].label),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TransportOption {
  const _TransportOption(this.label, this.icon);

  final String label;
  final IconData icon;
}

const _options = [
  _TransportOption('Wi-Fi', Icons.wifi),
  _TransportOption('Bluetooth', Icons.bluetooth),
  _TransportOption('USB Cable', Icons.usb),
  _TransportOption('Controller', Icons.sports_esports_outlined),
];

class _TransportCard extends StatelessWidget {
  const _TransportCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppTheme.primary : const Color(0xFF2A3548);
    return Material(
      color: selected ? const Color(0xFF1A2740) : AppTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? AppTheme.primary : AppTheme.text),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
