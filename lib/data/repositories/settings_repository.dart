import 'package:fc_frontend/data/models/battery_settings.dart';
import 'package:fc_frontend/data/models/flight_parameters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences must be overridden before the app starts');
});

class BatterySettingsNotifier extends StateNotifier<BatterySettings> {
  BatterySettingsNotifier(this._preferences) : super(_readBattery(_preferences));

  final SharedPreferences _preferences;

  Future<void> update(BatterySettings settings) async {
    state = settings;
    await _writeBattery(_preferences, settings);
  }
}

class FlightParametersNotifier extends StateNotifier<FlightParameters> {
  FlightParametersNotifier(this._preferences)
    : super(_readFlightParameters(_preferences));

  final SharedPreferences _preferences;

  Future<void> update(FlightParameters parameters) async {
    state = parameters;
    await _writeFlightParameters(_preferences, parameters);
  }
}

final batterySettingsProvider =
    StateNotifierProvider<BatterySettingsNotifier, BatterySettings>((ref) {
      return BatterySettingsNotifier(ref.watch(sharedPreferencesProvider));
    });

final flightParametersProvider =
    StateNotifierProvider<FlightParametersNotifier, FlightParameters>((ref) {
      return FlightParametersNotifier(ref.watch(sharedPreferencesProvider));
    });

const _firstWarningKey = 'battery.first_warning_percent';
const _secondWarningKey = 'battery.second_warning_percent';
const _criticalPercentKey = 'battery.critical_percent';
const _maxVoltageKey = 'battery.max_voltage';
const _minVoltageKey = 'battery.min_voltage';
const _lowVoltageKey = 'battery.low_voltage_threshold';
const _criticalVoltageKey = 'battery.critical_voltage_threshold';
const _cellCountKey = 'battery.cell_count';

const _maxYawRateKey = 'flight.max_yaw_rate';
const _maxRollAngleKey = 'flight.max_roll_angle';
const _maxPitchAngleKey = 'flight.max_pitch_angle';
const _maxSpeedKey = 'flight.max_speed';
const _cruiseSpeedKey = 'flight.cruise_speed';

BatterySettings _readBattery(SharedPreferences preferences) {
  const defaults = BatterySettings();
  return BatterySettings(
    firstWarningPercent:
        preferences.getInt(_firstWarningKey) ?? defaults.firstWarningPercent,
    secondWarningPercent:
        preferences.getInt(_secondWarningKey) ?? defaults.secondWarningPercent,
    criticalPercent:
        preferences.getInt(_criticalPercentKey) ?? defaults.criticalPercent,
    maxVoltage: preferences.getDouble(_maxVoltageKey) ?? defaults.maxVoltage,
    minVoltage: preferences.getDouble(_minVoltageKey) ?? defaults.minVoltage,
    lowVoltageThreshold:
        preferences.getDouble(_lowVoltageKey) ?? defaults.lowVoltageThreshold,
    criticalVoltageThreshold:
        preferences.getDouble(_criticalVoltageKey) ??
        defaults.criticalVoltageThreshold,
    cellCount: preferences.getInt(_cellCountKey) ?? defaults.cellCount,
  );
}

Future<void> _writeBattery(
  SharedPreferences preferences,
  BatterySettings settings,
) async {
  await preferences.setInt(_firstWarningKey, settings.firstWarningPercent);
  await preferences.setInt(_secondWarningKey, settings.secondWarningPercent);
  await preferences.setInt(_criticalPercentKey, settings.criticalPercent);
  await preferences.setDouble(_maxVoltageKey, settings.maxVoltage);
  await preferences.setDouble(_minVoltageKey, settings.minVoltage);
  await preferences.setDouble(_lowVoltageKey, settings.lowVoltageThreshold);
  await preferences.setDouble(
    _criticalVoltageKey,
    settings.criticalVoltageThreshold,
  );
  await preferences.setInt(_cellCountKey, settings.cellCount);
}

FlightParameters _readFlightParameters(SharedPreferences preferences) {
  const defaults = FlightParameters();
  return FlightParameters(
    maxYawRate: preferences.getDouble(_maxYawRateKey) ?? defaults.maxYawRate,
    maxRollAngle:
        preferences.getDouble(_maxRollAngleKey) ?? defaults.maxRollAngle,
    maxPitchAngle:
        preferences.getDouble(_maxPitchAngleKey) ?? defaults.maxPitchAngle,
    maxSpeed: preferences.getDouble(_maxSpeedKey) ?? defaults.maxSpeed,
    cruiseSpeed: preferences.getDouble(_cruiseSpeedKey) ?? defaults.cruiseSpeed,
  );
}

Future<void> _writeFlightParameters(
  SharedPreferences preferences,
  FlightParameters parameters,
) async {
  await preferences.setDouble(_maxYawRateKey, parameters.maxYawRate);
  await preferences.setDouble(_maxRollAngleKey, parameters.maxRollAngle);
  await preferences.setDouble(_maxPitchAngleKey, parameters.maxPitchAngle);
  await preferences.setDouble(_maxSpeedKey, parameters.maxSpeed);
  await preferences.setDouble(_cruiseSpeedKey, parameters.cruiseSpeed);
}
