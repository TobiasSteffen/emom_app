import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/providers/plan_library_notifier.dart';
import 'package:emom_app/features/plans/plan_editor_screen.dart';
import 'package:emom_app/features/plans/widgets/minute_row.dart';

// Must be > TrainingPlan.minIntervals (3) so deletion is allowed
List<IntervalConfig> _fourIntervals() => List.generate(
      4,
      (i) => IntervalConfig(
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_16',
        exerciseTypeId: 'swing_beidarmig',
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
        planLibraryProvider.overrideWith(() =>
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

/// Lösch-Modus über den AppBar-Toggle aktivieren.
Future<void> _enterDeleteMode(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('delete_mode_toggle')));
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

    await _enterDeleteMode(tester);
    await _tapTrash(tester, 0);

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Dialog erscheint beim Löschen aus dem aktiven Plan',
      (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    await _enterDeleteMode(tester);
    await _tapTrash(tester, 0);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
  });

  testWidgets('Abbrechen schließt Dialog und Row bleibt sichtbar',
      (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    await _enterDeleteMode(tester);
    await _tapTrash(tester, 0);

    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PlanMinuteRow), findsNWidgets(4));
  });

  testWidgets('Bestätigen löscht das Intervall', (tester) async {
    await _pumpEditor(tester, planId: 'plan-1', activePlanId: 'plan-1');

    await _enterDeleteMode(tester);
    await _tapTrash(tester, 0);
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.byType(PlanMinuteRow), findsNWidgets(3));
  });

  testWidgets('Swipe gesperrt wenn nur noch minIntervals Zeilen',
      (tester) async {
    final plan = TrainingPlan(
      id: 'plan-min',
      name: 'Min',
      intervals: List.generate(
        TrainingPlan.minIntervals,
        (_) => IntervalConfig(
          equipmentTypeId: 'kettlebell',
          variantId: 'kb_16',
          exerciseTypeId: 'swing_beidarmig',
          reps: 5,
          durationSeconds: 60,
        ),
      ),
    );
    final library = PlanLibrary(plans: [plan], activePlanId: 'other');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planLibraryProvider.overrideWith(
              () => _FakePlanLibraryNotifier(library)),
        ],
        child: MaterialApp(home: PlanEditorScreen(plan: plan)),
      ),
    );
    await tester.pumpAndSettle();

    await _enterDeleteMode(tester);

    expect(find.byKey(const ValueKey('delete_0')), findsNothing);
  });
}
