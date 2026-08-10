import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

class garmin_watch_appApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        Communications.transmit("opened", {}, new AppStatusListener());
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