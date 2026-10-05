import 'package:flutter/material.dart';

/// Shows the same simulated-command result used by Map/Flight.
void showSimulatedCommandSent(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Command sent (simulated)'),
      ),
    );
}
