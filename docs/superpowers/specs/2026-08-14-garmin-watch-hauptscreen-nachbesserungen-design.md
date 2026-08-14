# Garmin Watch Hauptscreen — Nachbesserungen (Design)

## Kontext

Das Plan `2026-08-12-garmin-watch-hauptscreen` wurde am 2026-08-13 formal geschlossen: die
Kernfunktion (Live-Spiegelung von Übung/Reps/Countdown/Phasenfarbe + Tastensteuerung auf die
Venu 4) ist fertig, reviewed und gemergt (Commit `9030e5f`). Die manuelle Hardware-Verifikation
(Task 11) auf einer echten Venu 4 fand fünf Punkte, die bewusst zurückgestellt und für einen
neuen Plan-Zyklus dokumentiert wurden (siehe `.superpowers/sdd/2026-08-12-garmin-watch-hauptscreen/progress.md`,
Zeilen 39–46, und `docs/emom_app_spezifikation.md`, Abschnitt "Garmin-Integration").

Neu in diesem Zyklus: ein funktionierender **lokaler Iterationsloop ohne echte Hardware** —
`monkeyc` baut gegen SDK 9.2.0, `simulator.exe` läuft, `monkeydo` pusht den Build hinein, und ein
Screenshot des Simulator-Fensters lässt sich direkt inspizieren. Für die Punkte 1 und 2 wird
dieser Loop zur Verifikation genutzt statt eines Sideloads auf die echte Uhr. Punkt 3 hat eine
geräte-spezifische Eigenart, die der Simulator nicht nachbilden kann (siehe dort).

Dieser Spec durchlief zwei unabhängige technische Reviews (Opus, hohe Prüftiefe). Beide fanden
echte Fehler — auch die "Korrekturen" nach dem ersten Review enthielten einen neuen Fehler
(falsche Root-Cause-Zuordnung in Punkt 4, s. dort). Diese Fassung ist die nach dem zweiten Review
überarbeitete Version.

## Ziel / Scope

Vier der fünf zurückgestellten Punkte:

1. Screen-Layout-Overlap (Zeilen überlappen sich auf allen drei Watch-Screens)
2. Equipment-Icon auf dem Running-Screen
3. Gesten sollen nie etwas auslösen; nur die physischen Knöpfe steuern die App (Sicherheits-/UX-Bug)
4. Cold-Start-Verbindungs-Icon braucht vollständigen App-Neustart zum Aktualisieren

Punkt "SnackBar entfernt" (ursprüngliche Findings-Liste, Punkt 2) ist **weiterhin offen**, nicht
Teil dieses Zyklus. Laut `progress.md` Zeile 46 wurde der Fix explizit verworfen (`git checkout --`),
nicht committet; der Code bestätigt das (`lib/features/workout/widgets/garmin_header_icon.dart:33-37`
zeigt die SnackBar weiterhin an; identisch auch in `lib/features/config/config_screen.dart:139-143`
— falls später angegangen, beide Stellen prüfen).

**Nicht-Ziel:** Equipment-Icon auf Confirming-/Finished-Screen (nur Running-Screen, wie
angefragt). Vitaldaten-Sync (Herzfrequenz etc.) — separates, größeres Thema, nicht Teil dieses
Zyklus.

## 1. Screen-Layout-Fix

**Root Cause:** `Graphics.TEXT_JUSTIFY_TOP` existiert in SDK 9.2.0 nicht (nur `LEFT`/`RIGHT`/
`CENTER`/`VCENTER`, per SDK-Doku und Community-Recherche bestätigt — Connect IQ hat keinen
Auto-Layout-Container wie WPF's StackPanel; jedes Element braucht eine explizite Position). Der
vorherige `drawStack()`-Versuch scheiterte deshalb am Build. Die bisherigen Y-Offsets in
`drawRunning`/`drawConfirming`/`drawFinished` sind geschätzte Pixelwerte statt gemessener
Schrifthöhen.

**Element-Modell (vereinheitlicht für Text und Icon, s. Punkt 2):** Ein Stack ist eine Liste aus
Elementen, jedes entweder `{kind: "text", value, font, color}` oder `{kind: "bitmap", value,
color}` — auch das Bitmap-Element trägt eine Farbe, für das Tinting (s. Punkt 2). Leere Text-Werte
(`""`) werden vor dem Aufbau der Liste weggelassen, verbrauchen keinen Slot.

**Fix:** Neuer Helper in `garmin_watch_appView.mc`:

```
drawStack(dc, elements, startY) -> endY
  y = startY
  for each element in elements:
    h = element.kind == "text"
          ? dc.getFontHeight(element.font)
          : element.value.getHeight()          // Bitmap-Höhe
    centerY = y + h / 2
    if element.kind == "text":
      dc.setColor(element.color, Graphics.COLOR_TRANSPARENT)
      dc.drawText(cx, centerY, element.font, element.value,
                  Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER)
    else:
      var w = element.value.getWidth()
      dc.drawBitmap2(cx - w / 2, centerY - h / 2, element.value, {:tintColor => element.color})
    y += h
  return y
```

Element *i* belegt exakt `[y, y+h_i]`, aufeinanderfolgende Zentren liegen `(h_{i-1}+h_i)/2`
auseinander — bündig, ohne Überlappung, unabhängig davon wie stark sich die Schriftgrößen der
Zeilen unterscheiden (z. B. `FONT_XTINY` neben `FONT_NUMBER_MEDIUM`). Jedes Element ist intern an
seiner vertikalen Mitte verankert (Text nutzt dafür `VCENTER` direkt, Bitmap rechnet die Mitte auf
die von `drawBitmap2()` verlangte Top-Left-Ecke um) — keine Vermischung zweier Anker-Konventionen.

`startY` ist pro Screen eine Konstante (Top-anchored). Der Fortschrittsring bleibt unverändert ein
eigener, bildschirmfüllender `dc.drawArc(cx, cy, ...)`-Aufruf (kein Stack-Element, keine Y-Position
im hier beschriebenen Sinn). Große Reps/Zeit-Zahl, Countdown und `nextText` bleiben eigene
`drawCentered()`-Aufrufe unterhalb des Stacks; ihre Y-Position wird **aus dem von `drawStack()`
zurückgegebenen `endY` abgeleitet** (z. B. `endY + Abstand`), nicht als unabhängige Konstante
geraten — sonst bleibt `endY` ungenutzt und der Zusammenhang zwischen Stack-Höhe und
nachfolgendem Element ist wieder nur geschätzt statt berechnet.

**Testing:** Kein automatisierter Render-Test möglich (Monkey C hat kein Pixel-Vergleichs-
Testing in diesem Projekt). Verifikation über den lokalen Simulator-Loop: Build → `monkeydo` →
Screenshot für alle drei Screens (running/confirming/finished, inkl. Pause-Intervall-Variante von
running) und visuelle Kontrolle auf Überlappung.

## 2. Equipment-Icon auf dem Running-Screen

**Datenfluss:** `buildStateSnapshot()` (`lib/features/workout/garmin_watch_snapshot.dart`) bekommt
ein neues Feld `equipmentIcon: String`, abgeleitet aus dem `iconAsset`-Dateinamen des aktuellen
Intervalls (z. B. `assets/icon/kettlebell.png` → `"kettlebell"` — Dateiname ohne Pfad/Extension).
Bei Pause-Intervallen: leerer String — die Watch zeigt dann (wie bisher) nur den Text "Pause" als
Stack-Element, kein Icon. `watchChangeKeyFor()` braucht keine Anpassung, `equipmentTypeId` ist dort
bereits enthalten.

**Watch-Ressourcen:** Alle 7 bekannten Icons (`kettlebell`, `steelmace`, `pezziball`,
`liegestuetz`, `kniebeuge`, `plank`, `dehnen` — feste Liste aus `kEquipmentIconAssets`, keine frei
hochladbaren Bilder) werden als kleine Bitmaps (~40×40px) in `garmin_watch_app/resources/drawables/drawables.xml`
gebündelt und als `Rez.Drawables.*` registriert. `Rez.Drawables.*`-Symbole sind Compile-Zeit-
Konstanten und lassen sich nicht per Laufzeit-String indizieren — der Code braucht eine explizite
statische Lookup-Map:

```
_ICONS = {
  "kettlebell" => Rez.Drawables.kettlebell,
  "steelmace"  => Rez.Drawables.steelmace,
  "pezziball"  => Rez.Drawables.pezziball,
  "liegestuetz" => Rez.Drawables.liegestuetz,
  "kniebeuge"  => Rez.Drawables.kniebeuge,
  "plank"      => Rez.Drawables.plank,
  "dehnen"     => Rez.Drawables.dehnen,
}
```

**Export-Entscheidung statt Palette-Annahme:** `automaticPalette` ist auf 16-Bit-Farb-Geräten
(Venu 4) bereits Standard — eine explizite Palette-Angabe bringt hier nichts. Das eigentliche
Risiko liegt bei Transparenz: Connect-IQ-Bitmaps kennen nur eine einzelne Transparenzfarbe, keinen
Alphakanal. Ein Teil der 7 Original-PNGs hat halbtransparente Kantenpixel (Anti-Aliasing gegen
Transparenz) — beim Herunterskalieren auf ~40×40px müssen diese Kanten bewusst gegen einen festen
Hintergrund geglättet ("geflattet") werden, sonst entstehen harte Treppenstufen oder (SDK-
dokumentiert) eine `Graphics.InvalidPaletteException` zur Laufzeit. `drawables.xml` kann den
Resource-Compiler das Skalieren übernehmen lassen (`scaleX`/`scaleY`), das erspart einen manuellen
Bild-Export-Schritt für die reine Größenänderung; die Transparenz-/Kantenentscheidung bleibt davon
unberührt.

**Farbgebung:** Am Handy werden dieselben Icons als Maske eingefärbt (`Image.asset(iconPath, …,
color: phaseColor)`, `reps_card.dart`) — die eigentliche PNG-Farbe wird dort immer überschrieben.
`dc.drawBitmap()` kennt kein Tinting, aber `dc.drawBitmap2(x, y, bitmap, {:tintColor => c})`
existiert seit API 4.2.1 und ist für "Venu® 4 45mm" gelistet (Manifest-`minApiLevel` 6.0.2 deckt
das ab). Das Icon-Stack-Element (s. Punkt 1) bekommt `ringColor` als `color`-Feld mit (derselbe
Wert, der schon für den Fortschrittsring berechnet wird — Phasenfarbe, bzw. Grau bei Pause) und
`drawStack()` zeichnet Bitmap-Elemente entsprechend mit `drawBitmap2`/`:tintColor` statt in der
eingebackenen Originalfarbe — sonst würde z. B. das rötliche `liegestuetz`-Icon fälschlich wie ein
Peak-Phasen-Hinweis wirken, unabhängig von der tatsächlichen Minute.

**Ressourcen-Laden:** SDK-Doku warnt ausdrücklich: *"Loading a resource can be an expensive
operation, so do not load resources when handling screen updates."* `onUpdate()` wird zwar nicht
buchstäblich jede Sekunde neu gezeichnet (`WatchState.tick()` ruft `requestUpdate()` nur während
eines laufenden Countdowns auf), aber während eines aktiven Intervalls tut es das laufend. Deshalb:
ein Ein-Element-Cache (letzte geladene `equipmentIcon`-ID + zugehörige `BitmapResource`) auf
Klassenebene in `garmin_watch_appView`. `drawRunning()` lädt per `Application.loadResource()` nur
dann neu, wenn die aktuelle `equipmentIcon`-ID vom gecachten Wert abweicht (passiert nur bei
Intervallwechsel). Nicht alle 7 Bitmaps bleiben gleichzeitig resident, nur das gerade genutzte.

**Rendering:** `drawRunning()` baut die Stack-Elemente für den Running-Screen als
`[icon-oder-nichts, line2]` (Icon ersetzt die bisherige Zeile 1) und übergibt sie an `drawStack()`
(s. Punkt 1). Gewicht/Variante (`"16kg"`) geht als sichtbarer Text verloren (bewusste
Entscheidung, s. Brainstorming).

**Fehlerbehandlung:**
- `equipmentIcon`-Wert ohne Eintrag in `_ICONS` (z. B. künftig neues Icon am Handy, altes
  Watch-Build) oder Feld fehlt komplett im Snapshot (älterer Handy-Build) → **Fallback auf den
  bisherigen Text** (`line1`, z. B. "Kettlebell 16kg") statt auf eine leere Zeile — verliert dann
  zwar die Icon-Optik, aber nicht die Information, welches Gerät gemeint ist.
- Phone-seitig: `catalog.findType() == null` liefert weiterhin `'?'` als `line1` (bestehender
  Pfad); `equipmentIcon` ist in diesem Fall leerer String, Watch fällt auf `'?'`-Text zurück (s.
  oben) — keine neue Fallunterscheidung nötig.

**Betroffene Screen-Zustände:** `drawRunning()` wird von `running`, `paused`, `holdWaiting` und
`holding` genutzt (nicht nur vom namensgebenden `running`-Zustand) — das Icon erscheint in allen
vieren, dem Zustand entsprechend mit demselben Intervall-Inhalt wie bisher Zeile 1.

**Testing:** Dart-seitig neuer Test in `garmin_watch_snapshot_test.dart` (Mapping `iconAsset` →
`equipmentIcon`-ID für alle 7 Fälle + Pause-Fall + fehlender/unbekannter Catalog-Eintrag).
Watch-seitig: Simulator-Loop wie bei Punkt 1, zusätzlich Build-Erfolg als Nachweis, dass die
Bitmap-Ressourcen keinen Laufzeitfehler verursachen (Simulator zeigt `InvalidPaletteException`
als Absturz, falls es doch auftritt).

## 3. Gesten sollen nie etwas auslösen — nur physische Knöpfe steuern die App

**Ziel (final geklärt mit Nutzer):** Nur drei Eingaben lösen etwas aus: oberer Knopf kurz =
Pause/Weiter/Bestätigen (unverändert), unterer Knopf kurz = Skip (unverändert), unterer Knopf
**gehalten** = Exit. Jede Wisch-Geste und jeder Bildschirm-Tap sollen **nichts** tun.

**Warum diese Zuordnung und nicht z. B. "oben halten = Skip":** Skip ist die mit Abstand
häufigste Aktion (potenziell jede Minute bei einem 30-Minuten-EMOM) — ein Halten-Erfordernis
würde den Workout-Fluss spürbar bremsen. Exit passiert höchstens einmal pro Session — genau die
Art seltener, folgenreicher Aktion, für die ein bewusstes Halten laut UX-Konvention gedacht ist.

**Root Cause der Kollision (SDK-Doku-bestätigt, `BehaviorDelegate.onBack()`):**
*"Some devices interpret SWIPE_RIGHT SwipeEvents as KEY_ESC events. On these devices, returning
`false` will cause `onKey()` to be called rather than `onSwipe()`."* Auf dieser Venu 4 wird die
"App schließen"-Wischgeste (Swipe-Rechts) vom Betriebssystem **unterhalb** der App-Logik in ein
`KEY_ESC`-Ereignis umgewandelt, bevor `onSwipe()` sie je sieht. Dieses `KEY_ESC` landet zuerst bei
der High-Level-Behandlung `onBack()` — **nicht** bei den Low-Level-Events `onKeyPressed`/
`onKeyReleased`. `onBack()` bekommt das Ereignis zuerst; nur ein `false`-Return lässt es zu
`onKey()` durchfallen. Allgemeiner (SDK-Doku, `BehaviorDelegate`-Übersicht): *"If a
BehaviorDelegate returns true for a function … then the InputDelegate function that corresponds
to the behavior will not be called."* Dieselbe Logik gilt für `onSelect()` — laut Doku wird das
**auch durch einen Bildschirm-Tap ausgelöst** (`CLICK_TYPE_TAP` auf Touchscreen-Geräten, Venu 4
hat einen), nicht nur durch den physischen Knopf. Ein Entwurf, der `onSelect()` unverändert lässt,
würde also weiterhin jeden Tap auf den Bildschirm als Pause/Weiter/Bestätigen behandeln — das
widerspräche dem Ziel "keine Geste tut etwas" direkt.

**Fix (Kanaltrennung für beide Knöpfe, nicht nur den unteren):**

- **`onSelect()`** gibt `false` zurück (lehnt ab). Laut SDK-Doku (`BehaviorDelegate`-Übersicht:
  "the InputDelegate function *that corresponds to the behavior* will not be called") heißt das
  konkret: der physische Tastendruck (`KEY_ENTER`) fällt zu `onKey()` durch, ein Tap dagegen zu
  `onTap()` — zwei getrennte Fallthrough-Ziele, kein gemeinsames. Die Play/Pause/Bestätigen-Logik
  wandert deshalb in **`onKey(keyEvent)`**, dort aber ausschließlich auf `KEY_ENTER` reagierend
  (exakte Konstante wird beim Bauen verifiziert, s. u.) — **jede andere Taste, insbesondere
  `KEY_ESC`, wird in `onKey()` ignoriert (`return true`, keine Aktion, kein Skip/Exit-Branch)**.
  Das ist wichtig: ein einzelner unterer Tastendruck erzeugt sowohl `onKeyPressed`/`onKeyReleased`
  (dort greift die Skip/Exit-Logik) als auch — über den abgelehnten `onBack()` — ein zusätzliches
  `onKey(KEY_ESC)`. Würde `onKey()` auch auf `KEY_ESC` reagieren, würde Skip doppelt ausgelöst.
- **`onTap(clickEvent)`** — no-op (`return true`, keine Aktion). Fängt den Fallthrough von
  `onSelect()` für Tap-Events auf.
- **`onHold(clickEvent)` / `onRelease(clickEvent)` / `onDrag(dragEvent)` / `onFlick(flickEvent)`**
  — ebenfalls no-op (`return true`). Für "Venu® 4 45mm" laut SDK-Doku unterstützt; ohne explizites
  No-op wäre die Zielaussage "keine Geste tut etwas" nicht vollständig — heute nutzt die App keine
  scrollbaren/`Selectable`-Elemente, die diese Events auslösen würden, aber die Handler sollen das
  nicht dem Zufall überlassen.
- **`onBack()`** gibt `false` zurück (lehnt ab), statt wie bisher `true`. Fällt laut Doku zu
  `onKey(KEY_ESC)` durch.
- **`onKeyPressed(keyEvent)` / `onKeyReleased(keyEvent)`** — implementieren für den unteren Knopf
  die Skip/Exit-Unterscheidung per echter Press/Release-Zeitmessung (Schwelle 600ms), gefiltert auf
  die Back/Lap-Tasten-Konstante. Zeitstempel wird zusammen mit der gedrückten Taste gespeichert;
  ein `onKeyReleased` mit abweichender Taste oder ohne vorherigen Press wird ignoriert (schützt
  gegen den Fall, dass ein Halten vom System nie mit einem Release quittiert wird). Exit ist
  **nicht** hinter dem bisherigen `WatchState.current == null`-Guard versteckt: auch auf dem
  "Verbinde..."-Screen muss Halten funktionieren.
- **`onSwipe(swipeEvent)`** — no-op für alle Richtungen. Deckt den Fall ab, dass eine Wisch-Geste
  ganz regulär als `SwipeEvent` ankommt (nicht als getarntes `KEY_ESC`).

**Befristeter Fallback — `SWIPE_LEFT` bleibt vorerst als zusätzlicher Exit-Weg aktiv:** Der
bisherige, nachweislich funktionierende Exit über `onSwipe()`/`SWIPE_LEFT` (rechts nach links) wird
**nicht** entfernt, bevor Halten-zum-Beenden auf echter Hardware bestätigt ist. Das widerspricht
kurzzeitig dem Ziel "keine Geste tut etwas", verhindert aber, dass die App im Fall einer falschen
Annahme zur Event-Reihenfolge komplett unbeendbar wird. `SWIPE_LEFT` bewusst nicht auf die
"natürliche" Richtung (links nach rechts / `SWIPE_RIGHT`) gelegt — das ist exakt die Richtung, die
auf dieser Venu 4 mit `KEY_ESC` kollidiert und vermutlich gar nicht bei `onSwipe()` ankäme. Sobald
Halten-zum-Beenden auf der echten Uhr bestätigt ist, wird dieser Fallback in einem Folge-Commit
entfernt (dann greift `onSwipe()`s No-op für alle Richtungen inkl. `SWIPE_LEFT`).

**Verbleibende Unsicherheit (nur auf echter Hardware zu klären, nicht im Simulator):** Ob eine
vom System als `KEY_ESC` getarnte Wisch-Geste tatsächlich `onKeyPressed`/`onKeyReleased`
**nicht** auslöst (nur `onBack()` → `onKey()`), ist eine SDK-Doku-gestützte, aber nicht
hardwareseitig bewiesene Annahme — die Doku beschreibt nur den Fallthrough zu `onKey()`, nicht
explizit, ob `onKeyPressed`/`onKeyReleased` bei synthetischen Events feuern. Der Simulator kann
diese geräte-spezifische Übersetzung nicht nachbilden. Ebenso ist die exakte `KEY_*`-Konstante für
Back/Lap eine Laufzeit-, keine Compile-Zeit-Frage — sowohl `KEY_ESC` als auch `KEY_LAP` existieren
in `Toybox.WatchUi` und kompilieren beide anstandslos; welche tatsächlich ankommt, muss vor dem
finalen Build per `System.println(keyEvent.getKey())` im Simulator geloggt werden, nicht geraten.
Konkret zu prüfende Ergebnisse auf echter Hardware:
1. Swipe-Rechts → nichts passiert (Ziel; Fallback `SWIPE_LEFT` bleibt vorerst als Exit aktiv)
2. Kurzer Druck unterer Knopf → Skip
3. Langer Druck (≥600ms) unterer Knopf → Exit
4. Langer Druck wird vom System nicht konsumiert/unterbrochen (kein "hängender" Zustand)
5. Bildschirm-Tap → nichts passiert
6. Oberer Knopf → weiterhin Pause/Weiter/Bestätigen
7. Kein doppeltes Skip bei einem einzelnen unteren Tastendruck (Regressionscheck für die
   `onKey()`/`onKeyReleased()`-Doppelabdeckung, s. Fix oben)

Sollte sich zeigen, dass die getarnte Wisch-Geste doch über `onKeyPressed`/`onKeyReleased`
ankommt, würde sie als kurzer Druck klassifiziert und Skip auslösen — das wäre dann ein Folge-Fix,
nicht Teil dieses Specs, da nicht vorab lösbar ohne diese Information.

**Testing:** Kein Dart-Code betroffen. Watch-seitig: Simulator erlaubt Halten der simulierten
Taste — Kurz-vs-Lang-Unterscheidung an beiden Knöpfen lässt sich dort verifizieren, ebenso dass
ein simulierter Tap nichts auslöst. Die Swipe-Kollision selbst nur auf echter Hardware (s. oben).

## 4. Cold-Start-Icon-Refresh

**Root Cause:** `GarminHeaderIcon` beobachtet `garminProvider` (autoDispose), solange das
Header-Icon sichtbar ist (`garminHeaderIconVisible`), und der Workout-Screen bleibt beim
Settings-Besuch im Hintergrund gemountet (`ConfigScreen` wird nur darüber gepusht) — `garminProvider`
übersteht den Settings-Besuch in diesem Fall also, wird aber **nicht neu abgefragt**: der einmalige
Bluetooth-Check in `build()` lief nur beim allerersten Mal, das ist die bereits in `CLAUDE.md`
dokumentierte "keine Live-Poll"-Entscheidung. Das Symptom ist also nicht fehlendes Am-Leben-Bleiben,
sondern fehlendes erneutes Abfragen trotz Am-Leben-Bleiben. (`GarminWorkoutSyncNotifier` — separat
geprüft — bricht bei `hasEverConnected() == false` vor seinem `ref.listen(garminProvider, ...)` ab
und hält `garminProvider` in diesem Zustand ohnehin nicht zusätzlich am Leben; für die eigentliche
Behebung dieses Bugs ist das nicht relevant, s. u. warum.)

**Fix — bewusst nur `garminProvider` invalidieren, nicht auch `garminWorkoutSyncProvider`:**

```dart
if (!mounted) return;
ref.invalidate(garminProvider);
ref.read(workoutProvider.notifier).updateSettings(ref.read(settingsProvider).requireValue);
```

Ein früherer Entwurf dieses Fixes invalidierte zusätzlich `garminWorkoutSyncProvider`, um dessen
`hasEverConnected()`-Guard bei einer ersten Verbindung während der laufenden Session neu zu
bewerten. Das wurde verworfen: `garminProvider` und `garminWorkoutSyncProvider` teilen sich einen
einzigen nativen EventChannel-Stream (`GarminService._rawEvents`, statisch gecacht,
`garmin_service.dart:84`) mit genau zwei Abonnenten (`GarminNotifier._appRunningSub`,
`GarminWorkoutSyncNotifier._commandSub`). `receiveBroadcastStream()` feuert das native `onCancel`
erst, wenn der **letzte** Abonnent abbestellt — invalidiert man **beide** Provider gleichzeitig,
fällt die Abonnentenzahl garantiert auf null, `MainActivity.kt` ruft
`bridge.unregisterAppEventListener()` auf, und für die Dauer der beiden `build()`-Neuaufbauten
(mehrere `await`s: Bluetooth-Berechtigung, eventually-consistent Geräteabfrage, `hasEverConnected()`,
`equipmentCatalogProvider.future`) gehen **alle** Connect-IQ-Events verloren — nicht nur der
Status, sondern auch jeder `cmd_*`-Tastendruck von der Uhr. Invalidiert man dagegen nur
`garminProvider`, bleibt `GarminWorkoutSyncNotifier._commandSub` die ganze Zeit aktiv, die
Abonnentenzahl fällt nie auf null, `onCancel` feuert nie — kein Event-Verlust.

Die Kehrseite: der `hasEverConnected()`-Guard von `GarminWorkoutSyncNotifier` wird durch diesen Fix
**nicht** neu bewertet. Verbindet sich der Nutzer während der laufenden Session zum allerersten Mal
(vorher `hasEverConnected() == false`), bleibt der Sync-Notifier inaktiv, bis die App neu gestartet
wird — ein schmalerer Rest-Fall als der ursprünglich gemeldete Bug (der ist behoben), bewusst nicht
mitgelöst, um nicht das gerade beschriebene Event-Verlust-Risiko einzugehen. Dokumentiert als
bekannte Einschränkung, kein stiller Kompromiss.

**Warum das den gemeldeten Bug trotzdem behebt:** Der gemeldete Bug ist die Anzeige
(grau/rot/grün), nicht der Sync-Mechanismus — `garminProvider`s `connected`/`everConnected`/
`watchAppStatus`-State steuert direkt das Icon. Ein `ref.invalidate(garminProvider)` beim Verlassen
der Settings erzwingt genau den fehlenden erneuten Bluetooth-Check. Der bereits vorhandene
"Watch-App öffnen"-Button (`config_screen.dart:137`) löst denselben Recheck schon heute aus, wenn
der Nutzer ihn antippt — dieser Fix deckt zusätzlich den Fall ab, in dem sich die Verbindung
während des Settings-Besuchs ändert, ohne dass dieser Button gedrückt wurde.

**Bekannte Rest-Einschränkung, bewusst akzeptiert (kein neues Problem):** Nach der Invalidierung
startet `watchAppStatus` wieder bei `unknown`, bis die Uhr die nächste "opened"-Transition sendet
— Connect IQ kennt nur Push-bei-Zustandswechsel, keine Abfrage des aktuellen Zustands. War die
Watch-App zum Zeitpunkt der Invalidierung schon offen, bleibt das Icon bis zum nächsten
Schließen/Öffnen der Watch-App auf der neutralen Farbe stehen. Das ist dieselbe, bereits an anderer
Stelle in `CLAUDE.md` dokumentierte und akzeptierte Einschränkung ("Cold-Start-Unknown ist real und
akzeptiert, kein Bug") — hier taucht sie nur an einer weiteren Stelle auf. Riverpods
`copyWithPrevious`-Verhalten sorgt dafür, dass die UI während des kurzen Rebuilds nicht auf
grau/`unknown` zurückfällt, bevor der neue Wert da ist (kein sichtbares Flackern).

**Testing:** Neuer Test in `garmin_notifier_test.dart` bzw. als Widget-Test:
`_openConfig()`-Rückkehr ruft `ref.invalidate(garminProvider)` auf, `garminWorkoutSyncProvider`
bleibt unangetastet (Regressionscheck: `_commandSub`-Subscription-Objekt bleibt über den
Settings-Besuch hinweg identisch / wird nicht neu erstellt).

## Verifikation

- Punkte 1, 2: automatisiert (Dart-Test für Punkt 2) + visuelle Kontrolle über den lokalen
  Connect-IQ-Simulator-Loop (kein Hardware-Sideload nötig) + Build-Erfolg als Nachweis gegen
  Ressourcen-Laufzeitfehler (Punkt 2)
- Punkt 3: `flutter test` unberührt; Simulator für Kurz/Lang-Unterscheidung an beiden Knöpfen und
  Tap-No-op; die eigentliche Swipe-Kollision und die exakte `KEY_*`-Konstante sind nur auf echter
  Hardware zu verifizieren (sieben konkrete Prüfergebnisse, s. dort)
- Punkt 4: vollständig Dart-seitig, regulärer `flutter test`, inkl. Regressionscheck, dass
  `garminWorkoutSyncProvider`/`_commandSub` beim Settings-Verlassen unangetastet bleibt
