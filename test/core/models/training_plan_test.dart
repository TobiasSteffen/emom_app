import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
  group('IntervalConfig', () {
    test('serializes and deserializes correctly', () {
      final iv = IntervalConfig(reps: 10, durationSeconds: 45, equipment: Equipment.steelmace);
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.reps, 10);
      expect(restored.durationSeconds, 45);
      expect(restored.equipment, Equipment.steelmace);
    });

    test('copyWith overrides only specified fields', () {
      final iv = IntervalConfig(reps: 5, durationSeconds: 60, equipment: Equipment.kettlebell);
      final copy = iv.copyWith(reps: 8);
      expect(copy.reps, 8);
      expect(copy.durationSeconds, 60);
      expect(copy.equipment, Equipment.kettlebell);
    });
  });

  group('TrainingPlan', () {
    test('pyramid() creates 30 intervals with correct reps', () {
      final plan = TrainingPlan.pyramid('Test');
      expect(plan.intervals.length, 30);
      expect(plan.intervals[0].reps, 5);
      expect(plan.intervals[14].reps, 15);
      expect(plan.intervals[29].reps, 10);
    });

    test('totalReps sums all interval reps', () {
      final plan = TrainingPlan.pyramid('Test');
      const expected = 5*5 + (6+7+8+9+10+11+12+13+14+15) + 15*5 + (14+13+12+11+10) + 10*5;
      expect(plan.totalReps, expected);
    });

    test('totalDurationSeconds sums all intervals', () {
      final plan = TrainingPlan.pyramid('Test');
      expect(plan.totalDurationSeconds, 30 * 60);
    });

    test('planKey changes when a rep value changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].reps = 99;
      expect(plan.planKey, isNot(key1));
    });

    test('serializes and deserializes correctly', () {
      final plan = TrainingPlan.pyramid('Mein Plan');
      final restored = TrainingPlan.fromJson(plan.toJson());
      expect(restored.id, plan.id);
      expect(restored.name, 'Mein Plan');
      expect(restored.intervals.length, 30);
      expect(restored.intervals[0].reps, plan.intervals[0].reps);
    });
  });

  group('PlanLibrary', () {
    test('activePlan returns the plan matching activePlanId', () {
      final lib = PlanLibrary.defaultLibrary();
      expect(lib.activePlan.id, lib.activePlanId);
    });

    test('serializes and deserializes correctly', () {
      final lib = PlanLibrary.defaultLibrary();
      final restored = PlanLibrary.fromJson(lib.toJson());
      expect(restored.plans.length, 1);
      expect(restored.activePlanId, lib.activePlanId);
      expect(restored.activePlan.name, 'Standard');
    });
  });
}
