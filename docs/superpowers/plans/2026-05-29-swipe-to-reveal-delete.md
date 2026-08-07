# Swipe-to-Reveal Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ersetze das Swipe-to-Dismiss (Dismissible) im Plan-Editor durch Swipe-to-Reveal: Die Zeile schiebt sich nach rechts auf und bleibt offen; erst der Tap auf die sichtbare Mülltonne löscht das Intervall (mit Bestätigungsdialog bei aktivem Plan).

**Architecture:** `Dismissible` wird aus `PlanMinuteExactEditor` entfernt. Ein neues privates `_SwipeToRevealRow`-Widget (in derselben Datei) übernimmt die Gestensteuerung via `GestureDetector` + `AnimationController`. Die Zeile übersetzt sich mit `Transform.translate` nach rechts; darunter liegt ein roter Bereich mit Trash-Icon. Das `onConfirmDelete`-Callback sowie das `onDelete`-Callback aus `PlanEditorScreen` bleiben unverändert — nur der Aufrufzeitpunkt ändert sich (Tap statt Swipe-Ende). Die Widget-Tests werden auf das neue Interaktionsmuster umgeschrieben.

**Tech Stack:** Flutter, `AnimationController` mit `SingleTickerProviderStateMixin`, `GestureDetector`, `Transform.translate`, `Stack`

---

## File Map

| File | Änderung |
|------|----------|
| `lib/features/plans/widgets/minute_exact_editor.dart` | Modify: `Dismissible` entfernen, `_SwipeToRevealRow` hinzufügen |
| `test/features/plans/plan_editor_delete_confirmation_test.dart` | Modify: Tests auf neues Interaktionsmuster umschreiben |

---

### Task 1: Tests auf neues Muster umschreiben (TDD — müssen erst scheitern)

**Files:**
- Modify: `test/features/plans/plan_editor_delete_confirmation_test.dart`

Der aktuelle Test dragged einen `Dismissible`. Das neue Widget hat keinen `Dismissible` mehr, daher schlagen diese Tests nach Task 2 fehl. Wir schreiben sie jetzt neu — mit einer `Key`-basierten Strategie, die den Trash-Button direkt findet.

Das neue Widget wird dem Trash-Button den Key `ValueKey('delete_$i')` geben (wird in Task 2 implementiert). Die Tests referenzieren diesen Key.

- [ ] **Step 1: Testdatei komplett ersetzen**

Ersetze den gesamten Inhalt von `test/features/plans/plan_editor_delete_confirmation_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/settings.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/providers/plan_library_notifier.dart';
import 'package:emom_app/features/plans/plan_editor_screen.dart';

// Must be > TrainingPlan.minIntervals (3) so deletion is allowed
List<IntervalConfig> _fourIntervals() => List.generate(
      4,
      (i) => IntervalConfig(
        equipment: Equipment.kb16,
        exercise: Exercise.swingBeidarmig,
        reps: 10,
        durationSeconds: 60,
      ),
    );

Future<void> _pumpEditor(
  WidgetTester tester, {
  required String planId,
  required String activePlanId,
}) async {
  final plan = TrainingPlan(
    id: planId,
    name: 'Test',
    intervals: _fourIntervals(),
  );
  final library = PlanLibrary(
    plans: [plan],
    activePlanId: activePlanId,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        planLibraryNotifierProvider.overrideWith(() =>
            _FakePlanLibraryNotifier(library)),
      ],
      child: MaterialApp(
        home: PlanEditorScreen(plan: plan),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakePlanLibraryNotifier extends PlanLibraryNotifier {
  final PlanLibrary _initial;
  _FakePlanLibraryNotifier(this._initial);

  @override
  Future<PlanLibrary> build() async => _initial;
}

/// Swipe row at [index] open (reveal trash button), then settle.
Future<void> _swipeOpen(WidgetTester tester, int index) async {
  final rowFinder = find.byKey(ValueKey('swipe_row_$index'));
  await tester.drag(rowFinder, const Offset(80, 0));
  await tester.pumpAndSettle();
}

/// Tap the trash button of row at [index].
Future<void> _tapTrash(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('delete_$index')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kein Dialog beim Löschen eines Intervalls im nicht-aktiven Plan',
      (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-2');

    await _swipeOpen(tester, 0);
    await _tapTrash(tester, 0);

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Dialog erscheint beim Löschen aus dem aktiven Plan',
      (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    await _swipeOpen(tester, 0);
    await _tapTrash(tester, 0);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
  });

  testWidgets('Abbrechen schließt Dialog und Row bleibt sichtbar',
      (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    await _swipeOpen(tester, 0);
    await _tapTrash(tester, 0);

    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    // Row still present — count stays at 4
    expect(find.byKey(const ValueKey('swipe_row_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe_row_3')), findsOneWidget);
  });

  testWidgets('Bestätigen löscht das Intervall', (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    await _swipeOpen(tester, 0);
    await _tapTrash(tester, 0);
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    // One row removed — row with index 3 is gone
    expect(find.byKey(const ValueKey('swipe_row_3')), findsNothing);
  });

  testWidgets('Swipe gesperrt wenn nur noch minIntervals Zeilen',
      (tester) async {
    // Build a plan with exactly minIntervals (3) rows
    final plan = TrainingPlan(
      id: 'plan-min',
      name: 'Min',
      intervals: List.generate(
        TrainingPlan.minIntervals,
        (_) => IntervalConfig(
          equipment: Equipment.kb16,
          exercise: Exercise.swingBeidarmig,
          reps: 5,
          durationSeconds: 60,
        ),
      ),
    );
    final library = PlanLibrary(plans: [plan], activePlanId: 'other');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planLibraryNotifierProvider.overrideWith(
              () => _FakePlanLibraryNotifier(library)),
        ],
        child: MaterialApp(home: PlanEditorScreen(plan: plan)),
      ),
    );
    await tester.pumpAndSettle();

    // Swipe should not reveal trash (canDelete = false)
    await tester.drag(
        find.byKey(const ValueKey('swipe_row_0')), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('delete_0')), findsNothing);
  });
}
```

- [ ] **Step 2: Tests ausführen (müssen scheitern — Keys existieren noch nicht)**

```
flutter test test/features/plans/plan_editor_delete_confirmation_test.dart -v
```

Erwartet: FAIL / compile-Fehler weil `ValueKey('swipe_row_0')` etc. nicht gefunden werden. Das ist korrekt.

---

### Task 2: `_SwipeToRevealRow` implementieren und `Dismissible` ersetzen

**Files:**
- Modify: `lib/features/plans/widgets/minute_exact_editor.dart`

- [ ] **Step 1: Datei vollständig ersetzen**

Ersetze den gesamten Inhalt von `lib/features/plans/widgets/minute_exact_editor.dart`:

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
  final Future<bool> Function(int index)? onConfirmDelete;

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
        child: _SwipeToRevealRow(
          rowKey: ValueKey('swipe_row_$i'),
          deleteKey: ValueKey('delete_$i'),
          canDelete: plan.intervals.length > TrainingPlan.minIntervals,
          onDeleteTap: () async {
            if (onConfirmDelete != null) {
              final confirmed = await onConfirmDelete!(i);
              if (!confirmed) return;
            }
            onDelete(i);
          },
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

// ---------------------------------------------------------------------------

class _SwipeToRevealRow extends StatefulWidget {
  final Key rowKey;
  final Key deleteKey;
  final bool canDelete;
  final Future<void> Function() onDeleteTap;
  final Widget child;

  const _SwipeToRevealRow({
    required this.rowKey,
    required this.deleteKey,
    required this.canDelete,
    required this.onDeleteTap,
    required this.child,
  });

  @override
  State<_SwipeToRevealRow> createState() => _SwipeToRevealRowState();
}

class _SwipeToRevealRowState extends State<_SwipeToRevealRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const double _revealWidth = 64.0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!widget.canDelete) return;
    _ctrl.value =
        (_ctrl.value + d.delta.dx / _revealWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.canDelete) return;
    if (_ctrl.value > 0.45 || d.velocity.pixelsPerSecond.dx > 250) {
      _ctrl.animateTo(1.0);
    } else {
      _ctrl.animateTo(0.0);
    }
  }

  Future<void> _handleDeleteTap() async {
    if (_busy) return;
    _busy = true;
    await widget.onDeleteTap();
    _busy = false;
    if (mounted) _ctrl.animateTo(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: widget.rowKey,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final offset = _ctrl.value * _revealWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Delete area (revealed behind the row)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: offset.clamp(0.0, _revealWidth),
                child: GestureDetector(
                  key: widget.deleteKey,
                  onTap: _handleDeleteTap,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: offset > 24
                        ? const Icon(Icons.delete_outline,
                            color: Colors.white, size: 22)
                        : null,
                  ),
                ),
              ),
              // Row content slides right
              Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}
```

- [ ] **Step 2: Analyse**

```
flutter analyze lib/features/plans/widgets/minute_exact_editor.dart
```

Erwartet: keine Fehler.

- [ ] **Step 3: Tests ausführen**

```
flutter test test/features/plans/plan_editor_delete_confirmation_test.dart -v
```

Erwartet: alle 5 Tests PASS.

- [ ] **Step 4: Gesamte Test-Suite**

```
flutter test
```

Erwartet: alle Tests PASS.

- [ ] **Step 5: Committen**

```bash
git add lib/features/plans/widgets/minute_exact_editor.dart
git add test/features/plans/plan_editor_delete_confirmation_test.dart
git commit -m "feat: swipe-to-reveal delete with trash button in plan editor"
```

---

## Self-Review

**Spec-Abdeckung:**
- ✅ Row bleibt nach Swipe offen (snap via AnimationController)
- ✅ Nur Mülltonne sichtbar (Icon erscheint ab offset > 24 px)
- ✅ Tap auf Mülltonne → onConfirmDelete → onDelete
- ✅ Bestätigungsdialog bei aktivem Plan (über bestehendes onConfirmDelete-Callback in PlanEditorScreen, unverändert)
- ✅ Swipe gesperrt bei minIntervals (canDelete = false → onDragUpdate/End no-op, kein deleteKey gerendert)
- ✅ Row schnappt nach Abbrechen zurück (animateTo(0.0) in _handleDeleteTap nach Ablehnung)
- ✅ Drag-to-Reorder bleibt funktionsfähig (ReorderableDelayedDragStartListener nutzt Long-Press, kein Konflikt)

**Placeholder-Scan:** Keine TODOs, alle Code-Blöcke vollständig.

**Typ-Konsistenz:**
- `onDeleteTap: Future<void> Function()` — konsistent zwischen `_SwipeToRevealRow` und dem Aufruf in `itemBuilder`
- `rowKey: ValueKey('swipe_row_$i')` / `deleteKey: ValueKey('delete_$i')` — konsistent mit Testfinder-Strings
- `_revealWidth = 64.0` — nur an einer Stelle definiert
