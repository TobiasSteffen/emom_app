import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// onSelect() (oberer Button) beendete die App bisher (Hello-World-Spike-
// Platzhalter) -- entfaellt jetzt, der obere Button steuert Pause/Weiter/
// Start/Fertig. Der untere Button (onBack()) steuert Skip.
//
// KORREKTUR (Korrekturlesung): Exit laeuft NICHT ueber die native
// Swipe-Rechts-Geste, wie eine fruehere Fassung dieser Spec/dieses Plans
// annahm. Laut SDK-Doku zu BehaviorDelegate.onBack() interpretieren manche
// Geraete SWIPE_RIGHT intern als KEY_ESC -- auf solchen Geraeten wuerde ein
// Exit-Swipe genau denselben onBack()-Callback ausloesen wie der untere
// Button, also "cmd_skip" senden statt die App zu beenden, und es gaebe
// gar keinen Exit-Weg mehr. Deshalb: Exit ueber eine eigene, von
// onBack()/KEY_ESC unabhaengige Geste (Swipe nach LINKS statt rechts).
// WICHTIG: onSwipe()/SwipeEvent/getDirection()/SWIPE_LEFT vor dem Bauen
// gegen die installierte SDK-Doku verifizieren -- anders als die uebrigen
// APIs in diesem Plan wurde dieser Teil (als Reaktion auf den Fund) noch
// nicht gegen ein echtes SDK kompiliert.
class garmin_watch_appDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Oberer Button: Pause/Weiter/Start/Fertig, je nach aktuellem
    // screenState (siehe WatchState) -- die Watch entscheidet nur zwischen
    // "cmd_pause" (laeuft gerade) und "cmd_resume" (alles andere), die
    // Feinauswertung (Start vs. Zeit-Uebung vs. Fertig) macht das Handy
    // anhand seines vollstaendigen WorkoutState (siehe applyWatchCommand).
    function onSelect() as Boolean {
        var snapshot = WatchState.current;
        if (snapshot == null) { return true; }
        var screenState = snapshot.get("screenState");
        if (screenState.equals("confirming")) {
            sendWatchCommand("cmd_confirm");
        } else if (screenState.equals("running")) {
            sendWatchCommand("cmd_pause");
        } else if (!screenState.equals("finished")) {
            sendWatchCommand("cmd_resume");
        }
        return true;
    }

    // Unterer Button (Back/Lap): Skip.
    function onBack() as Boolean {
        var snapshot = WatchState.current;
        if (snapshot == null) { return true; }
        var screenState = snapshot.get("screenState");
        if (!screenState.equals("confirming") && !screenState.equals("finished")) {
            sendWatchCommand("cmd_skip");
        }
        return true;
    }

    // Eigene, von onBack()/KEY_ESC unabhaengige Exit-Geste (siehe Kommentar
    // oben am Klassenkopf).
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        if (swipeEvent.getDirection() == WatchUi.SWIPE_LEFT) {
            System.exit();
            return true;
        }
        return false;
    }

}
