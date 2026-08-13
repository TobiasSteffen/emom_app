import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/features/workout/garmin_watch_commands.dart';
import 'package:emom_app/features/workout/workout_notifier.dart';

IntervalConfig _iv({int reps = 10}) => IntervalConfig(
    reps: reps, durationSeconds: 60, equipmentTypeId: 'kettlebell', exerciseTypeId: 'swing_beidarmig');

class _Calls {
  int pause = 0, start = 0, confirm = 0, skip = 0, startHold = 0, finishHold = 0;
}

WorkoutState _state({
  int currentMinute = 0,
  bool isRunning = false,
  bool isFinished = false,
  bool waitingForConfirmation = false,
  List<bool>? timedFlags,
  bool holdStarted = false,
}) =>
    WorkoutState(
      intervals: [_iv(), _iv()],
      currentMinute: currentMinute,
      secondsLeft: 42,
      isRunning: isRunning,
      isFinished: isFinished,
      waitingForConfirmation: waitingForConfirmation,
      totalRepsDone: 0,
      completedIntervals: const [],
      timedFlags: timedFlags ?? const [false, false],
      holdStarted: holdStarted,
    );

void main() {
  late _Calls calls;

  void apply(String command, WorkoutState state) {
    applyWatchCommand(
      command,
      state,
      pause: () => calls.pause++,
      start: () => calls.start++,
      confirmInterval: () => calls.confirm++,
      skip: () => calls.skip++,
      startHold: () => calls.startHold++,
      finishHold: () => calls.finishHold++,
    );
  }

  setUp(() => calls = _Calls());

  test('cmd_pause pausiert nur wenn isRunning', () {
    apply('cmd_pause', _state(isRunning: true));
    expect(calls.pause, 1);
    apply('cmd_pause', _state(isRunning: false));
    expect(calls.pause, 1); // unveraendert, kein zweiter Aufruf
  });

  test('cmd_resume startet, wenn paused und nicht Zeit-Uebung', () {
    apply('cmd_resume', _state(isRunning: false));
    expect(calls.start, 1);
  });

  test('cmd_resume ruft startHold auf, wenn holdWaiting', () {
    apply('cmd_resume', _state(timedFlags: const [true, false]));
    expect(calls.startHold, 1);
    expect(calls.start, 0);
  });

  test('cmd_resume ruft finishHold auf, wenn Zeit-Uebung schon gestartet', () {
    apply('cmd_resume',
        _state(timedFlags: const [true, false], holdStarted: true, isRunning: true));
    expect(calls.finishHold, 1);
    expect(calls.start, 0);
  });

  test('cmd_resume ist No-Op, wenn schon running und nicht Zeit-Uebung', () {
    apply('cmd_resume', _state(isRunning: true));
    expect(calls.start, 0);
  });

  test('cmd_confirm bestaetigt nur wenn waitingForConfirmation', () {
    apply('cmd_confirm', _state(waitingForConfirmation: true));
    expect(calls.confirm, 1);
    apply('cmd_confirm', _state(waitingForConfirmation: false));
    expect(calls.confirm, 1); // kein Absturz, kein zweiter Aufruf
  });

  test('cmd_skip laeuft ins Leere bei waitingForConfirmation oder isFinished', () {
    apply('cmd_skip', _state(waitingForConfirmation: true));
    expect(calls.skip, 0);
    apply('cmd_skip', _state(isFinished: true));
    expect(calls.skip, 0);
    apply('cmd_skip', _state());
    expect(calls.skip, 1);
  });

  test('cmd_resume ist No-Op, wenn waitingForConfirmation gesetzt ist', () {
    apply('cmd_resume', _state(isRunning: false, waitingForConfirmation: true));
    expect(calls.start, 0);
    expect(calls.startHold, 0);
    expect(calls.finishHold, 0);
  });

  test('cmd_resume ist No-Op, wenn isFinished gesetzt ist', () {
    apply('cmd_resume', _state(isRunning: false, isFinished: true));
    expect(calls.start, 0);
    expect(calls.startHold, 0);
    expect(calls.finishHold, 0);
  });

  test('unbekanntes Kommando loest nichts aus', () {
    apply('cmd_unbekannt', _state(isRunning: true));
    expect(calls.pause + calls.start + calls.confirm + calls.skip + calls.startHold + calls.finishHold, 0);
  });
}
