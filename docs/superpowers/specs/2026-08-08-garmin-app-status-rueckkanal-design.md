# Garmin-Verbindung: App-Status-Rückkanal – Design Spec
**Datum:** 2026-08-08
**Ansatz:** Connect IQ App Messages (Watch → Phone), zweiter nativer Kanal neben dem bestehenden MethodChannel

---

## Ziel

Das Ampel-Icon im Workout-Header (siehe `docs/superpowers/specs/2026-08-07-garmin-connect-spike-design.md`) zeigt aktuell nur, ob **irgendein** Garmin-Gerät per Bluetooth gekoppelt/erreichbar ist (`isWatchConnected()`). Grün bedeutet "Uhr da", nicht "unsere Watch-App läuft gerade". Dieses Vorhaben baut den in der Spike-Spec bewusst ausgeklammerten Rückkanal (Uhr → Handy): die Watch-App meldet sich beim Start und beim Beenden zurück, sodass das Icon live zeigt, ob die App auf der Uhr **tatsächlich gerade offen ist** — ein echter bidirektionaler Zustand statt einer reinen Erreichbarkeitsanzeige.

Grundlage bleibt `docs/emom_app_spezifikation.md`, Abschnitt „Garmin-Integration".

---

## Scope-Entscheidungen (aus der Klärung)

Drei bewusst minimal gehaltene Entscheidungen, jede mit einer breiteren Alternative verworfen:

1. **Nur "App läuft gerade" als Signal** — kein zusätzlicher Quittierungs-Handshake, keine Vorbereitung für künftige Vitaldaten-Payloads. Kleinster Umfang, der das eingangs beschriebene Problem löst.
2. **Nur im Vordergrund der Handy-App** — kein Android-Foreground-Service, kein Broadcast-Receiver für Events außerhalb der laufenden Flutter-App. Passt zum bestehenden „kein Hintergrund-Polling"-Architekturprinzip dieses Projekts. Beim nächsten Öffnen der App wird der Status ohnehin neu abgefragt.
3. **Nur "geöffnet"/"geschlossen" als Ereignisse** — kein periodischer Herzschlag. Einfacher, auf beiden Seiten weniger Logik und Akkuverbrauch; im Gegenzug keine Selbstheilung, falls eine einzelne Nachricht verloren geht (siehe Fehlerbehandlung).

**Kanal-Technik:** Ein neuer `EventChannel` (Push) statt Polling über den bestehenden `MethodChannel`. Echtes Live-Update ohne Verzögerung, kein Timer, widerspricht nicht dem "kein Polling"-Prinzip.

---

## Rechercheergebnis: App-Lifecycle statt View-Lifecycle als Sende-Hook

**Ursprüngliche Annahme (verworfen):** Watch-App sendet in `View.onShow()`/`onHide()` (`garmin_watch_appView.mc`), die dort bereits als leere Stubs existieren.

**Problem:** Auf AMOLED-Geräten (die Venu-Reihe, zu der auch die Venu 4 gehört) kann der Bildschirm-Timeout `onHide()` auslösen, ohne dass die App wirklich beendet wird — die Watch-App bliebe im Hintergrund "offen", das Handy würde aber fälschlich "geschlossen" empfangen. Das ist während eines 30-minütigen EMOM-Workouts der Normalfall (Bildschirm dimmt zwischen Intervallen ständig), hätte also die Live-Anzeige effektiv nutzlos gemacht.

**Belege:**
- Garmins offizielle API-Doku zu [`View.onHide()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/View.html) beschreibt den Trigger als View-Stack-Ereignis (neue View gepusht, aktuelle View gepoppt, oder App geschlossen) — Bildschirm-Power-State wird nicht erwähnt, schließt das Verhalten aber auch nicht aus.
- Ein Entwickler berichtet im Garmin-Forum [„Do AMOLED screen devices call onHide when screen turns off?"](https://forums.garmin.com/developer/connect-iq/f/discussion/265525/do-amoled-screen-devices-call-onhide-when-screen-turns-off) exakt dieses Verhalten auf einer **Venu** (gleiche Gerätefamilie wie die Venu 4): ein in `onShow()`/`onHide()` gestarteter/gestoppter Timer hört auf zu laufen, sobald der Bildschirm automatisch dunkel wird.

**Korrigierter Ansatz:** `Application.AppBase.onStart()`/`onStop()` (`garmin_watch_appApp.mc`) statt `View.onShow()`/`onHide()`. Laut [offizieller Doku zu `AppBase.onStop()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html): „Override to handle application cleanup upon termination. […] Once the function is complete, the application will terminate." — das ist Applikations-Lifecycle (App wird tatsächlich beendet/suspendiert), unabhängig vom View-Stack oder Bildschirm-Power-State. `onStart()`/`onStop()` existieren in `garmin_watch_appApp.mc` bereits als leere Stubs, `onStop()` sogar mit dem passenden Kommentar `// onStop() is called when your application is exiting`.

Restrisiko (unverifiziert, siehe Fehlerbehandlung): ob `Communications.transmit()` innerhalb von `onStop()` zuverlässig noch sendet, bevor der Prozess terminiert.

---

## Architektur & Datenfluss

Erweiterung des bestehenden Dreiteilers (Watch-App / Kotlin-Bridge / Dart-Service) um einen zweiten, entgegengesetzt gerichteten Kanal:

- Bisher (Spike): `Dart → MethodChannel → GarminBridge.kt → Connect IQ SDK → Uhr` (einseitig)
- Neu zusätzlich: `Uhr → Connect IQ SDK → GarminBridge.kt (dauerhafter Listener) → EventChannel → Dart-Stream → GarminNotifier → Header-Icon`

Ablauf:

1. **Watch-App** (`garmin_watch_appApp.mc`): `onStart(state)` sendet `Communications.transmit("opened", …)`; `onStop(state)` sendet `Communications.transmit("closed", …)`.
2. **GarminBridge.kt:** neue Methode `registerAppEventListener(onEvent: (String) -> Unit)` — nach `ensureSdkReady()` und demselben Device/App-Lookup wie in `openWatchApp()` wird `connectIQ.registerForAppEvents(device, app, listener)` aufgerufen; `onMessageReceived` reicht `"opened"`/`"closed"` weiter.
3. **MainActivity.kt:** neuer `EventChannel` (`com.example.emom_app/garmin_events`) neben dem bestehenden `MethodChannel`; Registrierung startet bei `onListen`, wird bei `onCancel` abgemeldet.
4. **garmin_service.dart:** `Stream<bool> watchAppRunningEvents()` — mappt `"opened"→true`, `"closed"→false`.
5. **garmin_notifier.dart:** `build()` abonniert den Stream und aktualisiert `state` live bei jedem Event; Subscription wird über `ref.onDispose` beendet. `GarminConnectionStatus` bekommt ein neues Feld `appRunning`. Der bestehende `connected`-Bluetooth-Check bleibt unverändert bestehen (weiterhin einmalig in `build()`, ausschließlich zur `everConnected`-Fortschreibung) — er steuert ab jetzt nur noch die Grau/Rot-Unterscheidung indirekt über `everConnected`, nicht mehr direkt die Icon-Farbe.
6. **garmin_header_icon.dart:** grün ⟺ `appRunning == true`; rot ⟺ `appRunning == false && everConnected == true`; grau ⟺ `everConnected == false`. `connected` fließt nicht mehr direkt in die Farblogik ein. Tap-Verhalten unverändert (öffnet Watch-App bzw. navigiert zu Settings).

Startzustand nach App-Start: `appRunning = false` (unbekannt wird als "läuft nicht" behandelt), bis das erste Event eintrifft — siehe Fehlerbehandlung.

---

## Dateistruktur (Delta zur bestehenden Spike-Struktur)

| Datei | Änderung |
|---|---|
| `garmin_watch_app/source/garmin_watch_appApp.mc` | `onStart()`/`onStop()` senden `Communications.transmit("opened"/"closed", …)` |
| `android/app/src/main/kotlin/.../GarminBridge.kt` | neue Methode `registerAppEventListener(...)` via `connectIQ.registerForAppEvents(...)` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | neuer `EventChannel` (`com.example.emom_app/garmin_events`) neben bestehendem `MethodChannel` |
| `lib/core/services/garmin_service.dart` | neue Methode `Stream<bool> watchAppRunningEvents()` |
| `lib/features/config/garmin_notifier.dart` | `GarminConnectionStatus` bekommt Feld `appRunning`; `build()` abonniert den Stream |
| `lib/features/workout/widgets/garmin_header_icon.dart` | Icon-Farblogik: grün ⟺ `appRunning` |

---

## Fehlerbehandlung / Risiken

- **Transmit-Timing bei `onStop()` ungeprüft:** `Communications.transmit()` ist asynchron; ob die "closed"-Nachricht zuverlässig noch rausgeht, bevor der Watch-Prozess nach `onStop()` tatsächlich terminiert, sagt Garmins Doku nicht explizit. Muss auf echter Hardware verifiziert werden (siehe Testing). Bleibt sie aus, zeigt das Icon fälschlich weiter grün, bis der nächste Tap den Status korrigiert (gleicher, bereits akzeptierter Trade-off wie beim Bluetooth-Aus-Fall in der ursprünglichen Spike-Spec) — kein Absturz, kein Blocker.
- **Kaltstart-Unbekannt:** Startet die Handy-App neu, ist `appRunning` zunächst `false`, auch wenn die Watch-App zufällig schon offen ist (z.B. manuell auf der Uhr gestartet, bevor die Handy-App läuft) — es gibt kein Connect-IQ-API, um den aktuellen Lauf-Status aktiv abzufragen, nur die Events selbst. Deckt sich mit dem gewählten Minimal-Scope (keine Heartbeat-Absicherung, Scope-Entscheidung 3).
- **EventChannel-Registrierung setzt eine bekannte Uhr voraus:** `registerForAppEvents` benötigt Device+App, genau wie `openWatchApp()`. Verbindet sich die Uhr erst, nachdem die Handy-App schon läuft, registriert sich der Listener nicht automatisch nach — erst ein Neustart der Handy-App oder ein erneuter Tap stößt eine neue Registrierung an. Gleicher Charakter wie der bereits akzeptierte "kein Live-Connect/Disconnect-Stream"-Trade-off aus der Spike-Spec.
- **Nachrichten-Zustellung ist best-effort:** Wie jede Bluetooth-Kommunikation kann eine einzelne "opened"/"closed"-Nachricht verloren gehen (Funkstörung, kurzer Verbindungsabbruch). Ohne Heartbeat (bewusst nicht gewählt) keine Selbstheilung — betrifft am ehesten den "closed"-Fall (Icon bleibt fälschlich grün); der "opened"-Fall führt höchstens dazu, dass ein tatsächlicher Start nicht sofort angezeigt wird (der Tap-Flow zum Öffnen der App liefert bereits eigenes Feedback per Snackbar).

---

## Testing

- Watch-Seite: `onStart()`/`onStop()`-Transmit-Aufrufe zuerst im Connect-IQ-Simulator prüfen (Companion-App-Simulation für App Messages).
- Kotlin-Bridge: kein sinnvoller Unit-Test (reiner Hardware-Wrapper, wie schon bei `GarminBridge.kt` etabliert) — `flutter analyze` muss weiter sauber bleiben, Kotlin muss kompilieren.
- Dart: Stream-Mapping in `garmin_service.dart` (`"opened"→true`/`"closed"→false`) und Zustandsübernahme in `garmin_notifier.dart` sind reine Logik — testbar über einen Fake-EventChannel/StreamController, analog zum bestehenden `garmin_header_icon_test.dart`-Muster (6 Widget-Tests für die Ampel-Logik). Neue/erweiterte Tests: Icon wird grün bei "opened"-Event, rot bei "closed"-Event, Subscription wird bei Provider-Dispose beendet.
- Manuell auf echter Venu 4 (nicht automatisierbar):
  - **Bildschirm-Timeout während laufender Watch-App → Icon muss grün bleiben.** Verifiziert direkt die zentrale Entscheidung dieser Spec (`onStop()` statt `onHide()`).
  - OK-Button auf der Uhr → Icon wird zeitnah rot (verifiziert Transmit-Timing-Risiko oben).
  - Handy-App dabei durchgehend im Vordergrund halten (Hintergrund-Fall ist explizit nicht im Scope).

---

## Erfolgskriterien

- Watch-App sendet beim Start eine "opened"- und beim Beenden eine "closed"-Nachricht über `Communications.transmit()`.
- Header-Icon wird grün, sobald die "opened"-Nachricht ankommt, und wechselt zeitnah zurück zu rot nach der "closed"-Nachricht — ohne Tap, ohne Timer, während die Handy-App im Vordergrund ist.
- Bildschirm-Timeout auf der Uhr während laufender Watch-App verändert das Icon **nicht** (bleibt grün).
- Bestehende Tap-Funktionalität (Watch-App öffnen bei rot/grün, Settings bei grau) bleibt unverändert.
- `flutter analyze` und alle Tests bleiben grün.

---

## Nicht im Scope

- Hintergrund-Betrieb der Handy-App (Foreground-Service/Broadcast-Receiver) — Scope-Entscheidung 2.
- Periodischer Herzschlag/Selbstheilung bei verlorenen Nachrichten — Scope-Entscheidung 3.
- Generische Payload-Struktur für künftige Vitaldaten/Trainingsanzeige — Scope-Entscheidung 1; bei Bedarf spätere Iteration.
- Vitaldaten (Herzfrequenz etc.), Trainingsanzeige auf der Uhr — weiterhin außerhalb des Scopes wie im Original-Spike.
- Zurücksetzen der `everConnected`-Verbindungshistorie — weiterhin offen aus dem Original-Spike.
- Live-Update des `connected`/`everConnected`-Bluetooth-Status selbst (Polling oder nativer Connect/Disconnect-Event-Stream) — bleibt wie in der Spike-Spec ausgeklammert; dieses Vorhaben ergänzt nur den neuen `appRunning`-Status.
