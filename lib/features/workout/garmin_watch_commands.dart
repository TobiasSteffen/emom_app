import 'package:flutter/foundation.dart';
import 'workout_notifier.dart';

/// Setzt ein `cmd_*`-Kommando von der Uhr auf die passende
/// `WorkoutNotifier`-Methode um, mit Guards gegen verspaetete/ungueltige
/// Kommandos (siehe Design-Spec, Korrekturlesung: `confirmInterval()` und
/// `start()` haben selbst keine Guards).
void applyWatchCommand(
  String command,
  WorkoutState state, {
  required VoidCallback pause,
  required VoidCallback start,
  required VoidCallback confirmInterval,
  required VoidCallback skip,
  required VoidCallback startHold,
  required VoidCallback finishHold,
}) {
  switch (command) {
    case 'cmd_pause':
      if (state.isRunning) pause();
      return;
    case 'cmd_resume':
      if (state.holdWaiting) {
        startHold();
      } else if (state.currentIsTimed && state.holdStarted) {
        finishHold();
      } else if (!state.isRunning &&
          !state.waitingForConfirmation &&
          !state.isFinished) {
        start();
      }
      return;
    case 'cmd_confirm':
      if (state.waitingForConfirmation) confirmInterval();
      return;
    case 'cmd_skip':
      if (!state.waitingForConfirmation && !state.isFinished) skip();
      return;
  }
}
