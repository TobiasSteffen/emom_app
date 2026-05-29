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

    test('kettlebell has 3 variants and 4 exercises', () {
      final kb = EquipmentCatalog.defaultCatalog().types[0];
      expect(kb.variants.length, 3);
      expect(kb.exercises.length, 4);
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
  });
}
