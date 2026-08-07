import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/services/garmin_service.dart';

part 'garmin_notifier.g.dart';

class GarminConnectionStatus {
  final bool connected;
  final bool everConnected;

  const GarminConnectionStatus({
    required this.connected,
    required this.everConnected,
  });
}

@riverpod
class GarminNotifier extends _$GarminNotifier {
  final GarminService _service = GarminService();

  @override
  Future<GarminConnectionStatus> build() async {
    final connected = await _service.isWatchConnected();
    if (connected) {
      await _service.markEverConnected();
    }
    final everConnected = await _service.hasEverConnected();
    return GarminConnectionStatus(connected: connected, everConnected: everConnected);
  }

  Future<String> openWatchApp() async {
    final status = await _service.openWatchApp();
    ref.invalidateSelf();
    await future; // wartet auf den neu ausgeloesten build(), bevor die Methode zurueckkehrt
    return status;
  }
}
