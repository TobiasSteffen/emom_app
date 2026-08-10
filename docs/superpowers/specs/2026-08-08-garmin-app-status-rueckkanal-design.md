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

1. **Watch-App** (`garmin_watch_appApp.mc`): `onStart(state)` sendet `Communications.transmit("opened", {}, new AppStatusListener())`; `onStop(state)` sendet `Communications.transmit("closed", {}, new AppStatusListener())` — **unabhängig vom `state[:suspend]`-Flag**. `onStop()` kann laut [Doku](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html) sowohl bei echter Terminierung als auch bei Suspendierung (`:suspend == true`, „the current state can be resumed at a later time") feuern; wir behandeln beide Fälle gleich und senden "closed" — aus Sicht des Handys ist die App in beiden Fällen gerade nicht sichtbar/aktiv. Wird die App später fortgesetzt, sendet `onStart()` erneut "opened". Payload ist der rohe String `"opened"`/`"closed"`, der zweite `transmit()`-Parameter ein leeres Options-Dict (`{}`) — auf echter Hardware verifiziert (Task 10), `GarminBridge.kt` liest ihn über `message.firstOrNull() as? String` entsprechend als einzelnes String-Element.
2. **GarminBridge.kt:** neue Methode `registerAppEventListener(onEvent: (String) -> Unit)` — nach `ensureSdkReady()` und demselben Device/App-Lookup wie in `openWatchApp()` wird `connectIQ.registerForAppEvents(device, app, listener)` aufgerufen (gekapselt in try/catch für `InvalidStateException`/`ServiceUnavailableException`, gleiches Muster wie die bestehenden Methoden). `onMessageReceived(device, app, message, status)` prüft `status == IQMessageStatus.SUCCESS`, liest das erste Element aus der `message`-Liste (`List<Object>`) und reicht es als `"opened"`/`"closed"` weiter; bei Fehlstatus wird das Event verworfen (geloggt, kein Absturz).
3. **MainActivity.kt:** neuer `EventChannel` (`com.example.emom_app/garmin_events`) neben dem bestehenden `MethodChannel`; Registrierung bei der Connect-IQ-SDK startet beim ersten `onListen`. `onCancel` meldet **nicht** von der SDK ab, sondern trennt nur die Weiterleitung an den aktuellen `EventSink` — die einmalige SDK-Registrierung bleibt für die Prozesslaufzeit (genauer: für die Lebensdauer der `GarminBridge`-Instanz) bestehen. **Korrektur:** `garminProvider` ist entgegen der Pauschalaussage in `CLAUDE.md` kein `keepAlive`-Provider (`@riverpod` ohne `keepAlive: true` in `garmin_notifier.dart`, verifiziert im generierten `garmin_notifier.g.dart` als `isAutoDispose: true`) — anders als die meisten übrigen Provider in diesem Projekt. `garminHeaderIconVisible` ist standardmäßig `false`; solange der Nutzer das nicht einschaltet, ist nicht `GarminHeaderIcon`, sondern `ConfigScreen` (`config_screen.dart`) der einzige Watcher von `garminProvider` — und der lebt nur so lange wie der Einstellungen-Screen offen ist. Jedes Öffnen/Schließen der Einstellungen disposed und rebuildet `garminProvider` also, und mit ihm feuert `EventChannel.onListen`/`onCancel` erneut. Deshalb ist `GarminBridge.registerAppEventListener()` bewusst idempotent gemacht (siehe Task 11 des Implementierungsplans): `connectIQ.registerForAppEvents()` wird nur beim allerersten erfolgreichen Aufruf tatsächlich bei der SDK registriert, jeder weitere `registerAppEventListener()`-Aufruf tauscht nur aus, welche Callback-Referenz eingehende Events bekommt. Das Rebuild-Verhalten selbst (Provider disposed und baut sich neu auf, wenn kein Watcher mehr da ist) bleibt beabsichtigtes, korrektes Riverpod-Verhalten — nur die SDK-Registrierung darf sich davon nicht wiederholen, sonst häufen sich Connect-IQ-Listener-Objekte für die gesamte Prozesslaufzeit an.
4. **garmin_service.dart:** `Stream<bool> watchAppRunningEvents()` — mappt `"opened"→true`, `"closed"→false`.
5. **garmin_notifier.dart:** `build()` abonniert den Stream **einmalig** und aktualisiert `state` live bei jedem Event; Subscription wird über `ref.onDispose` beendet. `GarminConnectionStatus` bekommt ein neues Feld `appRunning`. **Wichtige Korrektur:** `openWatchApp()` ruft heute `ref.invalidateSelf()` auf, um nach dem Öffnen den Bluetooth-Status neu zu laden — das würde `build()` erneut ausführen und damit die Stream-Subscription abreißen/neu aufsetzen, mit einer Event-Lücke genau in dem Moment, in dem die gerade gestartete Watch-App ihr "opened" sendet. `openWatchApp()` darf deshalb den Notifier nicht mehr per `invalidateSelf()` neu aufbauen; stattdessen fragt es `connected`/`everConnected` direkt ab und schreibt `state` gezielt neu, wobei der aktuelle (streamgetriebene) `appRunning`-Wert unverändert übernommen wird. Die Stream-Subscription aus `build()` bleibt dabei durchgehend bestehen.
6. **garmin_header_icon.dart:** grün ⟺ `appRunning == true`; rot ⟺ `appRunning == false && everConnected == true`; grau ⟺ `everConnected == false`. `connected` fließt nicht mehr direkt in die Farblogik ein. Tap-Verhalten unverändert (öffnet Watch-App bzw. navigiert zu Settings).

Startzustand nach App-Start: `watchAppStatus = unknown` (siehe Korrektur unten), bis das erste Event eintrifft — siehe Fehlerbehandlung.

---

## Korrektur nach Hardware-Verifikation (Task 7, 2026-08-10)

Die manuelle Verifikation auf echter Hardware (Venu 4) deckte einen reproduzierbaren Fehler auf, der über eine reine Implementierungslücke hinausgeht und zwei Korrekturen an dieser Spec nach sich zieht.

**Befund (per Logcat belegt):** `GarminBridge.registerAppEventListener()` (Architektur Punkt 2) läuft einmalig, ausgelöst durch `GarminNotifier.build()` beim App-Start. Genau zu diesem frühen Zeitpunkt liefert `connectIQ.connectedDevices` oft eine leere Liste — dieselbe bereits in `CLAUDE.md` dokumentierte Eventual-Consistency-Macke der Connect-IQ-SDK ("connectedDevices returned an empty list immediately after the very first onSdkReady()... then correctly populated a few seconds later"), die dort für `isWatchConnected()`/`openWatchApp()` als tolerierbar eingestuft wurde, weil jeder erneute Tap diese Methoden mit einer frischen Geräte-Abfrage neu aufruft. `registerForAppEvents` hat aber keinen solchen natürlichen Retry-Mechanismus: Bei leerem Geräte-Ergebnis bricht die Registrierung sofort und endgültig ab (kein Log, kein Fehler, einfach ein früher `return`). Für den Rest der App-Sitzung ist dann **kein Listener registriert** — jedes `"opened"`/`"closed"` von der Uhr geht ins Leere, unabhängig davon, wie oft die Watch-App geöffnet/geschlossen wird.

**Nachtrag (Whole-Branch-Review, 2026-08-10):** Die Prämisse „läuft einmalig … ausgelöst durch `GarminNotifier.build()` beim App-Start" erwies sich später als unvollständig — tatsächlicher Auslöser ist jedes `EventChannel.onListen`, also z.B. auch jedes Öffnen der Einstellungen, siehe Architektur Punkt 3 und den Nachtrag zu Task 11 in „Fehlerbehandlung / Risiken".

**Verschärfung durch Task 5:** Vor Task 5 hätte ein Tap aufs Icon (`ref.invalidateSelf()`) `build()` erneut ausgeführt und damit zufällig auch die Registrierung wiederholt — der ursprüngliche Fehlerbehandlung-Eintrag "EventChannel-Registrierung setzt eine bekannte Uhr voraus... erst ein Neustart der Handy-App oder ein erneuter Tap stößt eine neue Registrierung an" (siehe unten) verließ sich auf genau diesen Nebeneffekt. Task 5 hat `invalidateSelf()` bewusst entfernt (korrekt, siehe Architektur Punkt 5 — sonst reißt die Live-Subscription ab), aber damit auch diesen ungewollten Retry-Pfad beseitigt, ohne dass der Wegfall dieser Fallback-Annahme erkannt wurde. Ein Tap korrigiert eine fehlgeschlagene Registrierung seither **nicht mehr** — seit Task 11 stößt aber ein Öffnen/Schließen der Einstellungen (nicht der Tap) über den erneuten `EventChannel.onListen`-Zyklus einen neuen Registrierungsversuch für eine zuvor fehlgeschlagene Registrierung an.

**Korrektur 1 — Retry in `registerAppEventListener()`:** Bei leerem Geräte-Ergebnis wird die Registrierung mit kurzem Backoff wiederholt (gebunden, z.B. 5 Versuche à 2s), statt sofort endgültig aufzugeben. Das ist ein einmaliger Konvergenz-Wartevorgang während der Initialisierung auf ein bereits bekanntes, zeitlich begrenztes SDK-Verhalten — kein dauerhaftes Hintergrund-Polling und damit kein Widerspruch zu Scope-Entscheidung 2.

**Korrektur 2 — `appRunning: bool` → `WatchAppStatus`-Enum:** Der bisherige `appRunning`-Boolean kollabiert zwei unterscheidbare Situationen in denselben Wert `false`: „wir wissen sicher, dass die App nicht läuft" (ein `"closed"`-Event kam an) und „wir haben keine Ahnung, weil noch nichts angekommen ist" (Registrierung fehlgeschlagen oder einfach noch kein Event). Das war nicht nur unpräzise, sondern hat genau diesen Bug unsichtbar gemacht — der App-interne Zustand kannte keinen Unterschied zwischen beiden Fällen. Neues Modell:

```dart
enum WatchAppStatus { unknown, running, notRunning }
```

`GarminConnectionStatus.appRunning` (bool) wird durch `GarminConnectionStatus.watchAppStatus` (`WatchAppStatus`) ersetzt. Icon-Farblogik (Architektur Punkt 6) wird entsprechend angepasst: grün ⟺ `watchAppStatus == running`; rot ⟺ `everConnected && watchAppStatus != running` (fasst `unknown` und `notRunning` visuell weiterhin zusammen — dieselbe bewusste Vereinfachung wie im ursprünglichen "Ampel-Semantik kollabiert zwei Dimensionen"-Trade-off, jetzt aber auf Basis eines einzelnen eindeutigen Werts statt eines zwei-Boolean-Konstrukts mit impliziter Abhängigkeit). Startzustand: `watchAppStatus = unknown`. Der Registrierungs-Erfolg selbst (Korrektur 1) bekommt bewusst **kein** eigenes Feld im öffentlichen Status — er ist reine Plumbing, die den Zustand aus `unknown` herausbewegt, nicht selbst beobachtbarer App-Zustand.

---

## Dateistruktur (Delta zur bestehenden Spike-Struktur)

| Datei | Änderung |
|---|---|
| `garmin_watch_app/manifest.xml` | **Permission `Communications` ergänzen** (`<iq:permissions/>` ist aktuell leer) — ohne diesen Eintrag scheitert `Communications.transmit()` vollständig, siehe [`Toybox.Communications`-Doku](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html) ("Requires Permission: Communications") |
| `garmin_watch_app/source/garmin_watch_appApp.mc` | `onStart()`/`onStop()` senden `Communications.transmit("opened"/"closed", {}, listener)` |
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
- **Kaltstart-Unbekannt:** Startet die Handy-App neu, ist `watchAppStatus` zunächst `unknown`, auch wenn die Watch-App zufällig schon offen ist (z.B. manuell auf der Uhr gestartet, bevor die Handy-App läuft) — Connect IQ bietet keinen aktiven „läuft die App gerade?"-Query. Eine Teilinformation existiert bereits heute ungenutzt: der `openApplication()`-Callback in `GarminBridge.openWatchApp()` kann den Status `APP_IS_ALREADY_RUNNING` liefern (aktuell landet das nur in der Tap-Snackbar). Diese Spec nutzt das bewusst nicht zur Kaltstart-Auflösung, um beim gewählten Minimal-Scope zu bleiben (Scope-Entscheidung 3, keine Heartbeat-Absicherung) — als spätere Verbesserungsoption festgehalten.
- **EventChannel-Registrierung setzt eine bekannte Uhr voraus (bestätigt und behoben, siehe „Korrektur nach Hardware-Verifikation"):** `registerForAppEvents` benötigt Device+App, genau wie `openWatchApp()`. War die Uhr im Moment der Registrierung (App-Start) noch nicht in `connectedDevices` gelistet — per Logcat auf echter Hardware reproduziert, siehe Korrektur-Abschnitt —, brach die Registrierung bislang endgültig ab, ohne Retry. Die Annahme „ein erneuter Tap stößt eine neue Registrierung an" galt nur vor Task 5s `invalidateSelf()`-Entfernung und war zum Zeitpunkt der Verifikation bereits falsch. Behoben durch gebundenen Retry mit Backoff in `registerAppEventListener()`.
- **Nachrichten-Zustellung ist best-effort:** Wie jede Bluetooth-Kommunikation kann eine einzelne "opened"/"closed"-Nachricht verloren gehen (Funkstörung, kurzer Verbindungsabbruch) oder mit `IQMessageStatus != SUCCESS` ankommen. Ohne Heartbeat (bewusst nicht gewählt) keine Selbstheilung — betrifft am ehesten den "closed"-Fall (Icon bleibt fälschlich grün); der "opened"-Fall führt höchstens dazu, dass ein tatsächlicher Start nicht sofort angezeigt wird (der Tap-Flow zum Öffnen der App liefert bereits eigenes Feedback per Snackbar).
- **Vorbestehende Schwachstelle wird relevanter:** `GarminBridge` wird pro `configureFlutterEngine`-Aufruf neu instanziiert, während `ConnectIQ.getInstance()` ein prozessweiter Singleton ist und `sdkReady`/`initializing` Instanzfelder von `GarminBridge` sind. Bei einer Activity-Neuerstellung (z.B. Rotation, Speicherdruck) kann `initialize()` erneut auf demselben SDK-Singleton laufen. Bestand schon vor diesem Vorhaben, wird durch einen dauerhaft laufenden Event-Listener aber praxisrelevanter. Kein Blocker für diese Iteration, aber im Hinterkopf zu behalten.
- **Wiederholte `EventChannel.onListen`-Aufrufe lösten wiederholte SDK-Registrierung aus (gefunden im Whole-Branch-Review, behoben in Task 11):** `garminProvider` disposed und rebuildet bei jedem Verlust seines letzten Watchers — im Standardfall (`garminHeaderIconVisible == false`) ist `ConfigScreen` dieser Watcher, lebt also nur so lange wie der Einstellungen-Screen offen ist. Ohne Idempotenz-Schutz hätte das bei jedem Öffnen der Einstellungen eine neue `connectIQ.registerForAppEvents()`-Registrierung ausgelöst, ohne die vorherige abzumelden — ein unbegrenzt wachsender Listener-Leak für die Prozesslaufzeit. `GarminBridge.registerAppEventListener()` ist seit Task 11 idempotent (siehe Architektur Punkt 3).

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
