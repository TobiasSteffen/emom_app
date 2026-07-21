import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/equipment_catalog.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/providers/equipment_catalog_notifier.dart';
import 'package:emom_app/core/providers/plan_library_notifier.dart';
import 'package:emom_app/features/plans/emom_wizard_screen.dart';

class _FakeCatalogNotifier extends EquipmentCatalogNotifier {
  @override
  Future<EquipmentCatalog> build() async => EquipmentCatalog.defaultCatalog();
}

class _CapturingPlanLibraryNotifier extends PlanLibraryNotifier {
  final PlanLibrary initial;
  final List<TrainingPlan> added = [];
  _CapturingPlanLibraryNotifier(this.initial);

  @override
  Future<PlanLibrary> build() async => initial;

  @override
  Future<void> addPlan(TrainingPlan plan) async {
    added.add(plan);
    state = AsyncData(PlanLibrary(
      plans: [...initial.plans, plan],
      activePlanId: initial.activePlanId,
    ));
  }
}

void main() {
  testWidgets('Erstellen erzeugt einen 30-Intervall-EMOM-Plan',
      (tester) async {
    final base = TrainingPlan.fresh('Plan 1');
    final library = PlanLibrary(plans: [base], activePlanId: base.id);
    final fake = _CapturingPlanLibraryNotifier(library);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentCatalogProvider.overrideWith(() => _FakeCatalogNotifier()),
          planLibraryProvider.overrideWith(() => fake),
        ],
        child: const MaterialApp(
          home: EmomWizardScreen(planCount: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Der Katalog hat mittlerweile 4 Geräte-Typen; der Button liegt damit
    // unterhalb der Standard-Testviewport-Höhe und muss erst gescrollt werden.
    await tester.ensureVisible(find.text('Erstellen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    expect(fake.added.length, 1);
    expect(fake.added.single.intervals.length, 30);
    expect(
      fake.added.single.intervals.every((iv) => iv.durationSeconds == 60),
      isTrue,
    );
  });
}
