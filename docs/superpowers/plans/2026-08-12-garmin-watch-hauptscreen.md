# Garmin-Watch: Hauptscreen-Spiegelung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spiegelt den Trainings-Hauptscreen der Handy-App auf die Garmin-Uhr (Venu 4) — Anzeige plus Steuerung über die zwei physischen Buttons (Pause/Weiter/Start/Fertig oben, Skip unten).

**Architecture:** Bidirektionale Erweiterung der bestehenden Connect-IQ-App-Messages-Kanäle. Handy pusht bei jeder relevanten `WorkoutNotifier`-Zustandsänderung einen `state_snapshot`-Snapshot (Dictionary), die Uhr rechnet den Countdown dazwischen lokal weiter. Uhr sendet `cmd_*`-Strings über den bestehenden Rückkanal, ein neuer Riverpod-Provider (`garminWorkoutSyncNotifier`) vermittelt zwischen `workoutProvider` und `GarminService`, ohne dass `WorkoutNotifier` selbst etwas von Garmin weiß.

**Tech Stack:** Flutter/Dart (Riverpod mit Codegen), Kotlin (Connect IQ Mobile SDK), Monkey C (Connect IQ Watch SDK).

## Global Constraints

- Deutsche UI-Texte überall (Watch-Screens, Kommentare in Nutzertexten).
- Jeder `@riverpod`-Provider braucht `dart run build_runner build` danach, um `.g.dart` zu regenerieren.
- `garminWorkoutSyncProvider` ist `@Riverpod(keepAlive: true)` — muss die ganze App-Laufzeit über aktiv bleiben, auch im Hintergrund (nicht wie der Wakelock bei `AppLifecycleState.paused` abmelden).
- Zielgerät: `venu445mm` (Venu 4, 45mm) — kein anderes Produkt in `garmin_watch_app/manifest.xml` ergänzen.
- Reset wird niemals von der Uhr ausgelöst — kein `cmd_reset` im Protokoll.
- Kein Heartbeat, kein Request/Response-Protokoll für den Kaltstart — beides bewusst nicht im Scope (siehe Design-Spec).
- Kein neuer Kotlin-`EventChannel`/`MethodChannel`-Name — alles läuft über die bestehenden `com.example.emom_app/garmin` und `com.example.emom_app/garmin_events`.
- `flutter analyze` und `flutter test` müssen nach jedem Dart-Task grün bleiben.
- Referenz-Spec: `docs/superpowers/specs/2026-08-12-garmin-watch-hauptscreen-design.md` (bereits xhigh-Opus-korrekturgelesen — bei Widersprüchen zwischen diesem Plan und der Spec gilt der Plan, er ist die konkretere, spätere Quelle).

---

### Task 1: GarminService — ein einziger geteilter EventChannel-Stream + Kommando-Stream

**Files:**
- Modify: `lib/core/services/garmin_service.dart`
- Test: `test/core/services/garmin_service_test.dart`

**Interfaces:**
- Consumes: nichts Neues (bestehender `_eventChannel`, `_channel`)
- Produces: `Stream<String> GarminService.watchCommands()` — gefilterte Sicht auf `cmd_*`-Strings, für Task 6 (Sync-Notifier)

**Hintergrund:** `receiveBroadcastStream()` erzeugt bei jedem Aufruf einen neuen, unabhängigen `StreamController`, der eigenständig `onListen`/`onCancel` auf dem nativen Kanal auslöst. Ruft man es zweimal auf (heute: einmal für `watchAppRunningEvents()`, künftig zusätzlich für `watchCommands()`), überschreiben sich die beiden nativen Handler gegenseitig — schließt z.B. `garminProvider` seinen Abonnenten (Einstellungen zu), reißt das den Kommando-Stream mit ab. Fix: `receiveBroadcastStream()` genau einmal aufrufen, das Ergebnis cachen, beide öffentlichen Streams sind nur noch `.where()`/`.map()`-Sichten auf diesen einen geteilten Stream.

- [ ] **Step 1: Schreibe den fehlschlagenden Test für `watchCommands()`**

In `test/core/services/garmin_service_test.dart`, in der bestehenden `group('watchAppRunningEvents', ...)`-Umgebung eine neue Gruppe danach einfügen (gleiche Datei, gleicher `eventChannel`-Const, gleiches `tearDown`-Pattern):

```dart
  group('watchCommands', () {
    const eventChannel = EventChannel('com.example.emom_app/garmin_events');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('liefert nur cmd_*-Payloads, ignoriert opened/closed', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            events.success('opened');
            events.success('cmd_pause');
            events.success('cmd_skip');
          },
        ),
      );

      final service = GarminService();
      final results = await service.watchCommands().take(2).toList();
      expect(results, ['cmd_pause', 'cmd_skip']);
    });

    test('watchAppRunningEvents und watchCommands teilen sich einen Listener', () async {
      var listenCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            listenCount++;
            events.success('opened');
            events.success('cmd_pause');
          },
        ),
      );

      final service = GarminService();
      final runningSub = service.watchAppRunningEvents().listen((_) {});
      final commandsSub = service.watchCommands().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(listenCount, 1);
      await runningSub.cancel();
      await commandsSub.cancel();
    });
  });
```

- [ ] **Step 2: Test ausführen, muss fehlschlagen**

Run: `flutter test test/core/services/garmin_service_test.dart`
Expected: FAIL — `watchCommands` ist keine Methode von `GarminService`, und `listenCount` wäre ohne den Fix `2` statt `1`.

- [ ] **Step 3: `GarminService` auf geteilten Stream umstellen**

In `lib/core/services/garmin_service.dart`, das bestehende `watchAppRunningEvents()` ersetzen und `watchCommands()` ergänzen:

```dart
  Stream<Object?>? _rawEventsCache;

  /// Genau ein `receiveBroadcastStream()`-Aufruf fuer die gesamte
  /// Prozesslaufzeit -- mehrere Aufrufe wuerden unabhaengige native
  /// onListen/onCancel-Zyklen ausloesen und sich gegenseitig die
  /// Zustellung kappen (siehe Design-Spec, Architektur-Abschnitt).
  Stream<Object?> get _rawEvents =>
      _rawEventsCache ??= _eventChannel.receiveBroadcastStream();

  /// Live-Ereignisse der Watch-App: `true` bei "opened", `false` bei
  /// "closed". Unbekannte Payloads werden verworfen statt einen Fehler
  /// zu werfen (best-effort BLE-Zustellung, siehe Design-Spec).
  Stream<bool> watchAppRunningEvents() {
    return _rawEvents
        .where((event) => event == 'opened' || event == 'closed')
        .map((event) => event == 'opened');
  }

  /// Bedien-Kommandos von der Uhr (`cmd_pause`, `cmd_resume`, `cmd_confirm`,
  /// `cmd_skip`). Geteilte Quelle mit [watchAppRunningEvents] -- siehe dort.
  Stream<String> watchCommands() {
    return _rawEvents
        .where((event) => event is String && event.startsWith('cmd_'))
        .cast<String>();
  }
```

- [ ] **Step 4: Tests ausführen, müssen passen**

Run: `flutter test test/core/services/garmin_service_test.dart`
Expected: PASS (alle Tests, inkl. der beiden neuen und der bestehenden `watchAppRunningEvents`-Tests, die durch die Umstellung nicht brechen dürfen)

- [ ] **Step 5: `flutter analyze` und vollständige Testsuite**

Run: `flutter analyze && flutter test`
Expected: keine Fehler, alle Tests grün

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/garmin_service.dart test/core/services/garmin_service_test.dart
git commit -m "feat(garmin): geteilter EventChannel-Stream + watchCommands()"
```

---

### Task 2: Snapshot-Formatierung — screenState-Ableitung, Zeilen-Text, Snapshot-Builder

**Files:**
- Create: `lib/features/workout/garmin_watch_snapshot.dart`
- Test: `test/features/workout/garmin_watch_snapshot_test.dart`

**Interfaces:**
- Consumes: `WorkoutState`/`IntervalConfig` (`lib/features/workout/workout_notifier.dart`, `lib/core/models/training_plan.dart`), `EquipmentCatalog`/`EquipmentType`/`ExerciseType` (`lib/core/models/equipment_catalog.dart`), `ExerciseSide.shortLabel` (`lib/core/models/settings.dart`)
- Produces:
  - `enum WatchScreenState { paused, running, holdWaiting, holding, confirming, finished }` mit `String get wireValue`
  - `WatchScreenState watchScreenStateFor(WorkoutState state)`
  - `Map<String, dynamic> buildStateSnapshot(WorkoutState state, EquipmentCatalog catalog)`
  — beide werden von Task 3 (Change-Key) und Task 6 (Sync-Notifier) importiert.

- [ ] **Step 1: Schreibe die fehlschlagenden Tests**

Neue Datei `test/features/workout/garmin_watch_snapshot_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/equipment_catalog.dart';
import 'package:emom_app/core/models/settings.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/features/workout/garmin_watch_snapshot.dart';
import 'package:emom_app/features/workout/workout_notifier.dart';

final _catalog = EquipmentCatalog.defaultCatalog();

IntervalConfig _iv({
  String equipmentTypeId = 'kettlebell',
  String? variantId = 'kb_20',
  String exerciseTypeId = 'swing_beidarmig',
  ExerciseSide? side,
  int reps = 14,
  int durationSeconds = 60,
  bool isPause = false,
}) =>
    IntervalConfig(
      equipmentTypeId: equipmentTypeId,
      variantId: variantId,
      exerciseTypeId: exerciseTypeId,
      side: side,
      reps: reps,
      durationSeconds: durationSeconds,
      isPause: isPause,
    );

WorkoutState _state({
  required List<IntervalConfig> intervals,
  int currentMinute = 0,
  int secondsLeft = 42,
  bool isRunning = false,
  bool isFinished = false,
  bool waitingForConfirmation = false,
  List<bool>? timedFlags,
  bool holdStarted = false,
}) =>
    WorkoutState(
      intervals: intervals,
      currentMinute: currentMinute,
      secondsLeft: secondsLeft,
      isRunning: isRunning,
      isFinished: isFinished,
      waitingForConfirmation: waitingForConfirmation,
      totalRepsDone: 0,
      completedIntervals: const [],
      timedFlags: timedFlags ?? List.filled(intervals.length, false),
      holdStarted: holdStarted,
    );

void main() {
  group('watchScreenStateFor', () {
    test('finished hat Vorrang vor allem anderen', () {
      final s = _state(
        intervals: [_iv()],
        isFinished: true,
        waitingForConfirmation: true,
        isRunning: true,
      );
      expect(watchScreenStateFor(s), WatchScreenState.finished);
    });

    test('confirming, wenn waitingForConfirmation', () {
      final s = _state(intervals: [_iv(), _iv()], waitingForConfirmation: true);
      expect(watchScreenStateFor(s), WatchScreenState.confirming);
    });

    test('holdWaiting fuer Zeit-Uebung vor dem Start', () {
      final s = _state(intervals: [_iv()], timedFlags: [true]);
      expect(watchScreenStateFor(s), WatchScreenState.holdWaiting);
    });

    test('holding ist unabhaengig von isRunning', () {
      final running = _state(
          intervals: [_iv()], timedFlags: [true], holdStarted: true, isRunning: true);
      final paused = _state(
          intervals: [_iv()], timedFlags: [true], holdStarted: true, isRunning: false);
      expect(watchScreenStateFor(running), WatchScreenState.holding);
      expect(watchScreenStateFor(paused), WatchScreenState.holding);
    });

    test('running, wenn isRunning und nicht Zeit-Uebung', () {
      final s = _state(intervals: [_iv()], isRunning: true);
      expect(watchScreenStateFor(s), WatchScreenState.running);
    });

    test('paused als Default', () {
      final s = _state(intervals: [_iv()]);
      expect(watchScreenStateFor(s), WatchScreenState.paused);
    });

    test('wireValue liefert die snake_case-Strings aus der Spec', () {
      expect(WatchScreenState.holdWaiting.wireValue, 'hold_waiting');
      expect(WatchScreenState.holding.wireValue, 'holding');
      expect(WatchScreenState.confirming.wireValue, 'confirming');
    });
  });

  group('buildStateSnapshot', () {
    test('formatiert Geraet+Gewicht / Uebung+Seite auf zwei Zeilen', () {
      final iv = _iv(
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_20',
        exerciseTypeId: 'swing_einarmig',
        side: ExerciseSide.links,
      );
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['line1'], 'Kettlebell 20 kg');
      expect(snap['line2'], 'Swing einarmig · L');
      expect(snap['isPause'], false);
      expect(snap['isTimed'], false);
      expect(snap['reps'], 14);
      expect(snap['screenState'], 'paused');
    });

    test('Pause-Intervall: line1 Pause, line2 leer, reps 0', () {
      final iv = _iv(isPause: true, reps: 0);
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['line1'], 'Pause');
      expect(snap['line2'], '');
      expect(snap['isPause'], true);
      expect(snap['reps'], 0);
    });

    test('nextText zeigt die naechste Uebung, mit "Naechste:"-Praefix', () {
      final s = _state(intervals: [
        _iv(exerciseTypeId: 'swing_beidarmig'),
        _iv(exerciseTypeId: 'snatch', side: ExerciseSide.rechts, variantId: 'kb_24'),
      ]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['nextText'], 'Nächste: Kettlebell 24 kg · Snatch · R');
    });

    test('nextText fuer Pause-Intervall exakt wie am Handy formatiert', () {
      final s = _state(
          intervals: [_iv(), _iv(isPause: true, reps: 0, durationSeconds: 60)]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['nextText'], 'Nächste: Pause · 60s');
    });

    test('nextText ist leer beim letzten Intervall', () {
      final s = _state(intervals: [_iv()], currentMinute: 0);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['nextText'], '');
    });

    test('finished-Snapshot sucht rueckwaerts bis zur letzten Nicht-Pause-Uebung', () {
      final s = _state(
        intervals: [
          _iv(exerciseTypeId: 'swing_beidarmig', variantId: 'kb_16'),
          _iv(isPause: true, reps: 0),
        ],
        currentMinute: 1,
        isFinished: true,
      );
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['line1'], 'Kettlebell 16 kg');
      expect(snap['line2'], 'Swing beidarmig');
      expect(snap['screenState'], 'finished');
    });

    test('totalReps ist die Plan-Summe, nicht totalRepsDone', () {
      final s = _state(intervals: [_iv(reps: 10), _iv(reps: 20)]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['totalReps'], 30);
    });

    test('isTimed-Intervall: reps 0, duration ist das Ziel', () {
      final s = _state(
        intervals: [_iv(reps: 0, durationSeconds: 45), _iv()],
        timedFlags: [true, false],
      );
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['isTimed'], true);
      expect(snap['reps'], 0);
      expect(snap['duration'], 45);
    });
  });
}
```

- [ ] **Step 2: Test ausführen, muss fehlschlagen**

Run: `flutter test test/features/workout/garmin_watch_snapshot_test.dart`
Expected: FAIL — Datei `lib/features/workout/garmin_watch_snapshot.dart` existiert noch nicht.

- [ ] **Step 3: Implementiere `garmin_watch_snapshot.dart`**

```dart
import '../../core/models/equipment_catalog.dart';
import '../../core/models/training_plan.dart';
import 'workout_notifier.dart';

enum WatchScreenState { paused, running, holdWaiting, holding, confirming, finished }

extension WatchScreenStateWire on WatchScreenState {
  String get wireValue => switch (this) {
        WatchScreenState.paused => 'paused',
        WatchScreenState.running => 'running',
        WatchScreenState.holdWaiting => 'hold_waiting',
        WatchScreenState.holding => 'holding',
        WatchScreenState.confirming => 'confirming',
        WatchScreenState.finished => 'finished',
      };
}

/// Ableitung, erste zutreffende Regel gewinnt -- siehe Design-Spec,
/// Abschnitt "Architektur & Datenfluss".
WatchScreenState watchScreenStateFor(WorkoutState s) {
  if (s.isFinished) return WatchScreenState.finished;
  if (s.waitingForConfirmation) return WatchScreenState.confirming;
  if (s.holdWaiting) return WatchScreenState.holdWaiting;
  if (s.currentIsTimed && s.holdStarted) return WatchScreenState.holding;
  if (s.isRunning) return WatchScreenState.running;
  return WatchScreenState.paused;
}

class _WatchLines {
  final String line1;
  final String line2;
  const _WatchLines(this.line1, this.line2);
}

const _pauseLines = _WatchLines('Pause', '');

_WatchLines _formatInterval(IntervalConfig iv, EquipmentCatalog catalog) {
  if (iv.isPause) return _pauseLines;
  final eqType = catalog.findType(iv.equipmentTypeId);
  if (eqType == null) return const _WatchLines('?', '');
  final variant = iv.variantId != null
      ? eqType.variants.where((v) => v.id == iv.variantId).firstOrNull
      : null;
  final exercise =
      eqType.exercises.where((e) => e.id == iv.exerciseTypeId).firstOrNull;
  final line1 = variant != null ? '${eqType.name} ${variant.label}' : eqType.name;
  final exerciseName = exercise?.name ?? '?';
  final line2 = (exercise?.hasSide == true && iv.side != null)
      ? '$exerciseName · ${iv.side!.shortLabel}'
      : exerciseName;
  return _WatchLines(line1, line2);
}

_WatchLines _lastNonPauseLines(WorkoutState s, EquipmentCatalog catalog) {
  for (var i = s.currentMinute; i >= 0; i--) {
    if (!s.intervals[i].isPause) return _formatInterval(s.intervals[i], catalog);
  }
  return const _WatchLines('', '');
}

String _nextTextFor(WorkoutState s, EquipmentCatalog catalog) {
  final nextMinute = s.currentMinute + 1;
  if (nextMinute >= s.totalMinutes) return '';
  final next = s.intervals[nextMinute];
  if (next.isPause) return 'Nächste: Pause · ${next.durationSeconds}s';
  final lines = _formatInterval(next, catalog);
  return 'Nächste: ${lines.line1} · ${lines.line2}';
}

/// Baut den `state_snapshot`-Dictionary-Payload fuer die Uhr (siehe
/// Design-Spec, Abschnitt "Architektur & Datenfluss").
Map<String, dynamic> buildStateSnapshot(WorkoutState s, EquipmentCatalog catalog) {
  final screenState = watchScreenStateFor(s);
  final iv = s.intervals[s.currentMinute];
  final lines = screenState == WatchScreenState.finished
      ? _lastNonPauseLines(s, catalog)
      : _formatInterval(iv, catalog);
  return {
    'type': 'state_snapshot',
    'minute': s.currentMinute,
    'totalMinutes': s.totalMinutes,
    'line1': lines.line1,
    'line2': lines.line2,
    'isPause': iv.isPause,
    'isTimed': s.currentIsTimed,
    'reps': s.currentReps,
    'secondsLeft': s.secondsLeft,
    'duration': s.currentDuration,
    'screenState': screenState.wireValue,
    'nextText': _nextTextFor(s, catalog),
    'totalReps': s.totalReps,
  };
}
```

- [ ] **Step 4: Tests ausführen, müssen passen**

Run: `flutter test test/features/workout/garmin_watch_snapshot_test.dart`
Expected: PASS (alle 15 Tests)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: keine Fehler

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/garmin_watch_snapshot.dart test/features/workout/garmin_watch_snapshot_test.dart
git commit -m "feat(garmin): screenState-Ableitung und Snapshot-Builder fuer die Watch"
```

---

### Task 3: Änderungs-Schlüssel — kein Push bei reinem Sekunden-Tick

**Files:**
- Modify: `lib/features/workout/garmin_watch_snapshot.dart`
- Test: `test/features/workout/garmin_watch_snapshot_test.dart`

**Interfaces:**
- Consumes: `WorkoutState` (Task 2 kennt den Typ bereits)
- Produces: `typedef WatchChangeKey`, `WatchChangeKey watchChangeKeyFor(WorkoutState state)` — für Task 6 (Sync-Notifier)

- [ ] **Step 1: Schreibe die fehlschlagenden Tests**

An `test/features/workout/garmin_watch_snapshot_test.dart` anhängen:

```dart
  group('watchChangeKeyFor', () {
    test('gleicher Schluessel bei reinem secondsLeft-Wechsel', () {
      final a = _state(intervals: [_iv()], isRunning: true, secondsLeft: 42);
      final b = _state(intervals: [_iv()], isRunning: true, secondsLeft: 41);
      expect(watchChangeKeyFor(a), watchChangeKeyFor(b));
    });

    test('unterschiedlicher Schluessel bei Minutenwechsel', () {
      final a = _state(intervals: [_iv(), _iv()], currentMinute: 0);
      final b = _state(intervals: [_iv(), _iv()], currentMinute: 1);
      expect(watchChangeKeyFor(a), isNot(watchChangeKeyFor(b)));
    });

    test('unterschiedlicher Schluessel bei isRunning-Wechsel', () {
      final a = _state(intervals: [_iv()], isRunning: false);
      final b = _state(intervals: [_iv()], isRunning: true);
      expect(watchChangeKeyFor(a), isNot(watchChangeKeyFor(b)));
    });

    test('unterschiedlicher Schluessel bei waitingForConfirmation-Wechsel', () {
      final a = _state(intervals: [_iv(), _iv()], waitingForConfirmation: false);
      final b = _state(intervals: [_iv(), _iv()], waitingForConfirmation: true);
      expect(watchChangeKeyFor(a), isNot(watchChangeKeyFor(b)));
    });
  });
```

- [ ] **Step 2: Test ausführen, muss fehlschlagen**

Run: `flutter test test/features/workout/garmin_watch_snapshot_test.dart`
Expected: FAIL — `watchChangeKeyFor` existiert noch nicht.

- [ ] **Step 3: Implementiere den Änderungs-Schlüssel**

An `lib/features/workout/garmin_watch_snapshot.dart` anhängen:

```dart
typedef WatchChangeKey = ({
  int minute,
  bool isRunning,
  bool isPause,
  bool isTimed,
  bool holdWaiting,
  bool holdStarted,
  bool waitingForConfirmation,
  bool isFinished,
});

/// Nur wenn sich mindestens eines dieser Felder aendert, lohnt sich ein
/// Push an die Uhr -- explizit NICHT bei jedem `secondsLeft`-Tick (siehe
/// Design-Spec, Scope-Entscheidung 1).
WatchChangeKey watchChangeKeyFor(WorkoutState s) => (
      minute: s.currentMinute,
      isRunning: s.isRunning,
      isPause: s.intervals[s.currentMinute].isPause,
      isTimed: s.currentIsTimed,
      holdWaiting: s.holdWaiting,
      holdStarted: s.holdStarted,
      waitingForConfirmation: s.waitingForConfirmation,
      isFinished: s.isFinished,
    );
```

- [ ] **Step 4: Tests ausführen, müssen passen**

Run: `flutter test test/features/workout/garmin_watch_snapshot_test.dart`
Expected: PASS (alle Tests aus Task 2 + Task 3)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: keine Fehler

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/garmin_watch_snapshot.dart test/features/workout/garmin_watch_snapshot_test.dart
git commit -m "feat(garmin): Aenderungs-Schluessel gegen Sekunden-Ticks"
```

---

### Task 4: Guardierter Kommando-Dispatcher

**Files:**
- Create: `lib/features/workout/garmin_watch_commands.dart`
- Test: `test/features/workout/garmin_watch_commands_test.dart`

**Interfaces:**
- Consumes: `WorkoutState` (`workout_notifier.dart`)
- Produces: `void applyWatchCommand(String command, WorkoutState state, {required VoidCallback pause, required VoidCallback start, required VoidCallback confirmInterval, required VoidCallback skip, required VoidCallback startHold, required VoidCallback finishHold})` — für Task 6 (Sync-Notifier), das echte `WorkoutNotifier`-Methoden als Callbacks übergibt.

**Hintergrund:** `confirmInterval()` und `start()` haben in `WorkoutNotifier` keine Guards (anders als `skip()`/`startHold()`/`finishHold()`) — ein verspätetes Kommando von der Uhr könnte sonst einen Index-Fehler bzw. einen doppelten Timer auslösen (siehe Design-Spec, Korrekturlesung). Der Dispatcher guardet deshalb selbst, bevor er eine der sechs Methoden aufruft.

- [ ] **Step 1: Schreibe die fehlschlagenden Tests**

Neue Datei `test/features/workout/garmin_watch_commands_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/features/workout/garmin_watch_commands.dart';
import 'package:emom_app/features/workout/workout_notifier.dart';

IntervalConfig _iv({int reps = 10}) => IntervalConfig(
    reps: reps, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig');

class _Calls {
  int pause = 0, start = 0, confirm = 0, skip = 0, startHold = 0, finishHold = 0;
}

WorkoutState _state({
  int currentMinute = 0,
  bool isRunning = false,
  bool isFinished = false,
  bool waitingForConfirmation = false,
  List<bool>? timedFlags,
  bool holdStarted = false,
}) =>
    WorkoutState(
      intervals: [_iv(), _iv()],
      currentMinute: currentMinute,
      secondsLeft: 42,
      isRunning: isRunning,
      isFinished: isFinished,
      waitingForConfirmation: waitingForConfirmation,
      totalRepsDone: 0,
      completedIntervals: const [],
      timedFlags: timedFlags ?? const [false, false],
      holdStarted: holdStarted,
    );

void main() {
  late _Calls calls;

  void apply(String command, WorkoutState state) {
    applyWatchCommand(
      command,
      state,
      pause: () => calls.pause++,
      start: () => calls.start++,
      confirmInterval: () => calls.confirm++,
      skip: () => calls.skip++,
      startHold: () => calls.startHold++,
      finishHold: () => calls.finishHold++,
    );
  }

  setUp(() => calls = _Calls());

  test('cmd_pause pausiert nur wenn isRunning', () {
    apply('cmd_pause', _state(isRunning: true));
    expect(calls.pause, 1);
    apply('cmd_pause', _state(isRunning: false));
    expect(calls.pause, 1); // unveraendert, kein zweiter Aufruf
  });

  test('cmd_resume startet, wenn paused und nicht Zeit-Uebung', () {
    apply('cmd_resume', _state(isRunning: false));
    expect(calls.start, 1);
  });

  test('cmd_resume ruft startHold auf, wenn holdWaiting', () {
    apply('cmd_resume', _state(timedFlags: const [true, false]));
    expect(calls.startHold, 1);
    expect(calls.start, 0);
  });

  test('cmd_resume ruft finishHold auf, wenn Zeit-Uebung schon gestartet', () {
    apply('cmd_resume',
        _state(timedFlags: const [true, false], holdStarted: true, isRunning: true));
    expect(calls.finishHold, 1);
    expect(calls.start, 0);
  });

  test('cmd_resume ist No-Op, wenn schon running und nicht Zeit-Uebung', () {
    apply('cmd_resume', _state(isRunning: true));
    expect(calls.start, 0);
  });

  test('cmd_confirm bestaetigt nur wenn waitingForConfirmation', () {
    apply('cmd_confirm', _state(waitingForConfirmation: true));
    expect(calls.confirm, 1);
    apply('cmd_confirm', _state(waitingForConfirmation: false));
    expect(calls.confirm, 1); // kein Absturz, kein zweiter Aufruf
  });

  test('cmd_skip laeuft ins Leere bei waitingForConfirmation oder isFinished', () {
    apply('cmd_skip', _state(waitingForConfirmation: true));
    expect(calls.skip, 0);
    apply('cmd_skip', _state(isFinished: true));
    expect(calls.skip, 0);
    apply('cmd_skip', _state());
    expect(calls.skip, 1);
  });

  test('unbekanntes Kommando loest nichts aus', () {
    apply('cmd_unbekannt', _state(isRunning: true));
    expect(calls.pause + calls.start + calls.confirm + calls.skip + calls.startHold + calls.finishHold, 0);
  });
}
```

- [ ] **Step 2: Test ausführen, muss fehlschlagen**

Run: `flutter test test/features/workout/garmin_watch_commands_test.dart`
Expected: FAIL — `lib/features/workout/garmin_watch_commands.dart` existiert noch nicht.

- [ ] **Step 3: Implementiere den Dispatcher**

Neue Datei `lib/features/workout/garmin_watch_commands.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'workout_notifier.dart';

/// Setzt ein `cmd_*`-Kommando von der Uhr auf die passende
/// `WorkoutNotifier`-Methode um, mit Guards gegen verspaetete/ungueltige
/// Kommandos (siehe Design-Spec, Korrekturlesung: `confirmInterval()` und
/// `start()` haben selbst keine Guards).
void applyWatchCommand(
  String command,
  WorkoutState state, {
  required VoidCallback pause,
  required VoidCallback start,
  required VoidCallback confirmInterval,
  required VoidCallback skip,
  required VoidCallback startHold,
  required VoidCallback finishHold,
}) {
  switch (command) {
    case 'cmd_pause':
      if (state.isRunning) pause();
      return;
    case 'cmd_resume':
      if (state.holdWaiting) {
        startHold();
      } else if (state.currentIsTimed && state.holdStarted) {
        finishHold();
      } else if (!state.isRunning &&
          !state.waitingForConfirmation &&
          !state.isFinished) {
        start();
      }
      return;
    case 'cmd_confirm':
      if (state.waitingForConfirmation) confirmInterval();
      return;
    case 'cmd_skip':
      if (!state.waitingForConfirmation && !state.isFinished) skip();
      return;
  }
}
```

- [ ] **Step 4: Tests ausführen, müssen passen**

Run: `flutter test test/features/workout/garmin_watch_commands_test.dart`
Expected: PASS (alle 8 Tests)

- [ ] **Step 5: `flutter analyze` und vollständige Testsuite**

Run: `flutter analyze && flutter test`
Expected: keine Fehler, alle Tests grün

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/garmin_watch_commands.dart test/features/workout/garmin_watch_commands_test.dart
git commit -m "feat(garmin): guardierter Kommando-Dispatcher fuer Watch-Buttons"
```

---

### Task 5: Kotlin — `sendStateSnapshot` und Registrierungs-Retry

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/emom_app/GarminBridge.kt`
- Modify: `android/app/src/main/kotlin/com/example/emom_app/MainActivity.kt`

**Interfaces:**
- Consumes: bestehende `GarminBridge`-Struktur (`ensureSdkReady`, `connectIQ`, `watchAppId`, `registerAppEventListener`)
- Produces: MethodChannel-Calls `sendStateSnapshot` (Argument: `Map<String, Any?>`) und `retryEventRegistration` (kein Argument) auf `com.example.emom_app/garmin` — für Task 6/7 (Dart-Seite)

Kein automatisierter Test möglich (SDK-/Hardware-gebunden, wie der Rest von `GarminBridge`) — Verifikation über Kompilieren + spätere manuelle Hardware-Tests (Task 10).

- [ ] **Step 1: `sendStateSnapshot` in `GarminBridge.kt` ergänzen**

Nach der bestehenden `openWatchApp`-Methode einfügen:

```kotlin
    // WICHTIG: exakte ConnectIQ.sendMessage()-Signatur vor dem Bauen gegen
    // die installierte Connect-IQ-SDK-Version verifizieren (siehe
    // Design-Spec, Abschnitt "Fehlerbehandlung" -- nicht primaerquellen-
    // verifiziert, da developer.garmin.com per Fetch nicht erreichbar war).
    fun sendStateSnapshot(payload: Map<String, Any?>, callback: (String) -> Unit) {
        ensureSdkReady { ready ->
            if (!ready) {
                callback("error")
                return@ensureSdkReady
            }
            try {
                val devices = connectIQ.connectedDevices
                val device: IQDevice? = devices?.firstOrNull()
                if (device == null) {
                    callback("no_device")
                    return@ensureSdkReady
                }
                connectIQ.getApplicationInfo(watchAppId, device, object : ConnectIQ.IQApplicationInfoListener {
                    override fun onApplicationInfoReceived(app: IQApp) {
                        try {
                            connectIQ.sendMessage(device, app, payload) { _, _, status ->
                                callback(status.name)
                            }
                        } catch (e: InvalidStateException) {
                            Log.e(TAG, "sendMessage failed", e)
                            callback("error")
                        } catch (e: ServiceUnavailableException) {
                            Log.e(TAG, "sendMessage failed", e)
                            callback("error")
                        }
                    }
                    override fun onApplicationNotInstalled(applicationId: String) {
                        callback("not_installed")
                    }
                })
            } catch (e: InvalidStateException) {
                Log.e(TAG, "getApplicationInfo failed", e)
                callback("error")
            } catch (e: ServiceUnavailableException) {
                Log.e(TAG, "getApplicationInfo failed", e)
                callback("error")
            }
        }
    }
```

- [ ] **Step 2: `MainActivity.kt` um `sendStateSnapshot` und `retryEventRegistration` erweitern**

Datei komplett ersetzen durch:

```kotlin
package com.example.emom_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.emom_app/garmin"
    private val eventChannelName = "com.example.emom_app/garmin_events"
    private var currentEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = GarminBridge(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWatchConnected" -> bridge.isWatchConnected { connected -> result.success(connected) }
                "openWatchApp" -> bridge.openWatchApp { status -> result.success(status) }
                "sendStateSnapshot" -> {
                    @Suppress("UNCHECKED_CAST")
                    val payload = call.arguments as Map<String, Any?>
                    bridge.sendStateSnapshot(payload) { status -> result.success(status) }
                }
                "retryEventRegistration" -> {
                    // registerAppEventListener() ist idempotent (siehe GarminBridge) --
                    // dauerhafte Dart-Abonnenten (Task 6) sorgen dafuer, dass der
                    // native EventChannel.onListen nur einmal pro Prozess feuert,
                    // deshalb dieser explizite Retry-Pfad bei App-Resume.
                    currentEventSink?.let { sink ->
                        bridge.registerAppEventListener { payload -> sink.success(payload) }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    currentEventSink = events
                    bridge.registerAppEventListener { payload -> events.success(payload) }
                }

                override fun onCancel(arguments: Any?) {
                    currentEventSink = null
                    bridge.unregisterAppEventListener()
                }
            }
        )
    }
}
```

- [ ] **Step 3: Android-Build verifizieren**

Run: `flutter build apk --debug`
Expected: Build erfolgreich, keine Kotlin-Compile-Fehler. Falls `ConnectIQ.sendMessage()` nicht mit dieser Signatur existiert, gegen die installierte SDK-Version anpassen (siehe Kommentar in Step 1) — das ist der in der Design-Spec dokumentierte offene Verifikationspunkt.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/example/emom_app/GarminBridge.kt android/app/src/main/kotlin/com/example/emom_app/MainActivity.kt
git commit -m "feat(garmin): sendStateSnapshot und Registrierungs-Retry (Kotlin)"
```

---

### Task 6: `garmin_service.dart` — `sendStateSnapshot`/`retryCommandRegistration`

**Files:**
- Modify: `lib/core/services/garmin_service.dart`
- Test: `test/core/services/garmin_service_test.dart`

**Interfaces:**
- Consumes: `MethodChannel` (bestehend), Kotlin-Seite aus Task 5
- Produces: `Future<void> GarminService.sendStateSnapshot(Map<String, dynamic> payload)`, `Future<void> GarminService.retryCommandRegistration()` — für Task 7 (Sync-Notifier)

- [ ] **Step 1: Schreibe die fehlschlagenden Tests**

An `test/core/services/garmin_service_test.dart` anhängen (im bestehenden `setUp`-Mock-Handler für `channel` zusätzlich `case 'sendStateSnapshot': return 'SUCCESS';` und `case 'retryEventRegistration': return null;` ergänzen — die Datei dafür an der bestehenden `switch (call.method)`-Stelle in `setUp` erweitern):

```dart
        case 'sendStateSnapshot':
          return 'SUCCESS';
        case 'retryEventRegistration':
          return null;
```

(Diese zwei Zeilen in den bestehenden `switch` in `setUp()` einfügen, direkt nach dem `case 'openWatchApp':`-Block.) Danach neue Tests ergänzen:

```dart
  test('sendStateSnapshot ruft den MethodChannel mit dem Payload auf', () async {
    final service = GarminService();
    await service.sendStateSnapshot({'type': 'state_snapshot', 'minute': 5});
    expect(calls.last.method, 'sendStateSnapshot');
    expect(calls.last.arguments, {'type': 'state_snapshot', 'minute': 5});
  });

  test('retryCommandRegistration ruft den MethodChannel auf', () async {
    final service = GarminService();
    await service.retryCommandRegistration();
    expect(calls.last.method, 'retryEventRegistration');
  });
```

- [ ] **Step 2: Test ausführen, muss fehlschlagen**

Run: `flutter test test/core/services/garmin_service_test.dart`
Expected: FAIL — `sendStateSnapshot`/`retryCommandRegistration` existieren noch nicht auf `GarminService`.

- [ ] **Step 3: Implementiere beide Methoden**

An `lib/core/services/garmin_service.dart` anhängen (innerhalb der Klasse):

```dart
  Future<void> sendStateSnapshot(Map<String, dynamic> payload) async {
    try {
      await _channel.invokeMethod('sendStateSnapshot', payload);
    } on PlatformException catch (e) {
      debugPrint('GarminService.sendStateSnapshot failed: ${e.code} ${e.message}');
    }
  }

  Future<void> retryCommandRegistration() async {
    try {
      await _channel.invokeMethod('retryEventRegistration');
    } on PlatformException catch (e) {
      debugPrint('GarminService.retryCommandRegistration failed: ${e.code} ${e.message}');
    }
  }
```

- [ ] **Step 4: Tests ausführen, müssen passen**

Run: `flutter test test/core/services/garmin_service_test.dart`
Expected: PASS (alle Tests der Datei)

- [ ] **Step 5: `flutter analyze` und vollständige Testsuite**

Run: `flutter analyze && flutter test`
Expected: keine Fehler, alle Tests grün

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/garmin_service.dart test/core/services/garmin_service_test.dart
git commit -m "feat(garmin): GarminService.sendStateSnapshot/retryCommandRegistration"
```

---

### Task 7: `garminWorkoutSyncNotifier` — Riverpod-Vermittlerschicht

**Files:**
- Create: `lib/features/workout/garmin_workout_sync_notifier.dart`
- Create: `lib/features/workout/garmin_workout_sync_notifier.g.dart` (via `build_runner`, nicht von Hand schreiben)

**Interfaces:**
- Consumes: `workoutProvider`/`WorkoutNotifier` (`workout_notifier.dart`), `garminProvider`/`GarminConnectionStatus`/`WatchAppStatus` (`../config/garmin_notifier.dart`), `equipmentCatalogProvider` (`../../core/providers/equipment_catalog_notifier.dart`), `GarminService` (`../../core/services/garmin_service.dart`), `buildStateSnapshot`/`watchChangeKeyFor` (Task 2/3), `applyWatchCommand` (Task 4)
- Produces: `garminWorkoutSyncProvider` (keepAlive), Methode `retryRegistration()` — für Task 8 (`app.dart`)

Reine Wiring-Schicht ohne eigene Verzweigungslogik (die steckt bereits testgetrieben in Task 2/3/4) — kein zusätzlicher Unit-Test hier, Verifikation über `flutter analyze` und manuelles Starten der App (Step 4).

- [ ] **Step 1: Implementiere den Notifier**

Neue Datei `lib/features/workout/garmin_workout_sync_notifier.dart`:

```dart
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
```

- [ ] **Step 2: `.g.dart` generieren**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/features/workout/garmin_workout_sync_notifier.g.dart` wird erzeugt, `garminWorkoutSyncProvider` ist darin definiert.

- [ ] **Step 3: `flutter analyze`**

Run: `flutter analyze`
Expected: keine Fehler

- [ ] **Step 4: App manuell starten und auf Abstürze prüfen**

Run: `flutter run` (Debug-Build, Emulator oder Gerät reicht — noch ohne Watch-Hardware nötig)
Expected: App startet ohne Absturz; `garminWorkoutSyncProvider` wird noch von niemandem beobachtet, daher inaktiv — das ist erwartet, Task 8 hängt ihn ein.

- [ ] **Step 5: Vollständige Testsuite**

Run: `flutter test`
Expected: alle bestehenden Tests weiterhin grün (dieser Task fügt keine neuen automatisierten Tests hinzu, darf aber nichts brechen)

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/garmin_workout_sync_notifier.dart lib/features/workout/garmin_workout_sync_notifier.g.dart
git commit -m "feat(garmin): garminWorkoutSyncNotifier verbindet WorkoutNotifier und GarminService"
```

---

### Task 8: `app.dart` — Sync-Notifier dauerhaft aktiv halten, Resume-Retry

**Files:**
- Modify: `lib/app.dart`

**Interfaces:**
- Consumes: `garminWorkoutSyncProvider` (Task 7)
- Produces: nichts Neues für andere Tasks — Endpunkt der Dart-Kette

- [ ] **Step 1: Provider im Widget-Baum halten und Resume-Hook ergänzen**

In `lib/app.dart`: Import ergänzen und `build()`/`didChangeAppLifecycleState()` erweitern.

Import ergänzen (nach den bestehenden Imports):

```dart
import 'features/workout/garmin_workout_sync_notifier.dart';
```

`didChangeAppLifecycleState` ersetzen durch:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hold the wakelock only while resumed; release it when backgrounded so
    // the screen can sleep normally when the app isn't visible.
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
      // Ersetzt den Selbstheilungs-Pfad, der bisher am wiederholten Oeffnen
      // der Einstellungen hing (siehe garmin_workout_sync_notifier.dart).
      ref.read(garminWorkoutSyncProvider.notifier).retryRegistration();
    } else {
      WakelockPlus.disable();
    }
  }
```

`build()` ganz am Anfang um eine Watch-Zeile ergänzen (hält den `keepAlive`-Provider von Beginn an aktiv):

```dart
  @override
  Widget build(BuildContext context) {
    ref.watch(garminWorkoutSyncProvider);
    return MaterialApp(
```

(Die bestehende `return MaterialApp(` bleibt unverändert dahinter stehen, nur die neue Zeile davor einfügen.)

- [ ] **Step 2: `flutter analyze`**

Run: `flutter analyze`
Expected: keine Fehler

- [ ] **Step 3: App manuell starten**

Run: `flutter run`
Expected: App startet ohne Absturz, Verhalten unverändert (kein sichtbarer Unterschied ohne Watch-Hardware — dieser Task ist reine Verdrahtung)

- [ ] **Step 4: Vollständige Testsuite**

Run: `flutter test`
Expected: alle Tests grün

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart
git commit -m "feat(garmin): Sync-Notifier dauerhaft aktiv, Registrierungs-Retry bei Resume"
```

---

### Task 9: Watch — Zustandsempfang, Buttons, Exit-Verhalten

**Files:**
- Create: `garmin_watch_app/source/WatchState.mc`
- Create: `garmin_watch_app/source/StateSnapshotListener.mc`
- Modify: `garmin_watch_app/source/garmin_watch_appApp.mc`
- Modify: `garmin_watch_app/source/garmin_watch_appDelegate.mc`

**Interfaces:**
- Consumes: `Communications.registerForPhoneAppMessages()`, `Communications.transmit()` (bereits im Projekt verwendetes Muster aus `AppStatusListener.mc`)
- Produces: `WatchState.current as Dictionary?` und `WatchState.localSecondsLeft as Number` (globaler Zustand inkl. lokal weiterlaufendem Countdown, gelesen von `garmin_watch_appView.mc` in Task 10)

Kein automatisierter Test möglich (Monkey C, wie der Rest von `garmin_watch_app/`) — Verifikation über Connect-IQ-Simulator und Compile-Check.

- [ ] **Step 1: `WatchState.mc` — globaler Zustands-Halter**

Neue Datei `garmin_watch_app/source/WatchState.mc`:

```monkeyc
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Haelt den zuletzt empfangenen state_snapshot-Payload vom Handy UND
// rechnet den Countdown dazwischen lokal weiter (siehe Design-Spec,
// Scope-Entscheidung 1: das Handy pusht nur bei Zustandswechseln, nicht
// jede Sekunde -- ohne diesen lokalen Tick wuerde der Timer auf dem
// Running-Screen zwischen zwei Snapshots einfach stehenbleiben).
module WatchState {
    var current as Dictionary? = null;
    var localSecondsLeft as Number = 0;
    var _tickTimer as Timer.Timer?;

    function update(snapshot as Dictionary) as Void {
        current = snapshot;
        localSecondsLeft = snapshot.get("secondsLeft") as Number;
    }

    // Einmal aus garmin_watch_appApp.onStart() aufgerufen, laeuft dauerhaft.
    function startTicking() as Void {
        if (_tickTimer != null) { return; }
        _tickTimer = new Timer.Timer();
        _tickTimer.start(method(:onTick), 1000, true);
    }

    function onTick() as Void {
        if (current == null) { return; }
        var screenState = current.get("screenState") as String;
        // Nur running/holding zaehlen ueberhaupt runter -- paused/hold_waiting
        // stehen still, confirming/finished zeigen keinen Live-Timer.
        var counting = screenState.equals("running") || screenState.equals("holding");
        if (!counting) { return; }
        // Ausser im holding-Zustand (Ueberzeit ist vorgesehen, siehe
        // TimerDisplay am Handy) haelt der Countdown bei 0 an, statt negativ
        // weiterzuzaehlen (Design-Spec, Fehlerbehandlung).
        var floorAtZero = !screenState.equals("holding");
        if (floorAtZero && localSecondsLeft <= 0) { return; }
        localSecondsLeft -= 1;
        WatchUi.requestUpdate();
    }
}
```

- [ ] **Step 2: `StateSnapshotListener.mc` — Empfang vom Handy**

Neue Datei `garmin_watch_app/source/StateSnapshotListener.mc`:

```monkeyc
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

// Empfaengt state_snapshot-Nachrichten vom Handy (Gegenstueck zu
// AppStatusListener.mc, das die Uhr->Handy-Richtung bedient). Registrierung
// einmalig in garmin_watch_appApp.onStart().
// WICHTIG: exakte registerForPhoneAppMessages()-Signatur vor dem Bauen
// gegen die installierte Connect-IQ-SDK-Version verifizieren (siehe
// Design-Spec, Abschnitt "Fehlerbehandlung").
class StateSnapshotListener {
    function register() as Void {
        Communications.registerForPhoneAppMessages(method(:onMessage));
    }

    function onMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Dictionary && data.get("type").equals("state_snapshot")) {
            WatchState.update(data as Dictionary);
            WatchUi.requestUpdate();
        }
    }
}
```

- [ ] **Step 3: Registrierung + Kommando-Versand in `garmin_watch_appApp.mc`**

Datei komplett ersetzen durch:

```monkeyc
import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

class garmin_watch_appApp extends Application.AppBase {

    var snapshotListener as StateSnapshotListener?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        Communications.transmit("opened", {}, new AppStatusListener());
        snapshotListener = new StateSnapshotListener();
        snapshotListener.register();
        WatchState.startTicking();
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        Communications.transmit("closed", {}, new AppStatusListener());
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new garmin_watch_appView(), new garmin_watch_appDelegate() ];
    }

}

function getApp() as garmin_watch_appApp {
    return Application.getApp() as garmin_watch_appApp;
}

// Sendet ein Bedien-Kommando ans Handy -- von garmin_watch_appDelegate bei
// Tastendruck aufgerufen (siehe Design-Spec, Button-Zustandsmaschine).
function sendWatchCommand(command as String) as Void {
    Communications.transmit(command, {}, new AppStatusListener());
}
```

- [ ] **Step 4: Button-Handling in `garmin_watch_appDelegate.mc`, `onSelect()`-Exit entfernen**

Datei komplett ersetzen durch:

```monkeyc
import Toybox.Lang;
import Toybox.WatchUi;

// onSelect() (oberer Button) beendete die App bisher (Hello-World-Spike-
// Platzhalter) -- entfaellt jetzt, der obere Button steuert Pause/Weiter/
// Start/Fertig. Exit laeuft stattdessen ueber die native Swipe-Rechts-Geste
// des Touchscreens (Scope-Entscheidung 7 der Design-Spec, auf Hardware zu
// verifizieren).
class garmin_watch_appDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Oberer Button: Pause/Weiter/Start/Fertig, je nach aktuellem
    // screenState (siehe WatchState) -- die Watch entscheidet nur zwischen
    // "cmd_pause" (laeuft gerade) und "cmd_resume" (alles andere), die
    // Feinauswertung (Start vs. Zeit-Uebung vs. Fertig) macht das Handy
    // anhand seines vollstaendigen WorkoutState (siehe applyWatchCommand).
    function onSelect() as Boolean {
        var snapshot = WatchState.current;
        if (snapshot == null) { return true; }
        var screenState = snapshot.get("screenState");
        if (screenState.equals("confirming")) {
            sendWatchCommand("cmd_confirm");
        } else if (screenState.equals("running")) {
            sendWatchCommand("cmd_pause");
        } else if (!screenState.equals("finished")) {
            sendWatchCommand("cmd_resume");
        }
        return true;
    }

    // Unterer Button (Back/Lap): Skip.
    function onBack() as Boolean {
        var snapshot = WatchState.current;
        if (snapshot == null) { return true; }
        var screenState = snapshot.get("screenState");
        if (!screenState.equals("confirming") && !screenState.equals("finished")) {
            sendWatchCommand("cmd_skip");
        }
        return true;
    }

}
```

- [ ] **Step 5: Build im Simulator verifizieren**

```bash
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
cd garmin_watch_app
"$SDK/monkeyc.bat" -f monkey.jungle -d venu445mm -o bin/garmin_watch_app.prg -y "$KEY" -w
```

(`$SDK`/`$KEY` wie in `CLAUDE.md`, Abschnitt "Garmin Watch Integration" beschrieben.)
Expected: Build erfolgreich, keine Compile-Fehler. Bei Fehlern zu `registerForPhoneAppMessages()`/`onBack()`-Signatur: gegen die installierte SDK-Referenz korrigieren (siehe Kommentare in Step 2/4).

- [ ] **Step 6: Commit**

```bash
git add garmin_watch_app/source/WatchState.mc garmin_watch_app/source/StateSnapshotListener.mc garmin_watch_app/source/garmin_watch_appApp.mc garmin_watch_app/source/garmin_watch_appDelegate.mc
git commit -m "feat(watch): Zustandsempfang vom Handy, Button-Kommandos, Exit-Wechsel auf Swipe"
```

---

### Task 10: Watch — drei Screens rendern

**Files:**
- Modify: `garmin_watch_app/source/garmin_watch_appView.mc`

**Interfaces:**
- Consumes: `WatchState.current as Dictionary?` und `WatchState.localSecondsLeft as Number` (Task 9)
- Produces: nichts Neues — letzter Watch-seitiger Task

Kein automatisierter Test möglich — Verifikation über Simulator (visuell) und Compile-Check.

- [ ] **Step 1: View komplett neu implementieren**

Datei `garmin_watch_app/source/garmin_watch_appView.mc` komplett ersetzen durch:

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Rendert einen von drei Screens ausschliesslich anhand von
// WatchState.current["screenState"] (siehe Design-Spec, Abschnitt
// "Watch-Screens & Button-Zustandsmaschine"). Kein Rez.Layouts-XML --
// direktes Zeichnen ist bei drei dynamischen, textlastigen Screens
// einfacher als drei statische Layouts zu pflegen.
class garmin_watch_appView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var snapshot = WatchState.current;
        if (snapshot == null) {
            drawCentered(dc, "Verbinde...", dc.getHeight() / 2, Graphics.FONT_SMALL, Graphics.COLOR_LT_GRAY);
            return;
        }

        var screenState = snapshot.get("screenState") as String;
        if (screenState.equals("finished")) {
            drawFinished(dc, snapshot);
        } else if (screenState.equals("confirming")) {
            drawConfirming(dc, snapshot);
        } else {
            drawRunning(dc, snapshot);
        }

        drawButtonHints(dc, screenState);
    }

    function onHide() as Void {
    }

    private function drawCentered(dc as Dc, text as String, y as Number, font, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function phaseColorForMinute(minute as Number) as Number {
        // Muss mit lib/core/models/settings.dart::phaseColorForMinute in
        // Sync bleiben (siehe CLAUDE.md, Abschnitt "Phase color coding").
        if (minute < 5) { return 0x4CAF50; }
        if (minute < 15) { return 0xFF6B00; }
        if (minute < 20) { return 0xFF0000; }
        if (minute < 25) { return 0xFF6B00; }
        return 0x4CAF50;
    }

    private function formatSeconds(seconds as Number) as String {
        var overtime = seconds < 0;
        var abs = overtime ? -seconds : seconds;
        var m = abs / 60;
        var s = abs % 60;
        var text = m.format("%02d") + ":" + s.format("%02d");
        return overtime ? "+" + text : text;
    }

    private function drawRunning(dc as Dc, snapshot as Dictionary) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var isPause = snapshot.get("isPause") as Boolean;
        var ringColor = isPause ? Graphics.COLOR_DK_GRAY : phaseColorForMinute(snapshot.get("minute") as Number);

        dc.setPenWidth(6);
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        var totalMinutes = snapshot.get("totalMinutes") as Number;
        var minute = snapshot.get("minute") as Number;
        var degrees = totalMinutes > 0 ? (360.0 * minute / totalMinutes) : 0.0;
        dc.drawArc(cx, cy, cx - 6, Graphics.ARC_CLOCKWISE, 90, 90 - degrees);

        drawCentered(dc, snapshot.get("line1") as String, cy - 55, Graphics.FONT_XTINY, Graphics.COLOR_WHITE);
        drawCentered(dc, snapshot.get("line2") as String, cy - 38, Graphics.FONT_XTINY, Graphics.COLOR_WHITE);

        var isTimed = snapshot.get("isTimed") as Boolean;
        if (!isPause) {
            var big = isTimed ? snapshot.get("duration").toString() : snapshot.get("reps").toString();
            drawCentered(dc, big, cy - 5, Graphics.FONT_NUMBER_MEDIUM, ringColor);
        }

        // WatchState.localSecondsLeft statt snapshot["secondsLeft"] --
        // der Snapshot ist nur der Stand zum Sendezeitpunkt, WatchState
        // zaehlt seitdem lokal weiter (siehe WatchState.mc, Task 9).
        drawCentered(dc, formatSeconds(WatchState.localSecondsLeft), cy + 35, Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE);

        var nextText = snapshot.get("nextText") as String;
        if (!nextText.equals("")) {
            drawCentered(dc, nextText, cy + 65, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY);
        }
    }

    private function drawConfirming(dc as Dc, snapshot as Dictionary) as Void {
        var cy = dc.getHeight() / 2;
        drawCentered(dc, "NÄCHSTE ÜBUNG", cy - 30, Graphics.FONT_SMALL, Graphics.COLOR_ORANGE);
        drawCentered(dc, snapshot.get("nextText") as String, cy + 10, Graphics.FONT_XTINY, Graphics.COLOR_WHITE);
    }

    private function drawFinished(dc as Dc, snapshot as Dictionary) as Void {
        var cy = dc.getHeight() / 2;
        drawCentered(dc, "TRAINING BEENDET", cy - 40, Graphics.FONT_SMALL, Graphics.COLOR_ORANGE);
        drawCentered(dc, snapshot.get("totalReps").toString(), cy, Graphics.FONT_NUMBER_MEDIUM, Graphics.COLOR_WHITE);
        drawCentered(dc, (snapshot.get("line1") as String) + " · " + (snapshot.get("line2") as String), cy + 40, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY);
    }

    private function drawButtonHints(dc as Dc, screenState as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var topLabel = "";
        if (screenState.equals("confirming") || screenState.equals("holding")) {
            topLabel = "OK";
        } else if (screenState.equals("running")) {
            topLabel = "II";
        } else if (!screenState.equals("finished")) {
            topLabel = ">";
        }
        if (!topLabel.equals("")) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 22, 14, Graphics.FONT_XTINY, topLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (!screenState.equals("confirming") && !screenState.equals("finished")) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 20, h - 14, Graphics.FONT_XTINY, ">>", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

}
```

- [ ] **Step 2: Build und Simulator-Check**

```bash
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
cd garmin_watch_app
"$SDK/monkeyc.bat" -f monkey.jungle -d venu445mm -o bin/garmin_watch_app.prg -y "$KEY" -w
# Simulator-GUI vorher starten (PowerShell): Start-Process "$SDK\simulator.exe"
"$SDK/monkeydo.bat" bin/garmin_watch_app.prg venu445mm
```

Expected: Build erfolgreich; im Simulator zeigt der Screen zunächst "Verbinde..." (kein Snapshot ohne echtes Handy). Bei Compile-Fehlern zu `drawArc`/`Graphics.FONT_*`-Konstanten: gegen die installierte SDK-API-Referenz korrigieren.

- [ ] **Step 3: Commit**

```bash
git add garmin_watch_app/source/garmin_watch_appView.mc
git commit -m "feat(watch): Running/Confirming/Finished-Screens rendern"
```

---

### Task 11: Manuelle End-to-End-Verifikation auf echter Venu 4

**Files:** keine Code-Änderungen — reine Verifikation.

**Interfaces:** keine — Abschluss-Task.

- [ ] **Step 1: `.prg` auf die Uhr sideloaden**

Wie in `CLAUDE.md` beschrieben: gebautes `garmin_watch_app/bin/garmin_watch_app.prg` per File Explorer in `GARMIN\Apps\` auf dem per MTP verbundenen Gerät kopieren (nicht automatisierbar).

- [ ] **Step 2: Release-Build der Handy-App bauen und installieren**

Run: `flutter build apk --debug` (Debug reicht für die Verifikation; Release nur falls ProguGarard-Regeln aus dem vorherigen Fix mitgeprüft werden sollen)
Installieren auf dem Testgerät, mit der Uhr gekoppelt.

- [ ] **Step 3: Testmatrix aus der Design-Spec durchgehen**

Jeden Punkt einzeln verifizieren (siehe `docs/superpowers/specs/2026-08-12-garmin-watch-hauptscreen-design.md`, Abschnitt „Testing"):

- Watch öffnen, bevor das Handy-Training gestartet wurde → Idle-Zustand korrekt angezeigt.
- Watch öffnen, während das Handy-Training bereits mitten im Training läuft → korrekter Snapshot ohne Tap.
- Jeden Button in jedem der sechs `screenState`-Zustände auslösen, inklusive einer kompletten Zeit-Übung (Start → Halten → Fertig) rein über die Uhr.
- Pause am Handy auslösen, während die Watch-App offen ist → Uhr zieht ohne Zutun nach.
- Reset bzw. Planwechsel am Handy auslösen, während die Watch-App offen ist → Uhr zieht nach.
- BLE-Verbindung während des Trainings kurz kappen und wiederherstellen → nächste Zustandsänderung bringt die Uhr wieder auf aktuellen Stand.
- Trainingsende erreichen, während die Watch-App offen ist → Fertig-Screen erscheint automatisch, zeigt die letzte echte Übung.
- Handy-Display ausschalten (App nicht schließen), Training währenddessen über die Uhr weitersteuern.
- Exit-Swipe auf der Uhr während des Trainings → App schließt, Rückkanal meldet „closed".
- Einstellungen am Handy öffnen und wieder schließen, während die Watch-App offen ist und Kommandos sendet → Kommando-Zustellung darf nicht abreißen.

- [ ] **Step 4: Befunde dokumentieren**

Bei jedem abweichenden Verhalten: in `docs/emom_app_spezifikation.md`, Abschnitt „Garmin-Integration", nachtragen (Muster aus den vorherigen Garmin-Tasks — „Korrektur nach Hardware-Verifikation" — übernehmen) und ggf. als Folge-Task fixen, bevor dieser Plan als abgeschlossen gilt.

- [ ] **Step 5: Abschluss-Commit für die Dokumentation**

```bash
git add docs/emom_app_spezifikation.md
git commit -m "docs: Garmin-Watch-Hauptscreen-Spiegelung Hardware-verifiziert"
```
