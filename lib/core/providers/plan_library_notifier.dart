import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/training_plan.dart';

part 'plan_library_notifier.g.dart';

@Riverpod(keepAlive: true)
class PlanLibraryNotifier extends _$PlanLibraryNotifier {
  @override
  Future<PlanLibrary> build() => PlanLibraryStorage.load();

  Future<void> setActivePlan(String id) async {
    final lib = state.requireValue;
    if (lib.activePlanId == id) return;
    final updated = PlanLibrary(plans: lib.plans, activePlanId: id);
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }

  Future<void> addPlan(TrainingPlan plan) async {
    final lib = state.requireValue;
    final updated = PlanLibrary(
      plans: [...lib.plans, plan],
      activePlanId: lib.activePlanId,
    );
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }

  Future<void> updatePlan(TrainingPlan plan) async {
    final lib = state.requireValue;
    final updatedPlans = lib.plans.map((p) => p.id == plan.id ? plan : p).toList();
    final updated = PlanLibrary(plans: updatedPlans, activePlanId: lib.activePlanId);
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }

  Future<void> deletePlan(String id) async {
    final lib = state.requireValue;
    if (lib.plans.length <= 1 || lib.activePlanId == id) return;
    final updatedPlans = lib.plans.where((p) => p.id != id).toList();
    final updated = PlanLibrary(plans: updatedPlans, activePlanId: lib.activePlanId);
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }

  Future<void> renamePlan(String id, String name) async {
    final lib = state.requireValue;
    final updatedPlans = lib.plans.map((p) {
      if (p.id != id) return p;
      return TrainingPlan(id: p.id, name: name, intervals: p.intervals);
    }).toList();
    final updated = PlanLibrary(plans: updatedPlans, activePlanId: lib.activePlanId);
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }
}
