# Trainingshistorie – Editierbarkeit: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Abgeschlossene Workout-Einträge in der Trainingshistorie vollständig editierbar machen (Gerät, Übung, Seite, Wiederholungen, Dauer, Pause) — identisch mit dem Plan-Editor.

**Architecture:** `IntervalRecord` bekommt `side` + `isPause` Felder (backward-compatible JSON). Das Edit-Form aus `PlanMinuteRow._expandedForm` wird als eigenständiges `IntervalEditForm`-Widget extrahiert und in `HistoryDetailSheet` (jetzt `ConsumerStatefulWidget`) wiederverwendet. `HistoryNotifier` bekommt `updateRecord()`.

**Tech Stack:** Flutter, Riverpod 3.x (`riverpod_annotation`), `shared_preferences`, `dart:async`

---

## File Structure

| Datei | Änderung |
|---|---|
| `lib/core/models/workout_history.dart` | `IntervalRecord` + `side`, `isPause` |
| `test/core/models/workout_history_test.dart` | Tests für neue Felder (Serialisierung, Rückwärtskompatibilität) |
| `lib/features/workout/workout_notifier.dart` | `_onMinuteComplete` schreibt `side` + `isPause` |
| `lib/features/shared/widgets/interval_edit_form.dart` | **Neu** — extrahiertes `IntervalEditForm`-Widget |
| `lib/features/plans/widgets/minute_row.dart` | `_expandedForm` + alle Hilfs-Methoden → delegiert an `IntervalEditForm` |
| `lib/features/history/history_notifier.dart` | `updateRecord()` hinzugefügt |
| `lib/features/history/history_detail_sheet.dart` | `ConsumerStatefulWidget` mit Inline-Editing + Speichern-Button |

---

## Task 1: IntervalRecord Modell erweitern

**Files:**
- Modify: `lib/core/models/workout_history.dart`
- Test: `test/core/models/workout_history_test.dart`

- [ ] **Step 1: Failing tests schreiben**

Folgende drei Tests am Ende der `group('WorkoutHistory', ...)` Gruppe in `test/core/models/workout_history_test.dart` ergänzen:

```dart
test('IntervalRecord: side und isPause werden serialisiert und wiederhergestellt', () {
  final original = IntervalRecord(
    reps: 10,
    durationSeconds: 60,
    equipment: Equipment.kb24,
    exercise: Exercise.snatch,
    side: ExerciseSide.links,
    isPause: false,
  );
  final restored = IntervalRecord.fromJson(original.toJson());
  expect(restored.side, ExerciseSide.links);
  expect(restored.isPause, false);
  expect(restored.reps, 10);
  expect(restored.exercise, Exercise.snatch);
});

test('IntervalRecord: isPause=true wird korrekt serialisiert', () {
  final original = IntervalRecord(
    reps: 0,
    durationSeconds: 60,
    equipment: Equipment.kb24,
    exercise: Exercise.swingBeidarmig,
    isPause: true,
  );
  final restored = IntervalRecord.fromJson(original.toJson());
  expect(restored.isPause, true);
  expect(restored.side, isNull);
});

test('IntervalRecord: fromJson ohne side/isPause ergibt Standardwerte (Rückwärtskompatibilität)', () {
  final json = {'r': 10, 'd': 60, 'e': 2, 'x': 0}; // altes Format ohne 's' oder 'p'
  final iv = IntervalRecord.fromJson(json);
  expect(iv.side, isNull);
  expect(iv.isPause, false);
});
```

- [ ] **Step 2: Tests scheitern lassen**

```
flutter test test/core/models/workout_history_test.dart
```

Erwartet: FAIL (Constructor kennt `side`/`isPause` noch nicht)

- [ ] **Step 3: IntervalRecord erweitern**

`lib/core/models/workout_history.dart` vollständig ersetzen:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';

class IntervalRecord {
  final int reps;
  final int durationSeconds;
  final Equipment equipment;
  final Exercise exercise;
  final ExerciseSide? side;
  final bool isPause;

  IntervalRecord({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
    this.exercise = Exercise.swingBeidarmig,
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
    if (isPause) m['p'] = true;
    return m;
  }

  factory IntervalRecord.fromJson(Map<String, dynamic> j) {
    final sideIndex = j['s'] as int?;
    return IntervalRecord(
      reps: j['r'] as int,
      durationSeconds: j['d'] as int,
      equipment: Equipment.values.elementAtOrNull(j['e'] as int) ?? Equipment.kb24,
      exercise: Exercise.values.elementAtOrNull((j['x'] as int?) ?? 0) ?? Exercise.swingBeidarmig,
      side: sideIndex != null ? ExerciseSide.values.elementAtOrNull(sideIndex) : null,
      isPause: (j['p'] as bool?) ?? false,
    );
  }
}

class WorkoutRecord {
  final int timestamp; // milliseconds since epoch
  final int planMode; // 0 = phaseBased, 1 = minuteExact
  final List<IntervalRecord> intervals;

  WorkoutRecord({
    required this.timestamp,
    required this.planMode,
    required this.intervals,
  });

  int get totalReps => intervals.fold(0, (a, b) => a + b.reps);
  int get totalDurationSeconds => intervals.fold(0, (a, b) => a + b.durationSeconds);
  int get kettlebellReps => intervals.where((i) => i.equipment.isKettlebell).fold(0, (a, b) => a + b.reps);
  int get steelMaceReps  => intervals.where((i) => i.equipment.isSteelMace).fold(0, (a, b) => a + b.reps);

  Map<String, dynamic> toJson() => {
        't': timestamp,
        'pm': planMode,
        'iv': intervals.map((i) => i.toJson()).toList(),
      };

  factory WorkoutRecord.fromJson(Map<String, dynamic> j) => WorkoutRecord(
        timestamp: j['t'] as int,
        planMode: j['pm'] as int,
        intervals: (j['iv'] as List)
            .map((e) => IntervalRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WorkoutHistory {
  static const _key = 'workoutHistory';
  static const _maxEntries = 300;

  static Future<List<WorkoutRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => WorkoutRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addOrUpdateRecord(WorkoutRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await load();
    final idx = records.indexWhere((r) => r.timestamp == record.timestamp);
    if (idx >= 0) {
      records[idx] = record;
    } else {
      records.insert(0, record);
      if (records.length > _maxEntries) records.removeLast();
    }
    await prefs.setString(
      _key,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }
}
```

- [ ] **Step 4: Tests grün laufen**

```
flutter test test/core/models/workout_history_test.dart
```

Erwartet: Alle Tests PASS (inkl. bestehende — `side`/`isPause` haben Standardwerte)

- [ ] **Step 5: Commit**

```
git add lib/core/models/workout_history.dart test/core/models/workout_history_test.dart
git commit -m "feat: extend IntervalRecord with side and isPause fields"
```

---

## Task 2: workout_notifier – side + isPause aufzeichnen

**Files:**
- Modify: `lib/features/workout/workout_notifier.dart` (Zeilen 205–217)

- [ ] **Step 1: `_onMinuteComplete` anpassen**

In `lib/features/workout/workout_notifier.dart` die `IntervalRecord`-Konstruktion in `_onMinuteComplete` (ca. Zeile 211) ersetzen:

Alt:
```dart
IntervalRecord(
  reps: s.currentReps,
  durationSeconds: s.currentDuration,
  equipment: equipmentForMinute(s.currentMinute),
  exercise: _activePlan.intervals[s.currentMinute].exercise,
),
```

Neu:
```dart
IntervalRecord(
  reps: s.currentReps,
  durationSeconds: s.currentDuration,
  equipment: equipmentForMinute(s.currentMinute),
  exercise: _activePlan.intervals[s.currentMinute].exercise,
  side: _activePlan.intervals[s.currentMinute].side,
  isPause: _activePlan.intervals[s.currentMinute].isPause,
),
```

- [ ] **Step 2: Analyze + Test**

```
flutter analyze
flutter test
```

Erwartet: 0 Fehler, alle Tests PASS

- [ ] **Step 3: Commit**

```
git add lib/features/workout/workout_notifier.dart
git commit -m "feat: record side and isPause in IntervalRecord on interval complete"
```

---

## Task 3: IntervalEditForm extrahieren (neue Datei)

**Files:**
- Create: `lib/features/shared/widgets/interval_edit_form.dart`

Hinweis: Das Verzeichnis `lib/features/shared/widgets/` muss angelegt werden.

- [ ] **Step 1: Verzeichnis anlegen**

```
mkdir lib/features/shared && mkdir lib/features/shared/widgets
```

(Windows PowerShell: `New-Item -ItemType Directory -Force lib/features/shared/widgets`)

- [ ] **Step 2: `interval_edit_form.dart` erstellen**

Neue Datei `lib/features/shared/widgets/interval_edit_form.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';

Widget _stepButton(IconData icon, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null ? Colors.white38 : Colors.white12),
      ),
    );

class IntervalEditForm extends StatefulWidget {
  final IntervalConfig iv;
  final VoidCallback onChanged;

  /// Zeilenindex im Plan/History — wird für automatische Seitenzuweisung
  /// bei Einarm-Übungen verwendet (gerade = links, ungerade = rechts).
  final int? index;

  /// Optionaler Callback für den Einklappen-Button am unteren Rand.
  final VoidCallback? onCollapse;

  const IntervalEditForm({
    super.key,
    required this.iv,
    required this.onChanged,
    this.index,
    this.onCollapse,
  });

  @override
  State<IntervalEditForm> createState() => _IntervalEditFormState();
}

class _IntervalEditFormState extends State<IntervalEditForm> {
  String? _openPicker;

  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  void _togglePicker(String picker) {
    setState(() {
      _openPicker = _openPicker == picker ? null : picker;
    });
  }

  Widget _pickerChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFF6B00)
                : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(6),
            border: selected ? null : Border.all(color: Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.black : Colors.white54,
            ),
          ),
        ),
      );

  Widget _formSectionHeader(String label, String value, String picker) =>
      GestureDetector(
        onTap: () => _togglePicker(picker),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.white38)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ),
              Icon(
                _openPicker == picker ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.white24,
              ),
            ],
          ),
        ),
      );

  Widget _formRow(String label, Widget content) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ),
            content,
          ],
        ),
      );

  Widget _stepper({
    required String display,
    required VoidCallback onInc,
    VoidCallback? onDec,
  }) =>
      Row(
        children: [
          _stepButton(Icons.remove, onDec),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(display,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
            ),
          ),
          _stepButton(Icons.add, onInc),
        ],
      );

  Widget _equipmentGroup(
    String iconPath,
    List<Equipment> items,
    Equipment current,
    void Function(Equipment) onSelect,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Image.asset(iconPath, width: 14, height: 14,
                  color: Colors.white38),
            ),
            Expanded(
              child: Wrap(
                children: [
                  for (final eq in items)
                    _pickerChip(eq.shortLabel, current == eq, () => onSelect(eq)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final iv = widget.iv;

    void selectEquipment(Equipment eq) => _update(() {
          iv.equipment = eq;
          if (!eq.validExercises.contains(iv.exercise)) {
            iv.exercise = eq.defaultExercise;
          }
          if (iv.exercise.isOneArm && iv.side == null) {
            iv.side = (widget.index ?? 0) % 2 == 0
                ? ExerciseSide.links
                : ExerciseSide.rechts;
          }
          if (!iv.exercise.isOneArm) iv.side = null;
        });

    void selectExercise(Exercise ex) => _update(() {
          iv.exercise = ex;
          if (ex.isOneArm && iv.side == null) {
            iv.side = (widget.index ?? 0) % 2 == 0
                ? ExerciseSide.links
                : ExerciseSide.rechts;
          }
          if (!ex.isOneArm) iv.side = null;
        });

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pause-Toggle
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          // Gerät / Übung / Seite / Wiederholungen (ausgeblendet wenn Pause)
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
                if (_openPicker == 'equipment')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _equipmentGroup(
                          'assets/icon/kettlebell.png',
                          Equipment.values
                              .where((e) => e.isKettlebell)
                              .toList(),
                          iv.equipment,
                          selectEquipment,
                        ),
                        _equipmentGroup(
                          'assets/icon/steelmace.png',
                          Equipment.values
                              .where((e) => e.isSteelMace)
                              .toList(),
                          iv.equipment,
                          selectEquipment,
                        ),
                        _equipmentGroup(
                          'assets/icon/pezziball.png',
                          Equipment.values
                              .where((e) => e.isPezziball)
                              .toList(),
                          iv.equipment,
                          selectEquipment,
                        ),
                      ],
                    ),
                  ),
                const Divider(color: Colors.white12, height: 1),
                _formSectionHeader(
                    'Übung', iv.exercise.label, 'exercise'),
                if (_openPicker == 'exercise')
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
                if (iv.exercise.isOneArm) ...[
                  const Divider(color: Colors.white12, height: 1),
                  _formRow(
                    'Seite',
                    Row(
                      children: [
                        _pickerChip(
                            'Links',
                            iv.side == ExerciseSide.links,
                            () => _update(
                                () => iv.side = ExerciseSide.links)),
                        const SizedBox(width: 6),
                        _pickerChip(
                            'Rechts',
                            iv.side == ExerciseSide.rechts,
                            () => _update(
                                () => iv.side = ExerciseSide.rechts)),
                      ],
                    ),
                  ),
                ],
                const Divider(color: Colors.white12, height: 1),
                _formRow(
                  'Wiederholungen',
                  _stepper(
                    display: '${iv.reps}',
                    onDec: iv.reps > 1
                        ? () => _update(() => iv.reps--)
                        : null,
                    onInc: () => _update(() => iv.reps++),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
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
          if (widget.onCollapse != null)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onCollapse,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child:
                      Icon(Icons.expand_less, size: 20, color: Colors.white24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze**

```
flutter analyze lib/features/shared/widgets/interval_edit_form.dart
```

Erwartet: 0 Fehler

- [ ] **Step 4: Commit**

```
git add lib/features/shared/widgets/interval_edit_form.dart
git commit -m "feat: extract IntervalEditForm as shared widget"
```

---

## Task 4: minute_row.dart auf IntervalEditForm umstellen

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`

- [ ] **Step 1: `minute_row.dart` ersetzen**

`lib/features/plans/widgets/minute_row.dart` vollständig ersetzen:

```dart
import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';
import '../../shared/widgets/interval_edit_form.dart';

class PlanMinuteRow extends StatefulWidget {
  final int index;
  final TrainingPlan plan;
  final VoidCallback onChanged;
  final bool isSelected;
  final VoidCallback onSelect;

  const PlanMinuteRow({
    super.key,
    required this.index,
    required this.plan,
    required this.onChanged,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<PlanMinuteRow> createState() => _PlanMinuteRowState();
}

class _PlanMinuteRowState extends State<PlanMinuteRow> {
  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final iv = widget.plan.intervals[widget.index];
    final i = widget.index;
    final color = iv.isPause ? Colors.white24 : phaseColorForMinute(i);

    return GestureDetector(
      onTap: widget.onSelect,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    'Min ${i + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        color: widget.isSelected
                            ? Colors.white70
                            : Colors.white38,
                        letterSpacing: 1),
                  ),
                ),
                const Spacer(),
                if (iv.isPause) ...[
                  const Text('PAUSE',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                          letterSpacing: 1)),
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
                  Text(
                    iv.side != null
                        ? '${iv.exercise.label} ${iv.side!.shortLabel}'
                        : iv.exercise.label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38)),
                  const SizedBox(width: 6),
                  Text('${iv.reps}W',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white38)),
                  const SizedBox(width: 6),
                  Text('${iv.durationSeconds}s',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white38)),
                ],
              ],
            ),
          ),
          if (widget.isSelected)
            GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: IntervalEditForm(
                iv: iv,
                onChanged: () => _update(() {}),
                index: widget.index,
                onCollapse: widget.onSelect,
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Alle Tests + Analyze**

```
flutter analyze
flutter test
```

Erwartet: 0 Fehler, alle Tests PASS (Plan-Editor-Verhalten unverändert)

- [ ] **Step 3: Commit**

```
git add lib/features/plans/widgets/minute_row.dart
git commit -m "refactor: delegate PlanMinuteRow expanded form to IntervalEditForm"
```

---

## Task 5: HistoryNotifier – updateRecord hinzufügen

**Files:**
- Modify: `lib/features/history/history_notifier.dart`

- [ ] **Step 1: `updateRecord` ergänzen**

`lib/features/history/history_notifier.dart` ersetzen:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/models/workout_history.dart';

part 'history_notifier.g.dart';

@riverpod
class HistoryNotifier extends _$HistoryNotifier {
  @override
  Future<List<WorkoutRecord>> build() => WorkoutHistory.load();

  Future<void> addOrUpdate(WorkoutRecord record) async {
    await WorkoutHistory.addOrUpdateRecord(record);
    ref.invalidateSelf();
  }

  Future<void> updateRecord(WorkoutRecord updated) async {
    await WorkoutHistory.addOrUpdateRecord(updated);
    ref.invalidateSelf();
  }
}
```

- [ ] **Step 2: Analyze + Test**

```
flutter analyze
flutter test
```

Erwartet: 0 Fehler, alle Tests PASS

- [ ] **Step 3: Commit**

```
git add lib/features/history/history_notifier.dart
git commit -m "feat: add updateRecord to HistoryNotifier"
```

---

## Task 6: HistoryDetailSheet – Inline-Editing implementieren

**Files:**
- Modify: `lib/features/history/history_detail_sheet.dart`

- [ ] **Step 1: `history_detail_sheet.dart` ersetzen**

`lib/features/history/history_detail_sheet.dart` vollständig ersetzen:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/workout_history.dart';
import '../../core/models/settings.dart';
import '../../core/models/training_plan.dart';
import '../shared/widgets/interval_edit_form.dart';
import 'history_notifier.dart';

IntervalConfig _toConfig(IntervalRecord r) => IntervalConfig(
      equipment: r.equipment,
      exercise: r.exercise,
      reps: r.reps,
      durationSeconds: r.durationSeconds,
      side: r.side,
      isPause: r.isPause,
    );

IntervalRecord _toRecord(IntervalConfig c) => IntervalRecord(
      equipment: c.equipment,
      exercise: c.exercise,
      reps: c.reps,
      durationSeconds: c.durationSeconds,
      side: c.side,
      isPause: c.isPause,
    );

class HistoryDetailSheet extends ConsumerStatefulWidget {
  final WorkoutRecord record;
  const HistoryDetailSheet({super.key, required this.record});

  @override
  ConsumerState<HistoryDetailSheet> createState() =>
      _HistoryDetailSheetState();
}

class _HistoryDetailSheetState extends ConsumerState<HistoryDetailSheet> {
  late List<IntervalConfig> _editIntervals;
  int? _selectedRow;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _editIntervals = widget.record.intervals.map(_toConfig).toList();
  }

  String _formatDateTime(DateTime dt) =>
      DateFormat("EE, d. MMMM yyyy  HH:mm", 'de').format(dt);

  String _repBreakdown() {
    final Map<Equipment, int> byEquipment = {};
    for (final iv in _editIntervals) {
      if (!iv.isPause) {
        byEquipment[iv.equipment] =
            (byEquipment[iv.equipment] ?? 0) + iv.reps;
      }
    }
    final totalReps = byEquipment.values.fold(0, (a, b) => a + b);
    if (byEquipment.length <= 1) return '$totalReps Reps';
    return (byEquipment.entries.toList()
          ..sort((a, b) => a.key.index.compareTo(b.key.index)))
        .map((e) => '${e.value}× ${e.key.label}')
        .join(' / ');
  }

  Future<void> _save() async {
    final updated = WorkoutRecord(
      timestamp: widget.record.timestamp,
      planMode: widget.record.planMode,
      intervals: _editIntervals.map(_toRecord).toList(),
    );
    await ref.read(historyProvider.notifier).updateRecord(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dt =
        DateTime.fromMillisecondsSinceEpoch(widget.record.timestamp);
    final totalSecs =
        _editIntervals.fold(0, (a, b) => a + b.durationSeconds);
    final durStr =
        '${totalSecs ~/ 60}m ${(totalSecs % 60).toString().padLeft(2, '0')}s';
    final repBreakdown = _repBreakdown();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDateTime(dt),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_editIntervals.length}/30 Intervalle',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    Flexible(
                      child: Text(
                        '$repBreakdown  ·  $durStr',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFFF6B00), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(16, 8, 16, _isDirty ? 80 : 32),
              itemCount: _editIntervals.length,
              itemBuilder: (ctx, i) {
                final iv = _editIntervals[i];
                final isSelected = _selectedRow == i;
                final color =
                    iv.isPause ? Colors.white24 : phaseColorForMinute(i);

                return GestureDetector(
                  onTap: () => setState(
                      () => _selectedRow = isSelected ? null : i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 52,
                              child: Text('Min ${i + 1}',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12)),
                            ),
                            if (iv.isPause) ...[
                              const Text('PAUSE',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white38,
                                      letterSpacing: 1)),
                              const Spacer(),
                              Text('${iv.durationSeconds}s',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12)),
                            ] else ...[
                              Image.asset(
                                iv.equipment.iconPath,
                                width: 14,
                                height: 14,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 6),
                              Text(iv.equipment.label,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                iv.side != null
                                    ? '· ${iv.exercise.label} ${iv.side!.shortLabel}'
                                    : '· ${iv.exercise.label}',
                                style: const TextStyle(
                                    color: Colors.white24, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Text('${iv.reps} Reps',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('${iv.durationSeconds}s',
                                  style: const TextStyle(
                                      color: Colors.white24,
                                      fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        sizeCurve: Curves.easeInOut,
                        crossFadeState: isSelected
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: GestureDetector(
                          onTap: () {},
                          behavior: HitTestBehavior.opaque,
                          child: IntervalEditForm(
                            key: ValueKey(i),
                            iv: iv,
                            onChanged: () =>
                                setState(() => _isDirty = true),
                            index: i,
                            onCollapse: () =>
                                setState(() => _selectedRow = null),
                          ),
                        ),
                        secondChild: const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isDirty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Speichern',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```
flutter analyze
```

Erwartet: 0 Fehler

- [ ] **Step 3: Alle Tests**

```
flutter test
```

Erwartet: Alle Tests PASS

- [ ] **Step 4: Commit**

```
git add lib/features/history/history_detail_sheet.dart
git commit -m "feat: history detail sheet with inline interval editing and save button"
```

---

## Erfolgskriterien (Gesamt)

- `flutter analyze` — 0 Fehler
- `flutter test` — alle Tests grün
- Plan-Editor (Intervall aufklappen, Gerät/Übung/Seite/Reps/Sekunden ändern) verhält sich identisch wie vorher
- History-Sheet: Zeile antippen öffnet Edit-Form, Änderungen aktivieren Speichern-Button, Speichern schließt Sheet
- Bestehende History-Einträge (ohne `side`/`isPause`) laden ohne Fehler
- Neue Workout-Einträge enthalten `side` + `isPause` korrekt aufgezeichnet
