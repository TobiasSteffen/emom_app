import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
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
