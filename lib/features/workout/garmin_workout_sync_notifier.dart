import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/models/equipment_catalog.dart';
import '../../core/providers/equipment_catalog_notifier.dart';
import '../../core/services/garmin_service.dart';
import '../config/garmin_notifier.dart';
import 'garmin_watch_commands.dart';
import 'garmin_watch_snapshot.dart';
import 'workout_notifier.dart';

part 'garmin_workout_sync_notifier.g.dart';

@Riverpod(keepAlive: true)
class GarminWorkoutSyncNotifier extends _$GarminWorkoutSyncNotifier {
  final GarminService _service = GarminService();
  StreamSubscription<String>? _commandSub;
  WatchChangeKey? _lastSentKey;

  @override
  Future<void> build() async {
    // Kein Garmin-Geraet je verbunden -- garminProvider bewusst NICHT
    // beobachten. Ein ref.listen weiter unten wuerde garminProvider sofort
    // bauen, und GarminNotifier.build() fragt dabei Bluetooth-Permissions
    // an (garmin_notifier.dart -> isWatchConnected() ->
    // _ensureBluetoothPermissions()) -- das wuerde sonst JEDE Nutzerin
    // gleich beim allerersten App-Start mit einem Bluetooth-Dialog
    // begruessen, auch ganz ohne Garmin-Uhr. Verbindet sich der Nutzer
    // waehrend dieser Sitzung zum allerersten Mal (ueber die Einstellungen,
    // bestehender Weg), wird die Watch-Steuerung erst beim naechsten
    // App-Start aktiv -- seltener Uebergangsfall, kein Blocker
    // (Korrekturlesung, gefunden per Code-Ausfuehrung).
    if (!await GarminService().hasEverConnected()) return;

    final catalog = await ref.read(equipmentCatalogProvider.future);

    ref.listen<AsyncValue<WorkoutState>>(workoutProvider, (previous, next) {
      final state = next.value;
      if (state == null) return;
      _maybeSend(state, catalog);
    });

    // Dieses ref.listen haelt garminProvider (an sich autoDispose) ab jetzt
    // dauerhaft am Leben, weil es fortan immer mindestens einen Watcher hat
    // -- gewollt: dessen watchAppRunningEvents()-Subscription soll nicht
    // mehr abreissen, sobald z.B. die Einstellungen geschlossen werden.
    ref.listen<AsyncValue<GarminConnectionStatus>>(garminProvider, (previous, next) {
      final status = next.value;
      if (status == null) return;
      final wasRunning = previous?.value?.watchAppStatus == WatchAppStatus.running;
      final isRunning = status.watchAppStatus == WatchAppStatus.running;
      if (isRunning && !wasRunning) {
        // Kaltstart-Huckepack: sobald die Watch-App als "running" erkannt
        // wird, sofort einen frischen Snapshot schicken, unabhaengig vom
        // Aenderungs-Schluessel (siehe Design-Spec, Scope-Entscheidung 2).
        final state = ref.read(workoutProvider).value;
        if (state != null) unawaited(_send(state, catalog));
      }
    });

    _commandSub?.cancel();
    _commandSub = _service.watchCommands().listen((command) {
      final state = ref.read(workoutProvider).value;
      if (state == null) return;
      final notifier = ref.read(workoutProvider.notifier);
      applyWatchCommand(
        command,
        state,
        pause: notifier.pause,
        start: notifier.start,
        confirmInterval: notifier.confirmInterval,
        skip: notifier.skip,
        startHold: notifier.startHold,
        finishHold: notifier.finishHold,
      );
    });
    ref.onDispose(() => _commandSub?.cancel());
  }

  void _maybeSend(WorkoutState state, EquipmentCatalog catalog) {
    final key = watchChangeKeyFor(state);
    if (key == _lastSentKey) return;
    _lastSentKey = key;
    unawaited(_send(state, catalog));
  }

  Future<void> _send(WorkoutState state, EquipmentCatalog catalog) async {
    if (ref.read(garminProvider).value?.watchAppStatus != WatchAppStatus.running) {
      return;
    }
    await _service.sendStateSnapshot(buildStateSnapshot(state, catalog));
  }

  /// Wird bei jedem `AppLifecycleState.resumed` erneut aufgerufen (siehe
  /// `app.dart`, Task 8) -- ersetzt den Selbstheilungs-Pfad, der bisher am
  /// wiederholten Oeffnen der Einstellungen (EventChannel.onListen) hing
  /// und durch den dauerhaften Abonnenten hier wegfaellt.
  Future<void> retryRegistration() async {
    await _service.retryCommandRegistration();
  }
}
