import 'package:flutter/material.dart';

class SettingsNumberField extends StatelessWidget {
  const SettingsNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.errorText,
    required this.onChanged,
    this.decimal = true,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: errorText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
