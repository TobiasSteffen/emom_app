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

    test('label returns correct German string', () {
      expect(Equipment.kb16.label, 'KB 16kg');
      expect(Equipment.kb20.label, 'KB 20kg');
      expect(Equipment.kb24.label, 'KB 24kg');
      expect(Equipment.sm8.label, 'SM 8kg');
      expect(Equipment.sm12.label, 'SM 12kg');
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
  });

  group('ExerciseX', () {
    test('label returns correct string', () {
      expect(Exercise.swingBeidarmig.label, 'Swing beidarmig');
      expect(Exercise.swingEinarmig.label, 'Swing einarmig');
      expect(Exercise.snatch.label, 'Snatch');
      expect(Exercise.pushPress.label, 'Push Press');
      expect(Exercise.mace360.label, '360s');
    });
  });
}
