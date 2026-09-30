import 'package:fc_frontend/data/models/telemetry.dart';

abstract class TelemetrySource {
  Stream<Telemetry> get telemetryStream;

  void connect();

  void disconnect();

  bool get isConnected;
}
