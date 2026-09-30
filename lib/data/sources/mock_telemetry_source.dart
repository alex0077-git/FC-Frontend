import 'dart:async';
import 'dart:math';

import 'package:fc_frontend/data/models/telemetry.dart';
import 'package:fc_frontend/data/sources/telemetry_source.dart';

class MockTelemetrySource implements TelemetrySource {
  MockTelemetrySource() {
    _startTimer();
  }

  static const _interval = Duration(milliseconds: 500);
  static const _metersPerDegree = 111320.0;
  static const _stepMeters = 2.0;

  final StreamController<Telemetry> _controller =
      StreamController<Telemetry>.broadcast();

  Timer? _timer;
  bool _isConnected = true;
  bool _disposed = false;
  int _ticks = 0;

  double _latitude = 12.9716;
  double _longitude = 77.5946;
  double _heading = 45;
  double _battery = 86;

  @override
  Stream<Telemetry> get telemetryStream => _controller.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  void connect() {
    if (_disposed || _isConnected) {
      return;
    }

    _isConnected = true;
    _startTimer();
  }

  @override
  void disconnect() {
    _isConnected = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    disconnect();
    _controller.close();
  }

  void _startTimer() {
    if (_timer != null) {
      return;
    }

    _timer = Timer.periodic(_interval, (_) => _emit());
  }

  void _emit() {
    if (_disposed || !_isConnected || _controller.isClosed) {
      return;
    }

    _ticks += 1;
    _heading = (_heading + 0.35) % 360;
    _advancePosition();
    _battery = (_battery - 0.01).clamp(0, 100).toDouble();

    final phase = _ticks.toDouble();
    _controller.add(
      Telemetry(
        latitude: _latitude,
        longitude: _longitude,
        altitude: 30 + sin(phase * 0.05) * 0.4,
        speed: 4,
        heading: _heading,
        roll: sin(phase * 0.08) * 4,
        pitch: cos(phase * 0.06) * 2,
        battery: _battery,
        gpsCount: 12 + (_ticks ~/ 20) % 3,
        mode: 'AUTO',
        armed: true,
      ),
    );
  }

  void _advancePosition() {
    final headingRadians = _heading * pi / 180;
    final latitudeRadians = _latitude * pi / 180;
    final nextLatitude =
        _latitude + (_stepMeters * cos(headingRadians)) / _metersPerDegree;
    final nextLongitude =
        _longitude +
        (_stepMeters * sin(headingRadians)) /
            (_metersPerDegree * cos(latitudeRadians));
    _latitude = nextLatitude;
    _longitude = nextLongitude;
  }
}
