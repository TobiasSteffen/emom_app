import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class IntervalRecord {
  final int reps;
  final int durationSeconds;
  final int equipment; // Equipment enum index
  final int exercise;  // Exercise enum index, 0 = swingBeidarmig

  IntervalRecord({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
    this.exercise = 0,
  });

  Map<String, dynamic> toJson() => {
    'r': reps,
    'd': durationSeconds,
    'e': equipment,
    'x': exercise,
  };

  factory IntervalRecord.fromJson(Map<String, dynamic> j) => IntervalRecord(
    reps: j['r'] as int,
    durationSeconds: j['d'] as int,
    equipment: j['e'] as int,
    exercise: (j['x'] as int?) ?? 0,
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
  int get kettlebellReps => intervals.where((i) => i.equipment < 3).fold(0, (a, b) => a + b.reps);
  int get steelMaceReps => intervals.where((i) => i.equipment >= 3).fold(0, (a, b) => a + b.reps);

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
