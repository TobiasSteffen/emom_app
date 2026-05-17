import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';

class IntervalRecord {
  final int reps;
  final int durationSeconds;
  final Equipment equipment;
  final Exercise exercise;

  IntervalRecord({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
    this.exercise = Exercise.swingBeidarmig,
  });

  Map<String, dynamic> toJson() => {
    'r': reps,
    'd': durationSeconds,
    'e': equipment.index,
    'x': exercise.index,
  };

  factory IntervalRecord.fromJson(Map<String, dynamic> j) => IntervalRecord(
    reps: j['r'] as int,
    durationSeconds: j['d'] as int,
    equipment: Equipment.values.elementAtOrNull(j['e'] as int) ?? Equipment.kb24,
    exercise: Exercise.values.elementAtOrNull((j['x'] as int?) ?? 0) ?? Exercise.swingBeidarmig,
  );
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
  int get kettlebellReps => intervals.where((i) => i.equipment.isKettlebell).fold(0, (a, b) => a + b.reps);
  int get steelMaceReps  => intervals.where((i) => i.equipment.isSteelMace).fold(0, (a, b) => a + b.reps);

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
