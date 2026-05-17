import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
  group('IntervalConfig', () {
    test('serializes and deserializes correctly', () {
      final iv = IntervalConfig(
        reps: 10,
        durationSeconds: 45,
        equipment: Equipment.sm12,
        exercise: Exercise.mace360,
      );
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.reps, 10);
      expect(restored.durationSeconds, 45);
      expect(restored.equipment, Equipment.sm12);
      expect(restored.exercise, Exercise.mace360);
    });

    test('copyWith overrides only specified fields', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
      );
      final copy = iv.copyWith(reps: 8);
      expect(copy.reps, 8);
      expect(copy.durationSeconds, 60);
      expect(copy.equipment, Equipment.kb24);
      expect(copy.exercise, Exercise.swingBeidarmig);
    });

    test('copyWith can override exercise', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
      );
      final copy = iv.copyWith(exercise: Exercise.snatch);
      expect(copy.exercise, Exercise.snatch);
      expect(copy.equipment, Equipment.kb24);
    });

    test('migration: old e=0 (kettlebell) → kb24 + swingBeidarmig', () {
      final json = {'r': 12, 'd': 60, 'e': 0}; // old format, no 'x' key
      final iv = IntervalConfig.fromJson(json);
      expect(iv.equipment, Equipment.kb24);
      expect(iv.exercise, Exercise.swingBeidarmig);
    });

    test('migration: old e=1 (steelmace) → sm12 + mace360', () {
      final json = {'r': 8, 'd': 60, 'e': 1}; // old format, no 'x' key
      final iv = IntervalConfig.fromJson(json);
      expect(iv.equipment, Equipment.sm12);
      expect(iv.exercise, Exercise.mace360);
    });

    test('new format with x key reads equipment and exercise correctly', () {
      final json = {'r': 15, 'd': 45, 'e': 1, 'x': 2}; // kb20, snatch
      final iv = IntervalConfig.fromJson(json);
      expect(iv.equipment, Equipment.kb20);
      expect(iv.exercise, Exercise.snatch);
    });

    test('side is null by default', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
      );
      expect(iv.side, isNull);
    });

    test('side serializes and deserializes correctly', () {
      final iv = IntervalConfig(
        reps: 8,
        durationSeconds: 45,
        equipment: Equipment.kb24,
        exercise: Exercise.swingEinarmig,
        side: ExerciseSide.rechts,
      );
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.side, ExerciseSide.rechts);
    });

    test('fromJson without side key gives null side', () {
      final json = {'r': 10, 'd': 60, 'e': 2, 'x': 1};
      final iv = IntervalConfig.fromJson(json);
      expect(iv.side, isNull);
    });

    test('copyWith can set side', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingEinarmig,
        side: ExerciseSide.links,
      );
      final copy = iv.copyWith(side: ExerciseSide.rechts);
      expect(copy.side, ExerciseSide.rechts);
      expect(copy.reps, 5);
    });

    test('copyWith clearSide removes side', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingEinarmig,
        side: ExerciseSide.links,
      );
      final copy = iv.copyWith(clearSide: true);
      expect(copy.side, isNull);
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

    test('pyramid() uses kb24 + swingBeidarmig as default', () {
      final plan = TrainingPlan.pyramid('Test');
      expect(plan.intervals[0].equipment, Equipment.kb24);
      expect(plan.intervals[0].exercise, Exercise.swingBeidarmig);
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

    test('planKey changes when exercise changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].exercise = Exercise.snatch;
      expect(plan.planKey, isNot(key1));
    });

    test('planKey changes when side changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].side = ExerciseSide.links;
      expect(plan.planKey, isNot(key1));
    });

    test('serializes and deserializes correctly', () {
      final plan = TrainingPlan.pyramid('Mein Plan');
      final restored = TrainingPlan.fromJson(plan.toJson());
      expect(restored.id, plan.id);
      expect(restored.name, 'Mein Plan');
      expect(restored.intervals.length, 30);
      expect(restored.intervals[0].reps, plan.intervals[0].reps);
      expect(restored.intervals[0].exercise, Exercise.swingBeidarmig);
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

    test('activePlan falls back to first plan when activePlanId unknown', () {
      final plan = TrainingPlan.pyramid('Test');
      final lib = PlanLibrary(plans: [plan], activePlanId: 'unknown-id');
      expect(lib.activePlan.id, plan.id);
    });
  });
}
