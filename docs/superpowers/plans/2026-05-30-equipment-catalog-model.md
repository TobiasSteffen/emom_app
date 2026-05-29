# Equipment Catalog Model Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hardcoded `Equipment`/`Exercise` enums with a dynamic `EquipmentCatalog` data model stored as JSON, migrating all existing data and consumers.

**Architecture:** New `EquipmentCatalog` model (immutable data classes) stored in `equipment_catalog.json`. `EquipmentCatalogNotifier` Riverpod provider follows the same pattern as `PlanLibraryNotifier`. `IntervalConfig` and `IntervalRecord` replace enum fields with String IDs. All consumers (workout, history, plan editor) read the catalog at runtime.

**Tech Stack:** Flutter/Dart, Riverpod with code generation (`riverpod_annotation`), `path_provider`, `shared_preferences` (unchanged)

---

## File Map

| File | Action |
|---|---|
| `lib/core/models/equipment_catalog.dart` | CREATE — model classes + storage + default catalog |
| `lib/core/providers/equipment_catalog_notifier.dart` | CREATE — Riverpod CRUD provider |
| `lib/core/providers/equipment_catalog_notifier.g.dart` | GENERATED — via build_runner |
| `lib/core/models/training_plan.dart` | MODIFY — IntervalConfig: String IDs, migration, copyWith, planKey, pyramid |
| `lib/core/models/workout_history.dart` | MODIFY — IntervalRecord: String IDs, migration; WorkoutRecord: remove KB/SM computed props |
| `lib/features/workout/workout_notifier.dart` | MODIFY — read catalog, workoutLabelForMinute, iconAssetForMinute, _onMinuteComplete |
| `lib/features/workout/workout_screen.dart` | MODIFY — iconPath via iconAssetForMinute |
| `lib/features/shared/widgets/interval_edit_form.dart` | MODIFY — ConsumerStatefulWidget, reads catalog |
| `lib/features/workout/widgets/next_minute_preview.dart` | MODIFY — ConsumerWidget, reads catalog |
| `lib/features/history/history_detail_sheet.dart` | MODIFY — _repBreakdown uses catalog, _toConfig/_toRecord use String IDs |
| `lib/features/history/history_sheet.dart` | MODIFY — simplified _buildCard (remove KB/SM split) |
| `lib/core/models/settings.dart` | MODIFY — remove Equipment/Exercise enums (keep ExerciseSide, phaseColorForMinute, AppSettings) |
| `test/core/models/equipment_catalog_test.dart` | CREATE — unit tests |
| `test/core/models/interval_config_migration_test.dart` | CREATE — migration unit tests |

---

## Constant IDs (used throughout)

Equipment type IDs: `"kettlebell"`, `"steelmace"`, `"pezziball"`, `"bodyweight"`

Variant IDs: `"kb_16"`, `"kb_20"`, `"kb_24"`, `"sm_8"`, `"sm_12"`, `"pb_0"`, `"pb_2_5"`, `"pb_5"`, `"pb_7_5"`, `"pb_10"`

Exercise IDs: `"swing_beidarmig"`, `"swing_einarmig"`, `"snatch"`, `"push_press"`, `"mace_360"`, `"schulter_heben"`, `"myotatischer_crunch"`, `"liegestuetz"`

---

## Task 1: Create `equipment_catalog.dart`

**Files:**
- Create: `lib/core/models/equipment_catalog.dart`
- Create: `test/core/models/equipment_catalog_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/core/models/equipment_catalog_test.dart
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
```

- [ ] **Step 2: Run tests — expect FAIL (file not found)**

```
flutter test test/core/models/equipment_catalog_test.dart
```

Expected: compile error — `equipment_catalog.dart` not found.

- [ ] **Step 3: Create `lib/core/models/equipment_catalog.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

class ExerciseType {
  final String id;
  final String name;
  final bool hasSide;

  const ExerciseType({required this.id, required this.name, required this.hasSide});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'hasSide': hasSide};

  factory ExerciseType.fromJson(Map<String, dynamic> j) => ExerciseType(
        id: j['id'] as String,
        name: j['name'] as String,
        hasSide: j['hasSide'] as bool,
      );
}

class EquipmentVariant {
  final String id;
  final String label;
  final String shortLabel;

  const EquipmentVariant({required this.id, required this.label, required this.shortLabel});

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'shortLabel': shortLabel};

  factory EquipmentVariant.fromJson(Map<String, dynamic> j) => EquipmentVariant(
        id: j['id'] as String,
        label: j['label'] as String,
        shortLabel: j['shortLabel'] as String,
      );
}

class EquipmentType {
  final String id;
  final String name;
  final String iconAsset;
  final List<EquipmentVariant> variants;
  final List<ExerciseType> exercises;

  const EquipmentType({
    required this.id,
    required this.name,
    required this.iconAsset,
    required this.variants,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconAsset': iconAsset,
        'variants': variants.map((v) => v.toJson()).toList(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory EquipmentType.fromJson(Map<String, dynamic> j) => EquipmentType(
        id: j['id'] as String,
        name: j['name'] as String,
        iconAsset: j['iconAsset'] as String,
        variants: (j['variants'] as List)
            .map((v) => EquipmentVariant.fromJson(v as Map<String, dynamic>))
            .toList(),
        exercises: (j['exercises'] as List)
            .map((e) => ExerciseType.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class EquipmentCatalog {
  final List<EquipmentType> types;

  const EquipmentCatalog({required this.types});

  static String newId() {
    final r = Random();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  EquipmentType? findType(String id) {
    try {
      return types.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'types': types.map((t) => t.toJson()).toList(),
      };

  factory EquipmentCatalog.fromJson(Map<String, dynamic> j) => EquipmentCatalog(
        types: (j['types'] as List)
            .map((t) => EquipmentType.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  static EquipmentCatalog defaultCatalog() => const EquipmentCatalog(types: [
        EquipmentType(
          id: 'kettlebell',
          name: 'Kettlebell',
          iconAsset: 'assets/icon/kettlebell.png',
          variants: [
            EquipmentVariant(id: 'kb_16', label: '16 kg', shortLabel: '16 kg'),
            EquipmentVariant(id: 'kb_20', label: '20 kg', shortLabel: '20 kg'),
            EquipmentVariant(id: 'kb_24', label: '24 kg', shortLabel: '24 kg'),
          ],
          exercises: [
            ExerciseType(id: 'swing_beidarmig', name: 'Swing beidarmig', hasSide: false),
            ExerciseType(id: 'swing_einarmig', name: 'Swing einarmig', hasSide: true),
            ExerciseType(id: 'snatch', name: 'Snatch', hasSide: true),
            ExerciseType(id: 'push_press', name: 'Push Press', hasSide: true),
          ],
        ),
        EquipmentType(
          id: 'steelmace',
          name: 'Steel Mace',
          iconAsset: 'assets/icon/steelmace.png',
          variants: [
            EquipmentVariant(id: 'sm_8', label: '8 kg', shortLabel: '8 kg'),
            EquipmentVariant(id: 'sm_12', label: '12 kg', shortLabel: '12 kg'),
          ],
          exercises: [
            ExerciseType(id: 'mace_360', name: '360s', hasSide: true),
            ExerciseType(id: 'schulter_heben', name: 'Schulterheben', hasSide: true),
          ],
        ),
        EquipmentType(
          id: 'pezziball',
          name: 'Pezziball',
          iconAsset: 'assets/icon/pezziball.png',
          variants: [
            EquipmentVariant(id: 'pb_0', label: 'ohne', shortLabel: 'ohne'),
            EquipmentVariant(id: 'pb_2_5', label: '+2,5 kg', shortLabel: '+2,5 kg'),
            EquipmentVariant(id: 'pb_5', label: '+5 kg', shortLabel: '+5 kg'),
            EquipmentVariant(id: 'pb_7_5', label: '+7,5 kg', shortLabel: '+7,5 kg'),
            EquipmentVariant(id: 'pb_10', label: '+10 kg', shortLabel: '+10 kg'),
          ],
          exercises: [
            ExerciseType(id: 'myotatischer_crunch', name: 'Myotatischer Crunch', hasSide: false),
          ],
        ),
        EquipmentType(
          id: 'bodyweight',
          name: 'Körpergewicht',
          iconAsset: 'assets/icon/liegestuetz.png',
          variants: [],
          exercises: [
            ExerciseType(id: 'liegestuetz', name: 'Liegestütz', hasSide: false),
          ],
        ),
      ]);
}

class EquipmentCatalogStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/equipment_catalog.json');
  }

  static Future<EquipmentCatalog> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        final catalog = EquipmentCatalog.defaultCatalog();
        await save(catalog);
        return catalog;
      }
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return EquipmentCatalog.fromJson(json);
    } catch (_) {
      return EquipmentCatalog.defaultCatalog();
    }
  }

  static Future<void> save(EquipmentCatalog catalog) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(catalog.toJson()));
    } catch (_) {}
  }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```
flutter test test/core/models/equipment_catalog_test.dart
```

Expected: `+6: All tests passed!`

- [ ] **Step 5: Commit**

```
git add lib/core/models/equipment_catalog.dart test/core/models/equipment_catalog_test.dart
git commit -m "feat: add EquipmentCatalog model with default catalog and JSON storage"
```

---

## Task 2: Create `equipment_catalog_notifier.dart`

**Files:**
- Create: `lib/core/providers/equipment_catalog_notifier.dart`

- [ ] **Step 1: Create the notifier**

```dart
// lib/core/providers/equipment_catalog_notifier.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/equipment_catalog.dart';
import '../models/training_plan.dart';
import 'plan_library_notifier.dart';

part 'equipment_catalog_notifier.g.dart';

@Riverpod(keepAlive: true)
class EquipmentCatalogNotifier extends _$EquipmentCatalogNotifier {
  @override
  Future<EquipmentCatalog> build() async => EquipmentCatalogStorage.load();

  Future<EquipmentCatalog> _current() async =>
      await future;

  Future<void> _save(EquipmentCatalog catalog) async {
    state = AsyncData(catalog);
    await EquipmentCatalogStorage.save(catalog);
  }

  bool _equipmentUsedInPlans(String equipmentTypeId) {
    final library = ref.read(planLibraryProvider).valueOrNull;
    if (library == null) return false;
    return library.plans.any((p) =>
        p.intervals.any((iv) => iv.equipmentTypeId == equipmentTypeId));
  }

  bool _variantUsedInPlans(String variantId) {
    final library = ref.read(planLibraryProvider).valueOrNull;
    if (library == null) return false;
    return library.plans.any((p) =>
        p.intervals.any((iv) => iv.variantId == variantId));
  }

  bool _exerciseUsedInPlans(String exerciseId) {
    final library = ref.read(planLibraryProvider).valueOrNull;
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
      types: catalog.types.map((t) => t.id == updated.id ? updated : t).toList(),
    ));
  }

  /// Throws [StateError] if equipment type is referenced in any plan interval.
  Future<void> deleteEquipmentType(String id) async {
    if (_equipmentUsedInPlans(id)) {
      throw StateError('Equipment "$id" wird in einem Plan verwendet und kann nicht gelöscht werden.');
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
          id: t.id, name: t.name, iconAsset: t.iconAsset,
          variants: [...t.variants, v],
          exercises: t.exercises,
        );
      }).toList(),
    ));
  }

  Future<void> updateVariant(String equipmentTypeId, EquipmentVariant updated) async {
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id, name: t.name, iconAsset: t.iconAsset,
          variants: t.variants.map((v) => v.id == updated.id ? updated : v).toList(),
          exercises: t.exercises,
        );
      }).toList(),
    ));
  }

  /// Throws [StateError] if variant is referenced in any plan interval.
  Future<void> deleteVariant(String equipmentTypeId, String variantId) async {
    if (_variantUsedInPlans(variantId)) {
      throw StateError('Variante "$variantId" wird in einem Plan verwendet und kann nicht gelöscht werden.');
    }
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id, name: t.name, iconAsset: t.iconAsset,
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
          id: t.id, name: t.name, iconAsset: t.iconAsset,
          variants: t.variants,
          exercises: [...t.exercises, e],
        );
      }).toList(),
    ));
  }

  Future<void> updateExercise(String equipmentTypeId, ExerciseType updated) async {
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id, name: t.name, iconAsset: t.iconAsset,
          variants: t.variants,
          exercises: t.exercises.map((e) => e.id == updated.id ? updated : e).toList(),
        );
      }).toList(),
    ));
  }

  /// Throws [StateError] if exercise is referenced in any plan interval.
  Future<void> deleteExercise(String equipmentTypeId, String exerciseId) async {
    if (_exerciseUsedInPlans(exerciseId)) {
      throw StateError('Übung "$exerciseId" wird in einem Plan verwendet und kann nicht gelöscht werden.');
    }
    final catalog = await _current();
    await _save(EquipmentCatalog(
      types: catalog.types.map((t) {
        if (t.id != equipmentTypeId) return t;
        return EquipmentType(
          id: t.id, name: t.name, iconAsset: t.iconAsset,
          variants: t.variants,
          exercises: t.exercises.where((e) => e.id != exerciseId).toList(),
        );
      }).toList(),
    ));
  }
}
```

- [ ] **Step 2: Regenerate `.g.dart` files**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `equipment_catalog_notifier.g.dart` created. No errors.

- [ ] **Step 3: Verify compilation**

```
flutter analyze lib/core/providers/equipment_catalog_notifier.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```
git add lib/core/providers/equipment_catalog_notifier.dart lib/core/providers/equipment_catalog_notifier.g.dart
git commit -m "feat: add EquipmentCatalogNotifier Riverpod provider with CRUD and blocked-delete"
```

---

## Task 3: Migrate `IntervalConfig` in `training_plan.dart`

**Files:**
- Modify: `lib/core/models/training_plan.dart`
- Create: `test/core/models/interval_config_migration_test.dart`

- [ ] **Step 1: Write failing migration tests**

```dart
// test/core/models/interval_config_migration_test.dart
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
```

- [ ] **Step 2: Run tests — expect FAIL**

```
flutter test test/core/models/interval_config_migration_test.dart
```

Expected: compile error — `IntervalConfig` still has old `Equipment`/`Exercise` fields.

- [ ] **Step 3: Replace `IntervalConfig` in `training_plan.dart`**

Replace the entire `IntervalConfig` class (lines 7–77) with:

```dart
class IntervalConfig {
  String equipmentTypeId;
  String? variantId;
  String exerciseTypeId;
  ExerciseSide? side;
  int reps;
  int durationSeconds;
  bool isPause;

  IntervalConfig({
    required this.equipmentTypeId,
    required this.exerciseTypeId,
    required this.reps,
    required this.durationSeconds,
    this.variantId,
    this.side,
    this.isPause = false,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'r': reps,
      'd': durationSeconds,
      'et': equipmentTypeId,
      'x': exerciseTypeId,
    };
    if (variantId != null) m['v'] = variantId;
    if (side != null) m['s'] = side!.index;
    if (isPause) m['p'] = 1;
    return m;
  }

  factory IntervalConfig.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('et')) {
      // v3: new format with string IDs
      final sideIdx = j['s'] as int?;
      return IntervalConfig(
        reps: j['r'] as int,
        durationSeconds: j['d'] as int,
        equipmentTypeId: j['et'] as String,
        variantId: j['v'] as String?,
        exerciseTypeId: j['x'] as String,
        side: sideIdx != null ? ExerciseSide.values.elementAtOrNull(sideIdx) : null,
        isPause: (j['p'] as int?) == 1,
      );
    }
    final eIdx = j['e'] as int;
    if (!j.containsKey('x')) {
      // v1: only e key, two possible values
      return IntervalConfig(
        reps: j['r'] as int,
        durationSeconds: j['d'] as int,
        equipmentTypeId: eIdx == 0 ? 'kettlebell' : 'steelmace',
        variantId: eIdx == 0 ? 'kb_24' : 'sm_12',
        exerciseTypeId: eIdx == 0 ? 'swing_beidarmig' : 'mace_360',
      );
    }
    // v2: e = Equipment enum index, x = Exercise enum index (both ints)
    final xIdx = j['x'] as int;
    final sideIdx = j['s'] as int?;
    return IntervalConfig(
      reps: j['r'] as int,
      durationSeconds: j['d'] as int,
      equipmentTypeId: _migrateEqType(eIdx),
      variantId: _migrateVariant(eIdx),
      exerciseTypeId: _migrateExercise(xIdx),
      side: sideIdx != null ? ExerciseSide.values.elementAtOrNull(sideIdx) : null,
      isPause: (j['p'] as int?) == 1,
    );
  }

  static String _migrateEqType(int e) => switch (e) {
    0 || 1 || 2 => 'kettlebell',
    3 || 4       => 'steelmace',
    _            => 'pezziball',
  };

  static String? _migrateVariant(int e) => switch (e) {
    0 => 'kb_16',
    1 => 'kb_20',
    2 => 'kb_24',
    3 => 'sm_8',
    4 => 'sm_12',
    5 => 'pb_0',
    6 => 'pb_2_5',
    7 => 'pb_5',
    8 => 'pb_7_5',
    9 => 'pb_10',
    _ => null,
  };

  static String _migrateExercise(int x) => switch (x) {
    0 => 'swing_beidarmig',
    1 => 'swing_einarmig',
    2 => 'snatch',
    3 => 'push_press',
    4 => 'mace_360',
    5 => 'myotatischer_crunch',
    6 => 'schulter_heben',
    _ => 'swing_beidarmig',
  };

  IntervalConfig copyWith({
    String? equipmentTypeId,
    String? variantId,
    bool clearVariant = false,
    String? exerciseTypeId,
    ExerciseSide? side,
    bool clearSide = false,
    int? reps,
    int? durationSeconds,
    bool? isPause,
  }) =>
      IntervalConfig(
        equipmentTypeId: equipmentTypeId ?? this.equipmentTypeId,
        variantId: clearVariant ? null : (variantId ?? this.variantId),
        exerciseTypeId: exerciseTypeId ?? this.exerciseTypeId,
        side: clearSide ? null : (side ?? this.side),
        reps: reps ?? this.reps,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        isPause: isPause ?? this.isPause,
      );
}
```

- [ ] **Step 4: Update `TrainingPlan.planKey` and `TrainingPlan.pyramid` in the same file**

Replace `planKey` getter:
```dart
String get planKey => intervals
    .map((iv) =>
        '${iv.reps},${iv.durationSeconds},${iv.equipmentTypeId},${iv.variantId ?? ''},${iv.exerciseTypeId},${iv.side?.index ?? -1},${iv.isPause ? 1 : 0}')
    .join('|');
```

Replace `pyramid` factory:
```dart
factory TrainingPlan.pyramid(String name) {
  final reps = _pyramidReps();
  return TrainingPlan(
    id: _newId(),
    name: name,
    intervals: List.generate(30, (i) => IntervalConfig(
      equipmentTypeId: 'kettlebell',
      variantId: 'kb_24',
      exerciseTypeId: 'swing_beidarmig',
      reps: reps[i],
      durationSeconds: 60,
    )),
  );
}
```

Also remove the `import 'settings.dart';` line if `Equipment`/`Exercise` were the only things used from it. Keep `ExerciseSide` import — check if `settings.dart` still exports it (it will after Task 9). Keep the import.

- [ ] **Step 5: Run migration tests — expect PASS**

```
flutter test test/core/models/interval_config_migration_test.dart
```

Expected: `+10: All tests passed!`

- [ ] **Step 6: Commit**

```
git add lib/core/models/training_plan.dart test/core/models/interval_config_migration_test.dart
git commit -m "feat: migrate IntervalConfig from Equipment/Exercise enums to String IDs with v1/v2/v3 format migration"
```

---

## Task 4: Migrate `IntervalRecord` in `workout_history.dart`

**Files:**
- Modify: `lib/core/models/workout_history.dart`

- [ ] **Step 1: Replace `IntervalRecord` class**

Replace the entire `IntervalRecord` class with:

```dart
class IntervalRecord {
  final int reps;
  final int durationSeconds;
  final String equipmentTypeId;
  final String? variantId;
  final String exerciseTypeId;
  final ExerciseSide? side;
  final bool isPause;

  IntervalRecord({
    required this.reps,
    required this.durationSeconds,
    required this.equipmentTypeId,
    required this.exerciseTypeId,
    this.variantId,
    this.side,
    this.isPause = false,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'r': reps,
      'd': durationSeconds,
      'et': equipmentTypeId,
      'x': exerciseTypeId,
    };
    if (variantId != null) m['v'] = variantId;
    if (side != null) m['s'] = side!.index;
    if (isPause) m['p'] = true;
    return m;
  }

  factory IntervalRecord.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('et')) {
      // New format
      final sideIdx = j['s'] as int?;
      return IntervalRecord(
        reps: j['r'] as int,
        durationSeconds: j['d'] as int,
        equipmentTypeId: j['et'] as String,
        variantId: j['v'] as String?,
        exerciseTypeId: j['x'] as String,
        side: sideIdx != null ? ExerciseSide.values.elementAtOrNull(sideIdx) : null,
        isPause: (j['p'] as bool?) ?? false,
      );
    }
    // Old format: e = Equipment index, x = Exercise index
    final eIdx = j['e'] as int;
    final xIdx = (j['x'] as int?) ?? 0;
    final sideIdx = j['s'] as int?;
    return IntervalRecord(
      reps: j['r'] as int,
      durationSeconds: j['d'] as int,
      equipmentTypeId: IntervalConfig._migrateEqType(eIdx),
      variantId: IntervalConfig._migrateVariant(eIdx),
      exerciseTypeId: IntervalConfig._migrateExercise(xIdx),
      side: sideIdx != null ? ExerciseSide.values.elementAtOrNull(sideIdx) : null,
      isPause: (j['p'] as bool?) ?? false,
    );
  }
}
```

**Note:** `IntervalRecord.fromJson` reuses `IntervalConfig._migrateEqType/Variant/Exercise` static helpers. Since `IntervalRecord` is in the same package, this is fine — but the methods are `static` on `IntervalConfig` in `training_plan.dart`. Make those helpers package-accessible (they already are, since Dart has no private-to-file access for static methods without underscore prefix in the name). Rename them without leading `_` in `training_plan.dart`:

In `training_plan.dart`, rename (replace all 3):
- `_migrateEqType` → `migrateEqType`
- `_migrateVariant` → `migrateVariant`
- `_migrateExercise` → `migrateExercise`

And update the 3 call sites in `fromJson` within `training_plan.dart` accordingly.

- [ ] **Step 2: Update `WorkoutRecord` — remove KB/SM computed properties**

In `WorkoutRecord`, remove `kettlebellReps` and `steelMaceReps` getters. The class becomes:

```dart
class WorkoutRecord {
  final int timestamp;
  final int planMode;
  final List<IntervalRecord> intervals;

  WorkoutRecord({
    required this.timestamp,
    required this.planMode,
    required this.intervals,
  });

  int get totalReps => intervals.fold(0, (a, b) => a + b.reps);
  int get totalDurationSeconds => intervals.fold(0, (a, b) => a + b.durationSeconds);

  Map<String, dynamic> toJson() => {
        't': timestamp,
        'pm': planMode,
        'iv': intervals.map((i) => i.toJson()).toList(),
      };

  factory WorkoutRecord.fromJson(Map<String, dynamic> j) => WorkoutRecord(
        timestamp: j['t'] as int,
        planMode: j['pm'] as int,
        intervals: (j['iv'] as List)
            .map((e) => IntervalRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 3: Verify compilation of workout_history.dart**

```
flutter analyze lib/core/models/workout_history.dart
```

Expected: `No issues found!` (some errors in consumers are expected — fix in later tasks)

- [ ] **Step 4: Commit**

```
git add lib/core/models/workout_history.dart lib/core/models/training_plan.dart
git commit -m "feat: migrate IntervalRecord to String IDs, remove kettlebellReps/steelMaceReps from WorkoutRecord"
```

---

## Task 5: Update `workout_notifier.dart`

**Files:**
- Modify: `lib/features/workout/workout_notifier.dart`

- [ ] **Step 1: Add catalog field and load in `build()`**

Add import at top:
```dart
import '../../core/models/equipment_catalog.dart';
import '../../core/providers/equipment_catalog_notifier.dart';
```

Add field to `WorkoutNotifier`:
```dart
late EquipmentCatalog _catalog;
```

In `build()`, add after `_activePlan = library.activePlan;`:
```dart
_catalog = await ref.read(equipmentCatalogProvider.future);
```

In `reset()`, add after `_activePlan = library.activePlan;`:
```dart
_catalog = await ref.read(equipmentCatalogProvider.future);
```

- [ ] **Step 2: Replace `equipmentForMinute` with `iconAssetForMinute`**

Remove:
```dart
Equipment equipmentForMinute(int minute) =>
    _activePlan.intervals[minute].equipment;
```

Add:
```dart
String iconAssetForMinute(int minute) {
  final iv = _activePlan.intervals[minute];
  return _catalog.findType(iv.equipmentTypeId)?.iconAsset ??
      'assets/icon/kettlebell.png';
}
```

- [ ] **Step 3: Replace `workoutLabelForMinute`**

```dart
String workoutLabelForMinute(int minute) {
  final iv = _activePlan.intervals[minute];
  if (iv.isPause) return 'Pause';
  final eqType = _catalog.findType(iv.equipmentTypeId);
  if (eqType == null) return '?';
  final variant = iv.variantId != null
      ? eqType.variants.where((v) => v.id == iv.variantId).firstOrNull
      : null;
  final exercise = eqType.exercises.where((e) => e.id == iv.exerciseTypeId).firstOrNull;
  final sideStr = (exercise?.hasSide == true && iv.side != null)
      ? ' · ${iv.side!.label}'
      : '';
  final equipStr = variant != null ? '${eqType.name} ${variant.label}' : eqType.name;
  return '$equipStr · ${exercise?.name ?? '?'}$sideStr';
}
```

- [ ] **Step 4: Fix `_onMinuteComplete` — update `IntervalRecord` constructor**

Replace the `IntervalRecord(...)` call in `_onMinuteComplete`:
```dart
IntervalRecord(
  reps: s.currentReps,
  durationSeconds: s.currentDuration,
  equipmentTypeId: _activePlan.intervals[s.currentMinute].equipmentTypeId,
  variantId: _activePlan.intervals[s.currentMinute].variantId,
  exerciseTypeId: _activePlan.intervals[s.currentMinute].exerciseTypeId,
  side: _activePlan.intervals[s.currentMinute].side,
  isPause: _activePlan.intervals[s.currentMinute].isPause,
),
```

- [ ] **Step 5: Verify**

```
flutter analyze lib/features/workout/workout_notifier.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```
git add lib/features/workout/workout_notifier.dart
git commit -m "feat: update WorkoutNotifier to use EquipmentCatalog for labels and icon asset"
```

---

## Task 6: Update `workout_screen.dart` and `next_minute_preview.dart`

**Files:**
- Modify: `lib/features/workout/workout_screen.dart`
- Modify: `lib/features/workout/widgets/next_minute_preview.dart`

- [ ] **Step 1: Fix `workout_screen.dart` line 230**

Find:
```dart
final iconPath = notifier.equipmentForMinute(state.currentMinute).iconPath;
```

Replace with:
```dart
final iconPath = notifier.iconAssetForMinute(state.currentMinute);
```

- [ ] **Step 2: Rewrite `next_minute_preview.dart` as ConsumerWidget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';
import '../../../core/providers/equipment_catalog_notifier.dart';

class NextMinutePreview extends ConsumerWidget {
  final IntervalConfig interval;

  const NextMinutePreview({super.key, required this.interval});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const style = TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1);

    if (interval.isPause) {
      return Text('Nächste: PAUSE · ${interval.durationSeconds}s', style: style);
    }

    final catalogAsync = ref.watch(equipmentCatalogProvider);
    return catalogAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (catalog) {
        final eqType = catalog.findType(interval.equipmentTypeId);
        if (eqType == null) return const SizedBox();
        final variant = interval.variantId != null
            ? eqType.variants.where((v) => v.id == interval.variantId).firstOrNull
            : null;
        final exercise = eqType.exercises
            .where((e) => e.id == interval.exerciseTypeId)
            .firstOrNull;
        final equipLabel = variant != null
            ? '${eqType.name} ${variant.label}'
            : eqType.name;
        final exerciseLabel = interval.side != null
            ? '${exercise?.name ?? '?'} ${interval.side!.shortLabel}'
            : (exercise?.name ?? '?');
        final parts = [equipLabel, exerciseLabel, '${interval.reps}W', '${interval.durationSeconds}s'];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(eqType.iconAsset, width: 12, height: 12, color: Colors.white38),
            const SizedBox(width: 5),
            Text(parts.join(' · '), style: style),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 3: Verify**

```
flutter analyze lib/features/workout/workout_screen.dart lib/features/workout/widgets/next_minute_preview.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```
git add lib/features/workout/workout_screen.dart lib/features/workout/widgets/next_minute_preview.dart
git commit -m "feat: update workout screen and NextMinutePreview to use equipment catalog"
```

---

## Task 7: Rewrite `interval_edit_form.dart`

**Files:**
- Modify: `lib/features/shared/widgets/interval_edit_form.dart`

- [ ] **Step 1: Change to ConsumerStatefulWidget and rewrite build method**

Replace the entire file content with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';
import '../../../core/models/equipment_catalog.dart';
import '../../../core/providers/equipment_catalog_notifier.dart';

Widget _stepButton(IconData icon, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null ? Colors.white38 : Colors.white12),
      ),
    );

class IntervalEditForm extends ConsumerStatefulWidget {
  final IntervalConfig iv;
  final VoidCallback onChanged;
  final int? index;
  final VoidCallback? onCollapse;
  final VoidCallback? onBeforeChange;

  const IntervalEditForm({
    super.key,
    required this.iv,
    required this.onChanged,
    this.index,
    this.onCollapse,
    this.onBeforeChange,
  });

  @override
  ConsumerState<IntervalEditForm> createState() => _IntervalEditFormState();
}

class _IntervalEditFormState extends ConsumerState<IntervalEditForm> {
  String? _openPicker;

  void _update(VoidCallback fn) {
    widget.onBeforeChange?.call();
    setState(fn);
    widget.onChanged();
  }

  void _togglePicker(String picker) {
    setState(() => _openPicker = _openPicker == picker ? null : picker);
  }

  Widget _pickerChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF6B00) : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(6),
            border: selected ? null : Border.all(color: Colors.white12),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.black : Colors.white54)),
        ),
      );

  Widget _formSectionHeader(String label, String value, String picker) =>
      GestureDetector(
        onTap: () => _togglePicker(picker),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            SizedBox(
                width: 96,
                child: Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.white38))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontSize: 13, color: Colors.white70))),
            Icon(_openPicker == picker ? Icons.expand_less : Icons.expand_more,
                size: 16, color: Colors.white24),
          ]),
        ),
      );

  Widget _formRow(String label, Widget content) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.white38))),
          content,
        ]),
      );

  Widget _stepper({
    required String display,
    required VoidCallback onInc,
    VoidCallback? onDec,
  }) =>
      Row(children: [
        _stepButton(Icons.remove, onDec),
        SizedBox(
            width: 40,
            child: Center(
                child: Text(display,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)))),
        _stepButton(Icons.add, onInc),
      ]);

  void _selectEquipmentAndVariant(
      IntervalConfig iv, EquipmentType newType, String? newVariantId) {
    _update(() {
      final typeChanged = iv.equipmentTypeId != newType.id;
      iv.equipmentTypeId = newType.id;
      iv.variantId = newVariantId;
      if (typeChanged && !newType.exercises.any((e) => e.id == iv.exerciseTypeId)) {
        iv.exerciseTypeId = newType.exercises.first.id;
      }
      final exercise = newType.exercises
          .where((e) => e.id == iv.exerciseTypeId)
          .firstOrNull ?? newType.exercises.first;
      if (!exercise.hasSide) iv.side = null;
      if (exercise.hasSide && iv.side == null) {
        iv.side = (widget.index ?? 0) % 2 == 0
            ? ExerciseSide.links
            : ExerciseSide.rechts;
      }
    });
  }

  Widget _equipmentGroup(EquipmentType eqType, IntervalConfig iv) {
    final isCurrentType = iv.equipmentTypeId == eqType.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Image.asset(eqType.iconAsset,
                width: 14, height: 14, color: Colors.white38),
          ),
          Expanded(
            child: Wrap(children: [
              if (eqType.variants.isEmpty)
                _pickerChip(
                  eqType.name,
                  isCurrentType,
                  () => _selectEquipmentAndVariant(iv, eqType, null),
                )
              else
                for (final v in eqType.variants)
                  _pickerChip(
                    v.shortLabel,
                    isCurrentType && iv.variantId == v.id,
                    () => _selectEquipmentAndVariant(iv, eqType, v.id),
                  ),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(equipmentCatalogProvider);
    return catalogAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (catalog) => _buildForm(catalog),
    );
  }

  Widget _buildForm(EquipmentCatalog catalog) {
    final iv = widget.iv;
    final eqType =
        catalog.findType(iv.equipmentTypeId) ?? catalog.types.first;
    final variant = iv.variantId != null
        ? eqType.variants.where((v) => v.id == iv.variantId).firstOrNull
        : null;
    final exercise = eqType.exercises
        .where((e) => e.id == iv.exerciseTypeId)
        .firstOrNull ?? eqType.exercises.first;

    final equipmentLabel = variant != null
        ? '${eqType.name} · ${variant.label}'
        : eqType.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pause toggle
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                if (iv.isPause) {
                  _update(() => iv.isPause = false);
                } else {
                  _update(() {
                    _openPicker = null;
                    iv.isPause = true;
                    iv.side = null;
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: iv.isPause
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(6),
                  border: iv.isPause ? null : Border.all(color: Colors.white12),
                ),
                child: Text('Pause',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: iv.isPause
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: iv.isPause ? Colors.white : Colors.white38)),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
            crossFadeState: iv.isPause
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white12, height: 1),
                _formSectionHeader('Gerät', equipmentLabel, 'equipment'),
                if (_openPicker == 'equipment')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final t in catalog.types) _equipmentGroup(t, iv),
                      ],
                    ),
                  ),
                const Divider(color: Colors.white12, height: 1),
                _formSectionHeader('Übung', exercise.name, 'exercise'),
                if (_openPicker == 'exercise')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      children: [
                        for (final ex in eqType.exercises)
                          _pickerChip(
                            ex.name,
                            iv.exerciseTypeId == ex.id,
                            () => _update(() {
                              iv.exerciseTypeId = ex.id;
                              if (!ex.hasSide) iv.side = null;
                              if (ex.hasSide && iv.side == null) {
                                iv.side = (widget.index ?? 0) % 2 == 0
                                    ? ExerciseSide.links
                                    : ExerciseSide.rechts;
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                if (exercise.hasSide) ...[
                  const Divider(color: Colors.white12, height: 1),
                  _formRow(
                    'Seite',
                    Row(children: [
                      _pickerChip('Links', iv.side == ExerciseSide.links,
                          () => _update(() => iv.side = ExerciseSide.links)),
                      const SizedBox(width: 6),
                      _pickerChip('Rechts', iv.side == ExerciseSide.rechts,
                          () => _update(() => iv.side = ExerciseSide.rechts)),
                    ]),
                  ),
                ],
                const Divider(color: Colors.white12, height: 1),
                _formRow(
                  'Wiederholungen',
                  _stepper(
                    display: '${iv.reps}',
                    onDec: iv.reps > 1 ? () => _update(() => iv.reps--) : null,
                    onInc: () => _update(() => iv.reps++),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Sekunden',
            _stepper(
              display: '${iv.durationSeconds}',
              onDec: iv.durationSeconds > 30
                  ? () => _update(() => iv.durationSeconds =
                      (iv.durationSeconds - 5).clamp(30, 9999))
                  : null,
              onInc: () => _update(() => iv.durationSeconds += 5),
            ),
          ),
          if (widget.onCollapse != null)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onCollapse,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: Icon(Icons.expand_less, size: 20, color: Colors.white24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```
flutter analyze lib/features/shared/widgets/interval_edit_form.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```
git add lib/features/shared/widgets/interval_edit_form.dart
git commit -m "feat: rewrite IntervalEditForm as ConsumerStatefulWidget using EquipmentCatalog provider"
```

---

## Task 8: Update history files

**Files:**
- Modify: `lib/features/history/history_detail_sheet.dart`
- Modify: `lib/features/history/history_sheet.dart`

- [ ] **Step 1: Fix `_toConfig` and `_toRecord` in `history_detail_sheet.dart`**

Replace the two top-level converter functions:
```dart
IntervalConfig _toConfig(IntervalRecord r) => IntervalConfig(
      equipmentTypeId: r.equipmentTypeId,
      variantId: r.variantId,
      exerciseTypeId: r.exerciseTypeId,
      reps: r.reps,
      durationSeconds: r.durationSeconds,
      side: r.side,
      isPause: r.isPause,
    );

IntervalRecord _toRecord(IntervalConfig c) => IntervalRecord(
      equipmentTypeId: c.equipmentTypeId,
      variantId: c.variantId,
      exerciseTypeId: c.exerciseTypeId,
      reps: c.reps,
      durationSeconds: c.durationSeconds,
      side: c.side,
      isPause: c.isPause,
    );
```

- [ ] **Step 2: Fix `_repBreakdown` in `_HistoryDetailSheetState`**

Add import: `import '../../core/models/equipment_catalog.dart';`
Add import: `import '../../core/providers/equipment_catalog_notifier.dart';`

Replace `_repBreakdown()` method (it now takes the catalog as parameter):
```dart
String _repBreakdown(EquipmentCatalog catalog) {
  final Map<String, int> byType = {};
  for (final iv in _editIntervals) {
    if (!iv.isPause) {
      byType[iv.equipmentTypeId] = (byType[iv.equipmentTypeId] ?? 0) + iv.reps;
    }
  }
  final total = byType.values.fold(0, (a, b) => a + b);
  if (byType.length <= 1) return '$total Reps';
  return byType.entries.map((e) {
    final name = catalog.findType(e.key)?.name ?? e.key;
    return '${e.value}× $name';
  }).join(' / ');
}
```

- [ ] **Step 3: Fix `_computeIsDirty` — String comparison replaces enum comparison**

Replace the body:
```dart
bool _computeIsDirty() {
  for (int i = 0; i < _editIntervals.length; i++) {
    final orig = _savedIntervals[i];
    final edit = _editIntervals[i];
    if (orig.reps != edit.reps ||
        orig.durationSeconds != edit.durationSeconds ||
        orig.equipmentTypeId != edit.equipmentTypeId ||
        orig.variantId != edit.variantId ||
        orig.exerciseTypeId != edit.exerciseTypeId ||
        orig.side != edit.side ||
        orig.isPause != edit.isPause) {
      return true;
    }
  }
  return false;
}
```

- [ ] **Step 4: Fix `build()` method — pass catalog to `_repBreakdown` and fix icon/label display**

In `build()`, watch the catalog:
```dart
final catalogAsync = ref.watch(equipmentCatalogProvider);
final catalog = catalogAsync.valueOrNull;
final repBreakdown = catalog != null ? _repBreakdown(catalog) : '... Reps';
```

In the row list item (where `iv.equipment.iconPath` and labels were used), replace with catalog lookup. Find the section that renders each interval row (around line 224):

```dart
// Replace:
Image.asset(iv.equipment.iconPath, width: 14, height: 14, color: Colors.white38),
// With (using catalog):
if (catalog != null)
  Image.asset(catalog.findType(iv.equipmentTypeId)?.iconAsset ?? 'assets/icon/kettlebell.png',
      width: 14, height: 14, color: Colors.white38),

// Replace:
Text(iv.equipment.label, ...),
// With:
Text(catalog?.findType(iv.equipmentTypeId)?.name ?? iv.equipmentTypeId, ...),

// Replace:
iv.side != null ? '· ${iv.exercise.label} ${iv.side!.shortLabel}' : '· ${iv.exercise.label}',
// With:
() {
  final ex = catalog?.findType(iv.equipmentTypeId)?.exercises
      .where((e) => e.id == iv.exerciseTypeId).firstOrNull;
  return iv.side != null
      ? '· ${ex?.name ?? iv.exerciseTypeId} ${iv.side!.shortLabel}'
      : '· ${ex?.name ?? iv.exerciseTypeId}';
}(),
```

- [ ] **Step 5: Simplify `_buildCard` in `history_sheet.dart`**

Remove `kbReps`, `smReps`, `repBreakdown` local variables. Replace `_buildCard`:
```dart
Widget _buildCard(WorkoutRecord record) {
  final dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
  final totalSecs = record.totalDurationSeconds;
  final durStr =
      '${totalSecs ~/ 60}m ${(totalSecs % 60).toString().padLeft(2, '0')}s';
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatDateTime(dt),
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Text('${record.totalReps} Reps  ·  $durStr',
            style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 13)),
      ],
    ),
  );
}
```

- [ ] **Step 6: Verify**

```
flutter analyze lib/features/history/
```

Expected: `No issues found!`

- [ ] **Step 7: Commit**

```
git add lib/features/history/history_detail_sheet.dart lib/features/history/history_sheet.dart
git commit -m "feat: update history screens to use EquipmentCatalog for display"
```

---

## Task 9: Remove enums from `settings.dart` + final sweep

**Files:**
- Modify: `lib/core/models/settings.dart`

- [ ] **Step 1: Remove `Equipment` and `Exercise` enums from `settings.dart`**

Delete everything from line 4 (`enum Equipment { ... }`) through line 92 (`}` closing `ExerciseX`). Keep:
- `import 'package:flutter/material.dart';`
- `import 'package:shared_preferences/shared_preferences.dart';`
- `enum ExerciseSide { links, rechts }` and its extension
- `Color phaseColorForMinute(int minute) { ... }`
- `class AppSettings { ... }`

The file after editing starts with:
```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ExerciseSide { links, rechts }

extension ExerciseSideX on ExerciseSide {
  String get label => this == ExerciseSide.links ? 'Links' : 'Rechts';
  String get shortLabel => this == ExerciseSide.links ? 'L' : 'R';
}

Color phaseColorForMinute(int minute) { ... }

class AppSettings { ... }
```

- [ ] **Step 2: Run `flutter analyze` across the whole project**

```
flutter analyze
```

Fix any remaining errors. Common ones:
- Any file that still imports `Equipment` or `Exercise` from `settings.dart` — remove those references
- `plan_editor_screen.dart` may reference `Equipment`/`Exercise` in default interval creation — update to use String IDs

For `plan_editor_screen.dart`, find `_onAdd()` — if it creates a new `IntervalConfig` with old enum values, update to:
```dart
void _onAdd() {
  if (_plan.intervals.length >= TrainingPlan.maxIntervals) return;
  _undoManager.push(_plan.intervals);
  setState(() {
    final last = _plan.intervals.last;
    _plan = TrainingPlan(
      id: _plan.id,
      name: _plan.name,
      intervals: [
        ..._plan.intervals,
        IntervalConfig(
          equipmentTypeId: last.equipmentTypeId,
          variantId: last.variantId,
          exerciseTypeId: last.exerciseTypeId,
          reps: last.reps,
          durationSeconds: last.durationSeconds,
        ),
      ],
    );
  });
}
```

- [ ] **Step 3: Run all tests**

```
flutter test
```

Expected: All tests pass. Fix any broken tests:
- `plan_editor_delete_confirmation_test.dart` creates `IntervalConfig` — update constructor calls to use String IDs:
  ```dart
  IntervalConfig(
    equipmentTypeId: 'kettlebell',
    variantId: 'kb_16',
    exerciseTypeId: 'swing_beidarmig',
    reps: 10,
    durationSeconds: 60,
  )
  ```
- Other test files that use old `Equipment`/`Exercise` enums — update similarly.

- [ ] **Step 4: Commit**

```
git add -A
git commit -m "feat: remove Equipment/Exercise enums, complete migration to dynamic EquipmentCatalog model"
```

---

## Task 10: Wire `equipmentCatalogProvider` into app entry point

**Files:**
- Modify: `lib/main.dart` (verify `ProviderScope` wraps the app — already done)

- [ ] **Step 1: Verify `equipmentCatalogProvider` is eagerly loaded**

In `main.dart`, check if providers are pre-warmed. If not (typically they load lazily on first `ref.watch`), no action needed — `keepAlive: true` ensures the catalog loads once and persists.

Check `lib/main.dart`:
```dart
void main() {
  runApp(const ProviderScope(child: KettlebellApp()));
}
```

This is sufficient — `equipmentCatalogProvider` will load when first watched (in `IntervalEditForm`, `WorkoutNotifier`, etc.).

- [ ] **Step 2: Final smoke test**

```
flutter analyze
flutter test
```

Both must pass with zero errors/failures.

- [ ] **Step 3: Push**

```
git push
```

---
