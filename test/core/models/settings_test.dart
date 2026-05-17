import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
  group('EquipmentX', () {
    test('isKettlebell: kb16/kb20/kb24 → true; sm8/sm12 → false', () {
      expect(Equipment.kb16.isKettlebell, isTrue);
      expect(Equipment.kb20.isKettlebell, isTrue);
      expect(Equipment.kb24.isKettlebell, isTrue);
      expect(Equipment.sm8.isKettlebell, isFalse);
      expect(Equipment.sm12.isKettlebell, isFalse);
    });

    test('label returns correct string for KB and SM variants', () {
      expect(Equipment.kb16.label, 'Kettlebell 16kg');
      expect(Equipment.kb20.label, 'Kettlebell 20kg');
      expect(Equipment.kb24.label, 'Kettlebell 24kg');
      expect(Equipment.sm8.label,  'Steel Mace 8kg');
      expect(Equipment.sm12.label, 'Steel Mace 12kg');
    });

    test('iconPath returns kettlebell.png for KB variants, steelmace.png for SM', () {
      expect(Equipment.kb16.iconPath, 'assets/icon/kettlebell.png');
      expect(Equipment.kb24.iconPath, 'assets/icon/kettlebell.png');
      expect(Equipment.sm8.iconPath, 'assets/icon/steelmace.png');
      expect(Equipment.sm12.iconPath, 'assets/icon/steelmace.png');
    });

    test('defaultExercise: KB → swingBeidarmig; SM → mace360', () {
      expect(Equipment.kb16.defaultExercise, Exercise.swingBeidarmig);
      expect(Equipment.kb24.defaultExercise, Exercise.swingBeidarmig);
      expect(Equipment.sm8.defaultExercise, Exercise.mace360);
      expect(Equipment.sm12.defaultExercise, Exercise.mace360);
    });

    test('validExercises: KB has 4 exercises; SM has 1', () {
      expect(Equipment.kb20.validExercises, [
        Exercise.swingBeidarmig,
        Exercise.swingEinarmig,
        Exercise.snatch,
        Exercise.pushPress,
      ]);
      expect(Equipment.sm8.validExercises, [Exercise.mace360]);
    });

    test('isPezziball: pb0/pb2_5/pb5/pb7_5/pb10 → true; KB/SM → false', () {
      expect(Equipment.pb0.isPezziball, isTrue);
      expect(Equipment.pb2_5.isPezziball, isTrue);
      expect(Equipment.pb5.isPezziball, isTrue);
      expect(Equipment.pb7_5.isPezziball, isTrue);
      expect(Equipment.pb10.isPezziball, isTrue);
      expect(Equipment.kb24.isPezziball, isFalse);
      expect(Equipment.sm12.isPezziball, isFalse);
    });

    test('label returns correct string for PB variants', () {
      expect(Equipment.pb0.label,   'Pezziball');
      expect(Equipment.pb2_5.label, 'Pezziball + 2,5kg');
      expect(Equipment.pb5.label,   'Pezziball + 5kg');
      expect(Equipment.pb7_5.label, 'Pezziball + 7,5kg');
      expect(Equipment.pb10.label,  'Pezziball + 10kg');
    });

    test('shortLabel returns weight-only for PB variants', () {
      expect(Equipment.pb0.shortLabel,   'ohne');
      expect(Equipment.pb2_5.shortLabel, '2,5 kg');
      expect(Equipment.pb5.shortLabel,   '5 kg');
      expect(Equipment.pb7_5.shortLabel, '7,5 kg');
      expect(Equipment.pb10.shortLabel,  '10 kg');
    });

    test('iconPath returns pezziball.png for PB variants', () {
      expect(Equipment.pb0.iconPath,  'assets/icon/pezziball.png');
      expect(Equipment.pb10.iconPath, 'assets/icon/pezziball.png');
    });

    test('defaultExercise: PB → myotatischerCrunch', () {
      expect(Equipment.pb0.defaultExercise,  Exercise.myotatischerCrunch);
      expect(Equipment.pb10.defaultExercise, Exercise.myotatischerCrunch);
    });

    test('validExercises: PB has exactly [myotatischerCrunch]', () {
      expect(Equipment.pb5.validExercises, [Exercise.myotatischerCrunch]);
    });
  });

  group('ExerciseX', () {
    test('label returns correct string', () {
      expect(Exercise.swingBeidarmig.label, 'Swing beidarmig');
      expect(Exercise.swingEinarmig.label, 'Swing einarmig');
      expect(Exercise.snatch.label, 'Snatch');
      expect(Exercise.pushPress.label, 'Push Press');
      expect(Exercise.mace360.label, '360s');
    });

    test('label: myotatischerCrunch returns correct string', () {
      expect(Exercise.myotatischerCrunch.label, 'Myotatischer Crunch');
    });

    test('isOneArm: swingEinarmig/snatch/pushPress → true; swingBeidarmig/mace360/myotatischerCrunch → false', () {
      expect(Exercise.swingEinarmig.isOneArm, isTrue);
      expect(Exercise.snatch.isOneArm, isTrue);
      expect(Exercise.pushPress.isOneArm, isTrue);
      expect(Exercise.swingBeidarmig.isOneArm, isFalse);
      expect(Exercise.mace360.isOneArm, isFalse);
      expect(Exercise.myotatischerCrunch.isOneArm, isFalse);
    });
  });

  group('ExerciseSideX', () {
    test('label returns Links/Rechts', () {
      expect(ExerciseSide.links.label, 'Links');
      expect(ExerciseSide.rechts.label, 'Rechts');
    });

    test('shortLabel returns L/R', () {
      expect(ExerciseSide.links.shortLabel, 'L');
      expect(ExerciseSide.rechts.shortLabel, 'R');
    });
  });
}
