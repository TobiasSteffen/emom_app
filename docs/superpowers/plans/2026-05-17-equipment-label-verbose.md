# Equipment Label Verbose — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Equipment.label` ausschreiben: "Kettlebell 16kg", "Steel Mace 8kg", "Pezziball", "Pezziball + 2,5kg" etc. statt der bisherigen Abkürzungen "KB 16kg", "SM 8kg", "PB 2,5kg".

**Architecture:** Reine Datenwert-Änderung in `EquipmentX.label` in `lib/core/models/settings.dart`. Die Tests in `test/core/models/settings_test.dart` werden zuerst auf die neuen Strings umgestellt (Red), dann die Implementierung angepasst (Green). Alle anderen Stellen im Code, die `.label` nutzen (Workout-Screen, History, Plan-Editor-Header), profitieren automatisch.

**Tech Stack:** Flutter/Dart, keine neuen Abhängigkeiten

---

## File Map

| File | Change |
|------|--------|
| `lib/core/models/settings.dart` | `EquipmentX.label` — neue String-Werte |
| `test/core/models/settings_test.dart` | Test-Expectations auf neue Label-Werte anpassen |

---

### Task 1: Equipment-Label auf ausgeschriebene Namen umstellen

**Files:**
- Modify: `lib/core/models/settings.dart`
- Modify: `test/core/models/settings_test.dart`

#### Aktueller Zustand

```dart
// lib/core/models/settings.dart
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
```

```dart
// test/core/models/settings_test.dart (EquipmentX group)
test('label returns correct German string', () {
  expect(Equipment.kb16.label, 'KB 16kg');
  expect(Equipment.kb20.label, 'KB 20kg');
  expect(Equipment.kb24.label, 'KB 24kg');
  expect(Equipment.sm8.label, 'SM 8kg');
  expect(Equipment.sm12.label, 'SM 12kg');
});

test('label returns correct string for PB variants', () {
  expect(Equipment.pb0.label,   'Pezziball');
  expect(Equipment.pb2_5.label, 'PB 2,5kg');
  expect(Equipment.pb5.label,   'PB 5kg');
  expect(Equipment.pb7_5.label, 'PB 7,5kg');
  expect(Equipment.pb10.label,  'PB 10kg');
});
```

- [ ] **Step 1: Tests auf neue Werte umstellen (werden danach fehlschlagen)**

In `test/core/models/settings_test.dart` den Test `'label returns correct German string'` ersetzen durch:

```dart
    test('label returns correct string for KB and SM variants', () {
      expect(Equipment.kb16.label, 'Kettlebell 16kg');
      expect(Equipment.kb20.label, 'Kettlebell 20kg');
      expect(Equipment.kb24.label, 'Kettlebell 24kg');
      expect(Equipment.sm8.label,  'Steel Mace 8kg');
      expect(Equipment.sm12.label, 'Steel Mace 12kg');
    });
```

Und den Test `'label returns correct string for PB variants'` ersetzen durch:

```dart
    test('label returns correct string for PB variants', () {
      expect(Equipment.pb0.label,   'Pezziball');
      expect(Equipment.pb2_5.label, 'Pezziball + 2,5kg');
      expect(Equipment.pb5.label,   'Pezziball + 5kg');
      expect(Equipment.pb7_5.label, 'Pezziball + 7,5kg');
      expect(Equipment.pb10.label,  'Pezziball + 10kg');
    });
```

- [ ] **Step 2: Tests laufen lassen (sollen fehlschlagen)**

```powershell
flutter test test/core/models/settings_test.dart
```

Erwartet: Failures bei den geänderten Label-Tests.

- [ ] **Step 3: `EquipmentX.label` in settings.dart anpassen**

Den `label`-Getter in `lib/core/models/settings.dart` ersetzen durch:

```dart
  String get label {
    switch (this) {
      case Equipment.kb16:  return 'Kettlebell 16kg';
      case Equipment.kb20:  return 'Kettlebell 20kg';
      case Equipment.kb24:  return 'Kettlebell 24kg';
      case Equipment.sm8:   return 'Steel Mace 8kg';
      case Equipment.sm12:  return 'Steel Mace 12kg';
      case Equipment.pb0:   return 'Pezziball';
      case Equipment.pb2_5: return 'Pezziball + 2,5kg';
      case Equipment.pb5:   return 'Pezziball + 5kg';
      case Equipment.pb7_5: return 'Pezziball + 7,5kg';
      case Equipment.pb10:  return 'Pezziball + 10kg';
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
git commit -m "fix: spell out equipment labels (Kettlebell, Steel Mace, Pezziball + Xkg)"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|-------------|------|
| KB → "Kettlebell Xkg" | Task 1 |
| SM → "Steel Mace Xkg" | Task 1 |
| PB ohne Gewicht → "Pezziball" | Task 1 |
| PB mit Gewicht → "Pezziball + Xkg" | Task 1 |
| Tests angepasst | Task 1 |

**Placeholder-Scan:** Keine. Alle Label-Strings vollständig angegeben.

**Type-Konsistenz:** Nur String-Werte geändert, kein Typ-Mismatch möglich.
