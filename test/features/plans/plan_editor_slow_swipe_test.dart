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
        reps: 10 * (i + 1),
        durationSeconds: 60,
      ),
    );

class _FakePlanLibraryNotifier extends PlanLibraryNotifier {
  final PlanLibrary _initial;
  _FakePlanLibraryNotifier(this._initial);

  @override
  Future<PlanLibrary> build() async => _initial;

  @override
  Future<void> updatePlan(TrainingPlan plan) async {}
}

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
}

void main() {
  testWidgets('Zögern beim Start (600ms), dann Links-Swipe', (tester) async {
    await _pumpPushedEditor(tester);

    final center = tester.getCenter(find.byType(SwipeToRevealRow).at(0));
    final g = await tester.startGesture(center);
    // Finger liegt 600ms fast still — typisch bei bedächtigem Swipe-Start
    await tester.pump(const Duration(milliseconds: 600));
    for (int i = 0; i < 6; i++) {
      await g.moveBy(const Offset(-16, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget,
        reason: 'Nach Zögern beim Start sollte der Links-Swipe '
            'trotzdem Delete öffnen');
  });

  testWidgets('Langsamer Links-Swipe (~20px/s) ohne Zögern', (tester) async {
    await _pumpPushedEditor(tester);

    final center = tester.getCenter(find.byType(SwipeToRevealRow).at(0));
    final g = await tester.startGesture(center);
    // 2px alle 100ms = 20px/s — langsamer, bewusster Swipe
    for (int i = 0; i < 12; i++) {
      await g.moveBy(const Offset(-2, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // danach zügig weiter
    for (int i = 0; i < 4; i++) {
      await g.moveBy(const Offset(-16, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget,
        reason: 'Auch ein langsamer Links-Swipe sollte Delete öffnen');
  });

  testWidgets('Umsortieren über den Drag-Griff funktioniert', (tester) async {
    await _pumpPushedEditor(tester);

    double dyOf(String repsLabel) =>
        tester.getTopLeft(find.text(repsLabel)).dy;
    expect(dyOf('10W'), lessThan(dyOf('20W')));

    // Griff der ersten Zeile fassen und unter die zweite Zeile ziehen
    final handle = find.byIcon(Icons.drag_indicator).first;
    final rowHeight = dyOf('20W') - dyOf('10W');
    final g = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (int i = 0; i < 10; i++) {
      await g.moveBy(Offset(0, rowHeight / 4));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await g.up();
    await tester.pumpAndSettle();

    expect(dyOf('10W'), greaterThan(dyOf('20W')));
  });
}
