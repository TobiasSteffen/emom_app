import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Rendert einen von drei Screens ausschliesslich anhand von
// WatchState.current["screenState"] (siehe Design-Spec, Abschnitt
// "Watch-Screens & Button-Zustandsmaschine"). Kein Rez.Layouts-XML --
// direktes Zeichnen ist bei drei dynamischen, textlastigen Screens
// einfacher als drei statische Layouts zu pflegen.
class garmin_watch_appView extends WatchUi.View {

    private var _iconCacheId as String = "";
    private var _iconCacheBitmap;

    private function iconBitmapFor(iconId as String) {
        if (iconId.equals(_iconCacheId)) {
            return _iconCacheBitmap;
        }
        var resource = _iconResource(iconId);
        if (resource == null) {
            return null;
        }
        _iconCacheId = iconId;
        _iconCacheBitmap = WatchUi.loadResource(resource);
        return _iconCacheBitmap;
    }

    // Rez.Drawables.* sind Compile-Zeit-Konstanten, koennen nicht per
    // Laufzeit-String indiziert werden -- deshalb diese explizite Map
    // (siehe Design-Spec Abschnitt 2).
    private function _iconResource(iconId as String) {
        if (iconId.equals("kettlebell")) { return Rez.Drawables.kettlebell; }
        if (iconId.equals("steelmace")) { return Rez.Drawables.steelmace; }
        if (iconId.equals("pezziball")) { return Rez.Drawables.pezziball; }
        if (iconId.equals("liegestuetz")) { return Rez.Drawables.liegestuetz; }
        if (iconId.equals("kniebeuge")) { return Rez.Drawables.kniebeuge; }
        if (iconId.equals("plank")) { return Rez.Drawables.plank; }
        if (iconId.equals("dehnen")) { return Rez.Drawables.dehnen; }
        return null;
    }

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

    private function textElement(text as String, font, color as Number) as Dictionary {
        return {:kind => "text", :value => text, :font => font, :color => color};
    }

    private function bitmapElement(bitmap, color as Number) as Dictionary {
        return {:kind => "bitmap", :value => bitmap, :color => color};
    }

    // Zeichnet Elemente (Text oder Bitmap) buendig untereinander, ohne
    // Ueberlappung, unabhaengig von den jeweiligen Schriftgroessen/Bitmap-
    // Hoehen (siehe Design-Spec Abschnitt 1 -- Graphics.TEXT_JUSTIFY_TOP
    // existiert in diesem SDK nicht, deshalb VCENTER + kumulierte
    // dc.getFontHeight()/bitmap.getHeight()-Werte statt geschaetzter
    // Pixel-Offsets). Gibt die Y-Position direkt unterhalb des letzten
    // Elements zurueck, damit nachfolgende Elemente (z.B. die grosse
    // Reps-Zahl) ihre Position daraus ableiten koennen statt sie zu raten.
    private function drawStack(dc as Dc, elements as Array, startY as Number) as Number {
        var cx = dc.getWidth() / 2;
        var y = startY;
        for (var i = 0; i < elements.size(); i++) {
            var element = elements[i];
            var kind = element.get(:kind) as String;
            var h;
            if (kind.equals("text")) {
                h = dc.getFontHeight(element.get(:font));
            } else {
                h = element.get(:value).getHeight();
            }
            var centerY = y + h / 2;
            if (kind.equals("text")) {
                dc.setColor(element.get(:color) as Number, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, centerY, element.get(:font), element.get(:value) as String,
                            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                var bitmap = element.get(:value);
                var w = bitmap.getWidth();
                dc.drawBitmap2(cx - w / 2, centerY - h / 2, bitmap,
                               {:tintColor => element.get(:color) as Number});
            }
            y += h;
        }
        return y;
    }

    // Wie drawStack(), aber ohne zu zeichnen -- damit ein Aufrufer weiss,
    // wie viel Platz ein Stack braucht, BEVOR er seine Startposition
    // festlegt (z.B. um direkt oberhalb eines fix positionierten Ankers
    // wie der grossen Zahl zu enden, statt nur top-down von einer
    // geschaetzten Konstante aus zu wachsen).
    private function stackHeight(dc as Dc, elements as Array) as Number {
        var total = 0;
        for (var i = 0; i < elements.size(); i++) {
            var element = elements[i];
            if (element.get(:kind).equals("text")) {
                total += dc.getFontHeight(element.get(:font));
            } else {
                total += element.get(:value).getHeight();
            }
        }
        return total;
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

        var headerElements = [] as Array;
        var line1 = snapshot.get("line1") as String;
        var line2 = snapshot.get("line2") as String;
        var iconId = snapshot.get("equipmentIcon");
        var icon = (iconId != null && !iconId.equals("")) ? iconBitmapFor(iconId as String) : null;
        if (icon != null) {
            headerElements.add(bitmapElement(icon, ringColor));
        } else if (!line1.equals("")) {
            // Fallback, falls kein equipmentIcon ankam (Pause, unbekannte
            // Ausruestung, oder ein aelterer Handy-Build ohne dieses Feld) --
            // zeigt den Text statt gar nichts (siehe Design-Spec Abschnitt 2).
            headerElements.add(textElement(line1, Graphics.FONT_XTINY, Graphics.COLOR_WHITE));
        }
        if (!line2.equals("")) {
            headerElements.add(textElement(line2, Graphics.FONT_XTINY, Graphics.COLOR_WHITE));
        }

        var isTimed = snapshot.get("isTimed") as Boolean;
        var numberFont = Graphics.FONT_NUMBER_MEDIUM;
        var numberY = cy;
        var headerStartY = numberY - dc.getFontHeight(numberFont) / 2 - 6 - stackHeight(dc, headerElements);
        drawStack(dc, headerElements, headerStartY);

        if (!isPause) {
            var big = isTimed ? snapshot.get("duration").toString() : snapshot.get("reps").toString();
            drawCentered(dc, big, numberY, numberFont, ringColor);
        }

        var countdownFont = Graphics.FONT_MEDIUM;
        var countdownY = numberY + dc.getFontHeight(numberFont) / 2 + dc.getFontHeight(countdownFont) / 2 + 6;
        drawCentered(dc, formatSeconds(WatchState.localSecondsLeft), countdownY, countdownFont, Graphics.COLOR_WHITE);

        var nextText = snapshot.get("nextText") as String;
        if (!nextText.equals("")) {
            var nextFont = Graphics.FONT_XTINY;
            var nextY = countdownY + dc.getFontHeight(countdownFont) / 2 + dc.getFontHeight(nextFont) / 2 + 6;
            drawCentered(dc, nextText, nextY, nextFont, Graphics.COLOR_LT_GRAY);
        }
    }

    private function drawConfirming(dc as Dc, snapshot as Dictionary) as Void {
        var cy = dc.getHeight() / 2;
        var elements = [
            textElement("NÄCHSTE ÜBUNG", Graphics.FONT_SMALL, Graphics.COLOR_ORANGE),
            textElement(snapshot.get("nextText") as String, Graphics.FONT_XTINY, Graphics.COLOR_WHITE),
        ] as Array;
        drawStack(dc, elements, cy - 30);
    }

    private function drawFinished(dc as Dc, snapshot as Dictionary) as Void {
        var cy = dc.getHeight() / 2;
        var summary = (snapshot.get("line1") as String) + " · " + (snapshot.get("line2") as String);
        var elements = [
            textElement("TRAINING BEENDET", Graphics.FONT_SMALL, Graphics.COLOR_ORANGE),
            textElement(snapshot.get("totalReps").toString(), Graphics.FONT_NUMBER_MEDIUM, Graphics.COLOR_WHITE),
            textElement(summary, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY),
        ] as Array;
        drawStack(dc, elements, cy - 60);
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
