import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
  group('IntervalConfig.fromJson migration', () {
    test('v2 format: e=0 (kb16) + x=0 (swing_beidarmig)', () {
      final iv = IntervalConfig.fromJson({'r': 10, 'd': 60, 'e': 0, 'x': 0});
      expect(iv.equipmentTypeId, 'kettlebell');
      expect(iv.variantId, 'kb_16');
      expect(iv.exerciseTypeId, 'swing_beidarmig');
    });

    test('v2 format: e=2 (kb24) + x=2 (snatch)', () {
      final iv = IntervalConfig.fromJson({'r': 8, 'd': 60, 'e': 2, 'x': 2});
      expect(iv.equipmentTypeId, 'kettlebell');
      expect(iv.variantId, 'kb_24');
      expect(iv.exerciseTypeId, 'snatch');
    });

    test('v2 format: e=3 (sm8) + x=4 (mace_360)', () {
      final iv = IntervalConfig.fromJson({'r': 5, 'd': 60, 'e': 3, 'x': 4});
      expect(iv.equipmentTypeId, 'steelmace');
      expect(iv.variantId, 'sm_8');
      expect(iv.exerciseTypeId, 'mace_360');
    });

    test('v2 format: e=5 (pb0) + x=5 (myotatischer_crunch)', () {
      final iv = IntervalConfig.fromJson({'r': 12, 'd': 60, 'e': 5, 'x': 5});
      expect(iv.equipmentTypeId, 'pezziball');
      expect(iv.variantId, 'pb_0');
      expect(iv.exerciseTypeId, 'myotatischer_crunch');
    });

    test('v2 format: e=9 (pb10)', () {
      final iv = IntervalConfig.fromJson({'r': 10, 'd': 60, 'e': 9, 'x': 5});
      expect(iv.equipmentTypeId, 'pezziball');
      expect(iv.variantId, 'pb_10');
    });

    test('v1 format: e=0 (no x key) → kettlebell kb_24 swing_beidarmig', () {
      final iv = IntervalConfig.fromJson({'r': 10, 'd': 60, 'e': 0});
      expect(iv.equipmentTypeId, 'kettlebell');
      expect(iv.variantId, 'kb_24');
      expect(iv.exerciseTypeId, 'swing_beidarmig');
    });

    test('v1 format: e=1 (no x key) → steelmace sm_12 mace_360', () {
      final iv = IntervalConfig.fromJson({'r': 5, 'd': 60, 'e': 1});
      expect(iv.equipmentTypeId, 'steelmace');
      expect(iv.variantId, 'sm_12');
      expect(iv.exerciseTypeId, 'mace_360');
    });

    test('v3 new format roundtrip', () {
      final original = IntervalConfig(
        equipmentTypeId: 'bodyweight',
        variantId: null,
        exerciseTypeId: 'liegestuetz',
        reps: 15,
        durationSeconds: 60,
      );
      final restored = IntervalConfig.fromJson(original.toJson());
      expect(restored.equipmentTypeId, 'bodyweight');
      expect(restored.variantId, null);
      expect(restored.exerciseTypeId, 'liegestuetz');
      expect(restored.reps, 15);
    });

    test('v3 isPause roundtrip', () {
      final original = IntervalConfig(
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'swing_beidarmig',
        reps: 0,
        durationSeconds: 30,
        isPause: true,
      );
      final restored = IntervalConfig.fromJson(original.toJson());
      expect(restored.isPause, true);
    });

    test('v3 side roundtrip', () {
      final original = IntervalConfig(
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_20',
        exerciseTypeId: 'swing_einarmig',
        reps: 8,
        durationSeconds: 60,
        side: ExerciseSide.rechts,
      );
      final restored = IntervalConfig.fromJson(original.toJson());
      expect(restored.side, ExerciseSide.rechts);
    });
  });
}
