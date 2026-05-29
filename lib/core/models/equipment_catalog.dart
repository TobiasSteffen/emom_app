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
