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
          IntervalRecord(reps: 10, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
          IntervalRecord(reps: 12, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
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
          IntervalRecord(reps: 5, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
          IntervalRecord(reps: 6, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
        ],
      ));
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: t,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 5, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
          IntervalRecord(reps: 6, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
          IntervalRecord(reps: 7, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
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
          IntervalRecord(reps: 5, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
          IntervalRecord(reps: 5, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
        ],
      ));
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: 2000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 8, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
          IntervalRecord(reps: 8, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
        ],
      ));

      final records = await WorkoutHistory.load();
      expect(records[0].timestamp, 2000);
      expect(records[1].timestamp, 1000);
    });

    test('totalReps and totalDurationSeconds computed correctly', () async {
      final record = WorkoutRecord(
        timestamp: 3000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 10, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
          IntervalRecord(reps: 8, durationSeconds: 60, equipmentTypeId: 'steelmace', exerciseTypeId: 'mace_360'),
          IntervalRecord(reps: 6, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig'),
        ],
      );

      expect(record.totalReps, 24);
      expect(record.totalDurationSeconds, 180);
    });

    test('serialization round-trip preserves all fields including exerciseTypeId', () {
      final original = WorkoutRecord(
        timestamp: 9999,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 15, durationSeconds: 45, equipmentTypeId: 'steelmace', variantId: 'sm_12', exerciseTypeId: 'mace_360'),
          IntervalRecord(reps: 10, durationSeconds: 60, equipmentTypeId: 'kettlebell', variantId: 'kb_20', exerciseTypeId: 'snatch'),
        ],
      );
      final restored = WorkoutRecord.fromJson(original.toJson());

      expect(restored.timestamp, 9999);
      expect(restored.planMode, 1);
      expect(restored.intervals.length, 2);
      expect(restored.intervals[0].reps, 15);
      expect(restored.intervals[0].equipmentTypeId, 'steelmace');
      expect(restored.intervals[0].exerciseTypeId, 'mace_360');
      expect(restored.intervals[1].exerciseTypeId, 'snatch');
    });

    test('fromJson with missing exercise key defaults to swing_beidarmig', () {
      final json = {'r': 10, 'd': 60, 'e': 2}; // old record without 'x'
      final iv = IntervalRecord.fromJson(json);
      expect(iv.exerciseTypeId, 'swing_beidarmig');
    });

    test('IntervalRecord: side und isPause werden serialisiert und wiederhergestellt', () {
      final original = IntervalRecord(
        reps: 10,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'snatch',
        side: ExerciseSide.links,
        isPause: false,
      );
      final restored = IntervalRecord.fromJson(original.toJson());
      expect(restored.side, ExerciseSide.links);
      expect(restored.isPause, false);
      expect(restored.reps, 10);
      expect(restored.exerciseTypeId, 'snatch');
    });

    test('IntervalRecord: isPause=true wird korrekt serialisiert', () {
      final original = IntervalRecord(
        reps: 0,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_beidarmig',
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

    test('IntervalRecord: toJson omits s and p keys when side is null and isPause is false', () {
      final iv = IntervalRecord(
        reps: 5,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_beidarmig',
      );
      final json = iv.toJson();
      expect(json.containsKey('s'), isFalse);
      expect(json.containsKey('p'), isFalse);
    });

    test('IntervalRecord: toJson includes s and p keys when set', () {
      final iv = IntervalRecord(
        reps: 5,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'snatch',
        side: ExerciseSide.rechts,
        isPause: false,
      );
      expect(iv.toJson().containsKey('s'), isTrue);

      final pause = IntervalRecord(
        reps: 0,
        durationSeconds: 60,
        equipmentTypeId: 'kettlebell',
        exerciseTypeId: 'swing_beidarmig',
        isPause: true,
      );
      expect(pause.toJson().containsKey('p'), isTrue);
      expect(pause.toJson().containsKey('s'), isFalse);
    });
  });
}
