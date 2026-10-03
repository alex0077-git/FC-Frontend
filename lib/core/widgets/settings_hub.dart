import 'package:fc_frontend/core/widgets/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void showSettingsHub(BuildContext context) {
  final navigatorContext = shellNavigatorKey.currentContext ?? context;
  showModalBottomSheet<void>(
    context: navigatorContext,
    useRootNavigator: false,
    isScrollControlled: true,
    backgroundColor: Theme.of(navigatorContext).colorScheme.surface,
    showDragHandle: true,
    builder: (sheetContext) {
      return _SettingsHub(
        onSelect: (path) {
          Navigator.of(sheetContext).pop();
          context.go(path);
        },
      );
    },
  );
}

class _SettingsHub extends StatelessWidget {
  const _SettingsHub({required this.onSelect});

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
