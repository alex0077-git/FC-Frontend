import 'package:fc_frontend/data/models/flight_parameters.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/settings/settings_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlightParametersPage extends ConsumerStatefulWidget {
  const FlightParametersPage({super.key});

  @override
  ConsumerState<FlightParametersPage> createState() =>
      _FlightParametersPageState();
}

class _FlightParametersPageState extends ConsumerState<FlightParametersPage> {
  late final TextEditingController _maxYawRate;
  late final TextEditingController _maxRollAngle;
  late final TextEditingController _maxPitchAngle;
  late final TextEditingController _maxSpeed;
  late final TextEditingController _cruiseSpeed;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    final parameters = ref.read(flightParametersProvider);
    _maxYawRate = TextEditingController(text: _format(parameters.maxYawRate));
    _maxRollAngle = TextEditingController(text: _format(parameters.maxRollAngle));
    _maxPitchAngle = TextEditingController(
      text: _format(parameters.maxPitchAngle),
    );
    _maxSpeed = TextEditingController(text: _format(parameters.maxSpeed));
    _cruiseSpeed = TextEditingController(text: _format(parameters.cruiseSpeed));
  }

  @override
  void dispose() {
    _maxYawRate.dispose();
    _maxRollAngle.dispose();
    _maxPitchAngle.dispose();
    _maxSpeed.dispose();
    _cruiseSpeed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Flight Parameters', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        SettingsNumberField(
          label: 'Max Yaw Rate',
          controller: _maxYawRate,
          errorText: _errors['yaw'],
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Max Roll Angle',
          controller: _maxRollAngle,
          errorText: _errors['roll'],
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Max Pitch Angle',
          controller: _maxPitchAngle,
          errorText: _errors['pitch'],
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Max Speed',
          controller: _maxSpeed,
          errorText: _errors['maxSpeed'],
          onChanged: (_) => _save(),
        ),
        SettingsNumberField(
          label: 'Cruise Speed',
          controller: _cruiseSpeed,
          errorText: _errors['cruise'],
          onChanged: (_) => _save(),
        ),
      ],
    );
  }

  void _save() {
    final errors = <String, String>{};
    final yaw = _readRange(_maxYawRate.text, errors, 'yaw', 360, 'deg/s');
    final roll = _readRange(_maxRollAngle.text, errors, 'roll', 90, 'degrees');
    final pitch = _readRange(
      _maxPitchAngle.text,
      errors,
      'pitch',
      90,
      'degrees',
    );
    final maxSpeed = _readRange(
      _maxSpeed.text,
      errors,
      'maxSpeed',
      50,
      'm/s',
    );
    final cruise = _readRange(_cruiseSpeed.text, errors, 'cruise', 50, 'm/s');
    if (cruise != null && maxSpeed != null && cruise > maxSpeed) {
      errors['cruise'] = 'Must be at or below the max speed';
    }

    setState(() => _errors = errors);
    if (errors.isNotEmpty ||
        yaw == null ||
        roll == null ||
        pitch == null ||
        maxSpeed == null ||
        cruise == null) {
      return;
    }

    ref.read(flightParametersProvider.notifier).update(
      FlightParameters(
        maxYawRate: yaw,
        maxRollAngle: roll,
        maxPitchAngle: pitch,
        maxSpeed: maxSpeed,
        cruiseSpeed: cruise,
      ),
    );
  }
}

double? _readRange(
  String text,
  Map<String, String> errors,
  String key,
  double max,
  String unit,
) {
  final value = double.tryParse(text.trim());
  if (value == null) {
    errors[key] = 'Enter a number';
    return null;
  }
  if (value <= 0 || value > max) {
    errors[key] = 'Enter a value from 0 to $max $unit';
    return null;
  }
  return value;
}

String _format(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}
