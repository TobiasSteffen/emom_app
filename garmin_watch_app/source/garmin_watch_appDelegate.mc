import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class garmin_watch_appDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        System.exit();
        return true;
    }

}