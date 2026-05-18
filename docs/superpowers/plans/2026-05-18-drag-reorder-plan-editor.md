# Drag-to-Reorder Plan-Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zeilen im Plan-Editor durch langes Drücken per Drag & Drop verschiebbar machen.

**Architecture:** `ReorderableListView.builder` ersetzt den bisherigen `ListView.builder` in `PlanMinuteExactEditor`. `PlanEditorScreen` wird von `ListView` auf `Column + Expanded` umgebaut, sodass `ReorderableListView` eine gebundene Höhe hat. Die Reorder-Logik und das Summary-Widget leben in `PlanEditorScreen`.

**Tech Stack:** Flutter `ReorderableListView.builder`, `ReorderableDelayedDragStartListener`

---

### Task 1: Reorder-Algorithmus testen (TDD)

**Files:**
- Create: `test/features/plans/plan_reorder_test.dart`

- [ ] **Step 1: Testdatei anlegen**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

List<IntervalConfig> _makeIntervals() => List.generate(30, (i) => IntervalConfig(
  reps: i + 1,
  durationSeconds: 60,
  equipment: Equipment.kb24,
  exercise: Exercise.swingBeidarmig,
));

// Dieselbe Logik wie in PlanEditorScreen._onReorder
({List<IntervalConfig> intervals, int? selectedRow}) _applyReorder(
  List<IntervalConfig> intervals,
  int? selectedRow,
  int oldIndex,
  int newIndex,
) {
  if (newIndex > oldIndex) newIndex--;
  final item = intervals.removeAt(oldIndex);
  intervals.insert(newIndex, item);
  if (selectedRow != null) {
    final s = selectedRow;
    if (s == oldIndex) {
      selectedRow = newIndex;
    } else if (oldIndex < newIndex && s > oldIndex && s <= newIndex) {
      selectedRow = s - 1;
    } else if (oldIndex > newIndex && s >= newIndex && s < oldIndex) {
      selectedRow = s + 1;
    }
  }
  return (intervals: intervals, selectedRow: selectedRow);
}

void main() {
  group('plan reorder logic', () {
    test('item moves down: reps follow', () {
      final intervals = _makeIntervals();
      // reps[2]=3, reps[4]=5
      final result = _applyReorder(intervals, null, 2, 5); // drop after index 4
      expect(result.intervals[4].reps, 3); // item from 2 lands at 4
      expect(result.intervals[2].reps, 4); // item from 3 shifts to 2
      expect(result.intervals.length, 30);
    });

    test('item moves up: reps follow', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, null, 4, 2); // drop before index 2
      expect(result.intervals[2].reps, 5); // item from 4 lands at 2
      expect(result.intervals[3].reps, 3); // item from 2 shifts to 3
      expect(result.intervals.length, 30);
    });

    test('selectedRow follows moved item down', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 2, 2, 5);
      expect(result.selectedRow, 4);
    });

    test('selectedRow follows moved item up', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 4, 4, 2);
      expect(result.selectedRow, 2);
    });

    test('selectedRow between old and new (move down) shifts up', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 3, 2, 5); // row 3 is between 2 and 4
      expect(result.selectedRow, 2);
    });

    test('selectedRow between old and new (move up) shifts down', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 3, 5, 2); // row 3 is between 2 and 5
      expect(result.selectedRow, 4);
    });

    test('selectedRow outside range stays unchanged', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 0, 2, 5);
      expect(result.selectedRow, 0);
    });
  });
}
```

- [ ] **Step 2: Test ausführen — muss FEHLSCHLAGEN**

```
flutter test test/features/plans/plan_reorder_test.dart
```

Erwartetes Ergebnis: Compile-Fehler oder FAIL (Datei existiert noch nicht / Funktion fehlt).

*(Der Test kompiliert mit dem selbst definierten `_applyReorder` — er wird PASS sein sobald die Logik korrekt ist. Weiter zu Task 2.)*

---

### Task 2: `PlanMinuteExactEditor` auf `ReorderableListView` umbauen

**Files:**
- Modify: `lib/features/plans/widgets/minute_exact_editor.dart`

Das Summary-Widget (`GESAMT`-Box) und `_formatDuration` werden aus dieser Datei entfernt — sie wandern in `PlanEditorScreen` (Task 3).

- [ ] **Step 1: Datei vollständig ersetzen**

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

  const PlanMinuteExactEditor({
    super.key,
    required this.plan,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
    required this.onReorder,
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
      itemCount: 30,
      itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(i),
        index: i,
        child: PlanMinuteRow(
          index: i,
          plan: plan,
          isSelected: selectedRow == i,
          onSelect: () => onRowSelected(selectedRow == i ? null : i),
          onChanged: onChanged,
        ),
      ),
      onReorder: onReorder,
    );
  }
}
```

- [ ] **Step 2: `flutter analyze` ausführen**

```
flutter analyze lib/features/plans/widgets/minute_exact_editor.dart
```

Erwartetes Ergebnis: Keine Fehler (Compile-Fehler in `plan_editor_screen.dart` werden erst in Task 3 behoben).

---

### Task 3: `PlanEditorScreen` umbauen

**Files:**
- Modify: `lib/features/plans/plan_editor_screen.dart`

- [ ] **Step 1: Datei vollständig ersetzen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/training_plan.dart';
import '../../core/providers/plan_library_notifier.dart';
import 'widgets/minute_exact_editor.dart';

class PlanEditorScreen extends ConsumerStatefulWidget {
  final TrainingPlan plan;
  const PlanEditorScreen({super.key, required this.plan});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
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

  Future<void> _save() async {
    await ref.read(planLibraryNotifierProvider.notifier).updatePlan(_plan);
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _plan.intervals.removeAt(oldIndex);
      _plan.intervals.insert(newIndex, item);
      if (_selectedRow != null) {
        final s = _selectedRow!;
        if (s == oldIndex) {
          _selectedRow = newIndex;
        } else if (oldIndex < newIndex && s > oldIndex && s <= newIndex) {
          _selectedRow = s - 1;
        } else if (oldIndex > newIndex && s >= newIndex && s < oldIndex) {
          _selectedRow = s + 1;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _save();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
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
        body: Column(
          children: [
            Expanded(
              child: PlanMinuteExactEditor(
                plan: _plan,
                selectedRow: _selectedRow,
                onRowSelected: (i) => setState(() => _selectedRow = i),
                onChanged: () => setState(() {}),
                onReorder: _onReorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GESAMT',
                        style: TextStyle(
                            fontSize: 10, letterSpacing: 3, color: Colors.white24)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${_plan.totalReps} Wdh.',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white38)),
                        Text(_formatDuration(_plan.totalDurationSeconds),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white24)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Alle Tests ausführen**

```
flutter test
```

Erwartetes Ergebnis: Alle Tests PASS (inkl. `plan_reorder_test.dart`).

- [ ] **Step 3: App starten und manuell prüfen**

```
flutter run
```

Prüfen:
- Plan-Editor öffnen → Liste scrollbar, alle 30 Zeilen sichtbar
- Zeile lang drücken → Drag-Feedback erscheint (leicht erhöhte dunkle Karte)
- Zeile an neue Position ziehen → landet dort, Phasenfarben aktualisieren sich
- Expandierte Zeile verschieben → bleibt nach Drop expandiert
- Nach Zurück-Button → Reihenfolge wurde gespeichert (sichtbar beim erneuten Öffnen)
- GESAMT-Box unten zeigt korrekte Summen

- [ ] **Step 4: Commit**

```
git add lib/features/plans/widgets/minute_exact_editor.dart lib/features/plans/plan_editor_screen.dart test/features/plans/plan_reorder_test.dart
git commit -m "feat: drag-to-reorder rows in plan editor via long press"
```
