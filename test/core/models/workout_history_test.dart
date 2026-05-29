import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emom_app/core/models/workout_history.dart';
import 'package:emom_app/core/models/settings.dart';

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
          IntervalRecord(reps: 10, durationSeconds: 60, equipment: Equipment.kb16),
          IntervalRecord(reps: 12, durationSeconds: 60, equipment: Equipment.kb16),
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
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: Equipment.kb16),
          IntervalRecord(reps: 6, durationSeconds: 60, equipment: Equipment.kb16),
        ],
      ));
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: t,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: Equipment.kb16),
          IntervalRecord(reps: 6, durationSeconds: 60, equipment: Equipment.kb16),
          IntervalRecord(reps: 7, durationSeconds: 60, equipment: Equipment.kb16),
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
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: Equipment.kb16),
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: Equipment.kb16),
        ],
      ));
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: 2000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 8, durationSeconds: 60, equipment: Equipment.kb16),
          IntervalRecord(reps: 8, durationSeconds: 60, equipment: Equipment.kb16),
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
          IntervalRecord(reps: 10, durationSeconds: 60, equipment: Equipment.kb24), // kb24
          IntervalRecord(reps: 8, durationSeconds: 60, equipment: Equipment.sm8, exercise: Exercise.mace360),  // sm8
          IntervalRecord(reps: 6, durationSeconds: 60, equipment: Equipment.kb24), // kb24
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
          IntervalRecord(reps: 15, durationSeconds: 45, equipment: Equipment.sm12, exercise: Exercise.mace360), // sm12, mace360
          IntervalRecord(reps: 10, durationSeconds: 60, equipment: Equipment.kb20, exercise: Exercise.snatch), // kb20, snatch
        ],
      );
      final restored = WorkoutRecord.fromJson(original.toJson());

      expect(restored.timestamp, 9999);
      expect(restored.planMode, 1);
      expect(restored.intervals.length, 2);
      expect(restored.intervals[0].reps, 15);
      expect(restored.intervals[0].equipment, Equipment.sm12);
      expect(restored.intervals[0].exercise, Exercise.mace360);
      expect(restored.intervals[1].exercise, Exercise.snatch);
    });

    test('fromJson with missing exercise key defaults to 0 (swingBeidarmig)', () {
      final json = {'r': 10, 'd': 60, 'e': 2}; // old record without 'x'
      final iv = IntervalRecord.fromJson(json);
      expect(iv.exercise, Exercise.swingBeidarmig);
    });

    test('IntervalRecord: side und isPause werden serialisiert und wiederhergestellt', () {
      final original = IntervalRecord(
        reps: 10,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.snatch,
        side: ExerciseSide.links,
        isPause: false,
      );
      final restored = IntervalRecord.fromJson(original.toJson());
      expect(restored.side, ExerciseSide.links);
      expect(restored.isPause, false);
      expect(restored.reps, 10);
      expect(restored.exercise, Exercise.snatch);
    });

    test('IntervalRecord: isPause=true wird korrekt serialisiert', () {
      final original = IntervalRecord(
        reps: 0,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
        isPause: true,
      );
      final restored = IntervalRecord.fromJson(original.toJson());
      expect(restored.isPause, true);
      expect(restored.side, isNull);
    });

    test('IntervalRecord: fromJson ohne side/isPause ergibt Standardwerte (Rückwärtskompatibilität)', () {
      final json = {'r': 10, 'd': 60, 'e': 2, 'x': 0}; // altes Format ohne 's' oder 'p'
      final iv = IntervalRecord.fromJson(json);
      expect(iv.side, isNull);
      expect(iv.isPause, false);
    });
  });
}
