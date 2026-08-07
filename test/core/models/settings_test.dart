import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  group('AppSettings.garminHeaderIconVisible', () {
    test('Default ist false', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      expect(settings.garminHeaderIconVisible, false);
    });

    test('wird gespeichert und beim Laden wiederhergestellt', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      settings.garminHeaderIconVisible = true;
      await settings.save();

      final reloaded = await AppSettings.load();
      expect(reloaded.garminHeaderIconVisible, true);
    });
  });
}
