import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/features/workout/workout_notifier.dart';

IntervalConfig _iv({int reps = 10}) => IntervalConfig(
    reps: reps,
    durationSeconds: 60,
    equipmentTypeId: 'kettlebell',
    exerciseTypeId: 'swing_beidarmig');

WorkoutState _state({
  required List<bool> timedFlags,
  int currentMinute = 0,
  int secondsLeft = 60,
  bool holdStarted = false,
  List<IntervalConfig>? intervals,
}) =>
    WorkoutState(
      intervals: intervals ?? [_iv(), _iv(reps: 12)],
      currentMinute: currentMinute,
      secondsLeft: secondsLeft,
      isRunning: false,
      isFinished: false,
      waitingForConfirmation: false,
      totalRepsDone: 0,
      completedIntervals: const [],
      timedFlags: timedFlags,
      holdStarted: holdStarted,
    );

void main() {
  test('holdWaiting only for timed interval before start', () {
    expect(_state(timedFlags: [true, false]).holdWaiting, true);
    expect(_state(timedFlags: [true, false], holdStarted: true).holdWaiting, false);
    expect(_state(timedFlags: [false, false]).holdWaiting, false);
  });

  test('currentReps is 0 and totalReps excludes timed intervals', () {
    final s = _state(timedFlags: [true, false]);
    expect(s.currentReps, 0);
    expect(s.totalReps, 12);
  });

  test('overtimeSeconds is positive part of negative secondsLeft', () {
    expect(_state(timedFlags: [true, false], secondsLeft: -25).overtimeSeconds, 25);
    expect(_state(timedFlags: [true, false], secondsLeft: 10).overtimeSeconds, 0);
  });
}
