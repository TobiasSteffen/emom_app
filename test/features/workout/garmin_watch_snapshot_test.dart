import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/equipment_catalog.dart';
import 'package:emom_app/core/models/settings.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/features/workout/garmin_watch_snapshot.dart';
import 'package:emom_app/features/workout/workout_notifier.dart';

final _catalog = EquipmentCatalog.defaultCatalog();

IntervalConfig _iv({
  String equipmentTypeId = 'kettlebell',
  String? variantId = 'kb_20',
  String exerciseTypeId = 'swing_beidarmig',
  ExerciseSide? side,
  int reps = 14,
  int durationSeconds = 60,
  bool isPause = false,
}) =>
    IntervalConfig(
      equipmentTypeId: equipmentTypeId,
      variantId: variantId,
      exerciseTypeId: exerciseTypeId,
      side: side,
      reps: reps,
      durationSeconds: durationSeconds,
      isPause: isPause,
    );

WorkoutState _state({
  required List<IntervalConfig> intervals,
  int currentMinute = 0,
  int secondsLeft = 42,
  bool isRunning = false,
  bool isFinished = false,
  bool waitingForConfirmation = false,
  List<bool>? timedFlags,
  bool holdStarted = false,
}) =>
    WorkoutState(
      intervals: intervals,
      currentMinute: currentMinute,
      secondsLeft: secondsLeft,
      isRunning: isRunning,
      isFinished: isFinished,
      waitingForConfirmation: waitingForConfirmation,
      totalRepsDone: 0,
      completedIntervals: const [],
      timedFlags: timedFlags ?? List.filled(intervals.length, false),
      holdStarted: holdStarted,
    );

void main() {
  group('watchScreenStateFor', () {
    test('finished hat Vorrang vor allem anderen', () {
      final s = _state(
        intervals: [_iv()],
        isFinished: true,
        waitingForConfirmation: true,
        isRunning: true,
      );
      expect(watchScreenStateFor(s), WatchScreenState.finished);
    });

    test('confirming, wenn waitingForConfirmation', () {
      final s = _state(intervals: [_iv(), _iv()], waitingForConfirmation: true);
      expect(watchScreenStateFor(s), WatchScreenState.confirming);
    });

    test('holdWaiting fuer Zeit-Uebung vor dem Start', () {
      final s = _state(intervals: [_iv()], timedFlags: [true]);
      expect(watchScreenStateFor(s), WatchScreenState.holdWaiting);
    });

    test('holding ist unabhaengig von isRunning', () {
      final running = _state(
          intervals: [_iv()], timedFlags: [true], holdStarted: true, isRunning: true);
      final paused = _state(
          intervals: [_iv()], timedFlags: [true], holdStarted: true, isRunning: false);
      expect(watchScreenStateFor(running), WatchScreenState.holding);
      expect(watchScreenStateFor(paused), WatchScreenState.holding);
    });

    test('running, wenn isRunning und nicht Zeit-Uebung', () {
      final s = _state(intervals: [_iv()], isRunning: true);
      expect(watchScreenStateFor(s), WatchScreenState.running);
    });

    test('paused als Default', () {
      final s = _state(intervals: [_iv()]);
      expect(watchScreenStateFor(s), WatchScreenState.paused);
    });

    test('wireValue liefert die snake_case-Strings aus der Spec', () {
      expect(WatchScreenState.holdWaiting.wireValue, 'hold_waiting');
      expect(WatchScreenState.holding.wireValue, 'holding');
      expect(WatchScreenState.confirming.wireValue, 'confirming');
    });
  });

  group('buildStateSnapshot', () {
    test('formatiert Geraet+Gewicht / Uebung+Seite auf zwei Zeilen', () {
      final iv = _iv(
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_20',
        exerciseTypeId: 'swing_einarmig',
        side: ExerciseSide.links,
      );
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['line1'], 'Kettlebell 20 kg');
      expect(snap['line2'], 'Swing einarmig · L');
      expect(snap['isPause'], false);
      expect(snap['isTimed'], false);
      expect(snap['isRunning'], false);
      expect(snap['reps'], 14);
      expect(snap['screenState'], 'paused');
    });

    test('Pause-Intervall: line1 Pause, line2 leer, reps 0', () {
      final iv = _iv(isPause: true, reps: 0);
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['line1'], 'Pause');
      expect(snap['line2'], '');
      expect(snap['isPause'], true);
      expect(snap['isRunning'], false);
      expect(snap['reps'], 0);
    });

    test('nextText zeigt die naechste Uebung, mit "Naechste:"-Praefix', () {
      final s = _state(intervals: [
        _iv(exerciseTypeId: 'swing_beidarmig'),
        _iv(exerciseTypeId: 'snatch', side: ExerciseSide.rechts, variantId: 'kb_24'),
      ]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['nextText'], 'Nächste: Kettlebell 24 kg · Snatch · R');
    });

    test('nextText fuer Pause-Intervall exakt wie am Handy formatiert', () {
      final s = _state(
          intervals: [_iv(), _iv(isPause: true, reps: 0, durationSeconds: 60)]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['nextText'], 'Nächste: Pause · 60s');
    });

    test('nextText ist leer beim letzten Intervall', () {
      final s = _state(intervals: [_iv()], currentMinute: 0);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['nextText'], '');
    });

    test('finished-Snapshot sucht rueckwaerts bis zur letzten Nicht-Pause-Uebung', () {
      final s = _state(
        intervals: [
          _iv(exerciseTypeId: 'swing_beidarmig', variantId: 'kb_16'),
          _iv(isPause: true, reps: 0),
        ],
        currentMinute: 1,
        isFinished: true,
      );
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['line1'], 'Kettlebell 16 kg');
      expect(snap['line2'], 'Swing beidarmig');
      expect(snap['screenState'], 'finished');
    });

    test('totalReps ist die Plan-Summe, nicht totalRepsDone', () {
      final s = _state(intervals: [_iv(reps: 10), _iv(reps: 20)]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['totalReps'], 30);
    });

    test('equipmentIcon ist der Dateiname ohne Pfad/Extension aus iconAsset', () {
      final iv = _iv(equipmentTypeId: 'kettlebell');
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['equipmentIcon'], 'kettlebell');
    });

    test('equipmentIcon ist leer bei Pause-Intervallen', () {
      final iv = _iv(isPause: true, reps: 0);
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['equipmentIcon'], '');
    });

    test('equipmentIcon ist leer, wenn equipmentTypeId nicht im Katalog ist', () {
      final iv = _iv(equipmentTypeId: 'does_not_exist');
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['equipmentIcon'], '');
    });

    test('isTimed-Intervall: reps 0, duration ist das Ziel', () {
      final s = _state(
        intervals: [_iv(reps: 0, durationSeconds: 45), _iv()],
        timedFlags: [true, false],
      );
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['isTimed'], true);
      expect(snap['isRunning'], false);
      expect(snap['reps'], 0);
      expect(snap['duration'], 45);
    });

    test(
        'pausierter Zeit-Uebung-Hold: screenState bleibt holding, isRunning wird trotzdem als false mitgeschickt',
        () {
      // Der Bug, den dieser Test verhindert: watchScreenStateFor() liefert
      // "holding" unabhaengig von isRunning (siehe dort), aber ohne
      // isRunning im Snapshot konnte die Uhr eine pausierte Zeit-Uebung
      // (z.B. durch Auto-Pause beim Seitenwechsel, workout_screen.dart)
      // nicht von einer laufenden unterscheiden und zaehlte einfach weiter.
      final s = _state(
        intervals: [_iv(reps: 0, durationSeconds: 45)],
        timedFlags: [true],
        holdStarted: true,
        isRunning: false,
      );
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['screenState'], 'holding');
      expect(snap['isRunning'], false);
    });
  });

  group('watchChangeKeyFor', () {
    test('gleicher Schluessel bei reinem secondsLeft-Wechsel', () {
      final a = _state(intervals: [_iv()], isRunning: true, secondsLeft: 42);
      final b = _state(intervals: [_iv()], isRunning: true, secondsLeft: 41);
      expect(watchChangeKeyFor(a), watchChangeKeyFor(b));
    });

    test('unterschiedlicher Schluessel bei Minutenwechsel', () {
      final a = _state(intervals: [_iv(), _iv()], currentMinute: 0);
      final b = _state(intervals: [_iv(), _iv()], currentMinute: 1);
      expect(watchChangeKeyFor(a), isNot(watchChangeKeyFor(b)));
    });

    test('unterschiedlicher Schluessel bei isRunning-Wechsel', () {
      final a = _state(intervals: [_iv()], isRunning: false);
      final b = _state(intervals: [_iv()], isRunning: true);
      expect(watchChangeKeyFor(a), isNot(watchChangeKeyFor(b)));
    });

    test('unterschiedlicher Schluessel bei waitingForConfirmation-Wechsel', () {
      final a = _state(intervals: [_iv(), _iv()], waitingForConfirmation: false);
      final b = _state(intervals: [_iv(), _iv()], waitingForConfirmation: true);
      expect(watchChangeKeyFor(a), isNot(watchChangeKeyFor(b)));
    });

    test('unterschiedlicher Schluessel bei Reset/Planwechsel trotz gleicher Minute und isRunning', () {
      // Realer Fall: Nutzer steht bei Minute 0, pausiert; wechselt in der
      // Planbibliothek den aktiven Plan (Reset auf Minute 0). minute,
      // isRunning, isPause, isTimed etc. sind hier alle identisch zu vorher
      // -- ohne Intervall-Inhalt im Schluessel wuerde die Uhr die neue
      // Uebung nie zu sehen bekommen.
      final a = _state(intervals: [
        _iv(exerciseTypeId: 'swing_beidarmig'),
        _iv(),
      ]);
      final b = _state(intervals: [
        _iv(exerciseTypeId: 'snatch'),
        _iv(),
      ]);
      expect(watchChangeKeyFor(a), isNot(watchChangeKeyFor(b)));
    });

    test('unterschiedlicher Schluessel bei anderer Plan-Laenge (totalMinutes)', () {
      final a = _state(intervals: [_iv(), _iv()]);
      final b = _state(intervals: [_iv(), _iv(), _iv()]);
      expect(watchChangeKeyFor(a), isNot(watchChangeKeyFor(b)));
    });
  });
}
