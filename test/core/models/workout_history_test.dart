import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emom_app/core/models/workout_history.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkoutHistory', () {
    test('load returns empty list when no data stored', () async {
      final records = await WorkoutHistory.load();
      expect(records, isEmpty);
    });

    test('addOrUpdateRecord saves and load retrieves it', () async {
      final record = WorkoutRecord(
        timestamp: 1000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 10, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 12, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      );

      await WorkoutHistory.addOrUpdateRecord(record);
      final records = await WorkoutHistory.load();

      expect(records.length, 1);
      expect(records[0].timestamp, 1000);
      expect(records[0].intervals.length, 2);
      expect(records[0].totalReps, 22);
    });

    test('addOrUpdateRecord updates existing record with same timestamp', () async {
      const t = 2000;
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: t,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 6, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      ));
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: t,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 6, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 7, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      ));

      final records = await WorkoutHistory.load();
      expect(records.length, 1);
      expect(records[0].intervals.length, 3);
    });

    test('newest record appears first', () async {
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: 1000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      ));
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: 2000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 8, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 8, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      ));

      final records = await WorkoutHistory.load();
      expect(records[0].timestamp, 2000);
      expect(records[1].timestamp, 1000);
    });

    test('totalReps, kettlebellReps, steelMaceReps computed correctly', () async {
      final record = WorkoutRecord(
        timestamp: 3000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 10, durationSeconds: 60, equipment: 2, exercise: 0), // kb24
          IntervalRecord(reps: 8, durationSeconds: 60, equipment: 3, exercise: 4),  // sm8
          IntervalRecord(reps: 6, durationSeconds: 60, equipment: 2, exercise: 0),  // kb24
        ],
      );

      expect(record.totalReps, 24);
      expect(record.kettlebellReps, 16); // equipment < 3
      expect(record.steelMaceReps, 8);   // equipment >= 3
      expect(record.totalDurationSeconds, 180);
    });

    test('serialization round-trip preserves all fields including exercise', () {
      final original = WorkoutRecord(
        timestamp: 9999,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 15, durationSeconds: 45, equipment: 4, exercise: 4), // sm12, mace360
          IntervalRecord(reps: 10, durationSeconds: 60, equipment: 1, exercise: 2), // kb20, snatch
        ],
      );
      final restored = WorkoutRecord.fromJson(original.toJson());

      expect(restored.timestamp, 9999);
      expect(restored.planMode, 1);
      expect(restored.intervals.length, 2);
      expect(restored.intervals[0].reps, 15);
      expect(restored.intervals[0].equipment, 4);
      expect(restored.intervals[0].exercise, 4);
      expect(restored.intervals[1].exercise, 2);
    });

    test('fromJson with missing exercise key defaults to 0 (swingBeidarmig)', () {
      final json = {'r': 10, 'd': 60, 'e': 2}; // old record without 'x'
      final iv = IntervalRecord.fromJson(json);
      expect(iv.exercise, 0);
    });
  });
}
