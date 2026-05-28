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
    expect(find.byKey(const ValueKey('swipe_row_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe_row_3')), findsOneWidget);
  });

  testWidgets('Bestätigen löscht das Intervall', (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    await _swipeOpen(tester, 0);
    await _tapTrash(tester, 0);
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('swipe_row_3')), findsNothing);
  });

  testWidgets('Swipe gesperrt wenn nur noch minIntervals Zeilen',
      (tester) async {
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

    await tester.drag(
        find.byKey(const ValueKey('swipe_row_0')), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('delete_0')), findsNothing);
  });
}
