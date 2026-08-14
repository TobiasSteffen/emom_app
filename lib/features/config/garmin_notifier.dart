import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/services/garmin_service.dart';

part 'garmin_notifier.g.dart';

enum WatchAppStatus { unknown, running, notRunning }

class GarminConnectionStatus {
  final bool connected;
  final bool everConnected;
  final WatchAppStatus watchAppStatus;

  const GarminConnectionStatus({
    required this.connected,
    required this.everConnected,
    this.watchAppStatus = WatchAppStatus.unknown,
  });
}

@riverpod
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
        watchAppStatus: running ? WatchAppStatus.running : WatchAppStatus.notRunning,
      ));
    });
    ref.onDispose(() => _appRunningSub?.cancel());

    return GarminConnectionStatus(connected: connected, everConnected: everConnected);
  }

  /// Fragt den Bluetooth-Status neu ab und liefert das Ergebnis von
  /// openWatchApp() zurueck, OHNE den Notifier per invalidateSelf() neu
  /// aufzubauen -- das wuerde die watchAppStatus-Stream-Subscription aus
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
    final watchAppStatus = state.value?.watchAppStatus ?? WatchAppStatus.unknown;
    state = AsyncData(GarminConnectionStatus(
      connected: connected,
      everConnected: everConnected,
      watchAppStatus: watchAppStatus,
    ));
    return status;
  }

  /// Wie openWatchApp(), aber ohne die Watch-App zu starten -- fuer den
  /// Cold-Start-Icon-Refresh beim Verlassen der Settings (siehe Design-
  /// Spec). Schreibt state per AsyncData(...) direkt fest statt
  /// invalidateSelf()/ref.invalidate() zu nutzen -- das wuerde
  /// watchAppStatus auf unknown zuruecksetzen (kein Vorzustand bei einem
  /// kompletten Neuaufbau) und GarminWorkoutSyncNotifier._send() wuerde
  /// daraufhin jeden Snapshot-Versand stillschweigend unterdruecken, bis
  /// die naechste "opened"-Transition eintrifft.
  Future<void> refreshConnection() async {
    final connected = await _service.isWatchConnected();
    if (connected) {
      await _service.markEverConnected();
    }
    final everConnected = await _service.hasEverConnected();
    final watchAppStatus = state.value?.watchAppStatus ?? WatchAppStatus.unknown;
    state = AsyncData(GarminConnectionStatus(
      connected: connected,
      everConnected: everConnected,
      watchAppStatus: watchAppStatus,
    ));
  }
}
