import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vibration/vibration.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/models/settings.dart';
import '../../core/models/workout_history.dart';
import '../../core/providers/settings_provider.dart';
import '../history/history_notifier.dart';

part 'workout_notifier.g.dart';

@immutable
class WorkoutState {
  final List<int> plan;
  final List<int> durations;
  final int currentMinute;
  final int secondsLeft;
  final bool isRunning;
  final bool isFinished;
  final bool waitingForConfirmation;
  final int totalRepsDone;
  final List<IntervalRecord> completedIntervals;
  final DateTime? workoutStartTime;

  const WorkoutState({
    required this.plan,
    required this.durations,
    required this.currentMinute,
    required this.secondsLeft,
    required this.isRunning,
    required this.isFinished,
    required this.waitingForConfirmation,
    required this.totalRepsDone,
    required this.completedIntervals,
    this.workoutStartTime,
  });

  int get totalMinutes => plan.length;
  int get currentReps => plan[currentMinute];
  int get currentDuration => durations[currentMinute];
  int get totalReps => plan.fold(0, (a, b) => a + b);

  WorkoutState copyWith({
    List<int>? plan,
    List<int>? durations,
    int? currentMinute,
    int? secondsLeft,
    bool? isRunning,
    bool? isFinished,
    bool? waitingForConfirmation,
    int? totalRepsDone,
    List<IntervalRecord>? completedIntervals,
    DateTime? workoutStartTime,
    bool clearWorkoutStartTime = false,
  }) =>
      WorkoutState(
        plan: plan ?? this.plan,
        durations: durations ?? this.durations,
        currentMinute: currentMinute ?? this.currentMinute,
        secondsLeft: secondsLeft ?? this.secondsLeft,
        isRunning: isRunning ?? this.isRunning,
        isFinished: isFinished ?? this.isFinished,
        waitingForConfirmation: waitingForConfirmation ?? this.waitingForConfirmation,
        totalRepsDone: totalRepsDone ?? this.totalRepsDone,
        completedIntervals: completedIntervals ?? this.completedIntervals,
        workoutStartTime: clearWorkoutStartTime ? null : (workoutStartTime ?? this.workoutStartTime),
      );
}

@riverpod
class WorkoutNotifier extends _$WorkoutNotifier {
  Timer? _timer;
  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  StreamSubscription? _alarmLoopSub;
  bool? _hasVibrator;
  late AppSettings _settings;

  @override
  Future<WorkoutState> build() async {
    _settings = await ref.read(settingsNotifierProvider.future);
    _hasVibrator = await Vibration.hasVibrator();

    ref.onDispose(() {
      _timer?.cancel();
      _alarmLoopSub?.cancel();
      _tickPlayer.dispose();
      _alarmPlayer.dispose();
      WakelockPlus.disable();
    });

    final plan = _settings.buildPlan();
    final durations = _settings.buildDurations();
    return WorkoutState(
      plan: plan,
      durations: durations,
      currentMinute: 0,
      secondsLeft: durations[0],
      isRunning: false,
      isFinished: false,
      waitingForConfirmation: false,
      totalRepsDone: 0,
      completedIntervals: const [],
    );
  }

  WorkoutState get _s => state.requireValue;

  void start() {
    final now = _s.workoutStartTime == null ? DateTime.now() : null;
    state = AsyncData(_s.copyWith(
      isRunning: true,
      workoutStartTime: now,
    ));
    WakelockPlus.enable();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void pause() {
    _timer?.cancel();
    WakelockPlus.disable();
    state = AsyncData(_s.copyWith(isRunning: false));
  }

  void reset([AppSettings? newSettings]) {
    _timer?.cancel();
    _alarmLoopSub?.cancel();
    _alarmLoopSub = null;
    _alarmPlayer.stop();
    WakelockPlus.disable();
    if (newSettings != null) _settings = newSettings;
    final plan = _settings.buildPlan();
    final durations = _settings.buildDurations();
    state = AsyncData(WorkoutState(
      plan: plan,
      durations: durations,
      currentMinute: 0,
      secondsLeft: durations[0],
      isRunning: false,
      isFinished: false,
      waitingForConfirmation: false,
      totalRepsDone: 0,
      completedIntervals: const [],
    ));
  }

  void confirmInterval() {
    _alarmLoopSub?.cancel();
    _alarmLoopSub = null;
    _alarmPlayer.stop();
    final nextMinute = _s.currentMinute + 1;
    state = AsyncData(_s.copyWith(
      waitingForConfirmation: false,
      currentMinute: nextMinute,
      secondsLeft: _s.durations[nextMinute],
    ));
    _vibrate(400);
    _saveHistory();
    start();
  }

  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    if (_s.isRunning || _s.waitingForConfirmation) return;
    final plan = newSettings.buildPlan();
    final durations = newSettings.buildDurations();
    state = AsyncData(_s.copyWith(
      plan: plan,
      durations: durations,
      secondsLeft: durations[_s.currentMinute],
    ));
  }

  Equipment equipmentForMinute(int minute) {
    if (_settings.planMode == PlanMode.minuteExact) {
      return Equipment.values[_settings.customEquipment[minute]];
    }
    return _settings.equipment;
  }

  String exerciseLabelForMinute(int minute) =>
      equipmentForMinute(minute) == Equipment.kettlebell ? 'Swings' : '360s';

  void _tick(Timer timer) {
    final newSeconds = _s.secondsLeft - 1;
    if (newSeconds <= 0) {
      state = AsyncData(_s.copyWith(secondsLeft: 0));
      _onMinuteComplete();
    } else {
      state = AsyncData(_s.copyWith(secondsLeft: newSeconds));
      if (newSeconds <= 5 && _settings.warningTonesEnabled) {
        if (newSeconds == 5) _raiseVolume();
        _playTickSound();
      }
    }
  }

  Future<void> _raiseVolume() async {
    if (!_settings.volumeBoostEnabled || _settings.volumeBoostLevel <= 0) return;
    try {
      final current = await VolumeController().getVolume();
      if (current < _settings.volumeBoostLevel) {
        VolumeController().setVolume(_settings.volumeBoostLevel, showSystemUI: false);
      }
    } catch (_) {}
  }

  void _onMinuteComplete() {
    _timer?.cancel();
    final s = _s;
    final newTotalReps = s.totalRepsDone + s.currentReps;
    final newIntervals = [
      ...s.completedIntervals,
      IntervalRecord(
        reps: s.currentReps,
        durationSeconds: s.currentDuration,
        equipment: equipmentForMinute(s.currentMinute).index,
      ),
    ];

    if (s.currentMinute >= s.totalMinutes - 1) {
      state = AsyncData(s.copyWith(
        isFinished: true,
        isRunning: false,
        totalRepsDone: newTotalReps,
        completedIntervals: newIntervals,
      ));
      WakelockPlus.disable();
      _vibrate(600);
      _saveHistory(intervals: newIntervals, startTime: s.workoutStartTime);
    } else {
      state = AsyncData(s.copyWith(
        isRunning: false,
        waitingForConfirmation: true,
        totalRepsDone: newTotalReps,
        completedIntervals: newIntervals,
      ));
      _playAlarm();
    }
  }

  Source _soundSource(String f) =>
      f.startsWith('/') ? DeviceFileSource(f) : AssetSource('sounds/$f');

  Future<void> _playTickSound() async {
    try {
      await _tickPlayer.play(_soundSource(_settings.countdownSoundFile));
    } catch (_) {}
  }

  Future<void> _playAlarm() async {
    if (_hasVibrator == true && _settings.vibrationEnabled) {
      Vibration.vibrate(duration: 800);
    }
    if (!_settings.alarmEnabled) return;

    Future<void> playOnce() async {
      try {
        await _alarmPlayer.setReleaseMode(ReleaseMode.release);
        await _alarmPlayer.play(_soundSource(_settings.alarmSoundFile));
      } catch (_) {
        SystemSound.play(SystemSoundType.click);
      }
    }

    await _alarmLoopSub?.cancel();
    _alarmLoopSub = _alarmPlayer.onPlayerComplete.listen((_) async {
      if (!_s.waitingForConfirmation) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (_s.waitingForConfirmation) await playOnce();
    });
    await playOnce();
  }

  void _vibrate(int durationMs) {
    if (!_settings.vibrationEnabled || _hasVibrator != true) return;
    Vibration.vibrate(duration: durationMs);
  }

  Future<void> _saveHistory({
    List<IntervalRecord>? intervals,
    DateTime? startTime,
  }) async {
    final ivs = intervals ?? _s.completedIntervals;
    final t = startTime ?? _s.workoutStartTime;
    if (ivs.length < 2 || t == null) return;
    final record = WorkoutRecord(
      timestamp: t.millisecondsSinceEpoch,
      planMode: _settings.planMode.index,
      intervals: List.from(ivs),
    );
    await ref.read(historyNotifierProvider.notifier).addOrUpdate(record);
  }
}
