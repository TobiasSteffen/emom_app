# Close-Button im Plan-Editor-Formular — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tipp auf den Hintergrund der aufgeklappten Zeile schließt das Formular nicht mehr; stattdessen gibt es rechts unten einen Chevron-Up-Button zum expliziten Schließen.

**Architecture:** Zwei kleine Änderungen in `minute_row.dart`. Erstens: `_expandedForm` wird in einen `GestureDetector` mit leerem `onTap` gewrappt, der Tap-Events absorbiert und so die Propagation zum äußeren `onSelect`-GestureDetector verhindert. Zweitens: Am Ende von `_expandedForm` wird ein `Align`-Widget mit `Icons.expand_less` eingefügt, der `widget.onSelect` aufruft und das Formular damit explizit schließt.

**Tech Stack:** Flutter/Dart, keine neuen Abhängigkeiten

---

## File Map

| File | Change |
|------|--------|
| `lib/features/plans/widgets/minute_row.dart` | Tap-Absorption auf `_expandedForm`, Close-Button am Ende des Formulars |

---

### Task 1: Tap-Absorption + Close-Button in minute_row.dart

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`

#### Aktueller Zustand (relevante Stellen)

**`build()`-Methode, Ende:**
```dart
          if (widget.isSelected) _expandedForm(iv),
        ],
      ),
    );
  }
```

**`_expandedForm()`, Ende (nach dem Sekunden-`_formRow`):**
```dart
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Sekunden',
            _stepper(
              display: '${iv.durationSeconds}',
              onDec: iv.durationSeconds > 30
                  ? () => _update(() => iv.durationSeconds =
                      (iv.durationSeconds - 5).clamp(30, 9999))
                  : null,
              onInc: () => _update(() => iv.durationSeconds += 5),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 1: Tap-Absorption in `build()` einbauen**

In `lib/features/plans/widgets/minute_row.dart` die Zeile

```dart
          if (widget.isSelected) _expandedForm(iv),
```

ersetzen durch:

```dart
          if (widget.isSelected)
            GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: _expandedForm(iv),
            ),
```

- [ ] **Step 2: Close-Button am Ende von `_expandedForm` einfügen**

Das Ende von `_expandedForm` (nach dem letzten `_formRow` für 'Sekunden'):

```dart
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Sekunden',
            _stepper(
              display: '${iv.durationSeconds}',
              onDec: iv.durationSeconds > 30
                  ? () => _update(() => iv.durationSeconds =
                      (iv.durationSeconds - 5).clamp(30, 9999))
                  : null,
              onInc: () => _update(() => iv.durationSeconds += 5),
            ),
          ),
        ],
      ),
    );
  }
```

ersetzen durch:

```dart
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Sekunden',
            _stepper(
              display: '${iv.durationSeconds}',
              onDec: iv.durationSeconds > 30
                  ? () => _update(() => iv.durationSeconds =
                      (iv.durationSeconds - 5).clamp(30, 9999))
                  : null,
              onInc: () => _update(() => iv.durationSeconds += 5),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: widget.onSelect,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: const Icon(Icons.expand_less, size: 20, color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 3: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/plans/widgets/minute_row.dart
```

Erwartet: `No issues found!`

- [ ] **Step 4: Gesamte Test-Suite**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/plans/widgets/minute_row.dart
git commit -m "fix: absorb background taps in plan editor form; add explicit close button"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|-------------|------|
| Tipp auf Hintergrund schließt Formular nicht mehr | Task 1, Step 1 (GestureDetector-Wrapper mit leerem onTap) |
| Chevron-Up-Button rechts unten schließt explizit | Task 1, Step 2 (Align + GestureDetector mit widget.onSelect) |

**Placeholder-Scan:** Keine. Beide Steps enthalten vollständigen Code.

**Type-Konsistenz:** `widget.onSelect` ist `VoidCallback` — korrekt für den Close-Button-Tap.
