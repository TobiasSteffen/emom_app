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

**Korrektur nach Gegenprüfung (Opus-Review vom 2026-08-08):** Die ursprüngliche Fassung dieser Spec berief sich auf den Garmin-Forum-Thread [„Do AMOLED screen devices call onHide when screen turns off?"](https://forums.garmin.com/developer/connect-iq/f/discussion/265525/do-amoled-screen-devices-call-onhide-when-screen-turns-off) als Beleg dafür, dass Bildschirm-Timeout auf AMOLED-Geräten `onHide()` auslöst. Der Thread wurde vollständig gegengelesen: Die ursprüngliche Forumsfrage ist eine reine Vermutung des Autors; **derselbe Autor stellt Jahre später per eigenem Logging-Test auf einer echten Venu fest: „unfortunately no. Somehow the onHide() event is not triggered when amoled screen turns off."** Der Beleg zeigt also das Gegenteil der ursprünglich zitierten Behauptung — passiver Bildschirm-Timeout löst `onHide()` **nicht** aus.

**Die Entscheidung für `onStart()`/`onStop()` bleibt trotzdem richtig — nur aus einem anderen, tragfähigeren Grund:** `View.onHide()` ist laut [offizieller API-Doku](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/View.html) an den **View-Stack** gekoppelt — „a new View object is pushed on top of the current one, when the current View is popped, or when the app is closed". Sobald die Watch-App über die aktuelle Hello-World-Ansicht hinauswächst (z.B. ein Bestätigungsdialog, ein Menü), würde `onHide()` auf der Basis-View bei jeder internen Navigation feuern, nicht nur beim echten Schließen der App — ein fragiles Signal unabhängig von der AMOLED-Frage. `Application.AppBase.onStop()` dagegen ist laut [offizieller Doku](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html) explizit an die Applikations-Terminierung gebunden: „Override to handle application cleanup upon termination. […] Once the function is complete, the application will terminate." `onStart()`/`onStop()` existieren in `garmin_watch_appApp.mc` bereits als leere Stubs, `onStop()` sogar mit dem passenden Kommentar `// onStop() is called when your application is exiting`.

**Realer, belegter Risiko-Fall (ersetzt die widerlegte AMOLED-Annahme):** Auf der vivoactive 5 (gleiche AMOLED-Displaygeneration wie die Venu-Reihe) berichten mehrere Entwickler im Thread [„App quits unexpectedly - no crash"](https://forums.garmin.com/developer/connect-iq/f/discussion/371444/app-quits-unexpectedly---no-crash), dass Abdecken des Displays mit der Handfläche (Bildschirm-Aus-Geste) und versehentliche Zurück-Swipes (z.B. beim Hochschieben eines Ärmels) die App tatsächlich beenden, nicht nur den Bildschirm abschalten. Beides ist während eines Kettlebell-Workouts realistisch. In diesem Fall feuert `onStop()` korrekt (die App wird ja wirklich beendet) — das Icon zeigt dann zurecht "geschlossen" an, auch wenn der Nutzer das nicht beabsichtigt hat. Kein Fehler unserer Logik, aber ein UX-Risiko, das in den Erfolgskriterien nicht als Garantie formuliert werden darf (siehe unten).

Restrisiko (unverifiziert, siehe Fehlerbehandlung): ob `Communications.transmit()` innerhalb von `onStop()` zuverlässig noch sendet, bevor der Prozess terminiert.

---

## Architektur & Datenfluss

Erweiterung des bestehenden Dreiteilers (Watch-App / Kotlin-Bridge / Dart-Service) um einen zweiten, entgegengesetzt gerichteten Kanal:

- Bisher (Spike): `Dart → MethodChannel → GarminBridge.kt → Connect IQ SDK → Uhr` (einseitig)
- Neu zusätzlich: `Uhr → Connect IQ SDK → GarminBridge.kt (dauerhafter Listener) → EventChannel → Dart-Stream → GarminNotifier → Header-Icon`

Ablauf:

1. **Watch-App** (`garmin_watch_appApp.mc`): `onStart(state)` sendet `Communications.transmit(["opened"], null, listener)`; `onStop(state)` sendet `Communications.transmit(["closed"], null, listener)` — **unabhängig vom `state[:suspend]`-Flag**. `onStop()` kann laut [Doku](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html) sowohl bei echter Terminierung als auch bei Suspendierung (`:suspend == true`, „the current state can be resumed at a later time") feuern; wir behandeln beide Fälle gleich und senden "closed" — aus Sicht des Handys ist die App in beiden Fällen gerade nicht sichtbar/aktiv. Wird die App später fortgesetzt, sendet `onStart()` erneut "opened". Payload ist eine Liste (Connect-IQ-Messages sind kein Rohstring), daher `["opened"]`/`["closed"]` statt `"opened"`. Der dritte `transmit()`-Parameter ist ein `Communications.ConnectionListener` — dessen `onError()` wird minimal geloggt (kein Retry, siehe Fehlerbehandlung).
2. **GarminBridge.kt:** neue Methode `registerAppEventListener(onEvent: (String) -> Unit)` — nach `ensureSdkReady()` und demselben Device/App-Lookup wie in `openWatchApp()` wird `connectIQ.registerForAppEvents(device, app, listener)` aufgerufen (gekapselt in try/catch für `InvalidStateException`/`ServiceUnavailableException`, gleiches Muster wie die bestehenden Methoden). `onMessageReceived(device, app, message, status)` prüft `status == IQMessageStatus.SUCCESS`, liest das erste Element aus der `message`-Liste (`List<Object>`) und reicht es als `"opened"`/`"closed"` weiter; bei Fehlstatus wird das Event verworfen (geloggt, kein Absturz).
3. **MainActivity.kt:** neuer `EventChannel` (`com.example.emom_app/garmin_events`) neben dem bestehenden `MethodChannel`; Registrierung startet bei `onListen`, wird bei `onCancel` abgemeldet. In der Praxis lebt die Registrierung faktisch für die gesamte Prozesslaufzeit der Handy-App (siehe Punkt 5 — `onCancel` feuert bei einem `keepAlive`-Provider ohne expliziten Dispose praktisch nie), was exakt der Scope-Entscheidung „nur im Vordergrund, kein Hintergrund-Service" entspricht.
4. **garmin_service.dart:** `Stream<bool> watchAppRunningEvents()` — mappt `"opened"→true`, `"closed"→false`.
5. **garmin_notifier.dart:** `build()` abonniert den Stream **einmalig** und aktualisiert `state` live bei jedem Event; Subscription wird über `ref.onDispose` beendet. `GarminConnectionStatus` bekommt ein neues Feld `appRunning`. **Wichtige Korrektur:** `openWatchApp()` ruft heute `ref.invalidateSelf()` auf, um nach dem Öffnen den Bluetooth-Status neu zu laden — das würde `build()` erneut ausführen und damit die Stream-Subscription abreißen/neu aufsetzen, mit einer Event-Lücke genau in dem Moment, in dem die gerade gestartete Watch-App ihr "opened" sendet. `openWatchApp()` darf deshalb den Notifier nicht mehr per `invalidateSelf()` neu aufbauen; stattdessen fragt es `connected`/`everConnected` direkt ab und schreibt `state` gezielt neu, wobei der aktuelle (streamgetriebene) `appRunning`-Wert unverändert übernommen wird. Die Stream-Subscription aus `build()` bleibt dabei durchgehend bestehen.
6. **garmin_header_icon.dart:** grün ⟺ `appRunning == true`; rot ⟺ `appRunning == false && everConnected == true`; grau ⟺ `everConnected == false`. `connected` fließt nicht mehr direkt in die Farblogik ein. Tap-Verhalten unverändert (öffnet Watch-App bzw. navigiert zu Settings).

Startzustand nach App-Start: `appRunning = false` (unbekannt wird als "läuft nicht" behandelt), bis das erste Event eintrifft — siehe Fehlerbehandlung.

---

## Dateistruktur (Delta zur bestehenden Spike-Struktur)

| Datei | Änderung |
|---|---|
| `garmin_watch_app/manifest.xml` | **Permission `Communications` ergänzen** (`<iq:permissions/>` ist aktuell leer) — ohne diesen Eintrag scheitert `Communications.transmit()` vollständig, siehe [`Toybox.Communications`-Doku](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html) ("Requires Permission: Communications") |
| `garmin_watch_app/source/garmin_watch_appApp.mc` | `onStart()`/`onStop()` senden `Communications.transmit(["opened"]/["closed"], null, listener)` |
| `android/app/src/main/kotlin/.../GarminBridge.kt` | neue Methode `registerAppEventListener(...)` via `connectIQ.registerForAppEvents(...)` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | neuer `EventChannel` (`com.example.emom_app/garmin_events`) neben bestehendem `MethodChannel` |
| `lib/core/services/garmin_service.dart` | neue Methode `Stream<bool> watchAppRunningEvents()` |
| `lib/features/config/garmin_notifier.dart` | `GarminConnectionStatus` bekommt Feld `appRunning`; `build()` abonniert den Stream einmalig; `openWatchApp()` nutzt kein `invalidateSelf()` mehr (siehe Architektur Punkt 5) |
| `lib/features/workout/widgets/garmin_header_icon.dart` | Icon-Farblogik: grün ⟺ `appRunning` |
| `test/features/workout/garmin_header_icon_test.dart` | bestehende Tests „gruen wenn verbunden" und „rot wenn nicht verbunden aber schon mal verbunden gewesen" müssen umgeschrieben werden (Grün hängt jetzt an `appRunning`, nicht mehr an `connected`) |

---

## Fehlerbehandlung / Risiken

- **Transmit-Timing bei `onStop()` ungeprüft:** `Communications.transmit()` ist asynchron; ob die "closed"-Nachricht zuverlässig noch rausgeht, bevor der Watch-Prozess nach `onStop()` tatsächlich terminiert, sagt Garmins Doku nicht explizit. Muss auf echter Hardware verifiziert werden (siehe Testing). Bleibt sie aus, zeigt das Icon fälschlich weiter grün, bis der nächste Tap den Status korrigiert (gleicher, bereits akzeptierter Trade-off wie beim Bluetooth-Aus-Fall in der ursprünglichen Spike-Spec) — kein Absturz, kein Blocker.
- **Versehentliches Beenden der Watch-App während des Trainings:** Laut Entwicklerberichten zur vivoactive 5 ([Forum-Thread](https://forums.garmin.com/developer/connect-iq/f/discussion/371444/app-quits-unexpectedly---no-crash)) können ein Abdecken des Displays mit der Handfläche oder ein versehentlicher Zurück-Swipe (z.B. beim Ärmel-Hochschieben) die App tatsächlich beenden, nicht nur den Bildschirm abschalten — auf der gleichen AMOLED-Displaygeneration wie die Venu-Reihe. In diesem Fall feuert `onStop()` korrekt und das Icon zeigt zurecht "geschlossen" an, obwohl der Nutzer weitertrainiert. Kein Fehler unserer Logik, aber ein reales UX-Risiko — deshalb ist "Bildschirm-Timeout beeinflusst das Icon nicht" bewusst nicht als absolute Garantie formuliert (siehe Erfolgskriterien).
- **Ampel-Semantik kollabiert zwei Dimensionen (bewusster Trade-off):** Vor diesem Vorhaben bedeutete Rot „Uhr war schon mal verbunden, ist es aber gerade nicht" (reine Bluetooth-Erreichbarkeit). Danach bedeutet Rot „App läuft nicht — **entweder** weil sie nicht gestartet wurde **oder** weil die Uhr nicht erreichbar ist". Diese beiden Fälle sind am Icon nicht mehr unterscheidbar; der Normalzustand „Uhr verbunden, Watch-App aber nicht gestartet" ist jetzt dauerhaft rot statt wie im Spike grün. Das ist im Sinne des Ziels dieses Vorhabens gewollt (grün soll wirklich „App läuft" heißen), wird hier aber explizit als Informationsverlust festgehalten.
- **Kaltstart-Unbekannt:** Startet die Handy-App neu, ist `appRunning` zunächst `false`, auch wenn die Watch-App zufällig schon offen ist (z.B. manuell auf der Uhr gestartet, bevor die Handy-App läuft) — Connect IQ bietet keinen aktiven „läuft die App gerade?"-Query. Eine Teilinformation existiert bereits heute ungenutzt: der `openApplication()`-Callback in `GarminBridge.openWatchApp()` kann den Status `APP_IS_ALREADY_RUNNING` liefern (aktuell landet das nur in der Tap-Snackbar). Diese Spec nutzt das bewusst nicht zur Kaltstart-Auflösung, um beim gewählten Minimal-Scope zu bleiben (Scope-Entscheidung 3, keine Heartbeat-Absicherung) — als spätere Verbesserungsoption festgehalten.
- **EventChannel-Registrierung setzt eine bekannte Uhr voraus:** `registerForAppEvents` benötigt Device+App, genau wie `openWatchApp()`. Verbindet sich die Uhr erst, nachdem die Handy-App schon läuft, registriert sich der Listener nicht automatisch nach — erst ein Neustart der Handy-App oder ein erneuter Tap stößt eine neue Registrierung an. Gleicher Charakter wie der bereits akzeptierte "kein Live-Connect/Disconnect-Stream"-Trade-off aus der Spike-Spec.
- **Nachrichten-Zustellung ist best-effort:** Wie jede Bluetooth-Kommunikation kann eine einzelne "opened"/"closed"-Nachricht verloren gehen (Funkstörung, kurzer Verbindungsabbruch) oder mit `IQMessageStatus != SUCCESS` ankommen. Ohne Heartbeat (bewusst nicht gewählt) keine Selbstheilung — betrifft am ehesten den "closed"-Fall (Icon bleibt fälschlich grün); der "opened"-Fall führt höchstens dazu, dass ein tatsächlicher Start nicht sofort angezeigt wird (der Tap-Flow zum Öffnen der App liefert bereits eigenes Feedback per Snackbar).
- **Vorbestehende Schwachstelle wird relevanter:** `GarminBridge` wird pro `configureFlutterEngine`-Aufruf neu instanziiert, während `ConnectIQ.getInstance()` ein prozessweiter Singleton ist und `sdkReady`/`initializing` Instanzfelder von `GarminBridge` sind. Bei einer Activity-Neuerstellung (z.B. Rotation, Speicherdruck) kann `initialize()` erneut auf demselben SDK-Singleton laufen. Bestand schon vor diesem Vorhaben, wird durch einen dauerhaft laufenden Event-Listener aber praxisrelevanter. Kein Blocker für diese Iteration, aber im Hinterkopf zu behalten.

---

## Testing

- Watch-Seite: `onStart()`/`onStop()`-Transmit-Aufrufe zuerst im Connect-IQ-Simulator prüfen (Companion-App-Simulation für App Messages).
- Kotlin-Bridge: kein sinnvoller Unit-Test (reiner Hardware-Wrapper, wie schon bei `GarminBridge.kt` etabliert) — `flutter analyze` muss weiter sauber bleiben, Kotlin muss kompilieren.
- Dart: Stream-Mapping in `garmin_service.dart` (`"opened"→true`/`"closed"→false`) und Zustandsübernahme in `garmin_notifier.dart` sind reine Logik — testbar über einen Fake-EventChannel (`setMockStreamHandler` auf dem `BinaryMessenger`, Muster steht bereits in `test/core/services/garmin_service_test.dart`, nicht in `garmin_header_icon_test.dart`). Die beiden bestehenden Farb-Tests in `garmin_header_icon_test.dart` ("gruen wenn verbunden", "rot wenn nicht verbunden aber schon mal verbunden gewesen") müssen umgeschrieben werden, nicht nur ergänzt — Grün hängt jetzt an `appRunning`, nicht mehr an `connected`. Neue Tests: Icon wird grün bei "opened"-Event, rot bei "closed"-Event, `openWatchApp()`-Tap überschreibt den laufenden `appRunning`-Wert nicht (Regressionstest für die `invalidateSelf()`-Korrektur).
- Manuell auf echter Venu 4 (nicht automatisierbar):
  - **Passiver Bildschirm-Timeout (Uhr einfach liegen lassen) während laufender Watch-App → Icon sollte grün bleiben.** Verifiziert die zentrale Entscheidung dieser Spec (`onStop()` statt `onHide()`).
  - **Handfläche kurz auf den Bildschirm legen bzw. versehentlicher Zurück-Swipe während laufender Watch-App** → separat gegenprüfen, ob die App dabei wirklich beendet wird (dann korrekt Rot) oder nur der Bildschirm abschaltet (dann sollte Grün bleiben) — verifiziert das in der Recherche gefundene vivoactive-5-Risiko für die Venu 4 konkret.
  - OK-Button auf der Uhr → Icon wird zeitnah rot (verifiziert Transmit-Timing-Risiko oben).
  - Handy-App dabei durchgehend im Vordergrund halten (Hintergrund-Fall ist explizit nicht im Scope).

---

## Erfolgskriterien

- Watch-App sendet beim Start eine "opened"- und beim Beenden eine "closed"-Nachricht über `Communications.transmit()`.
- Header-Icon wird grün, sobald die "opened"-Nachricht ankommt, und wechselt zeitnah zurück zu rot nach der "closed"-Nachricht — ohne Tap, ohne Timer, während die Handy-App im Vordergrund ist.
- Passiver Bildschirm-Timeout auf der Uhr während laufender Watch-App verändert das Icon nicht (bleibt grün) — **keine absolute Garantie**: ein tatsächliches Beenden der App durch Handflächen-Abdeckung oder versehentlichen Zurück-Swipe (siehe Fehlerbehandlung) lässt das Icon korrekterweise auf Rot wechseln, das ist kein Fehlschlag dieses Kriteriums.
- Ein Tap auf das Icon (öffnet die Watch-App) verändert `appRunning` nicht rückwirkend auf `false` und reißt die laufende Live-Aktualisierung nicht ab (Regressionsschutz gegen die behobene `invalidateSelf()`-Race).
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
