# Pause-Intervall — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Intervall kann als "Pause" markiert werden — kein Gerät, keine Übung, nur ein Countdown; im Plan-Editor über einen Umschalter, im Workout-Screen mit grauer Darstellung und "PAUSE"-Label.

**Architecture:** `bool isPause` wird als neues optionales Feld in `IntervalConfig` ergänzt (default `false`, rückwärtskompatibel per `fromJson`). Im Plan-Editor erhält die aufgeklappte Zeile einen "Übung / Pause"-Umschalter; bei Pause werden Gerät/Übung/Seite/Reps ausgeblendet. Der Workout-Screen liest `isPause` und passt Farbe, Label und Rep-Anzeige an — ohne Architekturänderung, nur Parametererweiterungen an bestehenden Widgets.

**Tech Stack:** Flutter/Dart, Riverpod 2.x, keine neuen Abhängigkeiten

---

## File Map

| File | Change |
|------|--------|
| `lib/core/models/training_plan.dart` | `IntervalConfig`: `isPause` Feld, `toJson`, `fromJson`, `copyWith`, `planKey` |
| `test/core/models/training_plan_test.dart` | 5 neue Tests für `isPause` (TDD) |
| `lib/features/plans/widgets/minute_row.dart` | Pause-Toggle in expandierter Form, PAUSE-Anzeige in Kompaktzeile, grauer Phasenpunkt |
| `lib/features/workout/workout_notifier.dart` | `workoutLabelForMinute` + `WorkoutState.currentReps/totalReps` |
| `lib/features/workout/widgets/reps_card.dart` | `isPause`-Parameter, PAUSE-Darstellung |
| `lib/features/workout/widgets/next_minute_preview.dart` | `nextIsPause`-Parameter |
| `lib/features/workout/widgets/confirmation_overlay.dart` | `nextIsPause`-Parameter |
| `lib/features/workout/workout_screen.dart` | `isPause` an Widgets übergeben, graue `phaseColor` bei Pause |

---

### Task 1: IntervalConfig.isPause — Datenmodell + Tests (TDD)

**Files:**
- Modify: `lib/core/models/training_plan.dart`
- Modify: `test/core/models/training_plan_test.dart`

#### Aktueller Zustand (relevant)

```dart
// lib/core/models/training_plan.dart
class IntervalConfig {
  int reps;
  int durationSeconds;
  Equipment equipment;
  Exercise exercise;
  ExerciseSide? side;

  IntervalConfig({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
    required this.exercise,
    this.side,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'r': reps,
      'd': durationSeconds,
      'e': equipment.index,
      'x': exercise.index,
    };
    if (side != null) m['s'] = side!.index;
    return m;
  }

  factory IntervalConfig.fromJson(Map<String, dynamic> j) {
    // ... equipment/exercise parsing ...
    final sideIndex = j['s'] as int?;
    return IntervalConfig(
      reps: j['r'] as int,
      durationSeconds: j['d'] as int,
      equipment: eq,
      exercise: ex,
      side: sideIndex != null ? ExerciseSide.values.elementAtOrNull(sideIndex) : null,
    );
  }

  IntervalConfig copyWith({
    int? reps,
    int? durationSeconds,
    Equipment? equipment,
    Exercise? exercise,
    ExerciseSide? side,
    bool clearSide = false,
  }) => IntervalConfig(
    reps: reps ?? this.reps,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    equipment: equipment ?? this.equipment,
    exercise: exercise ?? this.exercise,
    side: clearSide ? null : (side ?? this.side),
  );
}

// planKey:
String get planKey => intervals
    .map((iv) => '${iv.reps},${iv.durationSeconds},${iv.equipment.index},${iv.exercise.index},${iv.side?.index ?? -1}')
    .join('|');
```

- [ ] **Step 1: Tests schreiben (werden danach fehlschlagen)**

Am Ende der `group('IntervalConfig', ...)` in `test/core/models/training_plan_test.dart` diese 4 Tests ergänzen (vor der schließenden `});` der Gruppe):

```dart
    test('isPause is false by default', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
      );
      expect(iv.isPause, false);
    });

    test('isPause serializes and deserializes correctly', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
        isPause: true,
      );
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.isPause, true);
    });

    test('fromJson without p key gives isPause = false', () {
      final json = {'r': 10, 'd': 60, 'e': 2, 'x': 0};
      final iv = IntervalConfig.fromJson(json);
      expect(iv.isPause, false);
    });

    test('copyWith can set isPause', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
      );
      final paused = iv.copyWith(isPause: true);
      expect(paused.isPause, true);
      expect(paused.reps, 5);
    });
```

Und in der `group('TrainingPlan', ...)` diesen Test ergänzen:

```dart
    test('planKey changes when isPause changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].isPause = true;
      expect(plan.planKey, isNot(key1));
    });
```

- [ ] **Step 2: Tests laufen lassen (sollen fehlschlagen)**

```powershell
flutter test test/core/models/training_plan_test.dart
```

Erwartet: 5 neue Tests schlagen fehl mit "named parameter 'isPause' not found" oder ähnlichem.

- [ ] **Step 3: IntervalConfig in training_plan.dart anpassen**

Die komplette Klasse `IntervalConfig` ersetzen durch:

```dart
class IntervalConfig {
  int reps;
  int durationSeconds;
  Equipment equipment;
  Exercise exercise;
  ExerciseSide? side;
  bool isPause;

  IntervalConfig({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
    required this.exercise,
    this.side,
    this.isPause = false,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'r': reps,
      'd': durationSeconds,
      'e': equipment.index,
      'x': exercise.index,
    };
    if (side != null) m['s'] = side!.index;
    if (isPause) m['p'] = 1;
    return m;
  }

  factory IntervalConfig.fromJson(Map<String, dynamic> j) {
    final Equipment eq;
    final Exercise ex;
    if (j.containsKey('x')) {
      eq = Equipment.values.elementAtOrNull(j['e'] as int) ?? Equipment.kb24;
      ex = Exercise.values.elementAtOrNull(j['x'] as int) ?? eq.defaultExercise;
    } else {
      final oldE = j['e'] as int;
      eq = oldE == 0 ? Equipment.kb24 : Equipment.sm12;
      ex = eq.defaultExercise;
    }
    final sideIndex = j['s'] as int?;
    return IntervalConfig(
      reps: j['r'] as int,
      durationSeconds: j['d'] as int,
      equipment: eq,
      exercise: ex,
      side: sideIndex != null ? ExerciseSide.values.elementAtOrNull(sideIndex) : null,
      isPause: (j['p'] as int?) == 1,
    );
  }

  IntervalConfig copyWith({
    int? reps,
    int? durationSeconds,
    Equipment? equipment,
    Exercise? exercise,
    ExerciseSide? side,
    bool clearSide = false,
    bool? isPause,
  }) =>
      IntervalConfig(
        reps: reps ?? this.reps,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        equipment: equipment ?? this.equipment,
        exercise: exercise ?? this.exercise,
        side: clearSide ? null : (side ?? this.side),
        isPause: isPause ?? this.isPause,
      );
}
```

Und `planKey` in `TrainingPlan` ersetzen durch:

```dart
  String get planKey => intervals
      .map((iv) =>
          '${iv.reps},${iv.durationSeconds},${iv.equipment.index},${iv.exercise.index},${iv.side?.index ?? -1},${iv.isPause ? 1 : 0}')
      .join('|');
```

- [ ] **Step 4: Tests laufen lassen (sollen bestehen)**

```powershell
flutter test test/core/models/training_plan_test.dart
```

Erwartet: All tests passed.

- [ ] **Step 5: Gesamte Test-Suite**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 6: Commit**

```powershell
git add lib/core/models/training_plan.dart test/core/models/training_plan_test.dart
git commit -m "feat: add isPause field to IntervalConfig with serialization and planKey support"
```

---

### Task 2: Plan-Editor — Pause-Toggle und Kompaktzeile

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`

#### Aktueller Zustand (relevante Stellen)

**`build()` — Kompaktzeile (Zeile 339–361 ca.):**
```dart
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              // ...
              Image.asset(iv.equipment.iconPath,
                  width: 14, height: 14, color: Colors.white38),
              const SizedBox(width: 4),
              Text(iv.equipment.label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white38)),
              const SizedBox(width: 6),
              Text(iv.exercise.label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white38)),
              const SizedBox(width: 6),
              Text('${iv.reps}R',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white38)),
              const SizedBox(width: 6),
              Text('${iv.durationSeconds}s',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white38)),
```

**`_expandedForm()` — Beginn des Column (nach `crossAxisAlignment`):**
```dart
        children: [
          const Divider(color: Colors.white12, height: 1),
          _formSectionHeader('Gerät', iv.equipment.label, 'equipment'),
```

- [ ] **Step 1: Phasenpunkt-Farbe in `build()` auf grau setzen bei Pause**

In `build()` die Zeile

```dart
    final color = phaseColorForMinute(i);
```

ersetzen durch:

```dart
    final color = iv.isPause ? Colors.white24 : phaseColorForMinute(i);
```

- [ ] **Step 2: Kompaktzeile in `build()` für Pause anpassen**

Den Block

```dart
              Image.asset(iv.equipment.iconPath,
                  width: 14, height: 14, color: Colors.white38),
              const SizedBox(width: 4),
              Text(iv.equipment.label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white38)),
              const SizedBox(width: 6),
              Text(iv.exercise.label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white38)),
              const SizedBox(width: 6),
              Text('${iv.reps}R',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white38)),
              const SizedBox(width: 6),
              Text('${iv.durationSeconds}s',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white38)),
```

ersetzen durch:

```dart
              if (iv.isPause) ...[
                const Text('PAUSE',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white38, letterSpacing: 1)),
                const SizedBox(width: 6),
                Text('${iv.durationSeconds}s',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white38)),
              ] else ...[
                Image.asset(iv.equipment.iconPath,
                    width: 14, height: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text(iv.equipment.label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38)),
                const SizedBox(width: 6),
                Text(iv.exercise.label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38)),
                const SizedBox(width: 6),
                Text('${iv.reps}R',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white38)),
                const SizedBox(width: 6),
                Text('${iv.durationSeconds}s',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white38)),
              ],
```

- [ ] **Step 3: Pause-Toggle am Anfang von `_expandedForm()` einfügen**

In `_expandedForm()` den Beginn des `Column`-`children`-Arrays

```dart
        children: [
          const Divider(color: Colors.white12, height: 1),
          _formSectionHeader('Gerät', iv.equipment.label, 'equipment'),
```

ersetzen durch:

```dart
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Row(
              children: [
                _pickerChip('Übung', !iv.isPause,
                    () => _update(() => iv.isPause = false)),
                _pickerChip('Pause', iv.isPause, () {
                  setState(() => _openPicker = null);
                  _update(() {
                    iv.isPause = true;
                    iv.side = null;
                  });
                }),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          _formSectionHeader('Gerät', iv.equipment.label, 'equipment'),
```

- [ ] **Step 4: Gerät/Übung/Seite/Reps in `_expandedForm()` bei Pause ausblenden**

Den gesamten Block vom ersten Divider bis zum Wiederholungen-`_formRow` (inklusive) in ein `if (!iv.isPause) ...[...]` einwickeln.

Den aktuellen Abschnitt (von der ersten `const Divider` bis zum letzten `_formRow` für Wiederholungen inklusive der schließenden `],`):

```dart
          const Divider(color: Colors.white12, height: 1),
          _formSectionHeader('Gerät', iv.equipment.label, 'equipment'),
          if (_openPicker == 'equipment') ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _equipmentGroup(
                    'assets/icon/kettlebell.png',
                    Equipment.values.where((e) => e.isKettlebell).toList(),
                    iv.equipment,
                    selectEquipment,
                  ),
                  _equipmentGroup(
                    'assets/icon/steelmace.png',
                    Equipment.values.where((e) => e.isSteelMace).toList(),
                    iv.equipment,
                    selectEquipment,
                  ),
                  _equipmentGroup(
                    'assets/icon/pezziball.png',
                    Equipment.values.where((e) => e.isPezziball).toList(),
                    iv.equipment,
                    selectEquipment,
                  ),
                ],
              ),
            ),
          ],
          const Divider(color: Colors.white12, height: 1),
          _formSectionHeader('Übung', iv.exercise.label, 'exercise'),
          if (_openPicker == 'exercise') ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                children: [
                  for (final ex in iv.equipment.validExercises)
                    _pickerChip(ex.label, iv.exercise == ex,
                        () => selectExercise(ex)),
                ],
              ),
            ),
          ],
          if (iv.exercise.isOneArm) ...[
            const Divider(color: Colors.white12, height: 1),
            _formRow(
              'Seite',
              Row(
                children: [
                  _pickerChip('Links', iv.side == ExerciseSide.links,
                      () => _update(() => iv.side = ExerciseSide.links)),
                  const SizedBox(width: 6),
                  _pickerChip('Rechts', iv.side == ExerciseSide.rechts,
                      () => _update(() => iv.side = ExerciseSide.rechts)),
                ],
              ),
            ),
          ],
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Wiederholungen',
            _stepper(
              display: '${iv.reps}',
              onDec: iv.reps > 1 ? () => _update(() => iv.reps--) : null,
              onInc: () => _update(() => iv.reps++),
            ),
          ),
```

ersetzen durch:

```dart
          if (!iv.isPause) ...[
            const Divider(color: Colors.white12, height: 1),
            _formSectionHeader('Gerät', iv.equipment.label, 'equipment'),
            if (_openPicker == 'equipment') ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _equipmentGroup(
                      'assets/icon/kettlebell.png',
                      Equipment.values.where((e) => e.isKettlebell).toList(),
                      iv.equipment,
                      selectEquipment,
                    ),
                    _equipmentGroup(
                      'assets/icon/steelmace.png',
                      Equipment.values.where((e) => e.isSteelMace).toList(),
                      iv.equipment,
                      selectEquipment,
                    ),
                    _equipmentGroup(
                      'assets/icon/pezziball.png',
                      Equipment.values.where((e) => e.isPezziball).toList(),
                      iv.equipment,
                      selectEquipment,
                    ),
                  ],
                ),
              ),
            ],
            const Divider(color: Colors.white12, height: 1),
            _formSectionHeader('Übung', iv.exercise.label, 'exercise'),
            if (_openPicker == 'exercise') ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  children: [
                    for (final ex in iv.equipment.validExercises)
                      _pickerChip(ex.label, iv.exercise == ex,
                          () => selectExercise(ex)),
                  ],
                ),
              ),
            ],
            if (iv.exercise.isOneArm) ...[
              const Divider(color: Colors.white12, height: 1),
              _formRow(
                'Seite',
                Row(
                  children: [
                    _pickerChip('Links', iv.side == ExerciseSide.links,
                        () => _update(() => iv.side = ExerciseSide.links)),
                    const SizedBox(width: 6),
                    _pickerChip('Rechts', iv.side == ExerciseSide.rechts,
                        () => _update(() => iv.side = ExerciseSide.rechts)),
                  ],
                ),
              ),
            ],
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

- [ ] **Step 5: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/plans/widgets/minute_row.dart
```

Erwartet: `No issues found!`

- [ ] **Step 6: Gesamte Test-Suite**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/plans/widgets/minute_row.dart
git commit -m "feat: add Pause toggle to plan editor row; compact row shows PAUSE label"
```

---

### Task 3: Workout-Screen — PAUSE-Darstellung

**Files:**
- Modify: `lib/features/workout/workout_notifier.dart`
- Modify: `lib/features/workout/widgets/reps_card.dart`
- Modify: `lib/features/workout/widgets/next_minute_preview.dart`
- Modify: `lib/features/workout/widgets/confirmation_overlay.dart`
- Modify: `lib/features/workout/workout_screen.dart`

#### Aktueller Zustand (relevante Stellen)

```dart
// workout_notifier.dart — WorkoutState
int get currentReps => intervals[currentMinute].reps;
int get totalReps => intervals.fold(0, (a, iv) => a + iv.reps);

// workout_notifier.dart — workoutLabelForMinute
String workoutLabelForMinute(int minute) {
  final iv = _activePlan.intervals[minute];
  final sideStr = (iv.exercise.isOneArm && iv.side != null)
      ? ' · ${iv.side!.label}'
      : '';
  return '${iv.equipment.label} · ${iv.exercise.label}$sideStr';
}

// reps_card.dart — Signatur
class RepsCard extends StatelessWidget {
  final int currentMinute;
  final int currentReps;
  final String workoutLabel;
  final String iconPath;
  final Animation<double> pulseAnimation;
  // ...
}

// next_minute_preview.dart — Signatur
class NextMinutePreview extends StatelessWidget {
  final int nextReps;
  // ...
  Widget build(_) => Text('Nächste Minute: $nextReps Reps', ...);
}

// confirmation_overlay.dart — Signatur
class ConfirmationOverlay extends StatelessWidget {
  final int nextReps;
  final Color nextColor;
  final String nextLabel;
  final int nextMinuteNumber;
  final VoidCallback onConfirm;
  // ...
}

// workout_screen.dart — _buildWorkoutScreen
final phaseColor = phaseColorForMinute(state.currentMinute);
// ...
RepsCard(
  currentMinute: state.currentMinute,
  currentReps: state.currentReps,
  workoutLabel: workoutLabel,
  iconPath: iconPath,
  pulseAnimation: _pulseAnimation,
),
// ...
NextMinutePreview(nextReps: state.intervals[state.currentMinute + 1].reps),

// workout_screen.dart — _buildConfirmationOverlay
Widget _buildConfirmationOverlay(WorkoutState state) {
  final notifier = ref.read(workoutNotifierProvider.notifier);
  final nextMinute = state.currentMinute + 1;
  return ConfirmationOverlay(
    nextReps: state.intervals[nextMinute].reps,
    nextColor: phaseColorForMinute(nextMinute),
    nextLabel: notifier.workoutLabelForMinute(nextMinute),
    nextMinuteNumber: nextMinute + 1,
    onConfirm: () { ... },
  );
}
```

- [ ] **Step 1: `WorkoutState` — `currentReps` und `totalReps` für Pause anpassen**

In `workout_notifier.dart` diese zwei Getter in `WorkoutState`:

```dart
  int get currentReps => intervals[currentMinute].reps;
  int get totalReps => intervals.fold(0, (a, iv) => a + iv.reps);
```

ersetzen durch:

```dart
  int get currentReps =>
      intervals[currentMinute].isPause ? 0 : intervals[currentMinute].reps;
  int get totalReps =>
      intervals.fold(0, (a, iv) => a + (iv.isPause ? 0 : iv.reps));
```

- [ ] **Step 2: `workoutLabelForMinute` für Pause anpassen**

In `workout_notifier.dart` die Methode `workoutLabelForMinute`:

```dart
  String workoutLabelForMinute(int minute) {
    final iv = _activePlan.intervals[minute];
    final sideStr = (iv.exercise.isOneArm && iv.side != null)
        ? ' · ${iv.side!.label}'
        : '';
    return '${iv.equipment.label} · ${iv.exercise.label}$sideStr';
  }
```

ersetzen durch:

```dart
  String workoutLabelForMinute(int minute) {
    final iv = _activePlan.intervals[minute];
    if (iv.isPause) return 'Pause';
    final sideStr = (iv.exercise.isOneArm && iv.side != null)
        ? ' · ${iv.side!.label}'
        : '';
    return '${iv.equipment.label} · ${iv.exercise.label}$sideStr';
  }
```

- [ ] **Step 3: `RepsCard` — `isPause`-Parameter + PAUSE-Darstellung**

`lib/features/workout/widgets/reps_card.dart` komplett ersetzen durch:

```dart
import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class RepsCard extends StatelessWidget {
  final int currentMinute;
  final int currentReps;
  final String workoutLabel;
  final String iconPath;
  final Animation<double> pulseAnimation;
  final bool isPause;

  const RepsCard({
    super.key,
    required this.currentMinute,
    required this.currentReps,
    required this.workoutLabel,
    required this.iconPath,
    required this.pulseAnimation,
    this.isPause = false,
  });

  @override
  Widget build(BuildContext context) {
    final phaseColor =
        isPause ? Colors.white24 : phaseColorForMinute(currentMinute);
    return ScaleTransition(
      scale: pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: phaseColor.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            if (!isPause) ...[
              Image.asset(iconPath, width: 48, height: 48, color: phaseColor),
              const SizedBox(height: 4),
              Text(
                'REPS',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              Text(
                '$currentReps',
                style: TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: phaseColor,
                    height: 1),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'PAUSE',
                style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: phaseColor,
                    height: 1,
                    letterSpacing: 4),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            Text(
              workoutLabel,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: `NextMinutePreview` — `nextIsPause`-Parameter**

`lib/features/workout/widgets/next_minute_preview.dart` komplett ersetzen durch:

```dart
import 'package:flutter/material.dart';

class NextMinutePreview extends StatelessWidget {
  final int nextReps;
  final bool nextIsPause;

  const NextMinutePreview({
    super.key,
    required this.nextReps,
    this.nextIsPause = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = nextIsPause ? 'Pause' : '$nextReps Reps';
    return Text(
      'Nächste Minute: $label',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
    );
  }
}
```

- [ ] **Step 5: `ConfirmationOverlay` — `nextIsPause`-Parameter**

`lib/features/workout/widgets/confirmation_overlay.dart` komplett ersetzen durch:

```dart
import 'package:flutter/material.dart';

class ConfirmationOverlay extends StatelessWidget {
  final int nextReps;
  final Color nextColor;
  final String nextLabel;
  final int nextMinuteNumber;
  final VoidCallback onConfirm;
  final bool nextIsPause;

  const ConfirmationOverlay({
    super.key,
    required this.nextReps,
    required this.nextColor,
    required this.nextLabel,
    required this.nextMinuteNumber,
    required this.onConfirm,
    this.nextIsPause = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onConfirm,
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('INTERVALL BEENDET',
                  style: TextStyle(
                      color: Colors.white24, fontSize: 11, letterSpacing: 4)),
              const SizedBox(height: 32),
              if (nextIsPause)
                Text(
                  'PAUSE',
                  style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: nextColor,
                      height: 1,
                      letterSpacing: 4),
                )
              else
                Text(
                  '$nextReps',
                  style: TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      color: nextColor,
                      height: 1),
                ),
              Text(nextLabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 16)),
              Text('Minute $nextMinuteNumber',
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 13)),
              const SizedBox(height: 48),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: nextColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: nextColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: const Text('WEITER',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Colors.white)),
              ),
              const SizedBox(height: 16),
              const Text('oder irgendwo tippen',
                  style: TextStyle(color: Colors.white12, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: `workout_screen.dart` — `isPause` an Widgets übergeben**

In `_buildWorkoutScreen` die Zeile

```dart
    final phaseColor = phaseColorForMinute(state.currentMinute);
```

ersetzen durch:

```dart
    final isPauseInterval = state.intervals[state.currentMinute].isPause;
    final phaseColor = isPauseInterval
        ? Colors.white24
        : phaseColorForMinute(state.currentMinute);
```

Dann `RepsCard(...)` ersetzen durch:

```dart
          RepsCard(
            currentMinute: state.currentMinute,
            currentReps: state.currentReps,
            workoutLabel: workoutLabel,
            iconPath: iconPath,
            pulseAnimation: _pulseAnimation,
            isPause: isPauseInterval,
          ),
```

Und `NextMinutePreview(nextReps: ...)` ersetzen durch:

```dart
            NextMinutePreview(
              nextReps: state.intervals[state.currentMinute + 1].reps,
              nextIsPause: state.intervals[state.currentMinute + 1].isPause,
            ),
```

In `_buildConfirmationOverlay` den kompletten Methodenkörper ersetzen durch:

```dart
  Widget _buildConfirmationOverlay(WorkoutState state) {
    final notifier = ref.read(workoutNotifierProvider.notifier);
    final nextMinute = state.currentMinute + 1;
    final nextInterval = state.intervals[nextMinute];
    final nextColor = nextInterval.isPause
        ? Colors.white24
        : phaseColorForMinute(nextMinute);
    return ConfirmationOverlay(
      nextReps: nextInterval.reps,
      nextColor: nextColor,
      nextLabel: notifier.workoutLabelForMinute(nextMinute),
      nextMinuteNumber: nextMinute + 1,
      nextIsPause: nextInterval.isPause,
      onConfirm: () {
        _pulseController.forward().then((_) => _pulseController.reverse());
        notifier.confirmInterval();
      },
    );
  }
```

- [ ] **Step 7: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/workout/
```

Erwartet: `No issues found!`

- [ ] **Step 8: Gesamte Test-Suite**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 9: Commit**

```powershell
git add lib/features/workout/workout_notifier.dart lib/features/workout/widgets/reps_card.dart lib/features/workout/widgets/next_minute_preview.dart lib/features/workout/widgets/confirmation_overlay.dart lib/features/workout/workout_screen.dart
git commit -m "feat: display pause intervals in workout screen (gray, PAUSE label, no icon/reps)"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|---|---|
| Intervall als "Pause" markierbar | Task 1 (isPause-Feld) |
| Kein Gerät, keine Übung, nur Countdown | Task 2 (Gerät/Übung/Reps ausgeblendet), Task 3 (currentReps=0) |
| Graue Farbe im Workout-Screen | Task 3 (RepsCard, phaseColor) |
| "PAUSE"-Label statt Reps-Anzeige | Task 3 (RepsCard) |
| Plan-Editor: Pause als eigene Option | Task 2 (Toggle "Übung / Pause") |
| Bestätigungs-Overlay zeigt PAUSE korrekt | Task 3 (ConfirmationOverlay) |
| Vorschau "Nächste Minute" zeigt Pause | Task 3 (NextMinutePreview) |
| Rückwärtskompatibilität (alte JSON ohne 'p') | Task 1 (fromJson: `(j['p'] as int?) == 1`) |
| planKey erkennt Pause-Änderung | Task 1 (planKey-Erweiterung) |
| totalReps zählt Pause-Intervalle nicht | Task 3 (WorkoutState.totalReps) |

**Placeholder-Scan:** Keine. Alle Steps enthalten vollständigen Code.

**Type-Konsistenz:**
- `isPause: bool` — überall konsistent verwendet
- `nextIsPause: bool` — in `NextMinutePreview` und `ConfirmationOverlay` identisch benannt
- `Colors.white24` als Grau-Ton — konsistent in RepsCard, ConfirmationOverlay (via nextColor), phaseColor in workout_screen und minute_row

**Offener Punkt (außerhalb dieses Plans):**
- `OverallProgress`-Widget zeigt `workoutLabel` und `totalReps` — beide werden korrekt befüllt (`workoutLabel` = 'Pause', `totalReps` ohne Pause-Intervalle), kein Anpassungsbedarf.
- `FinishedScreen` zeigt `workoutLabel` des letzten Intervalls — falls letztes Intervall eine Pause ist, steht dort "Pause". Akzeptabel.
