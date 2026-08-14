import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Ziel: nur physische Tastendruecke steuern die App, keine Geste loest je
// etwas aus (siehe Design-Spec Abschnitt 3). onSelect()/onBack() lehnen
// bewusst ab (return false), damit die eigentliche Logik ausschliesslich
// ueber die darunterliegenden Events laeuft, die sich pro Ausloeser
// unterscheiden lassen: onKey(KEY_ENTER) fuer den oberen Knopf,
// onKeyPressed/onKeyReleased(KEY_ESC) fuer Kurz/Lang-Druck am unteren
// Knopf. onTap()/onHold()/onRelease()/onDrag()/onFlick()/onSwipe() sind
// No-ops, damit wirklich keine Geste etwas ausloest.
class garmin_watch_appDelegate extends WatchUi.BehaviorDelegate {

    private const HOLD_THRESHOLD_MS = 600;

    // Ergebnis der Laufzeit-Discovery (s. Task 4, Schritt 1). Falls euer
    // Simulator-Log KEY_LAP statt KEY_ESC zeigte, hier WatchUi.KEY_LAP
    // eintragen.
    private const BACK_KEY = WatchUi.KEY_ESC;

    private var _backPressStart as Number?;
    private var _backPressKey as Number?;

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onRelease(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onDrag(dragEvent as WatchUi.DragEvent) as Boolean {
        return true;
    }

    function onFlick(flickEvent as WatchUi.FlickEvent) as Boolean {
        return true;
    }

    function onBack() as Boolean {
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            var snapshot = WatchState.current;
            if (snapshot != null) {
                var screenState = snapshot.get("screenState");
                if (screenState.equals("confirming")) {
                    sendWatchCommand("cmd_confirm");
                } else if (screenState.equals("running")) {
                    sendWatchCommand("cmd_pause");
                } else if (!screenState.equals("finished")) {
                    sendWatchCommand("cmd_resume");
                }
            }
        }
        // Jede andere Taste, insbesondere KEY_ESC (echter unterer Knopf UND
        // eine auf manchen Geraeten als KEY_ESC getarnte Swipe-Geste), wird
        // hier bewusst ignoriert -- die Skip/Exit-Logik dafuer laeuft
        // ausschliesslich ueber onKeyPressed/onKeyReleased unten. Wuerde
        // onKey() hier zusaetzlich auf KEY_ESC reagieren, wuerde ein
        // einzelner unterer Tastendruck Skip doppelt ausloesen.
        return true;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() != BACK_KEY) { return false; }
        _backPressStart = System.getTimer();
        _backPressKey = BACK_KEY;
        return true;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() != BACK_KEY || _backPressKey != BACK_KEY || _backPressStart == null) {
            return false;
        }
        var heldMs = System.getTimer() - _backPressStart;
        _backPressStart = null;
        _backPressKey = null;
        if (heldMs >= HOLD_THRESHOLD_MS) {
            System.exit();
            return true;
        }
        var snapshot = WatchState.current;
        if (snapshot == null) {
            return true;
        }
        var screenState = snapshot.get("screenState");
        if (!screenState.equals("confirming") && !screenState.equals("finished")) {
            sendWatchCommand("cmd_skip");
        }
        return true;
    }

    // Befristeter Fallback (siehe Design-Spec Abschnitt 3): bleibt aktiv,
    // bis Halten-zum-Beenden auf echter Hardware bestaetigt ist, dann in
    // einem eigenen Folge-Commit entfernen (dann no-op fuer alle
    // Richtungen wie unten fuer den Nicht-SWIPE_LEFT-Fall bereits der
    // Fall). Bewusst SWIPE_LEFT (rechts nach links), nicht SWIPE_RIGHT --
    // Letzteres kollidiert auf manchen Geraeten mit KEY_ESC und kaeme
    // vermutlich nie hier an.
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        if (swipeEvent.getDirection() == WatchUi.SWIPE_LEFT) {
            System.exit();
        }
        return true;
    }

}
