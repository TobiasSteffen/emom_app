# Seite (Links/Rechts) für einarmige Übungen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Einarmige Kettlebell-Übungen (Swing einarmig, Snatch, Push Press) bekommen ein Seiten-Feld (Links/Rechts), das im Plan-Editor konfigurierbar ist und im Workout-Screen angezeigt wird.

**Architecture:** Vier unabhängige Schichten. Task 1 ergänzt `settings.dart` um `ExerciseSide` + `isOneArm`. Task 2 erweitert `IntervalConfig` in `training_plan.dart` um das nullable `side`-Feld (lazy migration via `elementAtOrNull`-Fallback). Task 3 ergänzt den Plan-Editor (`minute_row.dart`) mit einer "Seite"-Zeile und Auto-Default. Task 4 zeigt die Seite im Workout-Screen (`workout_notifier.dart`).

**Tech Stack:** Flutter/Dart, keine neuen Abhängigkeiten

---

## File Map

| File | Change |
|------|--------|
| `lib/core/models/settings.dart` | `ExerciseSide` enum + `ExerciseSideX` extension, `isOneArm` getter auf `ExerciseX` |
| `lib/core/models/training_plan.dart` | `IntervalConfig` +`side` Feld, `toJson`/`fromJson`/`copyWith` aktualisiert, `planKey` erweitert |
| `lib/features/plans/widgets/minute_row.dart` | "Seite"-Zeile in `_expandedForm`, `selectExercise`-Funktion, Side-Auto-Default in `selectEquipment` |
| `lib/features/workout/workout_notifier.dart` | `workoutLabelForMinute` fügt Seite an |
| `test/core/models/settings_test.dart` | Tests für `isOneArm` und `ExerciseSideX` |
| `test/core/models/training_plan_test.dart` | Tests für Side-Serialisierung, `copyWith`, `planKey` |

---

### Task 1: ExerciseSide-Enum und isOneArm-Getter in settings.dart

**Files:**
- Modify: `lib/core/models/settings.dart`
- Modify: `test/core/models/settings_test.dart`

#### Aktueller Zustand (Auszug aus settings.dart)

```dart
extension ExerciseX on Exercise {
  String get label {
    switch (this) {
      case Exercise.swingBeidarmig: return 'Swing beidarmig';
      case Exercise.swingEinarmig:  return 'Swing einarmig';
      case Exercise.snatch:         return 'Snatch';
      case Exercise.pushPress:      return 'Push Press';
      case Exercise.mace360:        return '360s';
      case Exercise.myotatischerCrunch: return 'Myotatischer Crunch';
    }
  }
}
// danach: Color phaseColorForMinute(...)
```

- [ ] **Step 1: Tests schreiben (failing)**

In `test/core/models/settings_test.dart` am Ende der `ExerciseX`-Gruppe ergänzen:

```dart
    test('isOneArm: swingEinarmig/snatch/pushPress → true; swingBeidarmig/mace360/myotatischerCrunch → false', () {
      expect(Exercise.swingEinarmig.isOneArm, isTrue);
      expect(Exercise.snatch.isOneArm, isTrue);
      expect(Exercise.pushPress.isOneArm, isTrue);
      expect(Exercise.swingBeidarmig.isOneArm, isFalse);
      expect(Exercise.mace360.isOneArm, isFalse);
      expect(Exercise.myotatischerCrunch.isOneArm, isFalse);
    });
```

Und am Ende der Datei eine neue Gruppe:

```dart
  group('ExerciseSideX', () {
    test('label returns Links/Rechts', () {
      expect(ExerciseSide.links.label, 'Links');
      expect(ExerciseSide.rechts.label, 'Rechts');
    });

    test('shortLabel returns L/R', () {
      expect(ExerciseSide.links.shortLabel, 'L');
      expect(ExerciseSide.rechts.shortLabel, 'R');
    });
  });
```

- [ ] **Step 2: Tests laufen lassen (sollen fehlschlagen)**

```powershell
flutter test test/core/models/settings_test.dart
```

Erwartet: Compile-Fehler wegen fehlender `isOneArm`-/`ExerciseSide`-Definitionen.

- [ ] **Step 3: Implementierung in settings.dart**

In `ExerciseX` direkt vor dem `label`-Getter den `isOneArm`-Getter ergänzen:

```dart
extension ExerciseX on Exercise {
  bool get isOneArm =>
      this == Exercise.swingEinarmig ||
      this == Exercise.snatch ||
      this == Exercise.pushPress;

  String get label {
    switch (this) {
      case Exercise.swingBeidarmig:     return 'Swing beidarmig';
      case Exercise.swingEinarmig:      return 'Swing einarmig';
      case Exercise.snatch:             return 'Snatch';
      case Exercise.pushPress:          return 'Push Press';
      case Exercise.mace360:            return '360s';
      case Exercise.myotatischerCrunch: return 'Myotatischer Crunch';
    }
  }
}
```

Direkt nach der `ExerciseX`-Extension (vor `Color phaseColorForMinute`) einfügen:

```dart
enum ExerciseSide { links, rechts }

extension ExerciseSideX on ExerciseSide {
  String get label => this == ExerciseSide.links ? 'Links' : 'Rechts';
  String get shortLabel => this == ExerciseSide.links ? 'L' : 'R';
}
```

- [ ] **Step 4: Tests laufen lassen (sollen bestehen)**

```powershell
flutter test test/core/models/settings_test.dart
```

Erwartet: All tests passed.

- [ ] **Step 5: Gesamte Test-Suite**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 6: Commit**

```powershell
git add lib/core/models/settings.dart test/core/models/settings_test.dart
git commit -m "feat: add ExerciseSide enum and isOneArm getter for single-arm exercises"
```

---

### Task 2: IntervalConfig gewinnt side-Feld

**Files:**
- Modify: `lib/core/models/training_plan.dart`
- Modify: `test/core/models/training_plan_test.dart`

#### Aktueller Zustand (Auszug aus training_plan.dart)

```dart
class IntervalConfig {
  int reps;
  int durationSeconds;
  Equipment equipment;
  Exercise exercise;

  IntervalConfig({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
    required this.exercise,
  });

  Map<String, dynamic> toJson() => {
    'r': reps,
    'd': durationSeconds,
    'e': equipment.index,
    'x': exercise.index,
  };

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
    return IntervalConfig(
      reps: j['r'] as int,
      durationSeconds: j['d'] as int,
      equipment: eq,
      exercise: ex,
    );
  }

  IntervalConfig copyWith({
    int? reps,
    int? durationSeconds,
    Equipment? equipment,
    Exercise? exercise,
  }) =>
      IntervalConfig(
        reps: reps ?? this.reps,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        equipment: equipment ?? this.equipment,
        exercise: exercise ?? this.exercise,
      );
}
```

Und in `TrainingPlan`:

```dart
String get planKey => intervals
    .map((iv) => '${iv.reps},${iv.durationSeconds},${iv.equipment.index},${iv.exercise.index}')
    .join('|');
```

- [ ] **Step 1: Tests schreiben (failing)**

In `test/core/models/training_plan_test.dart` am Ende der `IntervalConfig`-Gruppe ergänzen:

```dart
    test('side is null by default', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
      );
      expect(iv.side, isNull);
    });

    test('side serializes and deserializes correctly', () {
      final iv = IntervalConfig(
        reps: 8,
        durationSeconds: 45,
        equipment: Equipment.kb24,
        exercise: Exercise.swingEinarmig,
        side: ExerciseSide.rechts,
      );
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.side, ExerciseSide.rechts);
    });

    test('fromJson without side key gives null side', () {
      final json = {'r': 10, 'd': 60, 'e': 2, 'x': 1};
      final iv = IntervalConfig.fromJson(json);
      expect(iv.side, isNull);
    });

    test('copyWith can set side', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingEinarmig,
        side: ExerciseSide.links,
      );
      final copy = iv.copyWith(side: ExerciseSide.rechts);
      expect(copy.side, ExerciseSide.rechts);
      expect(copy.reps, 5);
    });

    test('copyWith clearSide removes side', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingEinarmig,
        side: ExerciseSide.links,
      );
      final copy = iv.copyWith(clearSide: true);
      expect(copy.side, isNull);
    });
```

Am Ende der `TrainingPlan`-Gruppe ergänzen:

```dart
    test('planKey changes when side changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].side = ExerciseSide.links;
      expect(plan.planKey, isNot(key1));
    });
```

Außerdem in den Import-Bereich `training_plan_test.dart` nichts hinzufügen — `ExerciseSide` ist bereits über `settings.dart` via `training_plan.dart` transitiv importiert. Aber der Testfile importiert nur `training_plan.dart` und `settings.dart` direkt — `ExerciseSide` kommt aus `settings.dart`, das bereits importiert ist. ✓

- [ ] **Step 2: Tests laufen lassen (sollen fehlschlagen)**

```powershell
flutter test test/core/models/training_plan_test.dart
```

Erwartet: Compile-Fehler wegen fehlendem `side`-Feld.

- [ ] **Step 3: Implementierung in training_plan.dart**

`IntervalConfig` vollständig ersetzen:

```dart
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
    );
  }

  IntervalConfig copyWith({
    int? reps,
    int? durationSeconds,
    Equipment? equipment,
    Exercise? exercise,
    ExerciseSide? side,
    bool clearSide = false,
  }) =>
      IntervalConfig(
        reps: reps ?? this.reps,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        equipment: equipment ?? this.equipment,
        exercise: exercise ?? this.exercise,
        side: clearSide ? null : (side ?? this.side),
      );
}
```

`planKey` in `TrainingPlan` aktualisieren (die einzige andere zu ändernde Zeile):

```dart
  String get planKey => intervals
      .map((iv) => '${iv.reps},${iv.durationSeconds},${iv.equipment.index},${iv.exercise.index},${iv.side?.index ?? -1}')
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
git commit -m "feat: IntervalConfig gains nullable side field for single-arm exercise tracking"
```

---

### Task 3: Plan-Editor — "Seite"-Zeile in minute_row.dart

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`

#### Aktueller Zustand (relevanter Auszug, _expandedForm)

```dart
Widget _expandedForm(IntervalConfig iv) {
    void selectEquipment(Equipment eq) => _update(() {
          iv.equipment = eq;
          if (!eq.validExercises.contains(iv.exercise)) {
            iv.exercise = eq.defaultExercise;
          }
        });
    // ...
          _formSectionHeader('Übung', iv.exercise.label, 'exercise'),
          if (_openPicker == 'exercise') ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                children: [
                  for (final ex in iv.equipment.validExercises)
                    _pickerChip(ex.label, iv.exercise == ex,
                        () => _update(() => iv.exercise = ex)),
                ],
              ),
            ),
          ],
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Wiederholungen',
```

- [ ] **Step 1: _expandedForm aktualisieren**

Drei Änderungen in `lib/features/plans/widgets/minute_row.dart`:

**1. `selectEquipment` um Side-Logik erweitern:**

```dart
    void selectEquipment(Equipment eq) => _update(() {
          iv.equipment = eq;
          if (!eq.validExercises.contains(iv.exercise)) {
            iv.exercise = eq.defaultExercise;
          }
          if (iv.exercise.isOneArm && iv.side == null) {
            iv.side = widget.index % 2 == 0 ? ExerciseSide.links : ExerciseSide.rechts;
          }
          if (!iv.exercise.isOneArm) {
            iv.side = null;
          }
        });
```

**2. `selectExercise` hinzufügen (direkt nach `selectEquipment`):**

```dart
    void selectExercise(Exercise ex) => _update(() {
          iv.exercise = ex;
          if (ex.isOneArm && iv.side == null) {
            iv.side = widget.index % 2 == 0 ? ExerciseSide.links : ExerciseSide.rechts;
          }
          if (!ex.isOneArm) {
            iv.side = null;
          }
        });
```

**3. Exercise-Picker auf `selectExercise` umstellen UND "Seite"-Zeile nach dem Übung-Picker einfügen:**

```dart
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
```

- [ ] **Step 2: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/plans/widgets/minute_row.dart
```

Erwartet: `No issues found!`

- [ ] **Step 3: Gesamte Test-Suite**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 4: Commit**

```powershell
git add lib/features/plans/widgets/minute_row.dart
git commit -m "feat: show Seite picker in plan editor for single-arm exercises"
```

---

### Task 4: Workout-Screen — Seite im Label anzeigen

**Files:**
- Modify: `lib/features/workout/workout_notifier.dart`

#### Aktueller Zustand

```dart
String workoutLabelForMinute(int minute) {
  final iv = _activePlan.intervals[minute];
  return '${iv.equipment.label} · ${iv.exercise.label}';
}
```

- [ ] **Step 1: `workoutLabelForMinute` erweitern**

```dart
String workoutLabelForMinute(int minute) {
  final iv = _activePlan.intervals[minute];
  final sideStr = (iv.exercise.isOneArm && iv.side != null)
      ? ' · ${iv.side!.label}'
      : '';
  return '${iv.equipment.label} · ${iv.exercise.label}$sideStr';
}
```

Dies zeigt z.B. `"KB 24kg · Swing einarmig · Links"` in `RepsCard` und `ConfirmationOverlay`.

- [ ] **Step 2: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/workout/workout_notifier.dart
```

Erwartet: `No issues found!`

- [ ] **Step 3: Gesamte Test-Suite**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 4: Commit**

```powershell
git add lib/features/workout/workout_notifier.dart
git commit -m "feat: display side label in workout screen for single-arm exercises"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|-------------|------|
| `ExerciseSide` enum (links/rechts) | Task 1 |
| `ExerciseSideX.label` / `.shortLabel` | Task 1 |
| `Exercise.isOneArm` für swingEinarmig/snatch/pushPress | Task 1 |
| `IntervalConfig.side` (nullable, persistiert) | Task 2 |
| Migration (fehlendes 's'-Key → null) | Task 2 |
| `planKey` enthält side | Task 2 |
| "Seite"-Zeile im Plan-Editor (nur bei einarmigen Übungen) | Task 3 |
| Auto-Default Links/Rechts beim Wechsel auf einarmige Übung | Task 3 |
| Side wird null wenn Übung nicht mehr einarmig | Task 3 |
| Side-Anzeige im Workout-Screen | Task 4 |

**Placeholder-Scan:** Keine TBDs, alle Code-Blöcke vollständig.

**Type-Konsistenz:** `ExerciseSide.links`/`.rechts` durchgehend gleich. `isOneArm` in Task 1 definiert, in Tasks 3+4 genutzt. `iv.side` in Task 2 als `ExerciseSide?` definiert, in Tasks 3+4 korrekt verwendet.
