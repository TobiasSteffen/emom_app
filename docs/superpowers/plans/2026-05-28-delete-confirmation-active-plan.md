# Delete Confirmation for Active Plan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Beim Löschen eines Intervalls im Plan-Editor soll ein Bestätigungsdialog erscheinen, wenn der bearbeitete Plan der aktuell aktive Trainingsplan ist.

**Architecture:** Ein optionaler `onConfirmDelete`-Callback wird zu `PlanMinuteExactEditor` hinzugefügt. `PlanEditorScreen` liest den aktiven Plan aus dem Provider und zeigt bei Bedarf einen `AlertDialog`. Die Logik bleibt vollständig im Screen, der Editor-Widget bleibt generisch.

**Tech Stack:** Flutter, Riverpod (`planLibraryNotifierProvider`), `showDialog` / `AlertDialog`

---

## File Map

| File | Change |
|------|--------|
| `lib/features/plans/widgets/minute_exact_editor.dart` | Modify: add optional `onConfirmDelete` callback |
| `lib/features/plans/plan_editor_screen.dart` | Modify: add `_confirmDelete` method, pass callback |
| `test/features/plans/plan_editor_delete_confirmation_test.dart` | Create: widget tests |

---

### Task 1: Widget-Tests schreiben (TDD)

**Files:**
- Create: `test/features/plans/plan_editor_delete_confirmation_test.dart`

- [ ] **Step 1: Testdatei anlegen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/providers/plan_library_notifier.dart';
import 'package:emom_app/features/plans/plan_editor_screen.dart';

// Hilfsfunktion: baut zwei IntervalConfig-Objekte (minimum 2 für Löschung erlaubt)
List<IntervalConfig> _twoIntervals() => [
      const IntervalConfig(
        equipment: Equipment.kb16,
        exercise: Exercise.swingBeidarmig,
        reps: 10,
      ),
      const IntervalConfig(
        equipment: Equipment.kb20,
        exercise: Exercise.swingBeidarmig,
        reps: 8,
      ),
    ];

// Hilfsfunktion: rendert PlanEditorScreen mit einem gemockten PlanLibraryNotifier
Future<void> _pumpEditor(
  WidgetTester tester, {
  required String planId,
  required String activePlanId,
}) async {
  final plan = TrainingPlan(
    id: planId,
    name: 'Test',
    intervals: _twoIntervals(),
  );
  final library = PlanLibrary(
    plans: [plan],
    activePlanId: activePlanId,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        planLibraryNotifierProvider.overrideWith(() {
          // Gibt direkt den fertigen Zustand zurück
          return _FakePlanLibraryNotifier(library);
        }),
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
```

- [ ] **Step 2: Test 1 — Kein Dialog bei nicht-aktivem Plan**

Ergänze in der gleichen Datei:

```dart
void main() {
  testWidgets('kein Dialog beim Löschen eines Intervalls im nicht-aktiven Plan',
      (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-2');

    // Ersten Eintrag nach rechts swipen
    await tester.drag(find.byType(Dismissible).first, const Offset(400, 0));
    await tester.pumpAndSettle();

    // Kein AlertDialog soll erscheinen
    expect(find.byType(AlertDialog), findsNothing);
  });
```

- [ ] **Step 3: Test 2 — Dialog erscheint beim aktiven Plan**

```dart
  testWidgets('Dialog erscheint beim Löschen aus dem aktiven Plan',
      (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    await tester.drag(find.byType(Dismissible).first, const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
  });
```

- [ ] **Step 4: Test 3 — Abbrechen verhindert Löschung**

```dart
  testWidgets('Abbrechen verhindert Löschung des Intervalls', (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    final initialCount = find.byType(Dismissible).evaluate().length;

    await tester.drag(find.byType(Dismissible).first, const Offset(400, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.byType(Dismissible).evaluate().length, equals(initialCount));
  });

  testWidgets('Bestätigen löscht das Intervall', (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    final initialCount = find.byType(Dismissible).evaluate().length;

    await tester.drag(find.byType(Dismissible).first, const Offset(400, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.byType(Dismissible).evaluate().length, equals(initialCount - 1));
  });
}
```

- [ ] **Step 5: Tests ausführen (müssen fehlschlagen)**

```
flutter test test/features/plans/plan_editor_delete_confirmation_test.dart -v
```

Erwartet: FAIL — `onConfirmDelete` existiert noch nicht, Dialog erscheint nicht.

---

### Task 2: `PlanMinuteExactEditor` — optionalen Callback hinzufügen

**Files:**
- Modify: `lib/features/plans/widgets/minute_exact_editor.dart`

- [ ] **Step 1: Callback-Parameter zur Klasse hinzufügen**

Ersetze den Klassenkopf (Zeile 5–21):

```dart
class PlanMinuteExactEditor extends StatelessWidget {
  final TrainingPlan plan;
  final int? selectedRow;
  final ValueChanged<int?> onRowSelected;
  final VoidCallback onChanged;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onDelete;
  /// Wenn gesetzt, wird vor dem Löschen aufgerufen. Gibt false zurück → Löschen abgebrochen.
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
```

- [ ] **Step 2: `confirmDismiss` anpassen**

Ersetze in `build()` die `confirmDismiss`-Zeile:

```dart
confirmDismiss: (_) async {
  if (plan.intervals.length <= TrainingPlan.minIntervals) return false;
  if (onConfirmDelete != null) return await onConfirmDelete!(i);
  return true;
},
```

- [ ] **Step 3: Analyse — kein Fehler erwartet**

```
flutter analyze lib/features/plans/widgets/minute_exact_editor.dart
```

Erwartet: keine Issues.

---

### Task 3: `PlanEditorScreen` — Bestätigungsdialog implementieren

**Files:**
- Modify: `lib/features/plans/plan_editor_screen.dart`

- [ ] **Step 1: `_confirmDelete`-Methode hinzufügen**

Füge nach der `_onAdd`-Methode (nach Zeile 76) ein:

```dart
Future<bool> _confirmDelete(int index) async {
  final lib = ref.read(planLibraryNotifierProvider).valueOrNull;
  if (lib?.activePlanId != _plan.id) return true;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text(
        'Intervall löschen',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Dieser Plan ist gerade aktiv. Trotzdem löschen?',
        style: TextStyle(color: Colors.white60),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Abbrechen',
              style: TextStyle(color: Colors.white38)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Löschen',
              style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

- [ ] **Step 2: Callback an `PlanMinuteExactEditor` übergeben**

In `build()`, ergänze den `onConfirmDelete`-Parameter im `PlanMinuteExactEditor`-Aufruf (ab Zeile 108):

```dart
PlanMinuteExactEditor(
  plan: _plan,
  selectedRow: _selectedRow,
  onRowSelected: (i) => setState(() => _selectedRow = i),
  onChanged: () => setState(() {}),
  onReorder: _onReorder,
  onDelete: _onDelete,
  onConfirmDelete: _confirmDelete,
),
```

- [ ] **Step 3: Analyse — kein Fehler erwartet**

```
flutter analyze lib/features/plans/plan_editor_screen.dart
```

Erwartet: keine Issues.

---

### Task 4: Tests ausführen und committen

- [ ] **Step 1: Neue Widget-Tests ausführen**

```
flutter test test/features/plans/plan_editor_delete_confirmation_test.dart -v
```

Erwartet: alle 4 Tests PASS.

- [ ] **Step 2: Gesamte Test-Suite ausführen**

```
flutter test
```

Erwartet: alle Tests PASS (keine Regression).

- [ ] **Step 3: Analyse gesamtes Projekt**

```
flutter analyze
```

Erwartet: keine Issues.

- [ ] **Step 4: Committen**

```bash
git add lib/features/plans/widgets/minute_exact_editor.dart
git add lib/features/plans/plan_editor_screen.dart
git add test/features/plans/plan_editor_delete_confirmation_test.dart
git commit -m "feat: confirm before deleting interval in active plan"
```

---

## Self-Review

**Spec-Abdeckung:**
- ✅ Löschen ohne Bestätigung bei nicht-aktivem Plan → Task 3 + Test 1
- ✅ Dialog bei aktivem Plan → Task 3 + Test 2
- ✅ Abbrechen verhindert Löschung → Test 3
- ✅ Bestätigen löscht → Test 4
- ✅ Minimum-Intervall-Schutz bleibt erhalten → `confirmDismiss` prüft weiterhin `minIntervals` vor dem Callback

**Placeholder-Scan:** Keine TODOs, alle Code-Blöcke vollständig.

**Typ-Konsistenz:** `Future<bool> Function(int index)` konsistent in Widget-Parameter und Screen-Methode.
