import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'training_plan.dart';

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
      equipmentTypeId: IntervalConfig.migrateEqType(eIdx),
      variantId: IntervalConfig.migrateVariant(eIdx),
      exerciseTypeId: IntervalConfig.migrateExercise(xIdx),
      side: sideIdx != null ? ExerciseSide.values.elementAtOrNull(sideIdx) : null,
      isPause: (j['p'] as bool?) ?? false,
    );
  }
}

class WorkoutRecord {
  final int timestamp; // milliseconds since epoch
  final int planMode; // 0 = phaseBased, 1 = minuteExact
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

class WorkoutHistory {
  static const _key = 'workoutHistory';
  static const _maxEntries = 300;

  static Future<List<WorkoutRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => WorkoutRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addOrUpdateRecord(WorkoutRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await load();
    final idx = records.indexWhere((r) => r.timestamp == record.timestamp);
    if (idx >= 0) {
      records[idx] = record;
    } else {
      records.insert(0, record);
      if (records.length > _maxEntries) records.removeLast();
    }
    await prefs.setString(
      _key,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }
}
