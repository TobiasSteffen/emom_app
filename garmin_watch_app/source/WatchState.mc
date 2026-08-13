import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Haelt den zuletzt empfangenen state_snapshot-Payload vom Handy UND
// rechnet den Countdown dazwischen lokal weiter (siehe Design-Spec,
// Scope-Entscheidung 1: das Handy pusht nur bei Zustandswechseln, nicht
// jede Sekunde -- ohne diesen lokalen Tick wuerde der Timer auf dem
// Running-Screen zwischen zwei Snapshots einfach stehenbleiben).
module WatchState {
    var current as Dictionary? = null;
    var localSecondsLeft as Number = 0;
    var _ticker as WatchStateTicker?;

    function update(snapshot as Dictionary) as Void {
        current = snapshot;
        localSecondsLeft = snapshot.get("secondsLeft") as Number;
    }

    // Einmal aus garmin_watch_appApp.onStart() aufgerufen, laeuft dauerhaft.
    function startTicking() as Void {
        if (_ticker != null) { return; }
        _ticker = new WatchStateTicker();
        _ticker.start();
    }

    function tick() as Void {
        if (current == null) { return; }
        var screenState = current.get("screenState") as String;
        // Nur running/holding zaehlen ueberhaupt runter -- paused/hold_waiting
        // stehen still, confirming/finished zeigen keinen Live-Timer.
        var counting = screenState.equals("running") || screenState.equals("holding");
        if (!counting) { return; }
        // Ausser im holding-Zustand (Ueberzeit ist vorgesehen, siehe
        // TimerDisplay am Handy) haelt der Countdown bei 0 an, statt negativ
        // weiterzuzaehlen (Design-Spec, Fehlerbehandlung).
        var floorAtZero = !screenState.equals("holding");
        if (floorAtZero && localSecondsLeft <= 0) { return; }
        localSecondsLeft -= 1;
        WatchUi.requestUpdate();
    }
}

// `method(:symbol)` braucht ein Klassen-`self` -- ein `module` hat keins,
// deshalb traegt eine eigene, winzige Klasse den Timer und delegiert jeden
// Tick an WatchState.tick(). Gefunden beim tatsaechlichen Build gegen das
// installierte SDK (Compile-Fehler "Cannot find symbol ':method' on type
// 'self'" bei einem method()-Aufruf direkt im module).
class WatchStateTicker {
    private var _timer as Timer.Timer;

    function initialize() {
        _timer = new Timer.Timer();
    }

    function start() as Void {
        _timer.start(method(:onTick), 1000, true);
    }

    function onTick() as Void {
        WatchState.tick();
    }
}
