# Pause-Toggle Animation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das abrupte Ein-/Ausblenden des Gerät/Übung/Reps-Abschnitts beim Pause-Toggle in der Plan-Editor-Zeile durch eine sanfte Animation ersetzen (Fade + Höhenübergang gleichzeitig).

**Architecture:** `AnimatedCrossFade` ersetzt das `if (!iv.isPause) ...[...]` im `_expandedForm`-Column. Das Widget animiert simultan zwischen dem vollen Formular-Inhalt (`firstChild`) und einer leeren `SizedBox` (`secondChild`) — Fade und Höhe werden gleichzeitig animiert. Keine neuen Dependencies, kein Modell-Change, kein State-Umbau.

**Tech Stack:** Flutter/Dart, `AnimatedCrossFade` (built-in), keine neuen Abhängigkeiten

---

## File Map

| File | Change |
|------|--------|
| `lib/features/plans/widgets/minute_row.dart` | `if (!iv.isPause)` Block durch `AnimatedCrossFade` ersetzen |

---

### Task 1: AnimatedCrossFade für Pause-Toggle

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`

#### Aktueller Zustand (in `_expandedForm`, Column-children)

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

- [ ] **Step 1: `if (!iv.isPause)` Block durch `AnimatedCrossFade` ersetzen**

Den kompletten `if (!iv.isPause) ...[...]` Block ersetzen durch:

```dart
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
            crossFadeState: iv.isPause
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
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
git commit -m "feat: animate pause toggle with AnimatedCrossFade (fade + height transition)"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|---|---|
| Sanfter Übergang statt abruptem Ein-/Ausblenden | Task 1 (`AnimatedCrossFade`, 220 ms) |
| Fade und Höhenübergang gleichzeitig | Task 1 (`AnimatedCrossFade` macht beides nativ) |
| Keine neuen Dependencies | ✅ `AnimatedCrossFade` ist built-in |
| Kein Modell-Change | ✅ |

**Placeholder-Scan:** Keine. Vollständiger Code vorhanden.

**Hinweis zu `AnimatedCrossFade`:** Das Widget rendert beide Kinder (`firstChild` und `secondChild`) gleichzeitig im Widget-Tree, blendet aber nur eines ein. Das `firstChild` (der volle Formular-Inhalt) bleibt also immer im Tree und reagiert korrekt auf State-Änderungen (z.B. wenn `_openPicker` wechselt während pause aktiv ist). Das ist kein Bug, sondern das erwartete Verhalten.
