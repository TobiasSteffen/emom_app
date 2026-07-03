import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/providers/plan_library_notifier.dart';
import 'package:emom_app/features/plans/plan_editor_screen.dart';
import 'package:emom_app/features/shared/widgets/swipe_to_reveal_row.dart';

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

class _FakePlanLibraryNotifier extends PlanLibraryNotifier {
  final PlanLibrary _initial;
  _FakePlanLibraryNotifier(this._initial);

  @override
  Future<PlanLibrary> build() async => _initial;

  // Kein Datei-IO im Widget-Test (Save-on-Pop ruft updatePlan auf).
  @override
  Future<void> updatePlan(TrainingPlan plan) async {}
}

/// Pumps a launcher screen and pushes the editor as a real route,
/// so popping is observable.
Future<void> _pumpPushedEditor(WidgetTester tester) async {
  final plan = TrainingPlan(
    id: 'plan-1',
    name: 'Test',
    intervals: _fourIntervals(),
  );
  final library = PlanLibrary(plans: [plan], activePlanId: 'plan-1');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        planLibraryProvider
            .overrideWith(() => _FakePlanLibraryNotifier(library)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PlanEditorScreen(plan: plan)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byType(PlanEditorScreen), findsOneWidget);
}

void main() {
  testWidgets('Rechts-Fling im Editor navigiert zurück', (tester) async {
    await _pumpPushedEditor(tester);

    await tester.fling(
        find.byType(PlanEditorScreen), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(PlanEditorScreen), findsNothing);
  });

  testWidgets(
      'Links-Swipe mit Touch-Down-Jitter öffnet Delete trotz Gesten-Konkurrenz',
      (tester) async {
    await _pumpPushedEditor(tester);

    final center = tester.getCenter(find.byType(SwipeToRevealRow).at(0));
    final g = await tester.startGesture(center);
    // Finger rollt beim Aufsetzen minimal nach rechts (typisch bei echtem Touch)
    await g.moveBy(const Offset(2, 0));
    await tester.pump(const Duration(milliseconds: 16));
    // Danach klarer Links-Swipe, leicht diagonal wie ein echter Daumen
    for (int i = 0; i < 6; i++) {
      await g.moveBy(const Offset(-16, 1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byType(PlanEditorScreen), findsOneWidget);
  });

  testWidgets('Rechts-Fling über offener Delete-Row schließt nur die Row',
      (tester) async {
    await _pumpPushedEditor(tester);

    await tester.drag(
        find.byType(SwipeToRevealRow).at(0), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.fling(
        find.byType(SwipeToRevealRow).at(0), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(PlanEditorScreen), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
