import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/equipment_catalog.dart';
import 'plan_library_notifier.dart';

part 'equipment_catalog_notifier.g.dart';

@Riverpod(keepAlive: true)
class EquipmentCatalogNotifier extends _$EquipmentCatalogNotifier {
  @override
  Future<EquipmentCatalog> build() async => EquipmentCatalogStorage.load();

  Future<EquipmentCatalog> _current() async => await future;

  Future<void> _save(EquipmentCatalog catalog) async {
    state = AsyncData(catalog);
    await EquipmentCatalogStorage.save(catalog);
  }

  bool _equipmentUsedInPlans(String equipmentTypeId) {
    final library = ref.read(planLibraryProvider).value;
    if (library == null) return false;
    return library.plans.any((p) =>
        p.intervals.any((iv) => iv.equipmentTypeId == equipmentTypeId));
  }

  bool _variantUsedInPlans(String variantId) {
    final library = ref.read(planLibraryProvider).value;
    if (library == null) return false;
    return library.plans.any((p) =>
        p.intervals.any((iv) => iv.variantId == variantId));
  }

  bool _exerciseUsedInPlans(String exerciseId) {
    final library = ref.read(planLibraryProvider).value;
    if (library == null) return false;
    return library.plans.any((p) =>
        p.intervals.any((iv) => iv.exerciseTypeId == exerciseId));
  }

  Future<void> addEquipmentType(EquipmentType t) async {
    final catalog = await _current();
    await _save(EquipmentCatalog(types: [...catalog.types, t]));
  }

  Future<void> updateEquipmentType(EquipmentType updated) async {
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types
          .map((t) => t.id == updated.id ? updated : t)
          .toList(),
    ));
  }

  /// Throws [StateError] if equipment type is referenced in any plan interval.
  Future<void> deleteEquipmentType(String id) async {
    if (_equipmentUsedInPlans(id)) {
      throw StateError(
          'Equipment "$id" wird in einem Plan verwendet und kann nicht gelöscht werden.');
    }
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.where((t) => t.id != id).toList(),
    ));
  }

  Future<void> addVariant(String equipmentTypeId, EquipmentVariant v) async {
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id,
          name: t.name,
          iconAsset: t.iconAsset,
          variants: [...t.variants, v],
          exercises: t.exercises,
        );
      }).toList(),
    ));
  }

  Future<void> updateVariant(
      String equipmentTypeId, EquipmentVariant updated) async {
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id,
          name: t.name,
          iconAsset: t.iconAsset,
          variants: t.variants
              .map((v) => v.id == updated.id ? updated : v)
              .toList(),
          exercises: t.exercises,
        );
      }).toList(),
    ));
  }

  /// Throws [StateError] if variant is referenced in any plan interval.
  Future<void> deleteVariant(String equipmentTypeId, String variantId) async {
    if (_variantUsedInPlans(variantId)) {
      throw StateError(
          'Variante "$variantId" wird in einem Plan verwendet und kann nicht gelöscht werden.');
    }
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id,
          name: t.name,
          iconAsset: t.iconAsset,
          variants: t.variants.where((v) => v.id != variantId).toList(),
          exercises: t.exercises,
        );
      }).toList(),
    ));
  }

  Future<void> addExercise(String equipmentTypeId, ExerciseType e) async {
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id,
          name: t.name,
          iconAsset: t.iconAsset,
          variants: t.variants,
          exercises: [...t.exercises, e],
        );
      }).toList(),
    ));
  }

  Future<void> updateExercise(
      String equipmentTypeId, ExerciseType updated) async {
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id,
          name: t.name,
          iconAsset: t.iconAsset,
          variants: t.variants,
          exercises: t.exercises
              .map((e) => e.id == updated.id ? updated : e)
              .toList(),
        );
      }).toList(),
    ));
  }

  /// Throws [StateError] if exercise is referenced in any plan interval.
  Future<void> deleteExercise(
      String equipmentTypeId, String exerciseId) async {
    if (_exerciseUsedInPlans(exerciseId)) {
      throw StateError(
          'Übung "$exerciseId" wird in einem Plan verwendet und kann nicht gelöscht werden.');
    }
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id,
          name: t.name,
          iconAsset: t.iconAsset,
          variants: t.variants,
          exercises: t.exercises.where((e) => e.id != exerciseId).toList(),
        );
      }).toList(),
    ));
  }
}
