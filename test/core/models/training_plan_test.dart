import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

IntervalConfig _iv() => IntervalConfig(
      reps: 5,
      durationSeconds: 60,
      equipmentTypeId: 'kettlebell',
      variantId: 'kb_24',
      exerciseTypeId: 'swing_beidarmig',
    );

void main() {
  group('IntervalConfig', () {
    test('serializes and deserializes correctly', () {
      final iv = IntervalConfig(
        reps: 10,
        durationSeconds: 45,
        equipmentTypeId: 'steelmace',
        variantId: 'sm_12',
        exerciseTypeId: 'mace_360',
      );
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.reps, 10);
      expect(restored.durationSeconds, 45);
      expect(restored.equipmentTypeId, 'steelmace');
      expect(restored.variantId, 'sm_12');
      expect(restored.exerciseTypeId, 'mace_360');
    });

    test('copyWith overrides only specified fields', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'swing_beidarmig',
      );
      final copy = iv.copyWith(reps: 8);
      expect(copy.reps, 8);
      expect(copy.durationSeconds, 60);
      expect(copy.equipmentTypeId, 'kettlebell');
      expect(copy.variantId, 'kb_24');
      expect(copy.exerciseTypeId, 'swing_beidarmig');
    });

    test('copyWith can override exerciseTypeId', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'swing_beidarmig',
      );
      final copy = iv.copyWith(exerciseTypeId: 'snatch');
      expect(copy.exerciseTypeId, 'snatch');
      expect(copy.equipmentTypeId, 'kettlebell');
    });

    test('migration: old e=0 (kettlebell) → kettlebell + swing_beidarmig', () {
      final json = {'r': 12, 'd': 60, 'e': 0}; // old format, no 'x' key
      final iv = IntervalConfig.fromJson(json);
      expect(iv.equipmentTypeId, 'kettlebell');
      expect(iv.exerciseTypeId, 'swing_beidarmig');
    });

    test('migration: old e=1 (steelmace) → steelmace + mace_360', () {
      final json = {'r': 8, 'd': 60, 'e': 1}; // old format, no 'x' key
      final iv = IntervalConfig.fromJson(json);
      expect(iv.equipmentTypeId, 'steelmace');
      expect(iv.exerciseTypeId, 'mace_360');
    });

    test('new format with et key reads equipmentTypeId and exerciseTypeId correctly', () {
      final json = {'r': 15, 'd': 45, 'et': 'kettlebell', 'v': 'kb_20', 'x': 'snatch'};
      final iv = IntervalConfig.fromJson(json);
      expect(iv.equipmentTypeId, 'kettlebell');
      expect(iv.variantId, 'kb_20');
      expect(iv.exerciseTypeId, 'snatch');
    });

    test('side is null by default', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_beidarmig',
      );
      expect(iv.side, isNull);
    });

    test('side serializes and deserializes correctly', () {
      final iv = IntervalConfig(
        reps: 8,
        durationSeconds: 45,
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'swing_einarmig',
        side: ExerciseSide.rechts,
      );
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.side, ExerciseSide.rechts);
    });

    test('fromJson without side key gives null side', () {
      final json = {'r': 10, 'd': 60, 'et': 'kettlebell', 'x': 'swing_beidarmig'};
      final iv = IntervalConfig.fromJson(json);
      expect(iv.side, isNull);
    });

    test('copyWith can set side', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_einarmig',
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
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_einarmig',
        side: ExerciseSide.links,
      );
      final copy = iv.copyWith(clearSide: true);
      expect(copy.side, isNull);
    });

    test('isPause is false by default', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_beidarmig',
      );
      expect(iv.isPause, false);
    });

    test('isPause serializes and deserializes correctly', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_beidarmig',
        isPause: true,
      );
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.isPause, true);
    });

    test('fromJson without p key gives isPause = false', () {
      final json = {'r': 10, 'd': 60, 'et': 'kettlebell', 'x': 'swing_beidarmig'};
      final iv = IntervalConfig.fromJson(json);
      expect(iv.isPause, false);
    });

    test('copyWith can set isPause', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_beidarmig',
      );
      final paused = iv.copyWith(isPause: true);
      expect(paused.isPause, true);
      expect(paused.reps, 5);
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

    test('pyramid() uses kettlebell/kb_24/swing_beidarmig as default', () {
      final plan = TrainingPlan.pyramid('Test');
      expect(plan.intervals[0].equipmentTypeId, 'kettlebell');
      expect(plan.intervals[0].variantId, 'kb_24');
      expect(plan.intervals[0].exerciseTypeId, 'swing_beidarmig');
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

    test('planKey changes when exerciseTypeId changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].exerciseTypeId = 'snatch';
      expect(plan.planKey, isNot(key1));
    });

    test('planKey changes when side changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].side = ExerciseSide.links;
      expect(plan.planKey, isNot(key1));
    });

    test('planKey changes when isPause changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].isPause = true;
      expect(plan.planKey, isNot(key1));
    });

    test('serializes and deserializes correctly', () {
      final plan = TrainingPlan.pyramid('Mein Plan');
      final restored = TrainingPlan.fromJson(plan.toJson());
      expect(restored.id, plan.id);
      expect(restored.name, 'Mein Plan');
      expect(restored.intervals.length, 30);
      expect(restored.intervals[0].reps, plan.intervals[0].reps);
      expect(restored.intervals[0].exerciseTypeId, 'swing_beidarmig');
    });

    test('minIntervals is 3', () {
      expect(TrainingPlan.minIntervals, 3);
    });

    test('maxIntervals is 30', () {
      expect(TrainingPlan.maxIntervals, 30);
    });

    test('can create plan with 5 intervals', () {
      final intervals = List.generate(5, (_) => _iv());
      expect(
        () => TrainingPlan(id: 'x', name: 'test', intervals: intervals),
        returnsNormally,
      );
    });

    test('can create plan with 15 intervals', () {
      final intervals = List.generate(15, (_) => _iv());
      expect(
        () => TrainingPlan(id: 'x', name: 'test', intervals: intervals),
        returnsNormally,
      );
    });

    test('totalReps sums variable-length intervals', () {
      final intervals = List.generate(10, (_) => _iv());
      final plan = TrainingPlan(id: 'x', name: 'test', intervals: intervals);
      expect(plan.totalReps, 50);
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
