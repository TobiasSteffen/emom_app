import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'settings.dart';

class IntervalConfig {
  int reps;
  int durationSeconds;
  Equipment equipment;

  IntervalConfig({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
  });

  Map<String, dynamic> toJson() => {
    'r': reps,
    'd': durationSeconds,
    'e': equipment.index,
  };

  factory IntervalConfig.fromJson(Map<String, dynamic> j) => IntervalConfig(
    reps: j['r'] as int,
    durationSeconds: j['d'] as int,
    equipment: Equipment.values.elementAtOrNull(j['e'] as int) ?? Equipment.kb24,
  );

  IntervalConfig copyWith({int? reps, int? durationSeconds, Equipment? equipment}) =>
      IntervalConfig(
        reps: reps ?? this.reps,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        equipment: equipment ?? this.equipment,
      );
}

class TrainingPlan {
  final String id;
  String name;
  List<IntervalConfig> intervals; // immer genau 30 Einträge

  TrainingPlan({
    required this.id,
    required this.name,
    required this.intervals,
  }) : assert(intervals.length == 30);

  int get totalReps => intervals.fold(0, (s, iv) => s + iv.reps);
  int get totalDurationSeconds => intervals.fold(0, (s, iv) => s + iv.durationSeconds);

  String get planKey => intervals
      .map((iv) => '${iv.reps},${iv.durationSeconds},${iv.equipment.index}')
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
        reps: reps[i],
        durationSeconds: 60,
        equipment: Equipment.kb24,
      )),
    );
  }

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
