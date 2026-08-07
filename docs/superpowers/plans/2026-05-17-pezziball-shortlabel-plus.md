# Pezziball shortLabel mit +-Zeichen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `shortLabel` der gewichteten Pezziball-Varianten um ein "+" ergänzen, damit die Chips im Equipment-Picker "ohne", "+2,5 kg", "+5 kg", "+7,5 kg", "+10 kg" anzeigen.

**Architecture:** Reine Datenwert-Änderung in `EquipmentX.shortLabel` in `lib/core/models/settings.dart`. Tests in `test/core/models/settings_test.dart` werden zuerst auf die neuen Strings umgestellt (Red), dann die Implementierung angepasst (Green). pb0 bleibt 'ohne'.

**Tech Stack:** Flutter/Dart, keine neuen Abhängigkeiten

---

## File Map

| File | Change |
|------|--------|
| `lib/core/models/settings.dart` | `EquipmentX.shortLabel` — pb2_5/pb5/pb7_5/pb10 mit "+"-Präfix |
| `test/core/models/settings_test.dart` | Test-Expectations für PB-shortLabel anpassen |

---

### Task 1: Pezziball shortLabel mit +-Präfix

**Files:**
- Modify: `lib/core/models/settings.dart`
- Modify: `test/core/models/settings_test.dart`

#### Aktueller Zustand

```dart
// lib/core/models/settings.dart
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
```

```dart
// test/core/models/settings_test.dart
test('shortLabel returns weight-only for PB variants', () {
  expect(Equipment.pb0.shortLabel,   'ohne');
  expect(Equipment.pb2_5.shortLabel, '2,5 kg');
  expect(Equipment.pb5.shortLabel,   '5 kg');
  expect(Equipment.pb7_5.shortLabel, '7,5 kg');
  expect(Equipment.pb10.shortLabel,  '10 kg');
});
```

- [ ] **Step 1: Test auf neue Werte umstellen (wird danach fehlschlagen)**

In `test/core/models/settings_test.dart` den Test `'shortLabel returns weight-only for PB variants'` ersetzen durch:

```dart
    test('shortLabel returns + prefix for weighted PB variants', () {
      expect(Equipment.pb0.shortLabel,   'ohne');
      expect(Equipment.pb2_5.shortLabel, '+2,5 kg');
      expect(Equipment.pb5.shortLabel,   '+5 kg');
      expect(Equipment.pb7_5.shortLabel, '+7,5 kg');
      expect(Equipment.pb10.shortLabel,  '+10 kg');
    });
```

- [ ] **Step 2: Tests laufen lassen (sollen fehlschlagen)**

```powershell
flutter test test/core/models/settings_test.dart
```

Erwartet: 1 Test schlägt fehl (PB shortLabel-Werte stimmen noch nicht).

- [ ] **Step 3: `EquipmentX.shortLabel` in settings.dart anpassen**

Den `shortLabel`-Getter ersetzen durch:

```dart
  String get shortLabel {
    switch (this) {
      case Equipment.kb16:  return '16 kg';
      case Equipment.kb20:  return '20 kg';
      case Equipment.kb24:  return '24 kg';
      case Equipment.sm8:   return '8 kg';
      case Equipment.sm12:  return '12 kg';
      case Equipment.pb0:   return 'ohne';
      case Equipment.pb2_5: return '+2,5 kg';
      case Equipment.pb5:   return '+5 kg';
      case Equipment.pb7_5: return '+7,5 kg';
      case Equipment.pb10:  return '+10 kg';
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
git commit -m "fix: add + prefix to weighted Pezziball shortLabels in picker chips"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|-------------|------|
| pb0.shortLabel bleibt 'ohne' | Task 1 |
| pb2_5.shortLabel → '+2,5 kg' | Task 1 |
| pb5.shortLabel → '+5 kg' | Task 1 |
| pb7_5.shortLabel → '+7,5 kg' | Task 1 |
| pb10.shortLabel → '+10 kg' | Task 1 |
| Tests angepasst | Task 1 |

**Placeholder-Scan:** Keine. Alle String-Werte vollständig angegeben.

**Type-Konsistenz:** Nur String-Werte geändert, kein Typ-Mismatch möglich.
