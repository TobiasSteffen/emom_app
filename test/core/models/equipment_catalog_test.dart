import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/equipment_catalog.dart';

void main() {
  group('EquipmentCatalog', () {
    test('defaultCatalog has 4 equipment types', () {
      final catalog = EquipmentCatalog.defaultCatalog();
      expect(catalog.types.length, 4);
      expect(catalog.types.map((t) => t.id).toList(),
          ['kettlebell', 'steelmace', 'pezziball', 'bodyweight']);
    });

    test('kettlebell has 3 variants and 5 exercises', () {
      final kb = EquipmentCatalog.defaultCatalog().types[0];
      expect(kb.variants.length, 3);
      expect(kb.exercises.length, 5);
    });

    test('push_press default is named "Press"', () {
      final kb = EquipmentCatalog.defaultCatalog().types[0];
      expect(kb.exercises.firstWhere((e) => e.id == 'push_press').name, 'Press');
    });

    test('clean_press default exists and is one-armed', () {
      final kb = EquipmentCatalog.defaultCatalog().types[0];
      final cp = kb.exercises.firstWhere((e) => e.id == 'clean_press');
      expect(cp.name, 'Clean & Press');
      expect(cp.hasSide, true);
    });

    test('bodyweight has no variants and 1 exercise', () {
      final bw = EquipmentCatalog.defaultCatalog().types[3];
      expect(bw.variants, isEmpty);
      expect(bw.exercises.length, 1);
      expect(bw.exercises.first.id, 'liegestuetz');
    });

    test('JSON roundtrip preserves all data', () {
      final catalog = EquipmentCatalog.defaultCatalog();
      final restored = EquipmentCatalog.fromJson(catalog.toJson());
      expect(restored.types.length, catalog.types.length);
      expect(restored.types[0].id, catalog.types[0].id);
      expect(restored.types[0].variants.length, catalog.types[0].variants.length);
      expect(restored.types[0].exercises.length, catalog.types[0].exercises.length);
      expect(restored.types[3].variants, isEmpty);
    });

    test('ExerciseType hasSide correct for einarmig exercises', () {
      final catalog = EquipmentCatalog.defaultCatalog();
      final kb = catalog.types[0];
      expect(kb.exercises.firstWhere((e) => e.id == 'swing_beidarmig').hasSide, false);
      expect(kb.exercises.firstWhere((e) => e.id == 'swing_einarmig').hasSide, true);
      expect(kb.exercises.firstWhere((e) => e.id == 'snatch').hasSide, true);
    });

    test('newId generates unique IDs', () {
      final id1 = EquipmentCatalog.newId();
      final id2 = EquipmentCatalog.newId();
      expect(id1, isNotEmpty);
      expect(id1, isNot(equals(id2)));
    });

    group('addMissingDefaults migration', () {
      test('adds bodyweight to catalog that lacks it', () {
        final old = EquipmentCatalog(types: [
          const EquipmentType(
            id: 'kettlebell',
            name: 'Kettlebell',
            iconAsset: 'assets/icon/kettlebell.png',
            variants: [],
            exercises: [],
          ),
        ]);
        final result = EquipmentCatalog.addMissingDefaults(old);
        expect(result.types.any((t) => t.id == 'bodyweight'), isTrue);
        expect(result.types.length, 4);
      });

      test('does not duplicate existing types', () {
        final full = EquipmentCatalog.defaultCatalog();
        final result = EquipmentCatalog.addMissingDefaults(full);
        expect(result.types.length, full.types.length);
      });

      test('preserves original type order', () {
        final old = EquipmentCatalog(types: [
          const EquipmentType(
            id: 'kettlebell',
            name: 'Kettlebell',
            iconAsset: 'assets/icon/kettlebell.png',
            variants: [],
            exercises: [],
          ),
        ]);
        final result = EquipmentCatalog.addMissingDefaults(old);
        expect(result.types.first.id, 'kettlebell');
      });
    });

    group('migrate', () {
      EquipmentCatalog legacyKettlebell(List<ExerciseType> exercises) =>
          EquipmentCatalog(types: [
            EquipmentType(
              id: 'kettlebell',
              name: 'Kettlebell',
              iconAsset: 'assets/icon/kettlebell.png',
              variants: const [],
              exercises: exercises,
            ),
          ]);

      test('renames legacy "Push Press" to "Press"', () {
        final old = legacyKettlebell(const [
          ExerciseType(id: 'push_press', name: 'Push Press', hasSide: true),
        ]);
        final result = EquipmentCatalog.migrate(old);
        final kb = result.findType('kettlebell')!;
        expect(kb.exercises.firstWhere((e) => e.id == 'push_press').name,
            'Press');
      });

      test('adds missing clean_press to existing kettlebell', () {
        final old = legacyKettlebell(const [
          ExerciseType(id: 'push_press', name: 'Press', hasSide: true),
        ]);
        final result = EquipmentCatalog.migrate(old);
        final kb = result.findType('kettlebell')!;
        final cp = kb.exercises.firstWhere((e) => e.id == 'clean_press');
        expect(cp.name, 'Clean & Press');
        expect(cp.hasSide, true);
      });

      test('is idempotent', () {
        final old = legacyKettlebell(const [
          ExerciseType(id: 'push_press', name: 'Push Press', hasSide: true),
        ]);
        final once = EquipmentCatalog.migrate(old);
        final twice = EquipmentCatalog.migrate(once);
        expect(twice.toJson(), once.toJson());
      });

      test('does not overwrite a user-renamed push_press', () {
        final old = legacyKettlebell(const [
          ExerciseType(id: 'push_press', name: 'Mein Press', hasSide: true),
        ]);
        final result = EquipmentCatalog.migrate(old);
        final kb = result.findType('kettlebell')!;
        expect(kb.exercises.firstWhere((e) => e.id == 'push_press').name,
            'Mein Press');
      });
    });
  });
}
