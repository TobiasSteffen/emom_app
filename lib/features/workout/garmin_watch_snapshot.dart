import '../../core/models/equipment_catalog.dart';
import '../../core/models/settings.dart';
import '../../core/models/training_plan.dart';
import 'workout_notifier.dart';

enum WatchScreenState { paused, running, holdWaiting, holding, confirming, finished }

extension WatchScreenStateWire on WatchScreenState {
  String get wireValue => switch (this) {
        WatchScreenState.paused => 'paused',
        WatchScreenState.running => 'running',
        WatchScreenState.holdWaiting => 'hold_waiting',
        WatchScreenState.holding => 'holding',
        WatchScreenState.confirming => 'confirming',
        WatchScreenState.finished => 'finished',
      };
}

/// Ableitung, erste zutreffende Regel gewinnt -- siehe Design-Spec,
/// Abschnitt "Architektur & Datenfluss".
WatchScreenState watchScreenStateFor(WorkoutState s) {
  if (s.isFinished) return WatchScreenState.finished;
  if (s.waitingForConfirmation) return WatchScreenState.confirming;
  if (s.holdWaiting) return WatchScreenState.holdWaiting;
  if (s.currentIsTimed && s.holdStarted) return WatchScreenState.holding;
  if (s.isRunning) return WatchScreenState.running;
  return WatchScreenState.paused;
}

class _WatchLines {
  final String line1;
  final String line2;
  const _WatchLines(this.line1, this.line2);
}

const _pauseLines = _WatchLines('Pause', '');

_WatchLines _formatInterval(IntervalConfig iv, EquipmentCatalog catalog) {
  if (iv.isPause) return _pauseLines;
  final eqType = catalog.findType(iv.equipmentTypeId);
  if (eqType == null) return const _WatchLines('?', '');
  final variant = iv.variantId != null
      ? eqType.variants.where((v) => v.id == iv.variantId).firstOrNull
      : null;
  final exercise =
      eqType.exercises.where((e) => e.id == iv.exerciseTypeId).firstOrNull;
  final line1 = variant != null ? '${eqType.name} ${variant.label}' : eqType.name;
  final exerciseName = exercise?.name ?? '?';
  final line2 = (exercise?.hasSide == true && iv.side != null)
      ? '$exerciseName · ${iv.side!.shortLabel}'
      : exerciseName;
  return _WatchLines(line1, line2);
}

_WatchLines _lastNonPauseLines(WorkoutState s, EquipmentCatalog catalog) {
  for (var i = s.currentMinute; i >= 0; i--) {
    if (!s.intervals[i].isPause) return _formatInterval(s.intervals[i], catalog);
  }
  return const _WatchLines('', '');
}

String _nextTextFor(WorkoutState s, EquipmentCatalog catalog) {
  final nextMinute = s.currentMinute + 1;
  if (nextMinute >= s.totalMinutes) return '';
  final next = s.intervals[nextMinute];
  if (next.isPause) return 'Nächste: Pause · ${next.durationSeconds}s';
  final lines = _formatInterval(next, catalog);
  return 'Nächste: ${lines.line1} · ${lines.line2}';
}

/// Baut den `state_snapshot`-Dictionary-Payload fuer die Uhr (siehe
/// Design-Spec, Abschnitt "Architektur & Datenfluss").
Map<String, dynamic> buildStateSnapshot(WorkoutState s, EquipmentCatalog catalog) {
  final screenState = watchScreenStateFor(s);
  final iv = s.intervals[s.currentMinute];
  final lines = screenState == WatchScreenState.finished
      ? _lastNonPauseLines(s, catalog)
      : _formatInterval(iv, catalog);
  return {
    'type': 'state_snapshot',
    'minute': s.currentMinute,
    'totalMinutes': s.totalMinutes,
    'line1': lines.line1,
    'line2': lines.line2,
    'isPause': iv.isPause,
    'isTimed': s.currentIsTimed,
    'isRunning': s.isRunning,
    'reps': s.currentReps,
    'secondsLeft': s.secondsLeft,
    'duration': s.currentDuration,
    'screenState': screenState.wireValue,
    'nextText': _nextTextFor(s, catalog),
    'totalReps': s.totalReps,
  };
}

typedef WatchChangeKey = ({
  int minute,
  int totalMinutes,
  bool isRunning,
  bool isPause,
  bool isTimed,
  bool holdWaiting,
  bool holdStarted,
  bool waitingForConfirmation,
  bool isFinished,
  String equipmentTypeId,
  String? variantId,
  String exerciseTypeId,
  ExerciseSide? side,
  int reps,
  int durationSeconds,
});

/// Nur wenn sich mindestens eines dieser Felder aendert, lohnt sich ein
/// Push an die Uhr -- explizit NICHT bei jedem `secondsLeft`-Tick (siehe
/// Design-Spec, Scope-Entscheidung 1). Die letzten sechs Felder (Intervall-
/// Inhalt) sind noetig, weil ein Reset/Planwechsel bei Minute 0 im
/// Idle-Zustand sonst bitgleich zum vorherigen Schluessel waere, obwohl
/// sich die angezeigte Uebung tatsaechlich geaendert hat (Korrekturlesung).
WatchChangeKey watchChangeKeyFor(WorkoutState s) {
  final iv = s.intervals[s.currentMinute];
  return (
    minute: s.currentMinute,
    totalMinutes: s.totalMinutes,
    isRunning: s.isRunning,
    isPause: iv.isPause,
    isTimed: s.currentIsTimed,
    holdWaiting: s.holdWaiting,
    holdStarted: s.holdStarted,
    waitingForConfirmation: s.waitingForConfirmation,
    isFinished: s.isFinished,
    equipmentTypeId: iv.equipmentTypeId,
    variantId: iv.variantId,
    exerciseTypeId: iv.exerciseTypeId,
    side: iv.side,
    reps: iv.reps,
    durationSeconds: iv.durationSeconds,
  );
}
