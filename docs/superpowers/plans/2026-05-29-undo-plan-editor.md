# Undo-Funktion im Plan-Editor — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Undo-Stack (max. 90 Schritte) im Plan-Editor — Undo-Button erscheint in der AppBar sobald eine Änderung vorliegt, ein Tap stellt den vorherigen Zustand wieder her.

**Architecture:** Separate `UndoManager`-Klasse hält einen Snapshot-Stack aus tiefen Kopien der `intervals`-Liste (`ListQueue`). Strukturelle Mutationen (delete/add/reorder) pushen sofort; Feld-Änderungen nutzen einen `onBeforeChange`-Callback auf `IntervalEditForm` mit First-Push-Debounce (800ms). `undo()` resettet `_selectedRow` um inkonsistente expanded-State zu vermeiden.

**Tech Stack:** Flutter, Dart, `dart:async` Timer, `dart:collection` ListQueue, flutter_test/fakeAsync

---

## Dateiübersicht

| Datei | Aktion |
|---|---|
| `lib/features/plans/undo_manager.dart` | Neu erstellen |
| `test/features/plans/undo_manager_test.dart` | Neu erstellen |
| `lib/features/shared/widgets/interval_edit_form.dart` | Modifizieren — `onBeforeChange` Parameter |
| `lib/features/plans/widgets/minute_row.dart` | Modifizieren — `onBeforeFieldChange` durchreichen |
| `lib/features/plans/widgets/minute_exact_editor.dart` | Modifizieren — `onBeforeFieldChange` durchreichen |
| `lib/features/plans/plan_editor_screen.dart` | Modifizieren — `UndoManager` integrieren, Undo-Button |

---

## Task 1: `UndoManager` + Unit-Tests

**Files:**
- Create: `lib/features/plans/undo_manager.dart`
- Create: `test/features/plans/undo_manager_test.dart`

- [ ] **Schritt 1: Failing Tests schreiben**

Erstelle `test/features/plans/undo_manager_test.dart` mit folgendem Inhalt:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/features/plans/undo_manager.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

IntervalConfig _iv({int reps = 10}) => IntervalConfig(
      reps: reps,
      durationSeconds: 60,
      equipment: Equipment.kb16,
      exercise: Exercise.swingBeidarmig,
    );

void main() {
  group('UndoManager', () {
    test('canUndo is false initially', () {
      final um = UndoManager();
      expect(um.canUndo, isFalse);
    });

    test('canUndo is true after push', () {
      final um = UndoManager();
      um.push([_iv()]);
      expect(um.canUndo, isTrue);
    });

    test('undo returns deep copy — snapshot unaffected by later mutations', () {
      final um = UndoManager();
      final original = [_iv(reps: 5)];
      um.push(original);
      original[0].reps = 99;
      final restored = um.undo();
      expect(restored[0].reps, 5);
    });

    test('undo pops in LIFO order', () {
      final um = UndoManager();
      um.push([_iv(reps: 1)]);
      um.push([_iv(reps: 2)]);
      expect(um.undo()[0].reps, 2);
      expect(um.undo()[0].reps, 1);
    });

    test('canUndo is false after all steps undone', () {
      final um = UndoManager();
      um.push([_iv()]);
      um.undo();
      expect(um.canUndo, isFalse);
    });

    test('oldest entry discarded when maxSteps exceeded', () {
      final um = UndoManager(maxSteps: 3);
      um.push([_iv(reps: 1)]);
      um.push([_iv(reps: 2)]);
      um.push([_iv(reps: 3)]);
      um.push([_iv(reps: 4)]);
      expect(um.undo()[0].reps, 4);
      expect(um.undo()[0].reps, 3);
      expect(um.undo()[0].reps, 2);
      expect(um.canUndo, isFalse);
    });

    test('pushDebounced: first call pushes snapshot immediately', () {
      fakeAsync((async) {
        final um = UndoManager();
        final state = [_iv(reps: 10)];
        um.pushDebounced(state);
        state[0].reps = 20;
        expect(um.canUndo, isTrue);
        expect(um.undo()[0].reps, 10);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });

    test('pushDebounced: second call within 800ms does not push again', () {
      fakeAsync((async) {
        final um = UndoManager();
        um.pushDebounced([_iv(reps: 10)]);
        async.elapse(const Duration(milliseconds: 400));
        um.pushDebounced([_iv(reps: 11)]);
        um.undo();
        expect(um.canUndo, isFalse);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });

    test('pushDebounced: after cooldown, next call pushes again', () {
      fakeAsync((async) {
        final um = UndoManager();
        um.pushDebounced([_iv(reps: 10)]);
        async.elapse(const Duration(milliseconds: 900));
        um.pushDebounced([_iv(reps: 15)]);
        expect(um.undo()[0].reps, 15);
        expect(um.undo()[0].reps, 10);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });

    test('push() cancels active debounce and resets it', () {
      fakeAsync((async) {
        final um = UndoManager();
        um.pushDebounced([_iv(reps: 10)]);
        async.elapse(const Duration(milliseconds: 400));
        um.push([_iv(reps: 11)]);
        um.pushDebounced([_iv(reps: 12)]);
        expect(um.undo()[0].reps, 12);
        expect(um.undo()[0].reps, 11);
        expect(um.undo()[0].reps, 10);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });

    test('undo() resets debounce — next pushDebounced pushes immediately', () {
      fakeAsync((async) {
        final um = UndoManager();
        um.pushDebounced([_iv(reps: 10)]);
        um.undo();
        um.pushDebounced([_iv(reps: 20)]);
        expect(um.canUndo, isTrue);
        expect(um.undo()[0].reps, 20);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });
  });
}
```

- [ ] **Schritt 2: Tests laufen lassen — erwarte FAIL**

```
flutter test test/features/plans/undo_manager_test.dart
```

Erwartet: Fehler `Target of URI doesn't exist: 'package:emom_app/features/plans/undo_manager.dart'`

- [ ] **Schritt 3: `UndoManager` implementieren**

Erstelle `lib/features/plans/undo_manager.dart`:

```dart
import 'dart:async';
import 'dart:collection';
import '../../core/models/training_plan.dart';

class UndoManager {
  UndoManager({this.maxSteps = 90});

  final int maxSteps;
  final _stack = ListQueue<List<IntervalConfig>>();
  Timer? _debounceTimer;
  bool _debounceActive = false;

  bool get canUndo => _stack.isNotEmpty;

  void push(List<IntervalConfig> intervals) {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _debounceActive = false;
    _pushSnapshot(intervals);
  }

  void pushDebounced(List<IntervalConfig> intervals) {
    if (!_debounceActive) {
      _pushSnapshot(intervals);
      _debounceActive = true;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _debounceActive = false;
      _debounceTimer = null;
    });
  }

  List<IntervalConfig> undo() {
    if (_stack.isEmpty) throw StateError('Nothing to undo');
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _debounceActive = false;
    return _stack.removeLast();
  }

  void dispose() {
    _debounceTimer?.cancel();
  }

  void _pushSnapshot(List<IntervalConfig> intervals) {
    if (_stack.length >= maxSteps) {
      _stack.removeFirst();
    }
    _stack.addLast(intervals.map((iv) => iv.copyWith()).toList());
  }
}
```

- [ ] **Schritt 4: Tests laufen lassen — erwarte PASS**

```
flutter test test/features/plans/undo_manager_test.dart
```

Erwartet: All tests passed.

- [ ] **Schritt 5: Commit**

```
git add lib/features/plans/undo_manager.dart test/features/plans/undo_manager_test.dart
git commit -m "feat: add UndoManager with snapshot stack and debounce"
```

---

## Task 2: `onBeforeChange` in `IntervalEditForm`

**Files:**
- Modify: `lib/features/shared/widgets/interval_edit_form.dart`

- [ ] **Schritt 1: Parameter hinzufügen**

In `IntervalEditForm` nach dem bestehenden `onCollapse`-Parameter:

Find:
```dart
  /// Optionaler Callback für den Einklappen-Button am unteren Rand.
  final VoidCallback? onCollapse;

  const IntervalEditForm({
    super.key,
    required this.iv,
    required this.onChanged,
    this.index,
    this.onCollapse,
  });
```

Replace with:
```dart
  /// Optionaler Callback für den Einklappen-Button am unteren Rand.
  final VoidCallback? onCollapse;

  /// Wird aufgerufen direkt BEVOR eine Feldmutation stattfindet.
  /// Ermöglicht dem Parent, einen Snapshot für Undo zu erstellen.
  final VoidCallback? onBeforeChange;

  const IntervalEditForm({
    super.key,
    required this.iv,
    required this.onChanged,
    this.index,
    this.onCollapse,
    this.onBeforeChange,
  });
```

- [ ] **Schritt 2: `_update` anpassen**

Find:
```dart
  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }
```

Replace with:
```dart
  void _update(VoidCallback fn) {
    widget.onBeforeChange?.call();
    setState(fn);
    widget.onChanged();
  }
```

- [ ] **Schritt 3: Analyse**

```
flutter analyze lib/features/shared/widgets/interval_edit_form.dart
```

Erwartet: 0 Fehler, 0 Warnings.

- [ ] **Schritt 4: Commit**

```
git add lib/features/shared/widgets/interval_edit_form.dart
git commit -m "feat: add onBeforeChange callback to IntervalEditForm"
```

---

## Task 3: `onBeforeFieldChange` durch Widget-Baum durchreichen

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`
- Modify: `lib/features/plans/widgets/minute_exact_editor.dart`

- [ ] **Schritt 1: `PlanMinuteRow` — Parameter hinzufügen und weiterleiten**

Find in `minute_row.dart`:
```dart
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
```

Replace with:
```dart
  final VoidCallback onChanged;
  final VoidCallback onBeforeFieldChange;
  final bool isSelected;
  final VoidCallback onSelect;

  const PlanMinuteRow({
    super.key,
    required this.index,
    required this.plan,
    required this.onChanged,
    required this.onBeforeFieldChange,
    required this.isSelected,
    required this.onSelect,
  });
```

Find in `minute_row.dart`:
```dart
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
```

Replace with:
```dart
            GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: IntervalEditForm(
                iv: iv,
                onBeforeChange: widget.onBeforeFieldChange,
                onChanged: () => _update(() {}),
                index: widget.index,
                onCollapse: widget.onSelect,
              ),
            ),
```

- [ ] **Schritt 2: `PlanMinuteExactEditor` — Parameter hinzufügen und weiterleiten**

Find in `minute_exact_editor.dart`:
```dart
  final VoidCallback onChanged;
  final void Function(int oldIndex, int newIndex) onReorder;
```

Replace with:
```dart
  final VoidCallback onChanged;
  final VoidCallback onBeforeFieldChange;
  final void Function(int oldIndex, int newIndex) onReorder;
```

Find in `minute_exact_editor.dart`:
```dart
  const PlanMinuteExactEditor({
    super.key,
    required this.plan,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
    required this.onReorder,
    required this.onDelete,
    this.onConfirmDelete,
  });
```

Replace with:
```dart
  const PlanMinuteExactEditor({
    super.key,
    required this.plan,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
    required this.onBeforeFieldChange,
    required this.onReorder,
    required this.onDelete,
    this.onConfirmDelete,
  });
```

Find in `minute_exact_editor.dart`:
```dart
          child: PlanMinuteRow(
            index: i,
            plan: plan,
            isSelected: selectedRow == i,
            onSelect: () => onRowSelected(selectedRow == i ? null : i),
            onChanged: onChanged,
          ),
```

Replace with:
```dart
          child: PlanMinuteRow(
            index: i,
            plan: plan,
            isSelected: selectedRow == i,
            onSelect: () => onRowSelected(selectedRow == i ? null : i),
            onChanged: onChanged,
            onBeforeFieldChange: onBeforeFieldChange,
          ),
```

- [ ] **Schritt 3: Analyse**

```
flutter analyze lib/features/plans/widgets/
```

Erwartet: 0 Fehler. (Der Compiler wird `plan_editor_screen.dart` als Fehler anzeigen da `onBeforeFieldChange` noch fehlt — das ist erwartet und wird in Task 4 behoben.)

- [ ] **Schritt 4: Commit**

```
git add lib/features/plans/widgets/minute_row.dart lib/features/plans/widgets/minute_exact_editor.dart
git commit -m "feat: thread onBeforeFieldChange through PlanMinuteRow and PlanMinuteExactEditor"
```

---

## Task 4: `UndoManager` in `_PlanEditorScreenState` integrieren

**Files:**
- Modify: `lib/features/plans/plan_editor_screen.dart`

- [ ] **Schritt 1: Import hinzufügen**

Find:
```dart
import '../../core/providers/plan_library_notifier.dart';
import 'widgets/minute_exact_editor.dart';
```

Replace with:
```dart
import '../../core/providers/plan_library_notifier.dart';
import 'undo_manager.dart';
import 'widgets/minute_exact_editor.dart';
```

- [ ] **Schritt 2: `_undoManager` Feld + Lifecycle**

Find:
```dart
  late TrainingPlan _plan;
  int? _selectedRow;

  @override
  void initState() {
    super.initState();
    _plan = TrainingPlan(
      id: widget.plan.id,
      name: widget.plan.name,
      intervals: widget.plan.intervals.map((iv) => iv.copyWith()).toList(),
    );
  }
```

Replace with:
```dart
  late TrainingPlan _plan;
  int? _selectedRow;
  late final UndoManager _undoManager;

  @override
  void initState() {
    super.initState();
    _plan = TrainingPlan(
      id: widget.plan.id,
      name: widget.plan.name,
      intervals: widget.plan.intervals.map((iv) => iv.copyWith()).toList(),
    );
    _undoManager = UndoManager();
  }

  @override
  void dispose() {
    _undoManager.dispose();
    super.dispose();
  }
```

- [ ] **Schritt 3: Snapshot vor `_onReorder`**

Find:
```dart
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _plan.intervals.removeAt(oldIndex);
```

Replace with:
```dart
  void _onReorder(int oldIndex, int newIndex) {
    _undoManager.push(_plan.intervals);
    setState(() {
      final item = _plan.intervals.removeAt(oldIndex);
```

- [ ] **Schritt 4: Snapshot vor `_onDelete`**

Find:
```dart
  void _onDelete(int index) {
    if (_plan.intervals.length <= TrainingPlan.minIntervals) return;
    setState(() {
```

Replace with:
```dart
  void _onDelete(int index) {
    if (_plan.intervals.length <= TrainingPlan.minIntervals) return;
    _undoManager.push(_plan.intervals);
    setState(() {
```

- [ ] **Schritt 5: Snapshot vor `_onAdd`**

Find:
```dart
  void _onAdd() {
    if (_plan.intervals.length >= TrainingPlan.maxIntervals) return;
    setState(() {
```

Replace with:
```dart
  void _onAdd() {
    if (_plan.intervals.length >= TrainingPlan.maxIntervals) return;
    _undoManager.push(_plan.intervals);
    setState(() {
```

- [ ] **Schritt 6: `_undo()`-Methode hinzufügen**

Nach `_onAdd()` einfügen:

```dart
  void _undo() {
    setState(() {
      _plan = TrainingPlan(
        id: _plan.id,
        name: _plan.name,
        intervals: _undoManager.undo(),
      );
      _selectedRow = null;
    });
  }
```

- [ ] **Schritt 7: Undo-Button in AppBar + `onBeforeFieldChange` verdrahten**

Find:
```dart
        appBar: AppBar(
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white38),
            onPressed: () async {
              await _save();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Text(
            _plan.name.toUpperCase(),
            style: const TextStyle(
                fontSize: 15, letterSpacing: 4, color: Colors.white38),
          ),
        ),
```

Replace with:
```dart
        appBar: AppBar(
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white38),
            onPressed: () async {
              await _save();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Text(
            _plan.name.toUpperCase(),
            style: const TextStyle(
                fontSize: 15, letterSpacing: 4, color: Colors.white38),
          ),
          actions: [
            if (_undoManager.canUndo)
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white38),
                onPressed: _undo,
              ),
          ],
        ),
```

Find:
```dart
                onChanged: () => setState(() {}),
                onReorder: _onReorder,
```

Replace with:
```dart
                onChanged: () => setState(() {}),
                onBeforeFieldChange: () =>
                    _undoManager.pushDebounced(_plan.intervals),
                onReorder: _onReorder,
```

- [ ] **Schritt 8: Analyse + alle Tests**

```
flutter analyze
flutter test
```

Erwartet: 0 Fehler, alle Tests PASS.

- [ ] **Schritt 9: Commit**

```
git add lib/features/plans/plan_editor_screen.dart
git commit -m "feat: integrate UndoManager into plan editor with AppBar undo button"
```
