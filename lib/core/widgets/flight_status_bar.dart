import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/models/battery_settings.dart';
import 'package:fc_frontend/core/widgets/bottom_nav_bar.dart';
import 'package:fc_frontend/core/widgets/connect_panel.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/data/repositories/telemetry_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlightStatusBar extends ConsumerWidget {
  const FlightStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryStreamProvider).asData?.value;
    final settings = ref.watch(batterySettingsProvider);
    final connected = ref.watch(telemetryConnectionProvider);
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;
    final battery = telemetry?.battery;
    final batteryColor = _batteryColor(battery, settings, statusColors);

    return Material(
      color: AppTheme.surface,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: _StatusChip(
                icon: Icons.battery_std,
                label: battery == null
                    ? 'Battery --'
                    : 'Battery ${battery.toStringAsFixed(1)}%',
                color: batteryColor,
              ),
            ),
            Expanded(
              child: _StatusChip(
                icon: Icons.satellite_alt,
                label: telemetry == null ? 'GPS --' : 'GPS ${telemetry.gpsCount}',
              ),
            ),
            Expanded(
              child: _StatusChip(
                icon: Icons.flight,
                label: telemetry == null ? 'Mode --' : telemetry.mode,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => _openConnectPanel(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Connect'),
                  const SizedBox(width: 6),
                  Semantics(
                    label: connected ? 'Connected' : 'Disconnected',
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: connected
                            ? statusColors.statusGood
                            : const Color(0xFF6B7280),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openConnectPanel(BuildContext context) {
    final navigatorContext = shellNavigatorKey.currentContext ?? context;
    showModalBottomSheet<void>(
      context: navigatorContext,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Theme.of(navigatorContext).colorScheme.surface,
      showDragHandle: true,
      builder: (context) => const ConnectPanel(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppTheme.text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: itemColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: itemColor,
            ),
          ),
        ),
      ],
    );
  }
}

Color _batteryColor(
  double? battery,
  BatterySettings settings,
  AppStatusColors statusColors,
) {
  if (battery == null) {
    return statusColors.statusGood;
  }
  if (battery < settings.secondWarningPercent) {
    return statusColors.statusCritical;
  }
  if (battery < settings.firstWarningPercent) {
    return statusColors.statusWarning;
  }
  return statusColors.statusGood;
}
