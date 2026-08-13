import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Rendert einen von drei Screens ausschliesslich anhand von
// WatchState.current["screenState"] (siehe Design-Spec, Abschnitt
// "Watch-Screens & Button-Zustandsmaschine"). Kein Rez.Layouts-XML --
// direktes Zeichnen ist bei drei dynamischen, textlastigen Screens
// einfacher als drei statische Layouts zu pflegen.
class garmin_watch_appView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var snapshot = WatchState.current;
        if (snapshot == null) {
            drawCentered(dc, "Verbinde...", dc.getHeight() / 2, Graphics.FONT_SMALL, Graphics.COLOR_LT_GRAY);
            return;
        }

        var screenState = snapshot.get("screenState") as String;
        if (screenState.equals("finished")) {
            drawFinished(dc, snapshot);
        } else if (screenState.equals("confirming")) {
            drawConfirming(dc, snapshot);
        } else {
            drawRunning(dc, snapshot);
        }

        drawButtonHints(dc, screenState);
    }

    function onHide() as Void {
    }

    private function drawCentered(dc as Dc, text as String, y as Number, font, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function phaseColorForMinute(minute as Number) as Number {
        // Muss mit lib/core/models/settings.dart::phaseColorForMinute in
        // Sync bleiben (siehe CLAUDE.md, Abschnitt "Phase color coding").
        if (minute < 5) { return 0x4CAF50; }
        if (minute < 15) { return 0xFF6B00; }
        if (minute < 20) { return 0xFF0000; }
        if (minute < 25) { return 0xFF6B00; }
        return 0x4CAF50;
    }

    private function formatSeconds(seconds as Number) as String {
        var overtime = seconds < 0;
        var abs = overtime ? -seconds : seconds;
        var m = abs / 60;
        var s = abs % 60;
        var text = m.format("%02d") + ":" + s.format("%02d");
        return overtime ? "+" + text : text;
    }

    private function drawRunning(dc as Dc, snapshot as Dictionary) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var isPause = snapshot.get("isPause") as Boolean;
        var ringColor = isPause ? Graphics.COLOR_DK_GRAY : phaseColorForMinute(snapshot.get("minute") as Number);

        dc.setPenWidth(6);
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        var totalMinutes = snapshot.get("totalMinutes") as Number;
        var minute = snapshot.get("minute") as Number;
        var degrees = totalMinutes > 0 ? (360.0 * minute / totalMinutes) : 0.0;
        // drawArc() zeichnet laut SDK-Doku einen VOLLEN Kreis, wenn Start-
        // und End-Winkel gleich sind -- bei Minute 0 (degrees == 0) waere
        // das sonst ein Vollkreis statt gar keinem Fortschritt.
        if (degrees >= 1) {
            dc.drawArc(cx, cy, cx - 6, Graphics.ARC_CLOCKWISE, 90, 90 - degrees);
        }

        drawCentered(dc, snapshot.get("line1") as String, cy - 55, Graphics.FONT_XTINY, Graphics.COLOR_WHITE);
        drawCentered(dc, snapshot.get("line2") as String, cy - 38, Graphics.FONT_XTINY, Graphics.COLOR_WHITE);

        var isTimed = snapshot.get("isTimed") as Boolean;
        if (!isPause) {
            var big = isTimed ? snapshot.get("duration").toString() : snapshot.get("reps").toString();
            drawCentered(dc, big, cy - 5, Graphics.FONT_NUMBER_MEDIUM, ringColor);
        }

        // WatchState.localSecondsLeft statt snapshot["secondsLeft"] --
        // der Snapshot ist nur der Stand zum Sendezeitpunkt, WatchState
        // zaehlt seitdem lokal weiter (siehe WatchState.mc, Task 9).
        drawCentered(dc, formatSeconds(WatchState.localSecondsLeft), cy + 35, Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE);

        var nextText = snapshot.get("nextText") as String;
        if (!nextText.equals("")) {
            drawCentered(dc, nextText, cy + 65, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY);
        }
    }

    private function drawConfirming(dc as Dc, snapshot as Dictionary) as Void {
        var cy = dc.getHeight() / 2;
        drawCentered(dc, "NÄCHSTE ÜBUNG", cy - 30, Graphics.FONT_SMALL, Graphics.COLOR_ORANGE);
        drawCentered(dc, snapshot.get("nextText") as String, cy + 10, Graphics.FONT_XTINY, Graphics.COLOR_WHITE);
    }

    private function drawFinished(dc as Dc, snapshot as Dictionary) as Void {
        var cy = dc.getHeight() / 2;
        drawCentered(dc, "TRAINING BEENDET", cy - 40, Graphics.FONT_SMALL, Graphics.COLOR_ORANGE);
        drawCentered(dc, snapshot.get("totalReps").toString(), cy, Graphics.FONT_NUMBER_MEDIUM, Graphics.COLOR_WHITE);
        drawCentered(dc, (snapshot.get("line1") as String) + " · " + (snapshot.get("line2") as String), cy + 40, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY);
    }

    private function drawButtonHints(dc as Dc, screenState as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var topLabel = "";
        if (screenState.equals("confirming") || screenState.equals("holding")) {
            topLabel = "OK";
        } else if (screenState.equals("running")) {
            topLabel = "II";
        } else if (!screenState.equals("finished")) {
            topLabel = ">";
        }
        if (!topLabel.equals("")) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 22, 14, Graphics.FONT_XTINY, topLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (!screenState.equals("confirming") && !screenState.equals("finished")) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 20, h - 14, Graphics.FONT_XTINY, ">>", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

}
