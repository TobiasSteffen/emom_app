import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

class garmin_watch_appApp extends Application.AppBase {

    var snapshotListener as StateSnapshotListener?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        Communications.transmit("opened", {}, new AppStatusListener());
        snapshotListener = new StateSnapshotListener();
        snapshotListener.register();
        WatchState.startTicking();
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        Communications.transmit("closed", {}, new AppStatusListener());
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new garmin_watch_appView(), new garmin_watch_appDelegate() ];
    }

}

function getApp() as garmin_watch_appApp {
    return Application.getApp() as garmin_watch_appApp;
}

// Sendet ein Bedien-Kommando ans Handy -- von garmin_watch_appDelegate bei
// Tastendruck aufgerufen (siehe Design-Spec, Button-Zustandsmaschine).
function sendWatchCommand(command as String) as Void {
    Communications.transmit(command, {}, new AppStatusListener());
}
