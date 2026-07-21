import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/equipment_catalog.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/providers/equipment_catalog_notifier.dart';
import 'package:emom_app/core/providers/plan_library_notifier.dart';
import 'package:emom_app/features/plans/plan_library_screen.dart';

class _FakeCatalogNotifier extends EquipmentCatalogNotifier {
  @override
  Future<EquipmentCatalog> build() async => EquipmentCatalog.defaultCatalog();
}

class _FakePlanLibraryNotifier extends PlanLibraryNotifier {
  final PlanLibrary initial;
  _FakePlanLibraryNotifier(this.initial);
  @override
  Future<PlanLibrary> build() async => initial;
}

void main() {
  testWidgets('Neuer Plan zeigt Auswahl Leer / Klassisches EMOM',
      (tester) async {
    final base = TrainingPlan.fresh('Plan 1');
    final library = PlanLibrary(plans: [base], activePlanId: base.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentCatalogProvider.overrideWith(() => _FakeCatalogNotifier()),
          planLibraryProvider
              .overrideWith(() => _FakePlanLibraryNotifier(library)),
        ],
        child: const MaterialApp(home: PlanLibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Neuer Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('Klassisches EMOM'), findsOneWidget);
  });
}
