# Pezziball Equipment — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pezziball als drittes Sportgerät mit 5 Gewichtsvarianten (0/2,5/5/7,5/10 kg) und der Übung "Myotatischer Crunch" hinzufügen.

**Architecture:** Zwei unabhängige Änderungen. Task 1 erweitert das Datenmodell (`settings.dart` + Tests). Task 2 erweitert die Equipment-Picker-UI (`minute_row.dart`). Keine Migration nötig — neue Enum-Varianten werden hinten angehängt, `elementAtOrNull`-Fallbacks in `IntervalConfig.fromJson` und `IntervalRecord.fromJson` sind bereits vorhanden. Icon-Asset `assets/icon/pezziball.png` existiert bereits.

**Tech Stack:** Flutter/Dart, keine neuen Abhängigkeiten

---

## File Map

| File | Change |
|------|--------|
| `lib/core/models/settings.dart` | Equipment enum +5 PB-Varianten, Exercise enum +1, EquipmentX +isPezziball/label/shortLabel/iconPath/defaultExercise/validExercises, ExerciseX +label |
| `test/core/models/settings_test.dart` | Tests für Pezziball-Varianten und myotatischerCrunch |
| `lib/features/plans/widgets/minute_row.dart` | Pezziball-Gruppe im Equipment-Picker |

---

### Task 1: Datenmodell — Pezziball-Varianten und myotatischerCrunch

**Files:**
- Modify: `lib/core/models/settings.dart`
- Modify: `test/core/models/settings_test.dart`

#### Aktueller Zustand (relevant)

```dart
// settings.dart
enum Equipment { kb16, kb20, kb24, sm8, sm12 }
enum Exercise { swingBeidarmig, swingEinarmig, snatch, pushPress, mace360 }

extension EquipmentX on Equipment {
  bool get isKettlebell =>
      this == Equipment.kb16 || this == Equipment.kb20 || this == Equipment.kb24;
  bool get isSteelMace =>
      this == Equipment.sm8 || this == Equipment.sm12;

  String get label { switch (this) {
    case Equipment.kb16: return 'KB 16kg';
    case Equipment.kb20: return 'KB 20kg';
    case Equipment.kb24: return 'KB 24kg';
    case Equipment.sm8:  return 'SM 8kg';
    case Equipment.sm12: return 'SM 12kg';
  }}

  String get shortLabel { switch (this) {
    case Equipment.kb16: return '16 kg';
    case Equipment.kb20: return '20 kg';
    case Equipment.kb24: return '24 kg';
    case Equipment.sm8:  return '8 kg';
    case Equipment.sm12: return '12 kg';
  }}

  String get iconPath => switch (this) {
    Equipment.kb16 || Equipment.kb20 || Equipment.kb24 => 'assets/icon/kettlebell.png',
    Equipment.sm8  || Equipment.sm12                   => 'assets/icon/steelmace.png',
  };

  Exercise get defaultExercise => switch (this) {
    Equipment.kb16 || Equipment.kb20 || Equipment.kb24 => Exercise.swingBeidarmig,
    Equipment.sm8  || Equipment.sm12                   => Exercise.mace360,
  };

  List<Exercise> get validExercises => switch (this) {
    Equipment.kb16 || Equipment.kb20 || Equipment.kb24 =>
        [Exercise.swingBeidarmig, Exercise.swingEinarmig, Exercise.snatch, Exercise.pushPress],
    Equipment.sm8  || Equipment.sm12 => [Exercise.mace360],
  };
}

extension ExerciseX on Exercise {
  String get label { switch (this) {
    case Exercise.swingBeidarmig: return 'Swing beidarmig';
    case Exercise.swingEinarmig:  return 'Swing einarmig';
    case Exercise.snatch:         return 'Snatch';
    case Exercise.pushPress:      return 'Push Press';
    case Exercise.mace360:        return '360s';
  }}
}
```

- [ ] **Step 1: Tests schreiben (failing)**

In `test/core/models/settings_test.dart` folgende Tests ergänzen (am Ende der `EquipmentX`-Gruppe und der `ExerciseX`-Gruppe):

```dart
    test('isPezziball: pb0/pb2_5/pb5/pb7_5/pb10 → true; KB/SM → false', () {
      expect(Equipment.pb0.isPezziball, isTrue);
      expect(Equipment.pb2_5.isPezziball, isTrue);
      expect(Equipment.pb5.isPezziball, isTrue);
      expect(Equipment.pb7_5.isPezziball, isTrue);
      expect(Equipment.pb10.isPezziball, isTrue);
      expect(Equipment.kb24.isPezziball, isFalse);
      expect(Equipment.sm12.isPezziball, isFalse);
    });

    test('label returns correct string for PB variants', () {
      expect(Equipment.pb0.label,   'Pezziball');
      expect(Equipment.pb2_5.label, 'PB 2,5kg');
      expect(Equipment.pb5.label,   'PB 5kg');
      expect(Equipment.pb7_5.label, 'PB 7,5kg');
      expect(Equipment.pb10.label,  'PB 10kg');
    });

    test('shortLabel returns weight-only for PB variants', () {
      expect(Equipment.pb0.shortLabel,   'ohne');
      expect(Equipment.pb2_5.shortLabel, '2,5 kg');
      expect(Equipment.pb5.shortLabel,   '5 kg');
      expect(Equipment.pb7_5.shortLabel, '7,5 kg');
      expect(Equipment.pb10.shortLabel,  '10 kg');
    });

    test('iconPath returns pezziball.png for PB variants', () {
      expect(Equipment.pb0.iconPath,  'assets/icon/pezziball.png');
      expect(Equipment.pb10.iconPath, 'assets/icon/pezziball.png');
    });

    test('defaultExercise: PB → myotatischerCrunch', () {
      expect(Equipment.pb0.defaultExercise,  Exercise.myotatischerCrunch);
      expect(Equipment.pb10.defaultExercise, Exercise.myotatischerCrunch);
    });

    test('validExercises: PB has exactly [myotatischerCrunch]', () {
      expect(Equipment.pb5.validExercises, [Exercise.myotatischerCrunch]);
    });
```

Und in der `ExerciseX`-Gruppe:

```dart
    test('label: myotatischerCrunch returns correct string', () {
      expect(Exercise.myotatischerCrunch.label, 'Myotatischer Crunch');
    });
```

- [ ] **Step 2: Tests laufen lassen (sollen fehlschlagen)**

```powershell
flutter test test/core/models/settings_test.dart
```

Erwartet: Compile-Fehler wegen fehlender Enum-Varianten.

- [ ] **Step 3: Implementierung in `settings.dart`**

Vollständige neue Version der Enums und Extensions:

```dart
enum Equipment { kb16, kb20, kb24, sm8, sm12, pb0, pb2_5, pb5, pb7_5, pb10 }

enum Exercise { swingBeidarmig, swingEinarmig, snatch, pushPress, mace360, myotatischerCrunch }

extension EquipmentX on Equipment {
  bool get isKettlebell =>
      this == Equipment.kb16 || this == Equipment.kb20 || this == Equipment.kb24;

  bool get isSteelMace =>
      this == Equipment.sm8 || this == Equipment.sm12;

  bool get isPezziball =>
      this == Equipment.pb0   || this == Equipment.pb2_5 ||
      this == Equipment.pb5   || this == Equipment.pb7_5 ||
      this == Equipment.pb10;

  String get label {
    switch (this) {
      case Equipment.kb16:  return 'KB 16kg';
      case Equipment.kb20:  return 'KB 20kg';
      case Equipment.kb24:  return 'KB 24kg';
      case Equipment.sm8:   return 'SM 8kg';
      case Equipment.sm12:  return 'SM 12kg';
      case Equipment.pb0:   return 'Pezziball';
      case Equipment.pb2_5: return 'PB 2,5kg';
      case Equipment.pb5:   return 'PB 5kg';
      case Equipment.pb7_5: return 'PB 7,5kg';
      case Equipment.pb10:  return 'PB 10kg';
    }
  }

  String get shortLabel {
    switch (this) {
      case Equipment.kb16:  return '16 kg';
      case Equipment.kb20:  return '20 kg';
      case Equipment.kb24:  return '24 kg';
      case Equipment.sm8:   return '8 kg';
      case Equipment.sm12:  return '12 kg';
      case Equipment.pb0:   return 'ohne';
      case Equipment.pb2_5: return '2,5 kg';
      case Equipment.pb5:   return '5 kg';
      case Equipment.pb7_5: return '7,5 kg';
      case Equipment.pb10:  return '10 kg';
    }
  }

  String get iconPath => switch (this) {
    Equipment.kb16 || Equipment.kb20 || Equipment.kb24 => 'assets/icon/kettlebell.png',
    Equipment.sm8  || Equipment.sm12                   => 'assets/icon/steelmace.png',
    Equipment.pb0  || Equipment.pb2_5 || Equipment.pb5 ||
    Equipment.pb7_5 || Equipment.pb10                  => 'assets/icon/pezziball.png',
  };

  Exercise get defaultExercise => switch (this) {
    Equipment.kb16 || Equipment.kb20 || Equipment.kb24 => Exercise.swingBeidarmig,
    Equipment.sm8  || Equipment.sm12                   => Exercise.mace360,
    Equipment.pb0  || Equipment.pb2_5 || Equipment.pb5 ||
    Equipment.pb7_5 || Equipment.pb10                  => Exercise.myotatischerCrunch,
  };

  List<Exercise> get validExercises => switch (this) {
    Equipment.kb16 || Equipment.kb20 || Equipment.kb24 =>
        [Exercise.swingBeidarmig, Exercise.swingEinarmig, Exercise.snatch, Exercise.pushPress],
    Equipment.sm8  || Equipment.sm12 => [Exercise.mace360],
    Equipment.pb0  || Equipment.pb2_5 || Equipment.pb5 ||
    Equipment.pb7_5 || Equipment.pb10 => [Exercise.myotatischerCrunch],
  };
}

extension ExerciseX on Exercise {
  String get label {
    switch (this) {
      case Exercise.swingBeidarmig:    return 'Swing beidarmig';
      case Exercise.swingEinarmig:     return 'Swing einarmig';
      case Exercise.snatch:            return 'Snatch';
      case Exercise.pushPress:         return 'Push Press';
      case Exercise.mace360:           return '360s';
      case Exercise.myotatischerCrunch: return 'Myotatischer Crunch';
    }
  }
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
git commit -m "feat: add Pezziball equipment (5 variants) and myotatischerCrunch exercise"
```

---

### Task 2: Equipment-Picker UI — Pezziball-Gruppe

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`

Der Equipment-Picker in `_expandedForm` zeigt aktuell zwei Gruppen (KB, SM). Eine dritte Gruppe für Pezziball wird ergänzt. Die Methode `_equipmentGroup` ist bereits vorhanden und kann direkt genutzt werden.

#### Aktueller Zustand (relevant, ca. Zeile 192–212)

```dart
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
      ],
    ),
  ),
],
```

- [ ] **Step 1: Pezziball-Gruppe ergänzen**

Den `Column`-Inhalt um einen dritten `_equipmentGroup`-Aufruf erweitern:

```dart
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
```

- [ ] **Step 2: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/plans/widgets/minute_row.dart
```

Erwartet: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add lib/features/plans/widgets/minute_row.dart
git commit -m "feat: add Pezziball group to equipment picker in plan editor"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|-------------|------|
| 5 PB-Varianten (0/2,5/5/7,5/10 kg) im Enum | Task 1 |
| `isPezziball` getter | Task 1 |
| label / shortLabel für alle PB-Varianten | Task 1 |
| iconPath → pezziball.png | Task 1 |
| defaultExercise → myotatischerCrunch | Task 1 |
| validExercises → [myotatischerCrunch] | Task 1 |
| myotatischerCrunch im Exercise enum | Task 1 |
| ExerciseX.label für myotatischerCrunch | Task 1 |
| PB-Gruppe im Equipment-Picker | Task 2 |
| Keine Migration nötig (elementAtOrNull-Fallback bereits vorhanden) | — |
| Icon-Asset vorhanden | — (bereits committed) |

**Placeholder-Scan:** Keine TBDs, alle Code-Blöcke vollständig.

**Type-Konsistenz:** `Equipment.pb0`/`pb2_5` etc. durchgehend gleich benannt. `Exercise.myotatischerCrunch` in Task 1 definiert und in Task 2 implizit genutzt (via `defaultExercise`/`validExercises`).
