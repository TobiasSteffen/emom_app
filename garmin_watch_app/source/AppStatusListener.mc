import Toybox.Communications;
import Toybox.System;

// Sendebestaetigung fuer die App-Status-Nachricht ("opened"/"closed").
// Fehler werden nur geloggt, kein Retry -- siehe "Nachrichten-Zustellung
// ist best-effort" in der Design-Spec.
class AppStatusListener extends Communications.ConnectionListener {
    function initialize() {
        ConnectionListener.initialize();
    }

    function onComplete() as Void {
    }

    function onError() as Void {
        System.println("garmin_watch_app: Communications.transmit fehlgeschlagen");
    }
}
