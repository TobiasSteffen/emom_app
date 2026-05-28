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

void main() {
  testWidgets('kein Dialog beim Löschen eines Intervalls im nicht-aktiven Plan',
      (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-2');

    await tester.drag(find.byType(Dismissible).first, const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Dialog erscheint beim Löschen aus dem aktiven Plan',
      (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    await tester.drag(find.byType(Dismissible).first, const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
  });

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
