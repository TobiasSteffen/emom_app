import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/services/garmin_service.dart';

part 'garmin_notifier.g.dart';

class GarminConnectionStatus {
  final bool connected;
  final bool everConnected;
  final bool appRunning;

  const GarminConnectionStatus({
    required this.connected,
    required this.everConnected,
    this.appRunning = false,
  });
}

// keepAlive: true -- die appRunning-Stream-Subscription aus build() muss
// unabhaengig davon leben, ob gerade ein Widget den Provider watched (die
// Watch-App kann jederzeit "opened"/"closed" senden). Mit autoDispose
// (dem @riverpod-Default) wuerde der Provider ohne aktiven Listener sofort
// wieder verworfen und die Subscription mitsamt Events verloren gehen --
// bestaetigt durch die beiden Tests in garmin_notifier_test.dart, die ohne
// keepAlive fehlschlagen (state faellt nach dem ersten read() auf
// AsyncLoading zurueck).
@Riverpod(keepAlive: true)
class GarminNotifier extends _$GarminNotifier {
  final GarminService _service = GarminService();
  StreamSubscription<bool>? _appRunningSub;

  @override
  Future<GarminConnectionStatus> build() async {
    final connected = await _service.isWatchConnected();
    if (connected) {
      await _service.markEverConnected();
    }
    final everConnected = await _service.hasEverConnected();

    _appRunningSub?.cancel();
    _appRunningSub = _service.watchAppRunningEvents().listen((running) {
      final current = state.value;
      if (current == null) return;
      state = AsyncData(GarminConnectionStatus(
        connected: current.connected,
        everConnected: current.everConnected,
        appRunning: running,
      ));
    });
    ref.onDispose(() => _appRunningSub?.cancel());

    return GarminConnectionStatus(connected: connected, everConnected: everConnected);
  }

  /// Fragt den Bluetooth-Status neu ab und liefert das Ergebnis von
  /// openWatchApp() zurueck, OHNE den Notifier per invalidateSelf() neu
  /// aufzubauen -- das wuerde die appRunning-Stream-Subscription aus
  /// build() abreissen und neu aufsetzen, mit einer Event-Luecke genau in
  /// dem Moment, in dem die gerade gestartete Watch-App ihr "opened"
  /// sendet (siehe Design-Spec, Architektur Punkt 5).
  Future<String> openWatchApp() async {
    final status = await _service.openWatchApp();
    final connected = await _service.isWatchConnected();
    if (connected) {
      await _service.markEverConnected();
    }
    final everConnected = await _service.hasEverConnected();
    final appRunning = state.value?.appRunning ?? false;
    state = AsyncData(GarminConnectionStatus(
      connected: connected,
      everConnected: everConnected,
      appRunning: appRunning,
    ));
    return status;
  }
}
