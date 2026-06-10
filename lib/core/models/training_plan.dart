import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'equipment_catalog.dart';
import 'settings.dart';

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
        equipmentTypeId: eIdx == 0
            ? BuiltInEquipment.kettlebell.id
            : BuiltInEquipment.steelmace.id,
        variantId: eIdx == 0 ? BuiltInVariant.kb24.id : BuiltInVariant.sm12.id,
        exerciseTypeId: eIdx == 0
            ? BuiltInExercise.swingBeidarmig.id
            : BuiltInExercise.mace360.id,
      );
    }
    // v2: e = Equipment enum index, x = Exercise enum index (both ints)
    final xIdx = j['x'] as int;
    final sideIdx = j['s'] as int?;
    return IntervalConfig(
      reps: j['r'] as int,
      durationSeconds: j['d'] as int,
      equipmentTypeId: migrateEqType(eIdx),
      variantId: migrateVariant(eIdx),
      exerciseTypeId: migrateExercise(xIdx),
      side: sideIdx != null ? ExerciseSide.values.elementAtOrNull(sideIdx) : null,
      isPause: (j['p'] as int?) == 1,
    );
  }

  static String migrateEqType(int e) => switch (e) {
    0 || 1 || 2 => BuiltInEquipment.kettlebell.id,
    3 || 4      => BuiltInEquipment.steelmace.id,
    _           => BuiltInEquipment.pezziball.id,
  };

  static String? migrateVariant(int e) => switch (e) {
    0 => BuiltInVariant.kb16.id,
    1 => BuiltInVariant.kb20.id,
    2 => BuiltInVariant.kb24.id,
    3 => BuiltInVariant.sm8.id,
    4 => BuiltInVariant.sm12.id,
    5 => BuiltInVariant.pbNone.id,
    6 => BuiltInVariant.pbPlus2.id,
    7 => BuiltInVariant.pbPlus5.id,
    8 => BuiltInVariant.pbPlus7.id,
    9 => BuiltInVariant.pbPlus10.id,
    _ => null,
  };

  static String migrateExercise(int x) => switch (x) {
    0 => BuiltInExercise.swingBeidarmig.id,
    1 => BuiltInExercise.swingEinarmig.id,
    2 => BuiltInExercise.snatch.id,
    3 => BuiltInExercise.pushPress.id,
    4 => BuiltInExercise.mace360.id,
    5 => BuiltInExercise.myotatischerCrunch.id,
    6 => BuiltInExercise.schulterHeben.id,
    _ => BuiltInExercise.swingBeidarmig.id,
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

class TrainingPlan {
  static const int minIntervals = 3;
  static const int maxIntervals = 30;

  final String id;
  String name;
  List<IntervalConfig> intervals;

  TrainingPlan({
    required this.id,
    required this.name,
    required this.intervals,
  });

  int get totalReps => intervals.fold(0, (s, iv) => s + iv.reps);
  int get totalDurationSeconds => intervals.fold(0, (s, iv) => s + iv.durationSeconds);

  String get planKey => intervals
      .map((iv) =>
          '${iv.reps},${iv.durationSeconds},${iv.equipmentTypeId},${iv.variantId ?? ''},${iv.exerciseTypeId},${iv.side?.index ?? -1},${iv.isPause ? 1 : 0}')
      .join('|');

  static String _newId() {
    final r = Random();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  static List<int> _pyramidReps() => [
    5,5,5,5,5, 6,7,8,9,10,11,12,13,14,15, 15,15,15,15,15, 14,13,12,11,10, 10,10,10,10,10,
  ];

  factory TrainingPlan.pyramid(String name) {
    final reps = _pyramidReps();
    return TrainingPlan(
      id: _newId(),
      name: name,
      intervals: List.generate(30, (i) => IntervalConfig(
        equipmentTypeId: BuiltInEquipment.kettlebell.id,
        variantId: BuiltInVariant.kb24.id,
        exerciseTypeId: BuiltInExercise.swingBeidarmig.id,
        reps: reps[i],
        durationSeconds: 60,
      )),
    );
  }

  /// A freshly created user plan: starts with [minIntervals] intervals so the
  /// user builds it up from a minimal base (vs. the full pyramid example).
  factory TrainingPlan.fresh(String name) => TrainingPlan(
    id: _newId(),
    name: name,
    intervals: List.generate(minIntervals, (_) => IntervalConfig(
      equipmentTypeId: 'kettlebell',
      variantId: 'kb_24',
      exerciseTypeId: 'swing_beidarmig',
      reps: 10,
      durationSeconds: 60,
    )),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'intervals': intervals.map((iv) => iv.toJson()).toList(),
  };

  factory TrainingPlan.fromJson(Map<String, dynamic> j) => TrainingPlan(
    id: j['id'] as String,
    name: j['name'] as String,
    intervals: (j['intervals'] as List)
        .map((e) => IntervalConfig.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PlanLibrary {
  final List<TrainingPlan> plans;
  final String activePlanId;

  const PlanLibrary({required this.plans, required this.activePlanId});

  TrainingPlan get activePlan {
    if (plans.isEmpty) throw StateError('PlanLibrary has no plans');
    return plans.firstWhere((p) => p.id == activePlanId, orElse: () => plans.first);
  }

  Map<String, dynamic> toJson() => {
    'plans': plans.map((p) => p.toJson()).toList(),
    'activePlanId': activePlanId,
  };

  factory PlanLibrary.fromJson(Map<String, dynamic> j) {
    final plans = (j['plans'] as List)
        .map((e) => TrainingPlan.fromJson(e as Map<String, dynamic>))
        .toList();
    return PlanLibrary(
      plans: plans,
      activePlanId: j['activePlanId'] as String,
    );
  }

  static PlanLibrary defaultLibrary() {
    final plan = TrainingPlan.pyramid('Standard');
    return PlanLibrary(plans: [plan], activePlanId: plan.id);
  }
}

class PlanLibraryStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/plans.json');
  }

  static Future<PlanLibrary> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return PlanLibrary.defaultLibrary();
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return PlanLibrary.fromJson(json);
    } catch (_) {
      return PlanLibrary.defaultLibrary();
    }
  }

  static Future<void> save(PlanLibrary library) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(library.toJson()));
    } catch (_) {}
  }
}
