# Garmin-Watch: Hauptscreen-Spiegelung – Design Spec
**Datum:** 2026-08-12
**Ansatz:** Bidirektionale Erweiterung der bestehenden Connect-IQ-App-Messages-Kanäle (Ansatz A aus der Klärung), Uhr rechnet zwischen Ereignissen lokal weiter

---

## Ziel

Der Trainings-Hauptscreen der Handy-App (`workout_screen.dart`) soll auf die Garmin-Uhr gespiegelt werden — nicht nur zur Anzeige, sondern auch zur Steuerung: Training pausieren/fortsetzen, ein Intervall überspringen und nach einem Alarm zum nächsten Intervall bestätigen, alles direkt vom Handgelenk aus, über die zwei physischen Buttons der Uhr. Grundlage bleibt `docs/emom_app_spezifikation.md`, Abschnitt „Garmin-Integration", sowie der bereits abgeschlossene App-Status-Rückkanal (`docs/superpowers/specs/2026-08-08-garmin-app-status-rueckkanal-design.md`).

**Korrekturhinweis:** Diese Spec wurde nach einer gezielten xhigh-Effort-Korrekturlesung (Opus, 2026-08-12) gegen den tatsächlichen Code geprüft und an mehreren Stellen korrigiert. Die wichtigsten Korrekturen sind unten an ihrer jeweiligen Stelle vermerkt statt in einem eigenen Nachtrag gesammelt, weil sie die ursprüngliche Fassung direkt ersetzen, nicht ergänzen.

---

## Scope-Entscheidungen (aus der Klärung)

1. **Ereignisbasierter Sync, Uhr rechnet lokal** — das Handy pusht bei jeder Änderung eines Zustands-Schlüssels (siehe Architektur) einen vollen Snapshot; die Uhr zählt den Countdown dazwischen selbst runter, genau wie `WorkoutNotifier` das am Handy tut. Verworfen: Live-Push jede Sekunde — unnötiger Bluetooth-Traffic, fehleranfälliger bei einzelnen verlorenen Nachrichten, ohne echten Mehrwert gegenüber lokalem Rechnen.
2. **Kaltstart huckepack auf dem bestehenden Rückkanal statt eigenem Request/Response** — reagiert das Handy auf das bereits existierende `"opened"`-Event der Watch-App (Task 11–13) mit einem vollen Snapshot, ist kein zusätzlicher Nachrichtentyp nötig. Verworfen: eigenes `request_state`/`response_state`-Protokoll — Connect IQ hat kein echtes Request/Response (`Communications.transmit()` ist die Uhr→Handy-Richtung, `ConnectIQ.sendMessage()` die Handy→Uhr-Richtung, beide ohne Antwort-Kopplung); ein eigenes Protokoll hätte Zuordnung/Matching nachbauen müssen, ohne dass das einen Vorteil gegenüber dem Rückkanal gebracht hätte, der dieselbe Information ohnehin schon liefert.
3. **Kein Heartbeat in v1** — kein Beleg, dass App-Messages in der Praxis verloren gehen (gleiche Linie wie beim bestehenden Rückkanal, der aus demselben Grund ebenfalls ohne Heartbeat auskommt). Das Nachrichtenformat bekommt aber von Anfang an ein `type`-Feld, damit ein Heartbeat oder andere künftige Signale später als zusätzlicher Nachrichtentyp ergänzt werden können, ohne das Protokoll umzubauen.
4. **Zustandsänderungen werden unabhängig vom Auslöser gepusht** — pausiert der Nutzer am Handy, zieht die Uhr automatisch nach, weil der Push an jede relevante `WorkoutNotifier`-Zustandsänderung hängt, nicht an „Kommando kam von der Uhr". Das schließt **auch Reset und Planwechsel** ein (siehe Architektur) — Scope-Entscheidung 6 verbietet nur *Reset-Kommandos von der Uhr*, nicht das Nachziehen, wenn am Handy zurückgesetzt wird.
5. **Zeit-Übungen (Halten) werden unterstützt** — kein Sonderausschluss für Intervalle mit `isTimed` (z.B. Pezziball). Die Button-Zustandsmaschine bekommt zwei zusätzliche Zustände statt einer Ausnahme.
6. **Reset bleibt Handy-exklusiv** — von den vier möglichen Bedienelementen aus der Klärungsrunde wurden Play/Pause, Skip und Bestätigen für die Uhr gewählt, Reset bewusst nicht. Ein Fehlgriff beim Reset (Trainingsfortschritt weg) ist teurer als bei den anderen Aktionen, und Reset ist die am seltensten benutzte der vier.
7. **App-Exit wechselt vom oberen Button auf die Touch-Swipe-Geste** (neu, aus der Korrekturlesung): `garmin_watch_appDelegate.mc` beendet die App heute per `onSelect() { System.exit(); }` — ein Platzhalter aus dem Hello-World-Spike. Der obere Button wird mit dieser Spec für Pause/Weiter/Start/Fertig gebraucht, `onSelect()` als Exit-Weg entfällt deshalb. Exit läuft stattdessen über die für Venu-Touchscreens native Swipe-Rechts-Geste (System-Ebene, unabhängig von unserem `onKey()`-Handling) — muss vor der Implementierung auf echter Hardware verifiziert werden, dass sie unterhalb unseres Input-Handlings weiterhin funktioniert. Der bestehende Rückkanal-Testfall „Button-Druck auf der Uhr → Icon wird rot" (Rückkanal-Spec) bleibt gültig, der auslösende Vorgang wechselt aber von Tastendruck zu Swipe.

---

## Architektur & Datenfluss

Erweitert den bestehenden Dreiteiler (Watch-App / Kotlin-Bridge / Dart-Service) symmetrisch um einen zweiten Nachrichtentyp in beide Richtungen — kein neues Subsystem, dieselben Bausteine wie beim App-Status-Rückkanal. `GarminBridge`/`MainActivity` leiten schon heute jeden ankommenden Nachrichten-String ungefiltert weiter (`GarminBridge.kt`: `currentOnEvent?.invoke(payload)`; `MainActivity.kt` reicht das roh an den `EventSink` durch) — die vier neuen `cmd_*`-Werte brauchen dort **keine** Kotlin-Änderung, nur eine neue Sende-Richtung on top.

**Phone → Watch (neu):** Bisher kann das Handy der Uhr nur einen Öffnen-Befehl schicken (`openWatchApp()`). Neu: `GarminBridge.kt` bekommt eine Sende-Fähigkeit für Nutzdaten (`ConnectIQ.sendMessage(device, app, message, listener)` — exakte Signatur bei der Implementierung gegen die aktuelle SDK-Doku verifizieren, da sie hier nicht per Primärquelle nachgeprüft werden konnte, siehe Fehlerbehandlung). Payload ist ein Dictionary mit `type`-Feld:

```
{"type" => "state_snapshot",
 "minute" => 12, "totalMinutes" => 30,
 "line1" => "Kettlebell 20kg", "line2" => "Swing beidarmig · L",
 "isPause" => false, "isTimed" => false,
 "reps" => 14, "secondsLeft" => 42, "duration" => 60,
 "screenState" => "running",
 "nextText" => "Nächste: Kettlebell 24kg · Snatch R",
 "totalReps" => 187}
```

Feldbedeutung:

| Feld | Bedeutung |
|---|---|
| `minute` | aktueller `currentMinute`-Index, treibt die Phasenfarbe (Uhr berechnet sie lokal aus den bereits in `CLAUDE.md` dokumentierten Minuten-Bereichen — keine Farbwerte über die Leitung) |
| `line1`/`line2` | fertig formatierter Anzeigetext (Gerät+Gewicht / Übung+Seite). **Korrektur:** keine Wiederverwendung von `workoutLabelForMinute()` — die liefert einen einzelnen String mit `side.label` (`"Links"`/`"Rechts"`), nicht zwei Zeilen mit `side.shortLabel` (`"L"`/`"R"`). Der Zweizeilen-Split ist neue Formatierlogik, die im Sync-Notifier selbst entsteht (liest Katalogdaten über `equipmentCatalogProvider`, den `WorkoutNotifier` intern schon nutzt). Bei Pause: `line1 = "Pause"`, `line2 = ""`. Die Uhr formatiert nichts selbst nach, kein Abkürzungs-Mapping auf Watch-Seite nötig. |
| `isPause` | unterdrückt die Reps/Zeit-Zahl auf dem Running-Screen (Pendant zu `RepsCard`s `if (!isPause)`) und schaltet den Fortschrittsring auf Grau statt Phasenfarbe (Pendant zu `isPause ? Colors.white24 : phaseColorForMinute(...)`, so wie `workout_screen.dart`/`reps_card.dart`/`overall_progress.dart` es unabhängig voneinander schon handhaben) |
| `isTimed` | schaltet die große Zahl von „Reps" auf „Zeit" um; der angezeigte Zielwert ist in diesem Fall `duration` (identisch zu `RepsCard.timedSeconds`, das am Handy ebenfalls nur `intervals[currentMinute].durationSeconds` ist) — **kein eigenes `timedSeconds`-Feld**, das wäre nur eine Dopplung von `duration` gewesen |
| `reps` | aktuelle Ziel-Wiederholungszahl (0 bei Pause oder Zeit-Übung) |
| `secondsLeft`/`duration` | treiben die MM:SS-Anzeige inkl. Überzeit (negatives `secondsLeft` → `+MM:SS`, Pendant zu `TimerDisplay`) |
| `screenState` | einer von `paused`, `running`, `hold_waiting`, `holding`, `confirming`, `finished` — steuert allein, welcher der drei Screens aktiv ist und was der obere Button gerade tut (siehe Tabelle unten). Vom Handy vorberechnet, die Uhr repliziert die Ableitungslogik nicht selbst. **Ableitung, erste zutreffende Regel gewinnt:** (1) `isFinished` → `finished`; (2) `waitingForConfirmation` → `confirming`; (3) `isTimed && holdWaiting` → `hold_waiting`; (4) `isTimed && holdStarted` → `holding` — **unabhängig von `isRunning`**, weil `workout_screen.dart` den Play/Pause-Button für Zeit-Übungen komplett durch START/FERTIG ersetzt, nicht nur währenddessen; (5) `isRunning` → `running`; (6) sonst → `paused`. |
| `nextText` | Vorschau-Text auf die nächste Übung, **eigenständig für die Uhr formatiert** — kein Bezug mehr auf „exakt wie `NextMinutePreview`": dessen Nicht-Pause-Zweig rendert ein Icon-Widget plus `"<Gerät> · <Übung+Kürzel> · <Reps>W · <Dauer>s"`, zu lang für die Uhr. Zielformat: `"Nächste: Pause · <Sekunden>s"` bei Pause, sonst `"Nächste: <Gerät+Gewicht> · <Übung><Seiten-Kürzel>"` ohne Reps/Dauer (kein Platz). Leer beim letzten Intervall (kein Nächstes vorhanden), analog zur Handy-Bedingung `currentMinute < totalMinutes - 1` — die Running-Screen-Zeile entfällt dann einfach. |
| `totalReps` | **Korrektur:** `WorkoutState.totalReps` (Summe der geplanten Reps über den ganzen Plan, Getter in `workout_notifier.dart`), **nicht** `totalRepsDone` — genau der Wert, den `FinishedScreen` am Handy auch bekommt. |

**Sende-Trigger — Änderungs-Schlüssel statt Ereignis-Liste (Korrektur):** Ursprünglich als Aufzählung einzelner Ereignisse (Start, Pause, Skip, …) formuliert — das ist unvollständig (Reset und Planwechsel fehlten) und ohne Schutz gegen versehentliches Mitsenden bei jedem `secondsLeft`-Tick, wenn der Push naiv an `ref.listen(workoutProvider, ...)` hängt (`WorkoutState` hat kein `operator==`, jeder Tick erzeugt ein neues, „anderes" `AsyncData`). Stattdessen: ein Snapshot wird immer dann gesendet, wenn sich mindestens eines der Felder `minute`, `isRunning`, `isPause`, `isTimed`, `holdWaiting`, `holdStarted`, `waitingForConfirmation`, `isFinished` gegenüber dem zuletzt gesendeten Stand ändert — deckt Start, Pause, Resume, Skip, Intervallwechsel, Übergang in/aus Bestätigung, Start/Ende einer Zeit-Übungs-Haltephase, Reset und Planwechsel einheitlich ab, ohne Einzelfälle zu verdrahten, und pusht explizit nicht bei reinen `secondsLeft`-Ticks. Zusätzlich: Antwort auf das bestehende `"opened"`-Event des Rückkanals (Kaltstart). Gesendet wird nur, wenn `garminProvider`s `watchAppStatus == running` ist — sonst liefe jede Zustandsänderung ins Leere, inklusive eines unnötigen `_ensureBluetoothPermissions()`-Roundtrips pro Snapshot; die Berechtigung wird stattdessen einmalig geprüft und gecacht.

**Watch → Phone (Erweiterung des bestehenden Kanals):** wie bisher einfache Strings über `Communications.transmit()`/`registerForAppEvents()`, zusätzlich zu den bestehenden `"opened"`/`"closed"` vier neue Werte: `"cmd_pause"`, `"cmd_resume"`, `"cmd_confirm"`, `"cmd_skip"`. Phone-seitig **zustandsabhängiges** Routing auf sechs vorhandene `WorkoutNotifier`-Methoden (`pause()`, `start()`, `confirmInterval()`, `skip()`, `startHold()`, `finishHold()` — welche der sechs ein `cmd_pause`/`cmd_resume` tatsächlich auslöst, hängt vom aktuellen `WorkoutState` ab, siehe Button-Tabelle unten), keine neue Trainingslogik, nur Routing.

**Korrektur — Guards fehlen für zwei der sechs Zielmethoden:** `skip()`, `startHold()` und `finishHold()` sind bereits gegen ungültige Zustände abgesichert, `confirmInterval()` und `start()` dagegen nicht:
- `confirmInterval()` rechnet ungeprüft `currentMinute + 1` und indiziert `intervals[nextMinute]` — ein verspätetes `cmd_confirm` (z.B. Nachricht war unterwegs, während am Handy schon bestätigt wurde) kann im letzten Intervall zu einem Index außerhalb des Arrays führen.
- `start()` ruft, anders als `startHold()`, kein `_timer?.cancel()` vor dem neuen `Timer.periodic()` auf — ein verspätetes `cmd_resume` bei bereits laufendem Training erzeugt einen zweiten, parallelen Timer (Countdown läuft doppelt so schnell).

Der Kommando-Dispatcher im Sync-Notifier muss deshalb selbst guarden (`cmd_confirm` nur bei `waitingForConfirmation`, `cmd_resume`/`cmd_pause` nur beim jeweils passenden `isRunning`-Wert ausführen) — dieselbe Holschuld gilt nicht nur für „ungültige Kommandos", wie ursprünglich in dieser Spec behauptet, sondern ist eine notwendige Ergänzung.

**Neue Vermittlerschicht (Dart):** `WorkoutNotifier` bekommt keine Garmin-Abhängigkeit — stattdessen ein neuer Provider (Arbeitstitel `garminWorkoutSyncNotifier`), der `workoutProvider` beobachtet und bei relevanten Änderungen einen Snapshot über `GarminService` verschickt, sowie den Kommando-Stream von `GarminService` abonniert und (mit den oben beschriebenen Guards) auf `workoutProvider.notifier`-Methoden mapped. Damit bleiben Trainingslogik und Garmin-Anbindung getrennt, wie es die bestehende Trennung von `WorkoutNotifier` und `GarminNotifier` heute schon vorgibt. Muss dauerhaft aktiv sein (nicht nur solange z.B. das Einstellungen-Fenster offen ist) — wird analog zum Wakelock-Muster in `app.dart` von der App-Wurzel aus gehalten (**Einschränkung:** anders als der Wakelock, der sich bei `AppLifecycleState.paused` bewusst abmeldet, darf der Sync-Notifier das nicht — sonst verpasst er Kommandos, während das Handy-Display aus ist, siehe Fehlerbehandlung).

**Korrektur — zwei Konflikte mit der bestehenden `EventChannel`-Nutzung, gefunden in der Korrekturlesung, beide vor der Implementierung zu lösen:**

1. **Ein `EventChannel` erlaubt pro Kanalname nur einen aktiven Dart-Handler** (Flutter-`BinaryMessenger`-Semantik: `receiveBroadcastStream()` ruft `setMessageHandler(name, ...)`, ein zweiter Aufruf überschreibt den ersten kommentarlos). Würden sowohl `garminProvider` (heute schon Abonnent, aktiv z.B. solange die Einstellungen offen sind) als auch der neue, dauerhafte Sync-Notifier unabhängig voneinander `receiveBroadcastStream()` auf demselben Kanal aufrufen, kappt das Öffnen/Schließen der Einstellungen die Kommando-Zustellung des Sync-Notifiers lautlos für den Rest der Sitzung (oder umgekehrt). **Lösung:** `GarminService` ruft `receiveBroadcastStream()` genau einmal auf und hält das Ergebnis intern als eigenen Broadcast-Stream; `watchAppRunningEvents()` und die neue `watchCommands()` sind beide nur noch Filter/Maps über diesen einen geteilten Stream, kein Kotlin-seitiger zweiter Kanal nötig.
2. **Der bestehende Selbstheilungs-Pfad für eine fehlgeschlagene Watch-Registrierung hing bisher am wiederholten Öffnen der Einstellungen** (jedes `EventChannel.onListen` stößt laut Rückkanal-Spec einen neuen Registrierungsversuch an). Mit einem dauerhaften Abonnenten feuert `onListen` nur noch einmal pro App-Lebenszyklus — dieser Pfad fällt weg, genau in dem Moment, in dem er am wichtigsten wird (Rückkanal *und* Steuerung hängen jetzt beide an derselben Registrierung). **Lösung:** `registerAppEventListener()` ist bereits idempotent und gefahrlos erneut aufrufbar (bei bereits erfolgreicher Registrierung ein No-Op, nach einer zuvor endgültig aufgegebenen Registrierung startet ein neuer Aufruf einen frischen Versuchszyklus, siehe `GarminBridge.kt`). Der Sync-Notifier ruft sie deshalb zusätzlich bei jedem `AppLifecycleState.resumed` erneut auf — derselbe Lifecycle-Hook, an dem `app.dart` bereits den Wakelock steuert —, nicht nur einmal beim App-Start.

---

## Watch-Screens & Button-Zustandsmaschine

Drei Screens, ausschließlich über `screenState` gesteuert:

- **Running** (gewähltes Layout „V2 · Kompaktes Gesamtlayout" aus dem visuellen Brainstorming): aktuelle Übung zweizeilig (`line1`/`line2`), Reps- bzw. Zeit-Zahl groß mittig, Timer darunter (inkl. Überzeit-Format), Next-Preview (`nextText`) als kompakte dritte Zeile. Phasenfarbe als Fortschrittsring um den Bildschirmrand, lokal aus `minute` berechnet (grau bei `isPause`). Aktiv bei `screenState` = `paused`, `running`, `hold_waiting` oder `holding`.
- **Bestätigung:** eigener Übergangs-Screen, groß „NÄCHSTE ÜBUNG" plus `nextText`-Vorschau, deutlich abgesetzt vom laufenden Training. Aktiv bei `screenState == confirming`.
- **Fertig:** eigener Screen mit `totalReps` und Hinweis „Training beendet". Zeigt `line1`/`line2` des finalen Snapshots als „letzte Übung" — **Korrektur:** das ist nur dann tatsächlich die letzte *Übung* und nicht „Pause", wenn `_lastNonPauseLabel()`-Logik verwendet wird. Am Handy läuft `FinishedScreen` bewusst rückwärts bis zum letzten Nicht-Pause-Intervall (endet ein Plan mit Cool-Down-Pausen, was beim dokumentierten Phasenmodell der Normalfall ist, wäre das letzte Intervall sonst eine Pause). Der Sync-Notifier muss dieselbe Rückwärtssuche für den `finished`-Snapshot durchführen, nicht einfach `intervals[currentMinute]` nehmen. Aktiv bei `screenState == finished`.

Bezel-Hint-Icons (oben rechts = oberer Button, unten rechts = unterer Button, der Bezel-Rundung folgend — Garmins „Input Hints"-Muster aus der Personality-UI-Bibliothek) zeigen den jeweils aktuellen Button-Zweck an. Button-Semantik, vollständig aus `screenState` abgeleitet:

| `screenState` | Oberer Button (`cmd_pause`/`cmd_resume`/`cmd_confirm`) | Unterer Button (`cmd_skip`) |
|---|---|---|
| `paused` | Start → `start()` | Skip |
| `running` | Pause → `pause()` | Skip |
| `hold_waiting` | Start → `startHold()` | Skip |
| `holding` | Fertig → `finishHold()` | Skip |
| `confirming` | Bestätigen → `confirmInterval()` | deaktiviert (No-Op) |
| `finished` | ohne Funktion | ohne Funktion |

`hold_waiting`/`holding` sind das Watch-seitige Pendant zum `holdWaiting`/`holdStarted`-Flow am Handy (`workout_notifier.dart`); die Uhr sendet dafür dieselben Kommando-Strings wie für Pause/Resume, das Handy unterscheidet anhand des aktuellen `WorkoutState`, ob `pause()`/`start()` oder `startHold()`/`finishHold()` gemeint ist — dieselbe Ambiguitätsauflösung, die auch die Handy-UI heute schon für denselben Button-Bereich vornimmt (Play/Pause-Button wird dort durch den START/FERTIG-Button ersetzt, nicht ergänzt).

---

## Dateistruktur (Delta zur bestehenden Rückkanal-Struktur)

| Datei | Änderung |
|---|---|
| `garmin_watch_app/source/garmin_watch_appView.mc` | vollständige Neuimplementierung: drei Screens je nach `screenState`, Rendering von Fortschrittsring/Text/Bezel-Hints |
| `garmin_watch_app/source/garmin_watch_appDelegate.mc` | `onKey()`-Handling für die zwei physischen Buttons, mapped auf `cmd_*`-Strings; `onSelect()`-Exit entfällt (Scope-Entscheidung 7) |
| `garmin_watch_app/source/StateSnapshotListener.mc` (neu) | Empfang der `state_snapshot`-Nachrichten vom Handy über `Communications.registerForPhoneAppMessages()` (exakte API bei Implementierung verifizieren) |
| `android/app/src/main/kotlin/.../GarminBridge.kt` | neue Methode `sendStateSnapshot(payload, callback)` über `ConnectIQ.sendMessage()` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | `MethodChannel` um neuen Call (z.B. `sendStateSnapshot`) erweitert; bestehender `EventChannel` liefert unverändert alle Nachrichtentypen roh weiter (keine Kotlin-Änderung für die neuen `cmd_*`-Werte nötig) |
| `lib/core/services/garmin_service.dart` | interner Wechsel auf einen einmalig erzeugten, geteilten Broadcast-Stream (siehe Architektur); neue Methode `Future<void> sendStateSnapshot(Map)` und `Stream<String> watchCommands()` als zweite Sicht auf denselben Stream |
| `lib/features/workout/garmin_workout_sync_notifier.dart` (neu) | Vermittlerschicht zwischen `workoutProvider` und `GarminService`: Snapshot-Serialisierung inkl. `line1`/`line2`-Formatierung und `_lastNonPauseLabel()`-Äquivalent, Änderungs-Schlüssel-Vergleich, gegateter Versand (`watchAppStatus == running`), Kommando-Dispatch mit Guards, periodischer Registrierungs-Retry bei `AppLifecycleState.resumed` |
| `lib/app.dart` | hält `garminWorkoutSyncNotifier` dauerhaft aktiv (auch im Hintergrund, siehe Fehlerbehandlung) |
| `test/features/workout/garmin_workout_sync_notifier_test.dart` (neu) | Unit-Tests für Snapshot-Serialisierung (alle sechs `screenState`-Fälle, `finished`-Rückwärtssuche), Änderungs-Schlüssel-Vergleich und Kommando-Dispatch inkl. Guard-Fälle |

---

## Fehlerbehandlung / Risiken

- **API-Signaturen nicht primärquellenverifiziert:** `ConnectIQ.sendMessage()` (Kotlin) und `Communications.registerForPhoneAppMessages()` (Monkey C) sind aus bestehendem Connect-IQ-SDK-Wissen abgeleitet, nicht wie die übrige Doku dieses Projekts per Live-Abruf von `developer.garmin.com` gegengeprüft — die entsprechenden Seiten sind clientseitig gerendert (SPA) und ließen sich mit den verfügbaren Recherche-Werkzeugen nicht abrufen. Vor der Implementierung gegen die SDK-Referenz bzw. den Simulator verifizieren.
- **Nachrichten-Zustellung bleibt best-effort:** wie beim bestehenden Rückkanal kein Retry, kein Heartbeat (Scope-Entscheidung 3). Geht ein `state_snapshot` verloren, zeigt die Uhr den letzten bekannten Stand, bis die nächste Zustandsänderung einen neuen Push auslöst — kein explizites „veraltet"-Signal in v1.
- **Payload-Größe:** das `state_snapshot`-Dictionary ist deutlich größer als die bisherigen einzelnen Strings. Connect-IQ-App-Messages haben eine geräteabhängige Größenbegrenzung; die hier verwendeten Feldlängen (kurze, vorformatierte Strings) sollten unproblematisch sein, ist aber früh auf echter Hardware zu verifizieren statt erst spät im Implementierungsprozess.
- **Ungültige/verspätete Kommandos:** abgefangen durch die bestehenden Guards in `skip()`/`startHold()`/`finishHold()` **und** die neu im Dispatcher zu ergänzenden Guards für `confirmInterval()`/`start()` (siehe Architektur) — ohne Letztere sind ein Absturz (Index außerhalb des Arrays) bzw. ein doppelter Timer real erreichbar, nicht nur theoretisch.
- **Kaltstart ohne laufendes Training:** kein Sonderfall — der Snapshot des Idle-Zustands (`screenState == paused`, Minute 0) wird ganz normal auf dem Running-Screen angezeigt, wenn die Uhr geöffnet wird, bevor am Handy gestartet wurde.
- **Kaltstart der Handy-App bei bereits laufender Watch-App:** startet die Handy-App neu, während die Watch-App schon offen ist, kommt nie ein `"opened"`-Event (kein aktiver „läuft die App gerade?"-Query in Connect IQ, siehe Rückkanal-Spec) — der Huckepack-Trigger aus Scope-Entscheidung 2 greift dann nicht, die Uhr bleibt leer/veraltet bis zur nächsten Handy-seitigen Zustandsänderung. `GarminBridge.openWatchApp()`s bereits vorhandener `APP_IS_ALREADY_RUNNING`-Status wäre eine mögliche spätere Abhilfe (schon in der Rückkanal-Spec als Idee vermerkt), wird hier aber bewusst nicht gebaut.
- **Screen vor dem ersten Snapshot:** zeigt einen neutralen Lade-/Leerzustand, keinen der drei regulären Screens.
- **Lokaler Countdown hält bei 0 an:** außer im `holding`-Zustand (dort sind negative Werte/Überzeit explizit vorgesehen, exakt wie am Handy) zählt die Uhr nicht unter 0 weiter — verhindert einen unpassenden Überzeit-Countdown, falls ein `confirming`-Snapshot verspätet ankommt.
- **Hintergrundbetrieb ist eine geerbte, ungeprüfte Voraussetzung:** die Rückkanal-Spec schließt Hintergrundbetrieb der Handy-App explizit aus und verlangt in ihrer Testmatrix „Handy-App durchgehend im Vordergrund halten". Der ganze Sinn dieses Vorhabens ist aber gerade, *nicht* aufs Handy schauen zu müssen — ob Flutter-EventChannel/Kommando-Dispatch bei ausgeschaltetem Handy-Display (App weiter im Recents-Stack, nicht weggewischt) zuverlässig weiterläuft, ist nicht verifiziert. Gehört als eigener Testfall in die Matrix (siehe Testing) statt stillschweigend vorausgesetzt zu werden.
- **Buttonbelegung weicht von der Systemkonvention ab:** oberer Button ist system-üblich „Start/Stop", unterer „Back/Lap" — diese Spec belegt Skip auf dem unteren Button (Scope-Entscheidung 7). Bewusste Abweichung, siehe dort.

---

## Testing

- **Dart:** Snapshot-Serialisierung (`WorkoutState` → Dictionary, inkl. `line1`/`line2`-Formatierung und `finished`-Rückwärtssuche), der Änderungs-Schlüssel-Vergleich (kein Push bei reinem `secondsLeft`-Wechsel) und Kommando-Dispatch (`cmd_*`-String → `WorkoutNotifier`-Methodenaufruf, inkl. der Guard-Fälle für `cmd_confirm`/`cmd_resume` in ungültigem Zustand) sind reine Funktionen im neuen `garmin_workout_sync_notifier.dart`, unit-testbar ohne Hardware — inklusive aller sechs `screenState`-Fälle und der Zeit-Übungs-Ambiguität (Pause/Resume vs. Start/Fertig).
- **Kotlin (`GarminBridge`) & Monkey C:** wie bisher im Projekt üblich nicht automatisiert testbar (SDK-/Hardware-gebunden) — Verifikation über Connect-IQ-Simulator (`monkeydo`) und echtes Gerät, analog zur Vorgehensweise bei Tasks 11–13.
- **Manuelle Testmatrix auf echter Venu 4:**
  - Watch öffnen, bevor das Handy-Training gestartet wurde → Idle-Zustand korrekt angezeigt.
  - Watch öffnen, während das Handy-Training bereits mitten im Training läuft → korrekter Snapshot ohne Tap.
  - Jeden Button in jedem der sechs `screenState`-Zustände auslösen, inklusive einer kompletten Zeit-Übung (Start → Halten → Fertig) rein über die Uhr.
  - Pause am Handy auslösen, während die Watch-App offen ist → Uhr zieht ohne Zutun nach.
  - Reset bzw. Planwechsel am Handy auslösen, während die Watch-App offen ist → Uhr zieht nach.
  - BLE-Verbindung während des Trainings kurz kappen und wiederherstellen → nächste Zustandsänderung bringt die Uhr wieder auf aktuellen Stand.
  - Trainingsende erreichen, während die Watch-App offen ist → Fertig-Screen erscheint automatisch, zeigt die letzte echte Übung (nicht „Pause"), wenn der Plan mit einer Cool-Down-Pause endet.
  - Handy-Display ausschalten (App nicht schließen, nicht wegwischen), Training währenddessen über die Uhr weitersteuern → prüft die Hintergrundbetrieb-Annahme oben.
  - Exit-Swipe auf der Uhr während des Trainings → App schließt, Rückkanal meldet „closed".
  - Einstellungen am Handy öffnen und wieder schließen, während die Watch-App offen ist und Kommandos sendet → Kommando-Zustellung darf nicht abreißen (Regressionstest für den `EventChannel`-Konflikt oben).

---

## Erfolgskriterien

- Watch zeigt beim Öffnen den aktuellen Trainingsstand, unabhängig davon ob und wo im Training das Handy gerade steht — ohne Tap am Handy (Ausnahme: Kaltstart der Handy-App bei bereits laufender Watch-App, siehe Fehlerbehandlung).
- Pause/Start, Bestätigen und Skip sind über die zwei physischen Buttons der Uhr bedienbar; das Handy bleibt durchgehend Quelle der Wahrheit.
- Eine Zustandsänderung am Handy (z.B. Pause-Tap, Reset, Planwechsel) zieht die Uhr ohne Zutun nach, und umgekehrt.
- Zeit-Übungen (Halten) sind vollständig über die Uhr bedienbar (Start → Halten → Fertig).
- Bestätigungs- und Fertig-Zustand haben eigene, klar erkennbare Screens auf der Uhr; der Fertig-Screen zeigt die zuletzt tatsächlich absolvierte Übung, nicht ein abschließendes Pause-Intervall.
- Kein Absturz und kein doppelter Timer durch verspätete/veraltete Kommandos.
- Einstellungen öffnen/schließen unterbricht die Kommando-Zustellung von der Uhr nicht.
- `flutter analyze` und alle Tests bleiben grün.

---

## Nicht im Scope

- Reset über die Uhr (Scope-Entscheidung 6) — weiterhin nur am Handy möglich.
- Periodischer Heartbeat / Selbstheilung bei Nachrichtenverlust (Scope-Entscheidung 3) — Protokoll ist über das `type`-Feld dafür vorbereitet, aber nicht gebaut.
- Eigenes Request/Response-Protokoll für den Kaltstart (verworfener Ansatz B, Scope-Entscheidung 2).
- Sekundengenaue Live-Synchronisierung vom Handy (verworfener Live-Push-Ansatz, Scope-Entscheidung 1) — die Uhr rechnet lokal.
- „Veraltet"-Indikator bei verlorenen Nachrichten oder BLE-Aussetzern.
- Auflösung des Kaltstart-Falls „Handy-App startet neu, Watch-App läuft schon" (z.B. über `APP_IS_ALREADY_RUNNING`) — als spätere Verbesserung festgehalten, siehe Fehlerbehandlung.
- Inhaltliche Änderungen an der Registrierungs-/Nachrichten-Logik des bestehenden App-Status-Rückkanals (Task 11–13) — der zusätzliche `resumed`-Retry-Aufruf und der geteilte Broadcast-Stream sind Erweiterungen an der Dart-Konsumentenseite, keine Änderung an `GarminBridge`s SDK-Registrierung selbst.
