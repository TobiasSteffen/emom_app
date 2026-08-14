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

Diese Fassung des Specs wurde nach einem unabhängigen technischen Review (Opus, hohe
Prüftiefe) überarbeitet — der erste Entwurf enthielt mehrere echte Fehler, u. a. eine falsch
verstandene SDK-API-Dispatch-Reihenfolge in Punkt 3 und eine falsche Root-Cause-Annahme in
Punkt 4. Details dazu jeweils inline.

## Ziel / Scope

Vier der fünf zurückgestellten Punkte:

1. Screen-Layout-Overlap (Zeilen überlappen sich auf allen drei Watch-Screens)
2. Equipment-Icon auf dem Running-Screen
3. Gesten sollen nie etwas auslösen; nur die physischen Knöpfe steuern die App (Sicherheits-/UX-Bug)
4. Cold-Start-Verbindungs-Icon braucht vollständigen App-Neustart zum Aktualisieren

Punkt "SnackBar entfernt" (ursprüngliche Findings-Liste, Punkt 2) ist **weiterhin offen**, nicht
Teil dieses Zyklus — der erste Spec-Entwurf hatte fälschlich behauptet, das sei bereits erledigt.
Laut `progress.md` Zeile 46 wurde der Fix explizit verworfen (`git checkout --`), nicht committet;
der Code bestätigt das (`lib/features/workout/widgets/garmin_header_icon.dart:33-37` zeigt die
SnackBar weiterhin an). Bleibt bewusst außerhalb dieses Scopes; bei Bedarf eigener kleiner Fix
(dieselbe SnackBar existiert übrigens identisch auch in `lib/features/config/config_screen.dart:139-143`
— falls angegangen, beide Stellen prüfen).

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
Elementen, jedes entweder `{kind: "text", value, font, color}` oder `{kind: "bitmap", value}`.
Leere Text-Werte (`""`) werden vor dem Aufbau der Liste weggelassen, verbrauchen keinen Slot.

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
      dc.drawBitmap(cx - w / 2, centerY - h / 2, element.value)   // Bitmap: Top-Left-Koordinate
    y += h
  return y
```

Damit ist jedes Element intern konsistent an seiner vertikalen Mitte verankert (Text nutzt dafür
`VCENTER` direkt, Bitmap rechnet die Mitte auf die von `drawBitmap()` verlangte Top-Left-Ecke
um) — es gibt keine Vermischung zweier Anker-Konventionen mehr. Die kumulierte Höhe ist exakt,
keine geschätzten Pixel-Offsets mehr.

`startY` ist pro Screen ein Konstante (Top-anchored, kein weiteres Zentrierungsschema). Ring,
große Reps/Zeit-Zahl und Countdown bleiben eigene `drawCentered()`-Aufrufe unterhalb des Stacks;
ihre feste Y-Position wird so gewählt, dass sie unterhalb des von `drawStack()` zurückgegebenen
`endY` liegt (für den worst case: Icon + eine Textzeile auf dem Running-Screen, zwei Textzeilen
auf Confirming/Finished) — konkrete Pixelwerte werden beim Bauen gegen die echte Bildschirmgröße
festgelegt und über den Simulator-Loop visuell verifiziert.

**Testing:** Kein automatisierter Render-Test möglich (Monkey C hat kein Pixel-Vergleichs-
Testing in diesem Projekt). Verifikation über den lokalen Simulator-Loop: Build → `monkeydo` →
Screenshot für alle drei Screens (running/confirming/finished, inkl. Pause-Intervall-Variante von
running) und visuelle Kontrolle auf Überlappung.

## 2. Equipment-Icon auf dem Running-Screen

**Datenfluss:** `buildStateSnapshot()` (`lib/features/workout/garmin_watch_snapshot.dart`) bekommt
ein neues Feld `equipmentIcon: String`, abgeleitet aus dem `iconAsset`-Dateinamen des aktuellen
Intervalls (z. B. `assets/icon/kettlebell.png` → `"kettlebell"` — Dateiname ohne Pfad/Extension).
Bei Pause-Intervallen: leerer String — die Watch zeigt dann (wie bisher) nur den Text "Pause" als
Stack-Element, kein Icon.

**Watch-Ressourcen:** Alle 7 bekannten Icons (`kettlebell`, `steelmace`, `pezziball`,
`liegestuetz`, `kniebeuge`, `plank`, `dehnen` — feste Liste aus `kEquipmentIconAssets`, keine
frei hochladbaren Bilder) werden als kleine Bitmaps (~40×40px) in
`garmin_watch_app/resources/drawables/` gebündelt und per `resources.xml` als `Rez.Drawables.*`
registriert. Die Original-PNGs sind anti-aliasiert (Farbverlauf, nicht nur zwei Farben) — beim
Verkleinern/Exportieren für die Watch muss `drawables.xml` eine explizite Palette-Strategie
bekommen (`automaticPalette`, oder ein festes reduziertes Farbschema), sonst kann
`dc.drawBitmap()` zur Laufzeit `Graphics.InvalidPaletteException` werfen (SDK-dokumentiertes
Verhalten, kein hypothetischer Fall). Das ist Teil der Bild-Export-Arbeit, nicht nur ein
Ressourcen-Copy-Paste.

**Ressourcen-Laden:** SDK-Doku warnt ausdrücklich: *"Loading a resource can be an expensive
operation, so do not load resources when handling screen updates"* — `onUpdate()` läuft aber
einmal pro Sekunde (`WatchStateTicker`). Deshalb: ein Ein-Element-Cache (letzte geladene
`equipmentIcon`-ID + zugehörige `BitmapResource`) auf Klassenebene in `garmin_watch_appView`.
`drawRunning()` lädt per `Application.loadResource(Rez.Drawables.X)` nur dann neu, wenn die
aktuelle `equipmentIcon`-ID vom gecachten Wert abweicht (passiert nur bei Intervallwechsel, nicht
bei jedem Sekunden-Tick). Nicht alle 7 Bitmaps bleiben gleichzeitig resident, nur das gerade
genutzte.

**Rendering:** `drawRunning()` baut die Stack-Elemente für den Running-Screen als
`[icon-oder-nichts, line2]` (Icon ersetzt die bisherige Zeile 1) und übergibt sie an `drawStack()`
(s. Punkt 1). Gewicht/Variante (`"16kg"`) geht als sichtbarer Text verloren (bewusste
Entscheidung, s. Brainstorming).

**Fehlerbehandlung:**
- `equipmentIcon`-Wert ohne passenden `Rez.Drawables`-Eintrag (z. B. künftig neues Icon am Handy,
  altes Watch-Build) → kein Icon-Element im Stack, Zeile bleibt leer statt abzustürzen.
- `equipmentIcon`-Feld fehlt komplett im Snapshot (älterer Handy-Build ohne dieses Feld) →
  `dict.get("equipmentIcon")` liefert `null`, gleiche Behandlung wie oben (kein Icon).
- Phone-seitig: `catalog.findType() == null` liefert weiterhin `'?'` als `line1` (bestehender
  Pfad) — für diesen Fall ist `equipmentIcon` ebenfalls leerer String, keine neue Fallunterscheidung
  nötig.

**Betroffene Screen-Zustände:** `drawRunning()` wird von `running`, `paused`, `holdWaiting` und
`holding` genutzt (nicht nur vom namensgebenden `running`-Zustand) — das Icon erscheint in allen
vieren, dem Zustand entsprechend mit demselben Intervall-Inhalt wie bisher Zeile 1.

**Testing:** Dart-seitig neuer Test in `garmin_watch_snapshot_test.dart` (Mapping `iconAsset` →
`equipmentIcon`-ID für alle 7 Fälle + Pause-Fall + fehlender/unbekannter Catalog-Eintrag).
Watch-seitig: Simulator-Loop wie bei Punkt 1, zusätzlich Build-Erfolg als Nachweis, dass die
Palette-Definition keinen Laufzeitfehler verursacht (Simulator zeigt `InvalidPaletteException`
als Absturz, falls es doch auftritt).

## 3. Gesten sollen nie etwas auslösen — nur physische Knöpfe steuern die App

**Ziel (final geklärt mit Nutzer):** Nur drei Eingaben lösen etwas aus: oberer Knopf kurz =
Pause/Weiter/Bestätigen (unverändert), unterer Knopf kurz = Skip (unverändert), unterer Knopf
**gehalten** = Exit. Jede Wisch-Geste, egal in welche Richtung, soll **nichts** tun.

**Warum diese Zuordnung und nicht z. B. "oben halten = Skip":** Skip ist die mit Abstand
häufigste Aktion (potenziell jede Minute bei einem 30-Minuten-EMOM) — ein Halten-Erfordernis
würde den Workout-Fluss spürbar bremsen. Exit passiert höchstens einmal pro Session — genau die
Art seltener, folgenreicher Aktion, für die ein bewusstes Halten laut UX-Konvention gedacht ist
(verhindert versehentliches Auslösen, kostet aber im Normalbetrieb keine Zeit).

**Root Cause der Kollision (SDK-Doku-bestätigt, `BehaviorDelegate.onBack()`):**
*"Some devices interpret SWIPE_RIGHT SwipeEvents as KEY_ESC events. On these devices, returning
`false` will cause `onKey()` to be called rather than `onSwipe()`."* Auf dieser Venu 4 wird die
"App schließen"-Wischgeste (Swipe-Rechts) vom Betriebssystem **unterhalb** der App-Logik in ein
`KEY_ESC`-Ereignis umgewandelt, bevor `onSwipe()` sie je sieht. Dieses `KEY_ESC` landet zuerst bei
der High-Level-Behandlung `onBack()` — **nicht** bei den Low-Level-Events `onKeyPressed`/
`onKeyReleased`, wie der erste Entwurf dieses Specs fälschlich annahm (dort stand, diese seien
eine "niedrigere API-Ebene" und würden daher zuerst greifen — laut Doku ist es umgekehrt: `onBack()`
bekommt das Ereignis zuerst, und nur ein `false`-Return lässt es zu `onKey()` durchfallen). Ein
reiner Halten-Timer auf `onKeyPressed`/`onKeyReleased` (wie im ersten Entwurf) hätte die Wisch-
Geste nie gesehen — sie wäre weiterhin bei `onBack()` als Skip gelandet. Zusätzlich hat eine
Wisch-Geste ohnehin keine nennenswerte "Halten"-Dauer, selbst wenn sie den Handler erreichen
würde.

**Fix (Kanaltrennung statt Zeitmessung an der falschen Stelle):**

- **`onKeyPressed(keyEvent)` / `onKeyReleased(keyEvent)`** — implementieren die Skip/Exit-
  Unterscheidung für den unteren Knopf per echter Press/Release-Zeitmessung (Schwelle 600ms).
  Diese Events feuern nur bei echtem physischem Tastendruck. Filterung: nur reagieren, wenn
  `keyEvent.getKey()` dem Back/Lap-Tasten-Konstanten entspricht (exakte `WatchUi.KEY_*`-Konstante
  wird beim Bauen gegen SDK 9.2.0 verifiziert); für jede andere Taste `false` zurückgeben, damit
  z. B. der obere Knopf normal über `onSelect()` bedient wird. Zeitstempel wird zusammen mit der
  gedrückten Taste gespeichert; ein `onKeyReleased` mit abweichender Taste oder ohne vorherigen
  Press wird ignoriert (schützt gegen den Fall, dass ein Halten vom System nie mit einem Release
  quittiert wird — z. B. App wird während des Haltens pausiert/beendet).
  Exit ist **nicht** hinter dem bisherigen `WatchState.current == null`-Guard versteckt: auch auf
  dem "Verbinde..."-Screen (kein Snapshot vom Handy) muss Halten funktionieren, sonst gibt es dort
  keinen Ausweg.
- **`onBack()`** gibt `false` zurück (lehnt explizit ab), statt wie bisher `true`. Laut Doku
  fällt das Ereignis dadurch zu `onKey()` durch.
- **`onKey(keyEvent)`** — no-op (`return true`, keine Aktion). Fängt alles ab, was hier über den
  Fallthrough ankommt (im schlechtesten Fall: die getarnte Wisch-Geste) und lässt es folgenlos
  verpuffen — weder Skip noch Exit.
- **`onSwipe(swipeEvent)`** — no-op für alle Richtungen (`return true`, keine Aktion). Deckt den
  Fall ab, dass eine Wisch-Geste ganz regulär als `SwipeEvent` ankommt (nicht als getarntes
  `KEY_ESC`).

**Verbleibende Unsicherheit (nur auf echter Hardware zu klären, nicht im Simulator):** Ob eine
vom System als `KEY_ESC` getarnte Wisch-Geste tatsächlich `onKeyPressed`/`onKeyReleased`
**nicht** auslöst (nur `onBack()` → `onKey()`), ist eine SDK-Doku-gestützte, aber nicht
hardwareseitig bewiesene Annahme — die Doku beschreibt nur den Fallthrough zu `onKey()`, nicht
explizit, ob `onKeyPressed`/`onKeyReleased` bei synthetischen Events feuern oder nicht. Der
Simulator kann diese geräte-spezifische Übersetzung nicht nachbilden (SWIPE_RIGHT→KEY_ESC ist
eine reale Geräte-Eigenart dieser Venu 4, keine Simulator-Eigenschaft). Konkret zu prüfende
Ergebnisse auf echter Hardware:
1. Swipe-Rechts → nichts passiert (Ziel)
2. Kurzer Druck unterer Knopf → Skip
3. Langer Druck (≥600ms) unterer Knopf → Exit
4. Langer Druck wird vom System nicht konsumiert/unterbrochen (kein "hängender" Zustand)

Sollte sich auf der Hardware zeigen, dass die getarnte Wisch-Geste doch über
`onKeyPressed`/`onKeyReleased` ankommt (wider Erwarten), würde sie als kurzer Druck klassifiziert
und Skip auslösen — das wäre dann ein Folge-Fix (z. B. Mindest-Zeitspanne zwischen zwei Presses,
oder Auswertung von `keyEvent`-Zusatzinfos, falls vorhanden), nicht Teil dieses Specs, da nicht
vorab lösbar ohne diese Information.

**Testing:** Kein Dart-Code betroffen. Watch-seitig: Simulator erlaubt Halten der simulierten
Taste — Kurz-vs-Lang-Unterscheidung am unteren Knopf lässt sich dort verifizieren. Die
Swipe-Kollision selbst nur auf echter Hardware (s. oben).

## 4. Cold-Start-Icon-Refresh

**Korrigierte Root Cause:** Der erste Entwurf nahm an, das (standardmäßig ausgeblendete)
Header-Icon halte `garminProvider` (autoDispose) am Leben. Tatsächlich ist es
`garminWorkoutSyncProvider` (`GarminWorkoutSyncNotifier`, `keepAlive: true`) — dauerhaft
beobachtet in `app.dart:64` (`ref.watch(garminWorkoutSyncProvider)`), unabhängig vom
Header-Icon. Dessen `build()` ruft intern `ref.listen(garminProvider, ...)` auf und hält
`garminProvider` dadurch faktisch für die gesamte App-Session am Leben, sobald `app.dart` einmal
gebaut hat — der einmalige Bluetooth-Check in `garminProvider.build()` läuft dadurch nur beim
allerersten Mal, nie wieder.

**Zusätzliches Risiko, das der erste Entwurf übersehen hat:** `GarminWorkoutSyncNotifier.build()`
bricht früh ab, wenn `hasEverConnected()` beim *ersten* Build `false` war
(`garmin_workout_sync_notifier.dart:42`) — und wird wegen `keepAlive` danach nie neu gebaut. Ein
reiner Bluetooth-Status-Refresh (Icon grau→rot/grün) würde die Anzeige also korrigieren, *ohne*
dass der Sync-Notifier reaktiviert wird: die Uhr würde als "verbunden" angezeigt, obwohl nie ein
Snapshot gesendet wird und kein Watch-Knopf etwas bewirkt — eine falsche statt einer ehrlich
veralteten Anzeige. Das muss der Fix mit abdecken.

**Fix, zweigeteilt:**

1. Neue Methode `GarminNotifier.refreshConnectivity()` (`lib/features/config/garmin_notifier.dart`):
   wiederverwendet den bereits non-invasiven Bluetooth-Recheck-Code aus `openWatchApp()`
   (`isWatchConnected()` / `markEverConnected()` / `hasEverConnected()` + `state = AsyncData(...)`),
   aber *ohne* `_service.openWatchApp()` aufzurufen und *ohne* `invalidateSelf()` (das würde laut
   bestehendem Kommentar in dieser Datei, Zeilen 49–54, das `watchAppStatus`-EventChannel-Abo
   unnötig abreißen). Der eigentliche Mehrwert gegenüber dem bereits vorhandenen "Watch-App
   öffnen"-Button in den Settings (`config_screen.dart:138`, der über `openWatchApp()` denselben
   Recheck bereits auslöst): derselbe Recheck, aber *ohne* dabei ungefragt zu versuchen, die
   Watch-App zu starten.
2. `workout_screen.dart::_openConfig()` liest `everConnected` vor und nach dem Aufruf von
   `refreshConnectivity()`. Kippt der Wert von `false` auf `true` (erste Verbindung während der
   laufenden Session), wird zusätzlich `ref.invalidate(garminWorkoutSyncProvider)` aufgerufen —
   das reaktiviert den Sync-Notifier gezielt genau in dem einen Moment, in dem sein früher
   `hasEverConnected()`-Guard sonst dauerhaft falsch bliebe. Kein Invalidieren im Normalfall
   (Wert unverändert) — kein unnötiges Neuaufsetzen der `_commandSub`-Subscription bei jedem
   Settings-Besuch.

**Warum kein zusätzlicher Guard gegen unnötiges Neu-Erzeugen von `garminProvider` nötig ist**
(anders als der erste Entwurf befürchtete): Da `garminWorkoutSyncProvider` bereits ab dem
allerersten `app.dart`-Build dauerhaft lebt und `garminProvider` darüber transitiv mit am Leben
hält, existiert `garminProvider` zu dem Zeitpunkt, an dem `_openConfig()` überhaupt aufgerufen
werden kann (Nutzer muss schon auf dem Workout-Screen sein), so gut wie immer bereits — ein
`ref.read(garminProvider.notifier)` dort erzeugt keine zusätzliche Create/Dispose-Churn.

**Testing:** Neuer Test in `garmin_notifier_test.dart`: `refreshConnectivity()` aktualisiert
`connected`/`everConnected`, lässt eine laufende `watchAppStatus`-Subscription unangetastet (kein
`build()`-Rebuild). Neuer Test (Ort: `garmin_workout_sync_notifier_test.dart` falls vorhanden,
sonst Integrationstest über `workout_screen`-Verhalten): `everConnected`-Flip von `false` auf
`true` löst `garminWorkoutSyncProvider`-Invalidierung aus; unveränderter Wert löst sie nicht aus.

## Verifikation

- Punkte 1, 2: automatisiert (Dart-Test für Punkt 2) + visuelle Kontrolle über den lokalen
  Connect-IQ-Simulator-Loop (kein Hardware-Sideload nötig) + Build-Erfolg als Nachweis gegen
  Palette-Laufzeitfehler (Punkt 2)
- Punkt 3: `flutter test` unberührt; Simulator für Kurz/Lang-Unterscheidung; die eigentliche
  Swipe-Kollision ist nur auf echter Hardware zu verifizieren (s. dort, vier konkrete
  Prüfergebnisse)
- Punkt 4: vollständig Dart-seitig, regulärer `flutter test`, inkl. neuem Test für die
  `garminWorkoutSyncProvider`-Reaktivierung
