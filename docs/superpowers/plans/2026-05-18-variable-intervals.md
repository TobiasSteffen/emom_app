# Variable Intervalllänge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pläne können 5–30 Intervalle haben; Zeilen per Rechts-Wischen löschen, neue per "+" hinzufügen.

**Architecture:** `TrainingPlan.assert` entfernt, Konstanten `minIntervals/maxIntervals` hinzugefügt. `PlanMinuteExactEditor` bekommt `onDelete` + `Dismissible` pro Zeile. `PlanEditorScreen` bekommt `_onDelete`, `_onAdd` und einen konditionalen "+" Button.

**Tech Stack:** Flutter, Dart, Riverpod, flutter_test

---

### Task 1: TrainingPlan model — assert entfernen, Konstanten hinzufügen (TDD)

**Files:**
- Create: `test/core/models/training_plan_test.dart`
- Modify: `lib/core/models/training_plan.dart`

- [ ] **Step 1: Failing tests schreiben**

```dart
// test/core/models/training_plan_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

IntervalConfig _iv() => IntervalConfig(
      reps: 5,
      durationSeconds: 60,
      equipment: Equipment.kb24,
      exercise: Exercise.swingBeidarmig,
    );

void main() {
  group('TrainingPlan', () {
    test('minIntervals is 5', () {
      expect(TrainingPlan.minIntervals, 5);
    });

    test('maxIntervals is 30', () {
      expect(TrainingPlan.maxIntervals, 30);
    });

    test('can create plan with 5 intervals', () {
      final intervals = List.generate(5, (_) => _iv());
      expect(
        () => TrainingPlan(id: 'x', name: 'test', intervals: intervals),
        returnsNormally,
      );
    });

    test('can create plan with 15 intervals', () {
      final intervals = List.generate(15, (_) => _iv());
      expect(
        () => TrainingPlan(id: 'x', name: 'test', intervals: intervals),
        returnsNormally,
      );
    });

    test('totalReps sums variable-length intervals', () {
      final intervals = List.generate(10, (_) => _iv());
      final plan = TrainingPlan(id: 'x', name: 'test', intervals: intervals);
      expect(plan.totalReps, 50);
    });
  });
}
```

- [ ] **Step 2: Tests ausführen — müssen FEHLSCHLAGEN**

```
flutter test test/core/models/training_plan_test.dart
```

Erwartetes Ergebnis: FAIL (minIntervals/maxIntervals nicht definiert, assert schlägt bei 5 Intervallen an).

- [ ] **Step 3: `training_plan.dart` anpassen**

In `lib/core/models/training_plan.dart`:

Suche die Klasse `TrainingPlan` und ersetze den Konstruktor-Block:

```dart
class TrainingPlan {
  final String id;
  String name;
  List<IntervalConfig> intervals;

  static const int minIntervals = 5;
  static const int maxIntervals = 30;

  TrainingPlan({
    required this.id,
    required this.name,
    required this.intervals,
  });
```

*(Entferne `: assert(intervals.length == 30)` am Ende des Konstruktors)*

- [ ] **Step 4: Tests ausführen — müssen BESTEHEN**

```
flutter test test/core/models/training_plan_test.dart
```

Erwartetes Ergebnis: 5/5 PASS.

- [ ] **Step 5: Alle Tests ausführen**

```
flutter test
```

Erwartetes Ergebnis: Alle Tests PASS.

- [ ] **Step 6: Commit**

```
git add lib/core/models/training_plan.dart test/core/models/training_plan_test.dart
git commit -m "feat: remove 30-interval assert, add minIntervals/maxIntervals constants"
```

---

### Task 2: PlanMinuteExactEditor — onDelete + Dismissible

**Files:**
- Modify: `lib/features/plans/widgets/minute_exact_editor.dart`

- [ ] **Step 1: Datei lesen** (erforderlich vor dem Schreiben)

Lese `lib/features/plans/widgets/minute_exact_editor.dart`.

- [ ] **Step 2: Datei vollständig ersetzen**

```dart
import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import 'minute_row.dart';

class PlanMinuteExactEditor extends StatelessWidget {
  final TrainingPlan plan;
  final int? selectedRow;
  final ValueChanged<int?> onRowSelected;
  final VoidCallback onChanged;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onDelete;

  const PlanMinuteExactEditor({
    super.key,
    required this.plan,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
    required this.onReorder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => Material(
        elevation: 4,
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
      itemCount: plan.intervals.length,
      itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(i),
        index: i,
        child: Dismissible(
          key: ValueKey('dismiss_$i'),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (_) async =>
              plan.intervals.length > TrainingPlan.minIntervals,
          onDismissed: (_) => onDelete(i),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          ),
          child: PlanMinuteRow(
            index: i,
            plan: plan,
            isSelected: selectedRow == i,
            onSelect: () => onRowSelected(selectedRow == i ? null : i),
            onChanged: onChanged,
          ),
        ),
      ),
      onReorder: onReorder,
    );
  }
}
```

- [ ] **Step 3: flutter analyze**

```
flutter analyze lib/features/plans/widgets/minute_exact_editor.dart
```

Erwartetes Ergebnis: Keine Fehler in dieser Datei (Fehler in `plan_editor_screen.dart` wegen fehlendem `onDelete`-Argument sind OK — werden in Task 3 behoben).

---

### Task 3: PlanEditorScreen — _onDelete, _onAdd, "+" Button

**Files:**
- Modify: `lib/features/plans/plan_editor_screen.dart`

- [ ] **Step 1: Datei lesen**

Lese `lib/features/plans/plan_editor_screen.dart`.

- [ ] **Step 2: `_onDelete` Methode nach `_onReorder` einfügen**

Füge direkt nach der `_onReorder`-Methode ein:

```dart
void _onDelete(int index) {
  if (_plan.intervals.length <= TrainingPlan.minIntervals) return;
  setState(() {
    _plan.intervals.removeAt(index);
    if (_selectedRow != null) {
      if (_selectedRow == index) {
        _selectedRow = null;
      } else if (_selectedRow! > index) {
        _selectedRow = _selectedRow! - 1;
      }
    }
  });
}

void _onAdd() {
  if (_plan.intervals.length >= TrainingPlan.maxIntervals) return;
  setState(() {
    _plan.intervals.add(_plan.intervals.last.copyWith());
  });
}
```

- [ ] **Step 3: `onDelete: _onDelete` an `PlanMinuteExactEditor` übergeben**

Im `build`-Bereich, den `PlanMinuteExactEditor`-Aufruf erweitern:

```dart
PlanMinuteExactEditor(
  plan: _plan,
  selectedRow: _selectedRow,
  onRowSelected: (i) => setState(() => _selectedRow = i),
  onChanged: () => setState(() {}),
  onReorder: _onReorder,
  onDelete: _onDelete,
),
```

- [ ] **Step 4: "+" Button und Import hinzufügen**

Im `Column`-Body zwischen `Expanded` und dem `Padding`-Block mit der GESAMT-Box einfügen:

```dart
if (_plan.intervals.length < TrainingPlan.maxIntervals)
  Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    child: GestureDetector(
      onTap: _onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Color(0xFFFF6B00), size: 16),
            SizedBox(width: 6),
            Text('Intervall hinzufügen',
                style: TextStyle(
                    color: Color(0xFFFF6B00),
                    fontSize: 13,
                    letterSpacing: 1)),
          ],
        ),
      ),
    ),
  ),
```

Stelle sicher dass `TrainingPlan` importiert ist (sollte bereits via `training_plan.dart` sein).

- [ ] **Step 5: flutter analyze**

```
flutter analyze
```

Erwartetes Ergebnis: Keine Fehler.

- [ ] **Step 6: Alle Tests ausführen**

```
flutter test
```

Erwartetes Ergebnis: Alle Tests PASS.

- [ ] **Step 7: Commit**

```
git add lib/features/plans/widgets/minute_exact_editor.dart lib/features/plans/plan_editor_screen.dart
git commit -m "feat: swipe-to-delete intervals and add-interval button in plan editor"
```
