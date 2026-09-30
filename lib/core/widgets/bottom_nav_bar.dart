import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/core/widgets/connect_panel.dart';
import 'package:fc_frontend/core/widgets/home_button.dart';
import 'package:fc_frontend/data/repositories/telemetry_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final connected = ref.watch(telemetryConnectionProvider);
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;

    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              const Expanded(child: HomeButton()),
              Expanded(
                child: _ConnectButton(
                  connected: connected,
                  dotColor: connected
                      ? statusColors.statusGood
                      : const Color(0xFF6B7280),
                  onPressed: () => _openConnectPanel(),
                ),
              ),
              Expanded(
                child: _NavIconButton(
                  tooltip: 'Map/Flight',
                  icon: Icons.map_outlined,
                  selected: location == '/map',
                  onPressed: () => context.go('/map'),
                ),
              ),
              Expanded(
                child: _NavIconButton(
                  tooltip: 'Ground Plan',
                  icon: Icons.grid_on_outlined,
                  selected: location == '/ground-plan',
                  onPressed: () => context.go('/ground-plan'),
                ),
              ),
              Expanded(
                child: _NavIconButton(
                  tooltip: 'Profile',
                  icon: Icons.person_outline,
                  selected: location == '/profile',
                  onPressed: () => context.go('/profile'),
                ),
              ),
              Expanded(
                child: _NavIconButton(
                  tooltip: 'Settings',
                  icon: Icons.settings_outlined,
                  selected: location.startsWith('/settings'),
                  onPressed: () => _openSettingsMenu(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openConnectPanel() {
    final navigatorContext = shellNavigatorKey.currentContext;
    if (navigatorContext == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: navigatorContext,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Theme.of(navigatorContext).colorScheme.surface,
      showDragHandle: true,
      builder: (context) => const ConnectPanel(),
    );
  }

  void _openSettingsMenu(BuildContext context) {
    final navigatorContext = shellNavigatorKey.currentContext;
    if (navigatorContext == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: navigatorContext,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Theme.of(navigatorContext).colorScheme.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return _SettingsMenu(
          onSelect: (path) {
            Navigator.of(sheetContext).pop();
            context.go(path);
          },
        );
      },
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({
    required this.connected,
    required this.dotColor,
    required this.onPressed,
  });

  final bool connected;
  final Color dotColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Flexible(
            child: Text('Connect', overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: connected ? 'Connected' : 'Disconnected',
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: const Text('Calibration'),
          onTap: () => onSelect('/settings/calibration'),
        ),
        ListTile(
          title: const Text('Battery'),
          onTap: () => onSelect('/settings/battery'),
        ),
        ListTile(
          title: const Text('Flight Parameters'),
          onTap: () => onSelect('/settings/flight-parameters'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
