import 'package:fc_frontend/data/models/telemetry.dart';
import 'package:fc_frontend/data/sources/mock_telemetry_source.dart';
import 'package:fc_frontend/data/sources/telemetry_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class TelemetryRepository extends StateNotifier<bool> {
  TelemetryRepository(this._source) : super(_source.isConnected);

  final TelemetrySource _source;

  Stream<Telemetry> get telemetryStream => _source.telemetryStream;

  void connect() {
    _source.connect();
    state = _source.isConnected;
  }

  void disconnect() {
    _source.disconnect();
    state = _source.isConnected;
  }
}

final telemetryRepositoryProvider =
    StateNotifierProvider<TelemetryRepository, bool>((ref) {
      final source = MockTelemetrySource();
      ref.onDispose(source.dispose);
      return TelemetryRepository(source);
    });

final telemetryStreamProvider = StreamProvider<Telemetry>((ref) {
  return ref.watch(telemetryRepositoryProvider.notifier).telemetryStream;
});

final telemetryConnectionProvider = Provider<bool>((ref) {
  return ref.watch(telemetryRepositoryProvider);
});
