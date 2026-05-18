# Steel Mace Übungen + Wiederholung-Label Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Steel Mace bekommt Links/Rechts-Auswahl für mace360 und eine neue Übung schulterHeben; Wiederholungs-Label von "R" auf "W" umstellen.

**Architecture:** Alle drei Änderungen sind unabhängig voneinander. Task 1 führt TDD-Tests zuerst ein (failing), Task 2 macht settings.dart konform (passing), Task 3 ändert die UI-Labels. Kein neuer Datentyp, kein neues Widget — nur Erweiterung bestehender Muster.

**Tech Stack:** Flutter, Dart, Riverpod (unberührt), flutter_test

---

### Task 1: Failing Tests schreiben

**Files:**
- Modify: `test/core/models/settings_test.dart`

- [ ] **Step 1: Bestehenden isOneArm-Test ersetzen**

In `test/core/models/settings_test.dart` den Test bei Zeile 100–107 ersetzen:

```dart
test('isOneArm: swingEinarmig/snatch/pushPress/mace360/schulterHeben → true; swingBeidarmig/myotatischerCrunch → false', () {
  expect(Exercise.swingEinarmig.isOneArm, isTrue);
  expect(Exercise.snatch.isOneArm, isTrue);
  expect(Exercise.pushPress.isOneArm, isTrue);
  expect(Exercise.mace360.isOneArm, isTrue);
  expect(Exercise.schulterHeben.isOneArm, isTrue);
  expect(Exercise.swingBeidarmig.isOneArm, isFalse);
  expect(Exercise.myotatischerCrunch.isOneArm, isFalse);
});
```

- [ ] **Step 2: Test für schulterHeben-Label hinzufügen**

Direkt nach dem `label: myotatischerCrunch`-Test (ca. Zeile 98) einfügen:

```dart
test('label: schulterHeben returns Schulterheben', () {
  expect(Exercise.schulterHeben.label, 'Schulterheben');
});
```

- [ ] **Step 3: Test für Steel-Mace validExercises hinzufügen**

Im `group('EquipmentX', ...)` Block (oder passender Stelle in der Datei) einfügen:

```dart
test('validExercises: Steel Mace enthält mace360 und schulterHeben', () {
  expect(Equipment.sm8.validExercises, containsAll([Exercise.mace360, Exercise.schulterHeben]));
  expect(Equipment.sm12.validExercises, containsAll([Exercise.mace360, Exercise.schulterHeben]));
});
```

- [ ] **Step 4: Tests ausführen — müssen FEHLSCHLAGEN**

```
flutter test test/core/models/settings_test.dart
```

Erwartetes Ergebnis: Compile-Fehler oder Fehler wegen `Exercise.schulterHeben` nicht definiert, und `mace360.isOneArm` → `isFalse` statt `isTrue`.

---

### Task 2: settings.dart aktualisieren

**Files:**
- Modify: `lib/core/models/settings.dart`

- [ ] **Step 1: schulterHeben ans Ende des Exercise-Enums hängen**

Zeile 6 ändern von:
```dart
enum Exercise { swingBeidarmig, swingEinarmig, snatch, pushPress, mace360, myotatischerCrunch }
```
zu:
```dart
enum Exercise { swingBeidarmig, swingEinarmig, snatch, pushPress, mace360, myotatischerCrunch, schulterHeben }
```

*(schulterHeben nach myotatischerCrunch = Index 6, damit bestehende gespeicherte Pläne nicht korrumpiert werden)*

- [ ] **Step 2: isOneArm um mace360 und schulterHeben erweitern**

Den `isOneArm`-Getter (ca. Zeile 74) ändern von:
```dart
bool get isOneArm =>
    this == Exercise.swingEinarmig ||
    this == Exercise.snatch ||
    this == Exercise.pushPress;
```
zu:
```dart
bool get isOneArm =>
    this == Exercise.swingEinarmig ||
    this == Exercise.snatch ||
    this == Exercise.pushPress ||
    this == Exercise.mace360 ||
    this == Exercise.schulterHeben;
```

- [ ] **Step 3: Label für schulterHeben hinzufügen**

Im `label`-Getter (switch-Statement, ca. Zeile 79) den Case für `mace360` suchen und danach einfügen:
```dart
case Exercise.mace360:            return '360s';
case Exercise.schulterHeben:      return 'Schulterheben';
case Exercise.myotatischerCrunch: return 'Myotatischer Crunch';
```

- [ ] **Step 4: validExercises für Steel Mace erweitern**

Ca. Zeile 67 ändern von:
```dart
Equipment.sm8  || Equipment.sm12 => [Exercise.mace360],
```
zu:
```dart
Equipment.sm8  || Equipment.sm12 => [Exercise.mace360, Exercise.schulterHeben],
```

- [ ] **Step 5: Tests ausführen — müssen BESTEHEN**

```
flutter test test/core/models/settings_test.dart
```

Erwartetes Ergebnis: Alle Tests PASS.

- [ ] **Step 6: Commit**

```
git add lib/core/models/settings.dart test/core/models/settings_test.dart
git commit -m "feat: add schulterHeben exercise for Steel Mace with side selection"
```

---

### Task 3: UI-Labels W und Wdh.

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`
- Modify: `lib/features/plans/widgets/minute_exact_editor.dart`

- [ ] **Step 1: R → W in minute_row.dart**

In `minute_row.dart` ca. Zeile 415 ändern von:
```dart
Text('${iv.reps}R',
```
zu:
```dart
Text('${iv.reps}W',
```

- [ ] **Step 2: Reps → Wdh. in minute_exact_editor.dart**

In `minute_exact_editor.dart` ca. Zeile 58 ändern von:
```dart
Text('${plan.totalReps} Reps',
```
zu:
```dart
Text('${plan.totalReps} Wdh.',
```

- [ ] **Step 3: Alle Tests ausführen**

```
flutter test
```

Erwartetes Ergebnis: Alle Tests PASS (Label-Änderungen haben keine eigenen Tests — sie sind rein visuell).

- [ ] **Step 4: App starten und manuell prüfen**

```
flutter run
```

Prüfen:
- Plan-Editor öffnen → Minute-Zeile zeigt `5W` statt `5R`
- Gesamt-Zeile unten zeigt `150 Wdh.` statt `150 Reps`
- Steel Mace Übung auswählen → `360s` und `Schulterheben` erscheinen in der Übungsauswahl
- Bei `360s` oder `Schulterheben`: Seite-Zeile (Links/Rechts) erscheint
- Bestehende Kettlebell-Pläne unverändert

- [ ] **Step 5: Commit**

```
git add lib/features/plans/widgets/minute_row.dart lib/features/plans/widgets/minute_exact_editor.dart
git commit -m "feat: change repetition label R to W and Reps to Wdh."
```
