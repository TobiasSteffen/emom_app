# Zeit-Übungen (Haltezeit) & Intervall-Skip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Übungen können als zeitbasiert ("Zeit", z.B. Plank) markiert werden — im Workout wartet die App auf einen Start-Tap, zählt die Soll-Haltezeit herunter, läuft danach rot in Überzeit weiter und endet erst per "Fertig"-Tap. Zusätzlich: jedes Intervall kann per Skip-Button vorzeitig beendet werden.

**Architecture:** `ExerciseType` bekommt ein `isTimed`-Flag (analog `hasSide`). Bei zeitbasierten Intervallen ist `durationSeconds` die Soll-Haltezeit und `reps` ungenutzt. `WorkoutNotifier` bekommt einen Wartemodus (`holdStarted`-Flag + vorberechnete `timedFlags`), `startHold()`/`finishHold()`/`skip()`. `IntervalRecord` bekommt `isTimed` (tatsächliche Sekunden im `reps`-Feld, aus Rep-Summen ausgeschlossen) und `skipped` ("Vorzeitig beendet", zählt normal in Summen).

**Tech Stack:** Flutter, Riverpod (codegen, aber keine `@riverpod`-Signaturänderung nötig — kein build_runner-Lauf erforderlich), `flutter_test`.

## Global Constraints

- UI-Labels deutsch. Neues Übungs-Flag heißt überall **"Zeit"** (kein Icon, kein "T", kein "Timed").
- History-Label für geskippte Intervalle: **"Vorzeitig beendet"** (nicht ausgegraut, kein Icon).
- JSON-Abwärtskompatibilität: alle neuen Felder optional mit Default `false`; bestehende `equipment_catalog.json`, `plans.json` und History-Einträge müssen unverändert laden.
- Zeit-Countdown: Ticks nur bei Restsekunden 3, 2, 1; **kein** Alarm bei 0; danach zählt `secondsLeft` negativ weiter (Anzeige `+n` in Rot).
- Nur der "Fertig"-Tap (oder Skip) beendet ein zeitbasiertes Intervall; danach direkter Sprung ohne Confirmation-Overlay.
- Skip speichert bei Rep-Übungen die geplanten Reps, bei Zeit-Übungen die tatsächlich gehaltenen Sekunden (min. 0), jeweils mit `skipped: true`.
- Nach jedem Task: `flutter analyze` sauber, `flutter test` grün, Commit.

---

### Task 1: `ExerciseType.isTimed` im Katalog-Modell + "Zeit"-Schalter im Equipment-Editor

**Files:**
- Modify: `lib/core/models/equipment_catalog.dart` (ExerciseType, BuiltInExercise.toType)
- Modify: `lib/features/config/widgets/equipment_edit_widgets.dart` (EditableExercise, ExerciseRow)
- Modify: `lib/features/config/equipment_wizard_screen.dart` (ExerciseRow-Aufruf ~Zeile 295)
- Modify: `lib/features/config/equipment_detail_screen.dart` (ExerciseRow-Aufruf ~Zeile 237)
- Test: `test/core/models/equipment_catalog_test.dart` (neu oder ergänzen, falls vorhanden)

**Interfaces:**
- Produces: `ExerciseType.isTimed` (`bool`, Konstruktor-Parameter `this.isTimed = false`), JSON-Key `'isTimed'`. `EditableExercise.isTimed` (mutable `bool`). `ExerciseRow`-Parameter `onToggleTimed: VoidCallback`.

- [ ] **Step 1: Failing Test schreiben**

```dart
// test/core/models/equipment_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/equipment_catalog.dart';

void main() {
  test('ExerciseType.fromJson defaults isTimed to false (old format)', () {
    final e = ExerciseType.fromJson({'id': 'x', 'name': 'Swing', 'hasSide': true});
    expect(e.isTimed, false);
  });

  test('ExerciseType isTimed roundtrips through JSON', () {
    const e = ExerciseType(id: 'plank', name: 'Plank', hasSide: false, isTimed: true);
    final back = ExerciseType.fromJson(e.toJson());
    expect(back.isTimed, true);
    expect(back.hasSide, false);
  });
}
```

Hinweis: Paketname aus `pubspec.yaml` übernehmen, falls nicht `emom_app`.

- [ ] **Step 2: Test laufen lassen — erwartet FAIL** (`flutter test test/core/models/equipment_catalog_test.dart`, Fehler: `isTimed` existiert nicht)

- [ ] **Step 3: Modell implementieren**

In `lib/core/models/equipment_catalog.dart` `ExerciseType` ersetzen durch:

```dart
class ExerciseType {
  final String id;
  final String name;
  final bool hasSide;
  final bool isTimed;

  const ExerciseType(
      {required this.id,
      required this.name,
      required this.hasSide,
      this.isTimed = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'hasSide': hasSide, 'isTimed': isTimed};

  factory ExerciseType.fromJson(Map<String, dynamic> j) => ExerciseType(
        id: j['id'] as String,
        name: j['name'] as String,
        hasSide: j['hasSide'] as bool,
        isTimed: (j['isTimed'] as bool?) ?? false,
      );
}
```

In `EquipmentCatalog.migrate` (Zeile ~121) beim Legacy-Rename das Flag mitnehmen:

```dart
            return ExerciseType(
                id: e.id, name: builtIn.displayName, hasSide: e.hasSide, isTimed: e.isTimed);
```

(`BuiltInExercise.toType()` bleibt unverändert — alle Built-ins sind rep-basiert.)

- [ ] **Step 4: Editor-Widgets**

In `lib/features/config/widgets/equipment_edit_widgets.dart`:

```dart
class EditableExercise {
  final String id;
  String name;
  bool hasSide;
  bool isTimed;
  EditableExercise(
      {required this.id, required this.name, required this.hasSide, this.isTimed = false});

  factory EditableExercise.from(ExerciseType e) =>
      EditableExercise(id: e.id, name: e.name, hasSide: e.hasSide, isTimed: e.isTimed);

  ExerciseType toType() =>
      ExerciseType(id: id, name: name, hasSide: hasSide, isTimed: isTimed);
}
```

`ExerciseRow` bekommt einen Pflicht-Parameter `onToggleTimed` (VoidCallback) und direkt **nach** dem bestehenden L/R-Chip (Zeile ~198, vor `const SizedBox(width: 8)`) einen zweiten Chip im selben Stil:

```dart
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onToggleTimed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: exercise.isTimed
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Zeit',
                    style: TextStyle(
                        fontSize: 11,
                        color: exercise.isTimed ? Colors.black : Colors.white38,
                        fontWeight: FontWeight.bold)),
              ),
            ),
```

- [ ] **Step 5: Beide Aufrufer ergänzen**

`equipment_wizard_screen.dart` (~Zeile 298) und `equipment_detail_screen.dart` (~Zeile 240), jeweils direkt nach `onToggleSide`:

```dart
                        onToggleTimed: () => setState(
                            () => entry.value.isTimed = !entry.value.isTimed),
```

- [ ] **Step 6: Verifizieren** — `flutter test test/core/models/equipment_catalog_test.dart` PASS, `flutter analyze` sauber.

- [ ] **Step 7: Commit** — `git add -A && git commit -m "feat: ExerciseType.isTimed mit Zeit-Schalter im Equipment-Editor"`

---

### Task 2: `IntervalRecord` um `isTimed` und `skipped` erweitern

**Files:**
- Modify: `lib/core/models/workout_history.dart`
- Test: `test/core/models/workout_history_test.dart` (neu oder ergänzen)

**Interfaces:**
- Produces: `IntervalRecord({..., bool isTimed = false, bool skipped = false})`, JSON-Keys `'ti'` (isTimed) und `'sk'` (skipped), nur geschrieben wenn `true`. `WorkoutRecord.totalReps` summiert `reps` **ohne** `isTimed`-Intervalle (geskippte zählen normal).

- [ ] **Step 1: Failing Test schreiben**

```dart
// test/core/models/workout_history_test.dart (Tests ergänzen, falls Datei existiert)
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/workout_history.dart';

IntervalRecord _rec({int reps = 10, bool isTimed = false, bool skipped = false}) =>
    IntervalRecord(
        reps: reps,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_beidarmig',
        isTimed: isTimed,
        skipped: skipped);

void main() {
  test('isTimed and skipped roundtrip through JSON, absent keys default false', () {
    final r = IntervalRecord.fromJson(_rec(isTimed: true, skipped: true).toJson());
    expect(r.isTimed, true);
    expect(r.skipped, true);
    final old = IntervalRecord.fromJson(_rec().toJson());
    expect(old.isTimed, false);
    expect(old.skipped, false);
  });

  test('totalReps excludes timed intervals but counts skipped ones', () {
    final w = WorkoutRecord(timestamp: 1, planMode: 1, intervals: [
      _rec(reps: 10),
      _rec(reps: 85, isTimed: true), // gehaltene Sekunden, keine Reps
      _rec(reps: 12, skipped: true),
    ]);
    expect(w.totalReps, 22);
  });
}
```

- [ ] **Step 2: Test laufen lassen — erwartet FAIL** (Parameter existieren nicht)

- [ ] **Step 3: Implementieren**

In `IntervalRecord`: Felder `final bool isTimed;` und `final bool skipped;` ergänzen, Konstruktor `this.isTimed = false, this.skipped = false`. In `toJson()` nach `if (isPause) m['p'] = true;`:

```dart
    if (isTimed) m['ti'] = true;
    if (skipped) m['sk'] = true;
```

In **beiden** `fromJson`-Zweigen (neues und altes Format) ergänzen:

```dart
        isTimed: (j['ti'] as bool?) ?? false,
        skipped: (j['sk'] as bool?) ?? false,
```

In `WorkoutRecord`:

```dart
  int get totalReps =>
      intervals.fold(0, (a, b) => a + (b.isTimed ? 0 : b.reps));
```

- [ ] **Step 4: Verifizieren** — Test PASS, `flutter analyze` sauber, `flutter test` komplett grün.

- [ ] **Step 5: Commit** — `git commit -am "feat: IntervalRecord isTimed/skipped, Zeit-Intervalle nicht in Rep-Summe"`

---

### Task 3: WorkoutNotifier — Wartemodus, Haltezeit-Countdown mit Überzeit, Skip

**Files:**
- Modify: `lib/features/workout/workout_notifier.dart`
- Test: `test/features/workout/workout_state_test.dart` (neu, nur der provider-freie `WorkoutState`)

**Interfaces:**
- Consumes: `ExerciseType.isTimed` (Task 1), `IntervalRecord(isTimed:, skipped:)` (Task 2).
- Produces: `WorkoutState.timedFlags` (`List<bool>`, Index = Minute), `WorkoutState.holdStarted` (`bool`), Getter `currentIsTimed`, `holdWaiting`, `overtimeSeconds`. Notifier-Methoden `void startHold()`, `void finishHold()`, `void skip()`. Verhalten von `_tick`, `start`, `confirmInterval`, `totalReps`/`currentReps` wie unten.

- [ ] **Step 1: Failing State-Test schreiben**

```dart
// test/features/workout/workout_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/features/workout/workout_notifier.dart';

IntervalConfig _iv({int reps = 10}) => IntervalConfig(
    reps: reps,
    durationSeconds: 60,
    equipmentTypeId: 'kettlebell',
    exerciseTypeId: 'swing_beidarmig');

WorkoutState _state({
  required List<bool> timedFlags,
  int currentMinute = 0,
  int secondsLeft = 60,
  bool holdStarted = false,
  List<IntervalConfig>? intervals,
}) =>
    WorkoutState(
      intervals: intervals ?? [_iv(), _iv(reps: 12)],
      currentMinute: currentMinute,
      secondsLeft: secondsLeft,
      isRunning: false,
      isFinished: false,
      waitingForConfirmation: false,
      totalRepsDone: 0,
      completedIntervals: const [],
      timedFlags: timedFlags,
      holdStarted: holdStarted,
    );

void main() {
  test('holdWaiting only for timed interval before start', () {
    expect(_state(timedFlags: [true, false]).holdWaiting, true);
    expect(_state(timedFlags: [true, false], holdStarted: true).holdWaiting, false);
    expect(_state(timedFlags: [false, false]).holdWaiting, false);
  });

  test('currentReps is 0 and totalReps excludes timed intervals', () {
    final s = _state(timedFlags: [true, false]);
    expect(s.currentReps, 0);
    expect(s.totalReps, 12);
  });

  test('overtimeSeconds is positive part of negative secondsLeft', () {
    expect(_state(timedFlags: [true, false], secondsLeft: -25).overtimeSeconds, 25);
    expect(_state(timedFlags: [true, false], secondsLeft: 10).overtimeSeconds, 0);
  });
}
```

Hinweis: `IntervalConfig`-Konstruktor ggf. an tatsächliche Pflichtparameter in `training_plan.dart` anpassen (`variantId`/`side` sind optional).

- [ ] **Step 2: Test laufen lassen — erwartet FAIL** (Compile-Fehler: neue Felder fehlen)

- [ ] **Step 3: `WorkoutState` erweitern**

Neue Felder (in Konstruktor, `copyWith` und allen `WorkoutState(...)`-Konstruktionen in `build()` und `reset()` mitziehen):

```dart
  final List<bool> timedFlags;
  final bool holdStarted;
```

Neue/geänderte Getter:

```dart
  bool get currentIsTimed => timedFlags[currentMinute];
  bool get holdWaiting => currentIsTimed && !holdStarted && !isFinished;
  int get overtimeSeconds => secondsLeft < 0 ? -secondsLeft : 0;
  int get currentReps => (intervals[currentMinute].isPause || currentIsTimed)
      ? 0
      : intervals[currentMinute].reps;
  int get totalReps => intervals.indexed.fold(
      0,
      (a, e) => a +
          ((e.$2.isPause || timedFlags[e.$1]) ? 0 : e.$2.reps));
```

- [ ] **Step 4: Notifier — timedFlags berechnen**

Private Helper im Notifier, in `build()` und `reset()` beim Erzeugen des States verwenden (`timedFlags: _computeTimedFlags(), holdStarted: false`):

```dart
  List<bool> _computeTimedFlags() => _activePlan.intervals
      .map((iv) =>
          !iv.isPause &&
          (_catalog
                  .findType(iv.equipmentTypeId)
                  ?.exercises
                  .where((e) => e.id == iv.exerciseTypeId)
                  .firstOrNull
                  ?.isTimed ??
              false))
      .toList();
```

- [ ] **Step 5: Notifier — Ablauflogik**

`start()` guard am Anfang: `if (_s.holdWaiting) return;` (Haupt-Play startet keinen Hold).

Neue Methoden:

```dart
  void startHold() {
    if (!_s.holdWaiting) return;
    final now = _s.workoutStartTime == null ? DateTime.now() : null;
    state = AsyncData(_s.copyWith(
        holdStarted: true, isRunning: true, workoutStartTime: now));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void finishHold() {
    if (!_s.currentIsTimed || !_s.holdStarted) return;
    final held = (_s.currentDuration - _s.secondsLeft).clamp(0, 1 << 31);
    _completeCurrent(reps: held, isTimed: true);
  }

  void skip() {
    if (_s.isFinished || _s.waitingForConfirmation) return;
    final timed = _s.currentIsTimed;
    final held = timed && _s.holdStarted
        ? (_s.currentDuration - _s.secondsLeft).clamp(0, 1 << 31)
        : 0;
    _completeCurrent(
        reps: timed ? held : _s.currentReps, isTimed: timed, skipped: true);
  }
```

Gemeinsame Abschluss-/Advance-Logik (neu; `_onMinuteComplete` ruft für den Normalfall weiterhin seinen bestehenden Code auf und bleibt unverändert — `_completeCurrent` ist der direkte Sprung **ohne** Confirmation-Overlay für Fertig/Skip):

```dart
  void _completeCurrent({required int reps, bool isTimed = false, bool skipped = false}) {
    _timer?.cancel();
    _alarmLoopSub?.cancel();
    _alarmLoopSub = null;
    _alarmPlayer.stop();
    final s = _s;
    final iv = _activePlan.intervals[s.currentMinute];
    final newIntervals = [
      ...s.completedIntervals,
      IntervalRecord(
        reps: reps,
        durationSeconds: s.currentDuration,
        equipmentTypeId: iv.equipmentTypeId,
        variantId: iv.variantId,
        exerciseTypeId: iv.exerciseTypeId,
        side: iv.side,
        isPause: iv.isPause,
        isTimed: isTimed,
        skipped: skipped,
      ),
    ];
    final newTotalReps = s.totalRepsDone + (isTimed ? 0 : reps);
    if (s.currentMinute >= s.totalMinutes - 1) {
      state = AsyncData(s.copyWith(
        isFinished: true,
        isRunning: false,
        totalRepsDone: newTotalReps,
        completedIntervals: newIntervals,
      ));
      _vibrate(600);
      _saveHistory(intervals: newIntervals, startTime: s.workoutStartTime);
    } else {
      final next = s.currentMinute + 1;
      state = AsyncData(s.copyWith(
        currentMinute: next,
        secondsLeft: s.intervals[next].durationSeconds,
        isRunning: false,
        holdStarted: false,
        totalRepsDone: newTotalReps,
        completedIntervals: newIntervals,
      ));
      _vibrate(400);
      _saveHistory();
      if (!_s.holdWaiting) start();
    }
  }
```

`_tick` bekommt einen Timed-Zweig (vor der bestehenden Logik):

```dart
  void _tick(Timer timer) {
    if (_s.currentIsTimed && _s.holdStarted) {
      final newSeconds = _s.secondsLeft - 1; // darf negativ werden (Überzeit)
      state = AsyncData(_s.copyWith(secondsLeft: newSeconds));
      if (newSeconds >= 1 && newSeconds <= 3 && _settings.warningTonesEnabled) {
        if (newSeconds == 3) _raiseVolume();
        _playTickSound();
      }
      return;
    }
    // ... bestehender Code unverändert ...
  }
```

Achtung: `copyWith(secondsLeft:)` nutzt `??` — negatives `secondsLeft` funktioniert, nur `null` wäre Problem. Kein Umbau nötig.

`confirmInterval()` (Zeile ~149): nach dem State-Update prüfen, ob das nächste Intervall zeitbasiert ist — dann **nicht** `start()`:

```dart
    _vibrate(400);
    _saveHistory();
    if (_s.holdWaiting) return; // Zeit-Übung: auf Start-Tap warten
    start();
```

(Dafür im `copyWith` des `confirmInterval` zusätzlich `holdStarted: false` setzen.)

- [ ] **Step 6: Verifizieren** — `flutter test` komplett grün, `flutter analyze` sauber.

- [ ] **Step 7: Commit** — `git commit -am "feat: Wartemodus, Haltezeit-Countdown mit Überzeit und Skip im WorkoutNotifier"`

---

### Task 4: Workout-Screen-UI — Start/Fertig-Button, Überzeit-Anzeige, Skip-Button, Zeit-RepsCard

**Files:**
- Modify: `lib/features/workout/widgets/timer_display.dart`
- Modify: `lib/features/workout/widgets/reps_card.dart`
- Modify: `lib/features/workout/workout_screen.dart`

**Interfaces:**
- Consumes: `state.holdWaiting`, `state.holdStarted`, `state.currentIsTimed`, `state.overtimeSeconds`, `notifier.startHold()`, `notifier.finishHold()`, `notifier.skip()` (Task 3).
- Produces: `TimerDisplay` rendert negatives `secondsLeft` als rotes `+m:ss`; `RepsCard` bekommt `isTimed` (bool, default false) und `timedSeconds` (int, default 0).

- [ ] **Step 1: TimerDisplay — Überzeit**

`build()` so anpassen, dass Überzeit rot mit `+`-Präfix und vollem Balken gezeigt wird:

```dart
  @override
  Widget build(BuildContext context) {
    final overtime = secondsLeft < 0;
    final isWarning = !overtime && secondsLeft <= 5 && secondsLeft > 0 && isRunning;
    final secondProgress = overtime
        ? 1.0
        : ((currentDuration - secondsLeft) / currentDuration).clamp(0.0, 1.0);
    final display = overtime ? '+${_formatTime(-secondsLeft)}' : _formatTime(secondsLeft);
    final color = (overtime || isWarning) ? const Color(0xFFFF4444) : Colors.white;
```

Text-Widget nutzt `display` und `color`; der `LinearProgressIndicator`-`valueColor` nutzt `(overtime || isWarning) ? const Color(0xFFFF4444) : Colors.white24`.

- [ ] **Step 2: RepsCard — Zeit-Variante**

Neue Parameter `final bool isTimed;` und `final int timedSeconds;` (Konstruktor: `this.isTimed = false, this.timedSeconds = 0`). Im `build()` den ersten Branch erweitern — bei `isTimed` statt `'REPS'`/`'$currentReps'`:

```dart
            if (!isPause) ...[
              Image.asset(iconPath, width: 48, height: 48, color: phaseColor),
              const SizedBox(height: 4),
              Text(
                isTimed ? 'ZEIT' : 'REPS',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              Text(
                isTimed ? '${timedSeconds}s' : '$currentReps',
                style: TextStyle(
                    fontSize: isTimed ? 96 : 120,
                    fontWeight: FontWeight.w900,
                    color: phaseColor,
                    height: 1),
              ),
            ] else ...[
```

- [ ] **Step 3: WorkoutScreen — verdrahten**

In `_buildWorkoutScreen`:

RepsCard-Aufruf ergänzen:

```dart
          RepsCard(
            currentMinute: state.currentMinute,
            currentReps: state.currentReps,
            workoutLabel: workoutLabel,
            iconPath: iconPath,
            pulseAnimation: _pulseAnimation,
            isPause: isPauseInterval,
            isTimed: state.currentIsTimed,
            timedSeconds: state.intervals[state.currentMinute].durationSeconds,
          ),
```

Direkt **unter** `TimerDisplay(...)` den Start/Fertig-Button einfügen (nur bei Zeit-Intervallen sichtbar):

```dart
          if (state.currentIsTimed) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => state.holdWaiting
                  ? notifier.startHold()
                  : notifier.finishHold(),
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: state.holdWaiting
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF4444),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    state.holdWaiting ? 'START' : 'FERTIG',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3),
                  ),
                ),
              ),
            ),
          ],
```

Skip-Button in die untere Button-Row, zwischen Refresh-IconButton und dem Play/Pause-Container (nach dem Refresh-`IconButton`, vor `const SizedBox(width: 16)` bzw. als zusätzliches Element):

```dart
              IconButton(
                onPressed: () => notifier.skip(),
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white38,
                  size: 28,
                ),
              ),
```

`_startStop` bleibt unverändert (der `holdWaiting`-Guard in `start()` verhindert Fehlstarts; Pause/Resume während laufender Haltezeit funktioniert über `pause()`/`start()`, weil `holdStarted` gesetzt bleibt und `holdWaiting` dann `false` ist — **wichtig:** dafür muss `start()` den Timed-Fall normal starten, was der Guard `if (_s.holdWaiting) return;` genau zulässt).

- [ ] **Step 4: Verifizieren** — `flutter analyze` sauber, `flutter test` grün. Manuell (Emulator/Gerät): Übung im Katalog auf "Zeit" stellen, Plan mit dieser Übung starten → Wartemodus, START, Countdown mit Ticks nur bei 3-2-1, kein Alarm bei 0, rote `+`-Überzeit, FERTIG springt weiter; Skip bei normaler Übung springt sofort weiter.

- [ ] **Step 5: Commit** — `git commit -am "feat: Start/Fertig-Button, Ueberzeit-Anzeige und Skip-Button im Workout-Screen"`

---

### Task 5: Plan-Editor & Vorschauen — "Zeit" statt Wiederholungen

**Files:**
- Modify: `lib/features/shared/widgets/interval_edit_form.dart`
- Modify: `lib/features/plans/widgets/minute_row.dart`
- Modify: `lib/features/workout/widgets/next_minute_preview.dart`

**Interfaces:**
- Consumes: `ExerciseType.isTimed` (Task 1).

- [ ] **Step 1: IntervalEditForm**

In `_buildForm` ist `exercise` bereits aufgelöst. Die "Wiederholungen"-Row (Zeile ~306-314) nur für rep-basierte Übungen zeigen:

```dart
                if (!exercise.isTimed) ...[
                  const Divider(color: Colors.white12, height: 1),
                  _formRow(
                    'Wiederholungen',
                    _stepper(
                      display: '${iv.reps}',
                      onDec: iv.reps > 1 ? () => _update(() => iv.reps--) : null,
                      onInc: () => _update(() => iv.reps++),
                    ),
                  ),
                ],
```

Die bestehende "Sekunden"-Row bekommt bei Zeit-Übungen das Label `'Zeit (Sek.)'`:

```dart
          _formRow(
            iv.isPause || !exercise.isTimed ? 'Sekunden' : 'Zeit (Sek.)',
            _stepper(
```

Hinweis: `exercise` wird in `_buildForm` vor dem `return` aufgelöst und ist an dieser Stelle sichtbar; die Pause-Row nutzt weiterhin "Sekunden".

Beim Übungswechsel auf eine Zeit-Übung Default 60 setzen — im Exercise-Picker-`_update` (Zeile ~280) und in `_selectEquipmentAndVariant` (nach der Side-Logik) jeweils ergänzen:

```dart
                              if (ex.isTimed && !exercise.isTimed) {
                                iv.durationSeconds = 60;
                              }
```

(In `_selectEquipmentAndVariant` analog: vor der Zuweisung das bisherige `exercise` der alten Auswahl bestimmen bzw. den alten `isTimed`-Wert vorab in einer lokalen Variable `wasTimed` sichern und `if (exercise.isTimed && !wasTimed) iv.durationSeconds = 60;` nach der Exercise-Auflösung ausführen.)

- [ ] **Step 2: PlanMinuteRow**

`exerciseType` ist bereits aufgelöst. Den `'${iv.reps}W'`-Text (Zeile ~148-151) ersetzen:

```dart
                  Text(
                    exerciseType?.isTimed == true ? 'Zeit' : '${iv.reps}W',
                    style: const TextStyle(fontSize: 12, color: Colors.white38),
                  ),
```

- [ ] **Step 3: NextMinutePreview**

`parts`-Zeile (Zeile ~39) ersetzen:

```dart
        final parts = exercise?.isTimed == true
            ? [equipLabel, exerciseLabel, 'Zeit', '${interval.durationSeconds}s']
            : [equipLabel, exerciseLabel, '${interval.reps}W', '${interval.durationSeconds}s'];
```

- [ ] **Step 4: Verifizieren** — `flutter analyze` sauber; manuell: Zeit-Übung im Plan-Editor wählen → Wiederholungen-Row verschwindet, "Zeit (Sek.)" mit 60, Zeile zeigt "Zeit", Vorschau zeigt "Zeit · 60s".

- [ ] **Step 5: Commit** — `git commit -am "feat: Zeit-Uebungen im Plan-Editor und in Vorschauen"`

---

### Task 6: History — Sekunden-Anzeige und "Vorzeitig beendet"

**Files:**
- Modify: `lib/features/history/history_detail_sheet.dart`

**Interfaces:**
- Consumes: `IntervalRecord.isTimed` / `.skipped` (Task 2), `exerciseType.isTimed` (Task 1).

- [ ] **Step 1: Records → Edit-Configs prüfen**

`history_detail_sheet.dart` konvertiert oben (Zeile ~13/23) zwischen `IntervalRecord` und `IntervalConfig`. Sicherstellen, dass beim Zurückschreiben editierter Records `isTimed`/`skipped` des Original-Records erhalten bleiben (beim Erzeugen des neuen `IntervalRecord` aus dem Original übernehmen: `isTimed: r.isTimed, skipped: r.skipped`).

- [ ] **Step 2: Zeilen-Anzeige**

Die Detail-Liste rendert pro Intervall `'${iv.reps} Reps'` (Editier-Kopie als `IntervalConfig` — für die Anzeige der Flags die parallel gehaltene Original-Record-Liste indexieren, die im State des Sheets liegt; dort wo `iv.reps` gerendert wird, den zugehörigen Record `rec` per Index holen). Ersetzen:

```dart
                              Text(
                                  rec.isTimed
                                      ? '${rec.reps} Sek.'
                                      : '${iv.reps} Reps',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              if (rec.skipped) ...[
                                const SizedBox(width: 6),
                                const Text('Vorzeitig beendet',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white38,
                                        fontStyle: FontStyle.italic)),
                              ],
```

(Zeile normal gefärbt lassen — nicht ausgrauen.)

- [ ] **Step 3: Summen prüfen**

Die Summenzeile des Sheets (Zeile ~62, `byType`-Aggregation) Zeit-Intervalle ausschließen:

```dart
        if (!recs[idx].isTimed) {
          byType[iv.equipmentTypeId] = (byType[iv.equipmentTypeId] ?? 0) + iv.reps;
        }
```

(Konkrete Variablennamen an den Bestand anpassen; entscheidend: `isTimed`-Records nicht in Rep-Summen.) `WorkoutRecord.totalReps` ist seit Task 2 bereits korrekt — Aufrufer (History-Liste, FinishedScreen via `state.totalReps`) prüfen, dass keine weitere Stelle `intervals.fold` über `reps` ohne `isTimed`-Filter macht (`grep -n "fold" lib | grep -i rep`).

- [ ] **Step 4: Verifizieren** — `flutter analyze` sauber, `flutter test` grün; manuell: Workout mit Zeit-Übung + Skip absolvieren → Detailansicht zeigt "85 Sek." bzw. Reps mit "Vorzeitig beendet", Summen ohne Sekunden.

- [ ] **Step 5: Commit** — `git commit -am "feat: History zeigt Haltezeit-Sekunden und 'Vorzeitig beendet'"`

---

## Self-Review Notizen

- Spec-Abdeckung: Zeit-Flag + Editor (T1), Record-Flags (T2), Wartemodus/Countdown/Überzeit/Fertig/Skip (T3), Workout-UI (T4), Plan-Editor/Vorschau (T5), History (T6). Confirmation-Overlay braucht keine Änderung: `nextReps` zeigt bei Zeit-Übung über `nextInterval.reps` einen irrelevanten Wert — Executor in T4 prüfen und bei Zeit-Übung `0`/Label "Zeit" übergeben (`ConfirmationOverlay`-Aufruf: `nextReps: state.timedFlags[nextMinute] ? 0 : ...`).
- Typkonsistenz: `startHold`/`finishHold`/`skip`/`holdWaiting`/`holdStarted`/`timedFlags`/`overtimeSeconds`/`isTimed`/`skipped` werden überall gleich benannt.
- Kein build_runner nötig (keine `@riverpod`-Signatur geändert).
