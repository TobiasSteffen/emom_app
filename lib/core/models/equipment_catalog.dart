import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

class ExerciseType {
  final String id;
  final String name;
  final bool hasSide;
  final bool isTimed;

  const ExerciseType(
      {required this.id,
      required this.name,
      required this.hasSide,
      this.isTimed = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'hasSide': hasSide, 'isTimed': isTimed};

  factory ExerciseType.fromJson(Map<String, dynamic> j) => ExerciseType(
        id: j['id'] as String,
        name: j['name'] as String,
        hasSide: j['hasSide'] as bool,
        isTimed: (j['isTimed'] as bool?) ?? false,
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

  static EquipmentCatalog addMissingDefaults(EquipmentCatalog catalog) {
    final defaults = defaultCatalog();
    var types = List<EquipmentType>.from(catalog.types);
    for (final d in defaults.types) {
      if (!types.any((t) => t.id == d.id)) {
        types.add(d);
      }
    }
    return EquipmentCatalog(types: types);
  }

  /// Upgrades a loaded catalog in place: adds missing default equipment types,
  /// adds missing default exercises into existing default types, and renames
  /// the legacy "Push Press" default exercise to "Press". Idempotent — running
  /// it twice yields the same result, and it never overwrites a user-renamed
  /// exercise or touches user-created (non-default) equipment types.
  static EquipmentCatalog migrate(EquipmentCatalog catalog) {
    final withTypes = addMissingDefaults(catalog);
    final defaults = defaultCatalog();
    return EquipmentCatalog(
      types: withTypes.types.map((t) {
        final def = defaults.findType(t.id);
        if (def == null) return t; // user-created type — leave untouched
        // Upgrade any built-in exercise still carrying a legacy display name
        // to its current name (leaves user-renamed entries untouched).
        final exercises = t.exercises.map((e) {
          final builtIn = BuiltInExercise.byId(e.id);
          if (builtIn != null && builtIn.legacyNames.contains(e.name)) {
            return ExerciseType(
                id: e.id, name: builtIn.displayName, hasSide: e.hasSide, isTimed: e.isTimed);
          }
          return e;
        }).toList();
        // Add any default exercises missing from this type (by id).
        for (final de in def.exercises) {
          if (!exercises.any((e) => e.id == de.id)) {
            exercises.add(de);
          }
        }
        return EquipmentType(
          id: t.id,
          name: t.name,
          iconAsset: t.iconAsset,
          variants: t.variants,
          exercises: exercises,
        );
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'types': types.map((t) => t.toJson()).toList(),
      };

  factory EquipmentCatalog.fromJson(Map<String, dynamic> j) => EquipmentCatalog(
        types: (j['types'] as List)
            .map((t) => EquipmentType.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  /// Seeded built-in catalog, composed from the [BuiltInEquipment],
  /// [BuiltInVariant] and [BuiltInExercise] registries (single source of truth).
  static EquipmentCatalog defaultCatalog() => EquipmentCatalog(
        types: BuiltInEquipment.values
            .map((eq) => EquipmentType(
                  id: eq.id,
                  name: eq.displayName,
                  iconAsset: eq.iconAsset,
                  variants: BuiltInVariant.values
                      .where((v) => v.equipment == eq)
                      .map((v) => v.toVariant())
                      .toList(),
                  exercises: BuiltInExercise.values
                      .where((x) => x.equipment == eq)
                      .map((x) => x.toType())
                      .toList(),
                ))
            .toList(),
      );
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
      final catalog = EquipmentCatalog.fromJson(json);
      final migrated = EquipmentCatalog.migrate(catalog);
      if (jsonEncode(migrated.toJson()) != jsonEncode(catalog.toJson())) {
        await save(migrated);
      }
      return migrated;
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

/// Type-safe registry of the built-in equipment categories.
///
/// These enums are the single source of truth for the seeded [defaultCatalog]
/// and the catalog migration. They cover **built-ins only** — equipment and
/// exercises a user creates via the wizard live purely as catalog data with
/// generated ids and are intentionally not represented here. The stable
/// serialized key is always [id]; [displayName] is just a label.
enum BuiltInEquipment {
  kettlebell('kettlebell', 'Kettlebell', 'assets/icon/kettlebell.png'),
  steelmace('steelmace', 'Steel Mace', 'assets/icon/steelmace.png'),
  pezziball('pezziball', 'Pezziball', 'assets/icon/pezziball.png'),
  bodyweight('bodyweight', 'Körpergewicht', 'assets/icon/liegestuetz.png');

  const BuiltInEquipment(this.id, this.displayName, this.iconAsset);

  final String id;
  final String displayName;
  final String iconAsset;
}

/// Built-in equipment variants (weights), each tied to its [equipment].
enum BuiltInVariant {
  kb16(BuiltInEquipment.kettlebell, 'kb_16', '16 kg', '16 kg'),
  kb20(BuiltInEquipment.kettlebell, 'kb_20', '20 kg', '20 kg'),
  kb24(BuiltInEquipment.kettlebell, 'kb_24', '24 kg', '24 kg'),
  sm8(BuiltInEquipment.steelmace, 'sm_8', '8 kg', '8 kg'),
  sm12(BuiltInEquipment.steelmace, 'sm_12', '12 kg', '12 kg'),
  pbNone(BuiltInEquipment.pezziball, 'pb_0', 'ohne', 'ohne'),
  pbPlus2(BuiltInEquipment.pezziball, 'pb_2_5', '+2,5 kg', '+2,5 kg'),
  pbPlus5(BuiltInEquipment.pezziball, 'pb_5', '+5 kg', '+5 kg'),
  pbPlus7(BuiltInEquipment.pezziball, 'pb_7_5', '+7,5 kg', '+7,5 kg'),
  pbPlus10(BuiltInEquipment.pezziball, 'pb_10', '+10 kg', '+10 kg');

  const BuiltInVariant(this.equipment, this.id, this.label, this.shortLabel);

  final BuiltInEquipment equipment;
  final String id;
  final String label;
  final String shortLabel;

  EquipmentVariant toVariant() =>
      EquipmentVariant(id: id, label: label, shortLabel: shortLabel);
}

/// Built-in exercises, each tied to its [equipment].
///
/// [legacyNames] lists former default display names for the same [id]; the
/// migration upgrades any catalog entry still carrying one of them to the
/// current [displayName] (without touching user-renamed entries).
enum BuiltInExercise {
  swingBeidarmig(
      BuiltInEquipment.kettlebell, 'swing_beidarmig', 'Swing beidarmig',
      hasSide: false),
  swingEinarmig(
      BuiltInEquipment.kettlebell, 'swing_einarmig', 'Swing einarmig',
      hasSide: true),
  snatch(BuiltInEquipment.kettlebell, 'snatch', 'Snatch', hasSide: true),
  pushPress(BuiltInEquipment.kettlebell, 'push_press', 'Overhead Press',
      hasSide: true, legacyNames: ['Push Press', 'Press']),
  cleanPress(BuiltInEquipment.kettlebell, 'clean_press', 'Clean & Press',
      hasSide: true),
  mace360(BuiltInEquipment.steelmace, 'mace_360', '360s', hasSide: true),
  schulterHeben(
      BuiltInEquipment.steelmace, 'schulter_heben', 'Schulterheben',
      hasSide: true),
  myotatischerCrunch(BuiltInEquipment.pezziball, 'myotatischer_crunch',
      'Myotatischer Crunch',
      hasSide: false),
  liegestuetz(BuiltInEquipment.bodyweight, 'liegestuetz', 'Liegestütz',
      hasSide: false);

  const BuiltInExercise(
    this.equipment,
    this.id,
    this.displayName, {
    required this.hasSide,
    this.legacyNames = const [],
  });

  final BuiltInEquipment equipment;
  final String id;
  final String displayName;
  final bool hasSide;
  final List<String> legacyNames;

  ExerciseType toType() =>
      ExerciseType(id: id, name: displayName, hasSide: hasSide);

  /// The built-in exercise with [id], or null if [id] is a custom exercise.
  static BuiltInExercise? byId(String id) {
    for (final e in values) {
      if (e.id == id) return e;
    }
    return null;
  }
}
