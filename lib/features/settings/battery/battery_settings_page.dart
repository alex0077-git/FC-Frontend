import 'package:fc_frontend/data/models/battery_settings.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/settings/settings_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BatterySettingsPage extends ConsumerStatefulWidget {
  const BatterySettingsPage({super.key});

  @override
  ConsumerState<BatterySettingsPage> createState() => _BatterySettingsPageState();
}

class _BatterySettingsPageState extends ConsumerState<BatterySettingsPage> {
  late final TextEditingController _firstWarning;
  late final TextEditingController _secondWarning;
  late final TextEditingController _criticalPercent;
  late final TextEditingController _maxVoltage;
  late final TextEditingController _minVoltage;
  late final TextEditingController _lowVoltage;
  late final TextEditingController _criticalVoltage;
  late final TextEditingController _cellCount;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(batterySettingsProvider);
    _firstWarning = TextEditingController(text: '${settings.firstWarningPercent}');
    _secondWarning = TextEditingController(
      text: '${settings.secondWarningPercent}',
    );
    _criticalPercent = TextEditingController(text: '${settings.criticalPercent}');
    _maxVoltage = TextEditingController(text: formatSettingsNumber(settings.maxVoltage));
    _minVoltage = TextEditingController(text: formatSettingsNumber(settings.minVoltage));
    _lowVoltage = TextEditingController(text: formatSettingsNumber(settings.lowVoltageThreshold));
    _criticalVoltage = TextEditingController(
      text: formatSettingsNumber(settings.criticalVoltageThreshold),
    );
    _cellCount = TextEditingController(text: '${settings.cellCount}');
  }

  @override
  void dispose() {
    _firstWarning.dispose();
    _secondWarning.dispose();
    _criticalPercent.dispose();
    _maxVoltage.dispose();
    _minVoltage.dispose();
    _lowVoltage.dispose();
    _criticalVoltage.dispose();
    _cellCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Battery', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        SettingsNumberField(
          label: 'First Warning Threshold (%)',
          controller: _firstWarning,
          errorText: _errors['first'],
          decimal: false,
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Second Warning Threshold (%)',
          controller: _secondWarning,
          errorText: _errors['second'],
          decimal: false,
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Critical Battery Level (%)',
          controller: _criticalPercent,
          errorText: _errors['criticalPercent'],
          decimal: false,
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Max Voltage',
          controller: _maxVoltage,
          errorText: _errors['maxVoltage'],
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Min Voltage',
          controller: _minVoltage,
          errorText: _errors['minVoltage'],
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Low-Voltage Threshold',
          controller: _lowVoltage,
          errorText: _errors['lowVoltage'],
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Critical-Voltage Threshold',
          controller: _criticalVoltage,
          errorText: _errors['criticalVoltage'],
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Cell Count',
          controller: _cellCount,
          errorText: _errors['cellCount'],
          decimal: false,
          onChanged: (_) => _save(),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Battery calibrated (simulated)')),
            );
          },
          child: const Text('Calibrate Battery'),
        ),
      ],
    );
  }

  void _save() {
    final errors = <String, String>{};
    final first = _readPercent(_firstWarning.text, errors, 'first');
    final second = _readPercent(_secondWarning.text, errors, 'second');
    final critical = _readPercent(
      _criticalPercent.text,
      errors,
      'criticalPercent',
    );
    final maxVoltage = _readVoltage(_maxVoltage.text, errors, 'maxVoltage');
    final minVoltage = _readVoltage(_minVoltage.text, errors, 'minVoltage');
    final lowVoltage = _readVoltage(_lowVoltage.text, errors, 'lowVoltage');
    final criticalVoltage = _readVoltage(
      _criticalVoltage.text,
      errors,
      'criticalVoltage',
    );
    final cellCount = _readCellCount(_cellCount.text, errors);

    if (first != null && second != null && first <= second) {
      errors['first'] = 'Must be above the second warning';
    }
    if (second != null && critical != null && second <= critical) {
      errors['second'] = 'Must be above the critical level';
    }
    if (maxVoltage != null && minVoltage != null && maxVoltage <= minVoltage) {
      errors['maxVoltage'] = 'Must be above the minimum voltage';
    }
    if (lowVoltage != null &&
        minVoltage != null &&
        maxVoltage != null &&
        (lowVoltage <= minVoltage || lowVoltage >= maxVoltage)) {
      errors['lowVoltage'] = 'Must be between the minimum and maximum voltage';
    }
    if (criticalVoltage != null &&
        minVoltage != null &&
        lowVoltage != null &&
        (criticalVoltage <= minVoltage || criticalVoltage >= lowVoltage)) {
      errors['criticalVoltage'] =
          'Must be between the minimum voltage and the low-voltage threshold';
    }

    setState(() => _errors = errors);
    if (errors.isNotEmpty ||
        first == null ||
        second == null ||
        critical == null ||
        maxVoltage == null ||
        minVoltage == null ||
        lowVoltage == null ||
        criticalVoltage == null ||
        cellCount == null) {
      return;
    }

    ref.read(batterySettingsProvider.notifier).update(
      BatterySettings(
        firstWarningPercent: first,
        secondWarningPercent: second,
        criticalPercent: critical,
        maxVoltage: maxVoltage,
        minVoltage: minVoltage,
        lowVoltageThreshold: lowVoltage,
        criticalVoltageThreshold: criticalVoltage,
        cellCount: cellCount,
      ),
    );
  }
}

int? _readPercent(String text, Map<String, String> errors, String key) {
  final value = int.tryParse(text.trim());
  if (value == null) {
    errors[key] = 'Enter a whole number';
    return null;
  }
  if (value < 0 || value > 100) {
    errors[key] = 'Enter a percentage from 0 to 100';
    return null;
  }
  return value;
}

double? _readVoltage(String text, Map<String, String> errors, String key) {
  final value = double.tryParse(text.trim());
  if (value == null) {
    errors[key] = 'Enter a number';
    return null;
  }
  if (value <= 0 || value > 100) {
    errors[key] = 'Enter a voltage from 0 to 100';
    return null;
  }
  return value;
}

int? _readCellCount(String text, Map<String, String> errors) {
  final value = int.tryParse(text.trim());
  if (value == null) {
    errors['cellCount'] = 'Enter a whole number';
    return null;
  }
  if (value < 1 || value > 18) {
    errors['cellCount'] = 'Enter a cell count from 1 to 18';
    return null;
  }
  return value;
}

