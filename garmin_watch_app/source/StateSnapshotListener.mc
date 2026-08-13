import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

// Empfaengt state_snapshot-Nachrichten vom Handy (Gegenstueck zu
// AppStatusListener.mc, das die Uhr->Handy-Richtung bedient). Registrierung
// einmalig in garmin_watch_appApp.onStart().
// Verifiziert: registerForPhoneAppMessages() kompiliert erfolgreich gegen
// SDK 9.2.0 (siehe Design-Spec, Abschnitt "Fehlerbehandlung").
class StateSnapshotListener {
    function register() as Void {
        Communications.registerForPhoneAppMessages(method(:onMessage));
    }

    function onMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (!(data instanceof Dictionary)) { return; }
        var dict = data as Dictionary;
        var type = dict.get("type");
        if (type != null && type.equals("state_snapshot")) {
            WatchState.update(dict);
            WatchUi.requestUpdate();
        }
    }
}
