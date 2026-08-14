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
Screenshot des Simulator-Fensters lässt sich direkt inspizieren. Für die Screens 1 (Layout) und 2
(Icon) wird dieser Loop zur Verifikation genutzt statt eines Sideloads auf die echte Uhr.

## Ziel / Scope

Vier der fünf zurückgestellten Punkte (Punkt 2 "SnackBar entfernt" war bereits vor Plan-Schluss
erledigt):

1. Screen-Layout-Overlap (Zeilen überlappen sich auf allen drei Watch-Screens)
2. Equipment-Icon auf dem Running-Screen
3. Exit-Geste kollidiert mit Skip (Sicherheits-/UX-Bug)
4. Cold-Start-Verbindungs-Icon braucht vollständigen App-Neustart zum Aktualisieren

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

**Fix:** Neuer Helper in `garmin_watch_appView.mc`:

```
drawStack(dc, lines, startY)
  // lines: Array von [text, font, color]-Tripeln
  // zeichnet jede Zeile mit TEXT_JUSTIFY_CENTER | TEXT_JUSTIFY_VCENTER
  // an y = kumulierte Summe der vorherigen dc.getFontHeight(font)-Werte, ab startY
```

`drawRunning`, `drawConfirming`, `drawFinished` rufen `drawStack()` mit ihrer jeweiligen
Zeilenliste statt einzelner `drawCentered()`-Aufrufe mit hart codierten Offsets auf. Fortschrittsring,
große Reps/Zeit-Zahl und Countdown bleiben eigene `drawCentered()`-Aufrufe (kein Bestandteil des
Stacks, da visuell hervorgehoben), aber ihre Y-Position wird ebenfalls anhand der Stack-Höhe der
Zeilen darüber validiert, damit nichts kollidiert.

**Testing:** Kein automatisierter Render-Test möglich (Monkey C hat kein Pixel-Vergleichs-
Testing in diesem Projekt). Verifikation über den lokalen Simulator-Loop: Build → `monkeydo` →
Screenshot für alle drei Screens (running/confirming/finished, inkl. Pause-Intervall-Variante von
running) und visuelle Kontrolle auf Überlappung.

## 2. Equipment-Icon auf dem Running-Screen

**Datenfluss:** `buildStateSnapshot()` (`lib/features/workout/garmin_watch_snapshot.dart`) bekommt
ein neues Feld `equipmentIcon: String`, abgeleitet aus dem `iconAsset`-Dateinamen des aktuellen
Intervalls (z. B. `assets/icon/kettlebell.png` → `"kettlebell"` — Dateiname ohne Pfad/Extension).
Bei Pause-Intervallen: leerer String (kein Icon-Lookup nötig, Watch zeigt weiterhin nur "Pause"-Text).

**Watch-Ressourcen:** Alle 7 bekannten Icons (`kettlebell`, `steelmace`, `pezziball`,
`liegestuetz`, `kniebeuge`, `plank`, `dehnen` — feste Liste aus `kEquipmentIconAssets`, keine
frei hochladbaren Bilder) werden als kleine Bitmaps (~40×40px, von den Original-PNGs verkleinert)
in `garmin_watch_app/resources/drawables/` gebündelt und per `resources.xml` als
`Rez.Drawables.*` registriert.

**Rendering:** `drawRunning()` ersetzt die bisherige Zeile 1 (`"Kettlebell 16kg"`) durch das
Icon, gezeichnet mit `dc.drawBitmap()`, zentriert oben im `drawStack()`. Zeile 2 (Übungsname,
z. B. `"Swing beidarmig"`) bleibt als Text erhalten. Gewicht/Variante (`"16kg"`) geht als
sichtbarer Text verloren (bewusste Entscheidung, s. Brainstorming).

**Fehlerbehandlung:** Kommt ein `equipmentIcon`-Wert an, der auf der Watch-Seite keinem
gebündelten Bitmap entspricht (z. B. künftig neu hinzugefügtes Icon am Handy, altes Watch-Build),
fällt `drawRunning()` auf keine Icon-Anzeige zurück (Zeile bleibt leer) statt abzustürzen — kein
Crash durch unbekannte Ressourcen-IDs.

**Testing:** Dart-seitig neuer Test in `garmin_watch_snapshot_test.dart` (Mapping `iconAsset` →
`equipmentIcon`-ID für alle 7 Fälle + Pause-Fall). Watch-seitig: Simulator-Loop wie bei Punkt 1.

## 3. Exit-Geste (Hold-to-Exit)

**Root Cause (SDK-Doku-bestätigt):** `BehaviorDelegate.onBack()` ist laut Doku *die* Behandlung
für `KEY_ESC` — sowohl vom physischen unteren Knopf als auch von der Swipe-Rechts-Geste, die
manche Geräte (bestätigt: diese Venu 4) intern in `KEY_ESC` übersetzen. Beide Quellen sind auf
API-Ebene nicht unterscheidbar. Das aktuelle `onBack()` sendet immer `cmd_skip` — die Swipe-Rechts-
Geste (die Nutzer intuitiv zum Schließen versuchen) landet also ungewollt bei Skip statt Exit.

**Fix:** `garmin_watch_appDelegate` überschreibt `onKeyPressed(keyEvent)`/`onKeyReleased(keyEvent)`
(niedrigere API-Ebene als `onBack()`) für den Skip/Back-Knopf: Zeitstempel bei Press merken, bei
Release die Differenz prüfen.
- Kürzer als 600ms → bisheriges Verhalten (Skip, außer auf confirming/finished-Screens, wo Skip
  schon jetzt unterdrückt wird — Guard bleibt erhalten)
- 600ms oder länger gehalten → Exit (`System.exit()`)

Da Swipe-Rechts auf betroffenen Geräten über denselben `KEY_ESC`-Kanal ankommt, deckt dieser Fix
automatisch auch die Swipe-Geste ab, ohne Swipe-Richtungen separat behandeln zu müssen. Die
bisherige `onSwipe()`-Behandlung (SWIPE_LEFT → Exit) bleibt als zusätzlicher, unveränderter
Exit-Weg für Geräte ohne die SWIPE_RIGHT-als-KEY_ESC-Eigenheit bestehen.

**Offene technische Details (werden beim Bauen gegen SDK 9.2.0 verifiziert, wie bei den übrigen
APIs in diesem Projekt üblich):** exakte `WatchUi.KEY_*`-Konstante für den Skip/Back-Knopf; ob
`onKeyReleased()` bei `return true` die (redundante) Auslösung von `onBack()` zuverlässig
unterdrückt, oder ob ein manueller Guard-Flag nötig ist.

**Testing:** Kein Dart-Code betroffen. Watch-seitig: Simulator erlaubt Halten der simulierten
Taste — manuelle Verifikation von kurz (Skip) vs. lang (Exit) im Simulator; finale Bestätigung
des *Gefühls* der 600ms-Schwelle bleibt echte Hardware vorbehalten (Simulator-Tastendruck fühlt
sich anders an als ein Fingertipp auf der Uhr).

## 4. Cold-Start-Icon-Refresh

**Root Cause:** `garminProvider` ist `autoDispose`. Ist das Header-Icon sichtbar
(`garminHeaderIconVisible = true`), hält `GarminHeaderIcon` den Provider dauerhaft am Leben —
der einmalige Bluetooth-Check in `build()` läuft dann nur beim allerersten App-Start, nie wieder.
Ein simples `ref.invalidate(garminProvider)` beim Zurückkehren aus den Settings wäre riskant: es
würde laut bestehendem Code-Kommentar in `garmin_notifier.dart` (Zeilen 49–54) das
`watchAppStatus`-EventChannel-Abo abreißen und neu aufsetzen — mit einer Event-Lücke genau in dem
Moment, in dem die gerade geöffnete Watch-App ihr "opened" sendet.

**Fix:** Neue Methode `GarminNotifier.refreshConnectivity()`, die den bestehenden, bereits
non-invasiven Bluetooth-Recheck-Code aus `openWatchApp()` (Zeilen 57–61: `isWatchConnected()` /
`markEverConnected()` / `hasEverConnected()` + `state = AsyncData(...)`) wiederverwendet, aber
*ohne* `_service.openWatchApp()` aufzurufen. `workout_screen.dart::_openConfig()` ruft diese
Methode direkt nach `Navigator.push()` zurückkehrt auf, neben dem bestehenden
`updateSettings(...)`-Aufruf — symmetrisch zum dort schon etablierten Muster.

**Testing:** Neuer Test in `garmin_notifier_test.dart`: `refreshConnectivity()` aktualisiert
`connected`/`everConnected`, lässt eine laufende `watchAppStatus`-Subscription unangetastet
(kein `build()`-Rebuild).

## Verifikation

- Punkte 1, 2: automatisiert (Dart-Test für Punkt 2) + visuelle Kontrolle über den lokalen
  Connect-IQ-Simulator-Loop (kein Hardware-Sideload nötig)
- Punkt 3: `flutter test` unberührt; Simulator für Kurz/Lang-Unterscheidung, finales Gefühl auf
  echter Hardware
- Punkt 4: vollständig Dart-seitig, regulärer `flutter test`
