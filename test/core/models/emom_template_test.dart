import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
  group('emomRepSequence', () {
    test('konstant liefert überall denselben Wert', () {
      final seq = emomRepSequence(EmomRepScheme.konstant,
          from: 10, to: 10, count: 30);
      expect(seq.length, 30);
      expect(seq.every((r) => r == 10), isTrue);
    });

    test('aufsteigend interpoliert von Start bis Ziel (nicht fallend)', () {
      final seq = emomRepSequence(EmomRepScheme.aufsteigend,
          from: 5, to: 15, count: 30);
      expect(seq.length, 30);
      expect(seq.first, 5);
      expect(seq.last, 15);
      for (var i = 0; i < seq.length - 1; i++) {
        expect(seq[i] <= seq[i + 1], isTrue);
      }
    });

    test('absteigend interpoliert von Start bis Ziel (nicht steigend)', () {
      final seq = emomRepSequence(EmomRepScheme.absteigend,
          from: 15, to: 5, count: 30);
      expect(seq.first, 15);
      expect(seq.last, 5);
      for (var i = 0; i < seq.length - 1; i++) {
        expect(seq[i] >= seq[i + 1], isTrue);
      }
    });

    test('pyramide steigt zum Peak und fällt zurück', () {
      final seq = emomRepSequence(EmomRepScheme.pyramide,
          from: 5, to: 15, count: 30);
      expect(seq.length, 30);
      expect(seq.first, 5);
      expect(seq.last, 5);
      expect(seq.reduce((a, b) => a > b ? a : b), 15);
    });

    test('rundet nie unter 1', () {
      final seq = emomRepSequence(EmomRepScheme.absteigend,
          from: 2, to: 1, count: 30);
      expect(seq.every((r) => r >= 1), isTrue);
    });
  });

  group('TrainingPlan.emom', () {
    test('erzeugt 30 Intervalle der gewählten Übung', () {
      final plan = TrainingPlan.emom(
        name: 'Swings',
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'swing_beidarmig',
        hasSide: false,
        isTimed: false,
        scheme: EmomRepScheme.konstant,
        fromReps: 10,
        toReps: 10,
      );
      expect(plan.name, 'Swings');
      expect(plan.intervals.length, 30);
      expect(plan.intervals.every((iv) => iv.equipmentTypeId == 'kettlebell'),
          isTrue);
      expect(plan.intervals.every((iv) => iv.variantId == 'kb_24'), isTrue);
      expect(
          plan.intervals.every((iv) => iv.exerciseTypeId == 'swing_beidarmig'),
          isTrue);
      expect(plan.intervals.every((iv) => iv.durationSeconds == 60), isTrue);
      expect(plan.intervals.every((iv) => iv.reps == 10), isTrue);
      expect(plan.intervals.every((iv) => iv.side == null), isTrue);
      expect(plan.intervals.every((iv) => iv.isPause == false), isTrue);
    });

    test('wechselt die Seite bei einarmigen Übungen', () {
      final plan = TrainingPlan.emom(
        name: 'Snatch',
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_20',
        exerciseTypeId: 'snatch',
        hasSide: true,
        isTimed: false,
        scheme: EmomRepScheme.konstant,
        fromReps: 8,
        toReps: 8,
      );
      expect(plan.intervals[0].side, ExerciseSide.links);
      expect(plan.intervals[1].side, ExerciseSide.rechts);
      expect(plan.intervals[2].side, ExerciseSide.links);
    });

    test('aufsteigendes Schema landet in den Wiederholungen', () {
      final plan = TrainingPlan.emom(
        name: 'Ramp',
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'swing_beidarmig',
        hasSide: false,
        isTimed: false,
        scheme: EmomRepScheme.aufsteigend,
        fromReps: 5,
        toReps: 15,
      );
      expect(plan.intervals.first.reps, 5);
      expect(plan.intervals.last.reps, 15);
    });

    test('Zeit-Übung ignoriert Schema und setzt reps auf 0', () {
      final plan = TrainingPlan.emom(
        name: 'Plank',
        equipmentTypeId: 'custom_bw',
        variantId: null,
        exerciseTypeId: 'plank',
        hasSide: false,
        isTimed: true,
        scheme: EmomRepScheme.aufsteigend,
        fromReps: 5,
        toReps: 15,
      );
      expect(plan.intervals.length, 30);
      expect(plan.intervals.every((iv) => iv.durationSeconds == 60), isTrue);
      expect(plan.intervals.every((iv) => iv.reps == 0), isTrue);
    });
  });
}
