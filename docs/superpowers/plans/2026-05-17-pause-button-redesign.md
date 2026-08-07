# Pause-Button Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den "Übung / Pause"-Umschalter durch einen einzelnen blauen Toggle-Button ersetzen, der rechts oben in der aufgeklappten Plan-Editor-Zeile erscheint.

**Architecture:** Reine UI-Änderung in `minute_row.dart`. Der zweichipige Row am Anfang von `_expandedForm` wird entfernt; stattdessen steht ein einzelner `Align(centerRight)`-Button ganz oben in der Form — blauer Hintergrund wenn aktiv, gedimmter dunkler Hintergrund wenn inaktiv. Die Toggle-Logik (isPause=true/false, openPicker=null, side=null) bleibt identisch. Kein Modell-Change, keine neuen Tests.

**Tech Stack:** Flutter/Dart, keine neuen Abhängigkeiten

---

## File Map

| File | Change |
|------|--------|
| `lib/features/plans/widgets/minute_row.dart` | Zwei-Chip-Row durch einzelnen blauen Toggle-Button ersetzen |

---

### Task 1: Pause-Toggle durch einzelnen Button ersetzen

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`

#### Aktueller Zustand (oben in `_expandedForm`, Column-children)

```dart
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Row(
              children: [
                _pickerChip('Übung', !iv.isPause,
                    () => _update(() => iv.isPause = false)),
                _pickerChip('Pause', iv.isPause, () {
                  _update(() {
                    _openPicker = null;
                    iv.isPause = true;
                    iv.side = null;
                  });
                }),
              ],
            ),
          ),
          if (!iv.isPause) ...[
```

- [ ] **Step 1: Zwei-Chip-Row ersetzen durch einzelnen Pause-Button**

Den gesamten `Padding(...)` Block (mit dem `Row` der zwei `_pickerChip`-Aufrufe) ersetzen durch:

```dart
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                if (iv.isPause) {
                  _update(() => iv.isPause = false);
                } else {
                  _update(() {
                    _openPicker = null;
                    iv.isPause = true;
                    iv.side = null;
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: iv.isPause
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(6),
                  border: iv.isPause
                      ? null
                      : Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Pause',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        iv.isPause ? FontWeight.bold : FontWeight.normal,
                    color: iv.isPause ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
          ),
          if (!iv.isPause) ...[
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
git commit -m "fix: replace dual-chip pause toggle with single blue toggle button (top-right)"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|---|---|
| Nur ein Pause-Button (kein "Übung"-Chip mehr) | Task 1 |
| Rechts oben in der aufgeklappten Zeile | Task 1 (`Align(centerRight)`) |
| Aktiv → blau (`0xFF1565C0`) | Task 1 |
| Inaktiv → gedimmt, dunkler Hintergrund | Task 1 (`0xFF222222`, `Colors.white12` Border) |
| Nochmal antippen deaktiviert Pause | Task 1 (`if (iv.isPause) ... else ...`) |
| Beim Aktivieren: openPicker schließen, side=null | Task 1 |

**Placeholder-Scan:** Keine. Vollständiger Code vorhanden.

**Type-Konsistenz:** `_update` ist `void Function(VoidCallback)` — korrekt verwendet.
