import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A labeled undo or redo control. Stays on screen when it cannot be used,
/// drawn in a muted gray so the control is still obvious.
class PlanHistoryButton extends StatelessWidget {
  const PlanHistoryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  static const _muted = Color(0x73E8EDF5);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? AppTheme.text : _muted;
    return Tooltip(
      message: label,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.text,
          disabledForegroundColor: _muted,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
