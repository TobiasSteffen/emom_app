# Garmin-Watch: Hauptscreen-Spiegelung – Design Spec
**Datum:** 2026-08-12
**Ansatz:** Bidirektionale Erweiterung der bestehenden Connect-IQ-App-Messages-Kanäle (Ansatz A aus der Klärung), Uhr rechnet zwischen Ereignissen lokal weiter

---

## Ziel

Der Trainings-Hauptscreen der Handy-App (`workout_screen.dart`) soll auf die Garmin-Uhr gespiegelt werden — nicht nur zur Anzeige, sondern auch zur Steuerung: Training pausieren/fortsetzen, ein Intervall überspringen und nach einem Alarm zum nächsten Intervall bestätigen, alles direkt vom Handgelenk aus, über die zwei physischen Buttons der Uhr. Grundlage bleibt `docs/emom_app_spezifikation.md`, Abschnitt „Garmin-Integration", sowie der bereits abgeschlossene App-Status-Rückkanal (`docs/superpowers/specs/2026-08-08-garmin-app-status-rueckkanal-design.md`).

---

## Scope-Entscheidungen (aus der Klärung)

1. **Ereignisbasierter Sync, Uhr rechnet lokal** — das Handy pusht nur bei Zustandswechseln (Start, Pause, Skip, Intervallwechsel, Bestätigung, Ende) einen vollen Snapshot; die Uhr zählt den Countdown dazwischen selbst runter, genau wie `WorkoutNotifier` das am Handy tut. Verworfen: Live-Push jede Sekunde — unnötiger Bluetooth-Traffic, fehleranfälliger bei einzelnen verlorenen Nachrichten, ohne echten Mehrwert gegenüber lokalem Rechnen.
2. **Kaltstart huckepack auf dem bestehenden Rückkanal statt eigenem Request/Response** — reagiert das Handy auf das bereits existierende `"opened"`-Event der Watch-App (Task 11–13) mit einem vollen Snapshot, ist kein zusätzlicher Nachrichtentyp nötig. Verworfen: eigenes `request_state`/`response_state`-Protokoll — Connect IQ hat kein echtes Request/Response, `Communications.transmit()` ist in beide Richtungen Fire-and-Forget; ein eigenes Protokoll hätte Zuordnung/Matching nachbauen müssen, ohne dass der Rückkanal nicht ohnehin schon dieselbe Information liefert.
3. **Kein Heartbeat in v1** — kein Beleg, dass App-Messages in der Praxis verloren gehen (gleiche Linie wie beim bestehenden Rückkanal, der aus demselben Grund ebenfalls ohne Heartbeat auskommt). Das Nachrichtenformat bekommt aber von Anfang an ein `type`-Feld, damit ein Heartbeat oder andere künftige Signale später als zusätzlicher Nachrichtentyp ergänzt werden können, ohne das Protokoll umzubauen.
4. **Zustandsänderungen werden unabhängig vom Auslöser gepusht** — pausiert der Nutzer am Handy, zieht die Uhr automatisch nach, weil der Push an jede relevante `WorkoutNotifier`-Zustandsänderung hängt, nicht an „Kommando kam von der Uhr". Kein Sonderfall, keine zusätzliche Logik nötig.
5. **Zeit-Übungen (Halten) werden unterstützt** — kein Sonderausschluss für Intervalle mit `isTimed` (z.B. Pezziball). Die Button-Zustandsmaschine (siehe unten) bekommt zwei zusätzliche Zustände statt einer Ausnahme.
6. **Reset bleibt Handy-exklusiv** — von den vier möglichen Bedienelementen aus der Klärungsrunde wurden Play/Pause, Skip und Bestätigen für die Uhr gewählt, Reset bewusst nicht. Ein Fehlgriff beim Reset (Trainingsfortschritt weg) ist teurer als bei den anderen Aktionen, und Reset ist die am seltensten benutzte der vier.

---

## Architektur & Datenfluss

Erweitert den bestehenden Dreiteiler (Watch-App / Kotlin-Bridge / Dart-Service) symmetrisch um einen zweiten Nachrichtentyp in beide Richtungen — kein neues Subsystem, dieselben Bausteine wie beim App-Status-Rückkanal.

**Phone → Watch (neu):** Bisher kann das Handy der Uhr nur einen Öffnen-Befehl schicken (`openWatchApp()`). Neu: `GarminBridge.kt` bekommt eine Sende-Fähigkeit für Nutzdaten (`ConnectIQ.sendMessage(device, app, message, listener)` — exakte Signatur bei der Implementierung gegen die aktuelle SDK-Doku verifizieren, da sie hier nicht per Primärquelle nachgeprüft werden konnte, siehe Fehlerbehandlung). Payload ist ein Dictionary mit `type`-Feld:

```
{"type" => "state_snapshot",
 "minute" => 12, "totalMinutes" => 30,
 "line1" => "Kettlebell 20kg", "line2" => "Swing beidarmig · L",
 "isPause" => false, "isTimed" => false,
 "reps" => 14, "timedSeconds" => 0,
 "secondsLeft" => 42, "duration" => 60,
 "screenState" => "running",
 "nextText" => "Nächste: PAUSE · 60s",
 "totalReps" => 187}
```

Feldbedeutung:

| Feld | Bedeutung |
|---|---|
| `minute` | aktueller `currentMinute`-Index, treibt die Phasenfarbe (Uhr berechnet sie lokal aus den bereits in `CLAUDE.md` dokumentierten Minuten-Bereichen — keine Farbwerte über die Leitung) |
| `line1`/`line2` | fertig formatierter Anzeigetext (Gerät+Gewicht / Übung+Seite), von der gleichen Logik wie `workoutLabelForMinute()` am Handy erzeugt. Bei Pause: `line1 = "Pause"`, `line2 = ""`. Die Uhr formatiert nichts selbst nach, kein Abkürzungs-Mapping auf Watch-Seite nötig. |
| `isPause` | unterdrückt die Reps/Zeit-Zahl auf dem Running-Screen (Pendant zu `RepsCard`s `if (!isPause)`) |
| `isTimed`/`timedSeconds` | schaltet die große Zahl von „Reps" auf „Zeit" (`timedSeconds`) um, Pendant zu `RepsCard` |
| `reps` | aktuelle Ziel-Wiederholungszahl (0 bei Pause oder Zeit-Übung) |
| `secondsLeft`/`duration` | treiben die MM:SS-Anzeige inkl. Überzeit (negatives `secondsLeft` → `+MM:SS`, Pendant zu `TimerDisplay`) |
| `screenState` | einer von `paused`, `running`, `hold_waiting`, `holding`, `confirming`, `finished` — steuert allein, welcher der drei Screens aktiv ist und was der obere Button gerade tut (siehe Tabelle unten). Vom Handy vorberechnet, die Uhr repliziert die Ableitungslogik nicht selbst. |
| `nextText` | fertig formatierter Vorschau-Text auf die nächste Übung, exakt im Format von `NextMinutePreview` (`"Nächste: ..."`), für die Uhr gekürzt. Leer beim letzten Intervall (kein Nächstes vorhanden), analog zur Handy-Bedingung `currentMinute < totalMinutes - 1` — die Running-Screen-Zeile entfällt dann einfach. |
| `totalReps` | nur für den Fertig-Screen relevant |

Gesendet: bei jeder relevanten `WorkoutNotifier`-Zustandsänderung (Start, Pause, Skip, Intervallwechsel, Bestätigung, Start/Ende einer Zeit-Übungs-Haltephase, Trainingsende) sowie als Antwort auf das bestehende `"opened"`-Event des Rückkanals.

**Watch → Phone (Erweiterung des bestehenden Kanals):** wie bisher einfache Strings über `Communications.transmit()`/`registerForAppEvents()`, zusätzlich zu den bestehenden `"opened"`/`"closed"` vier neue Werte: `"cmd_pause"`, `"cmd_resume"`, `"cmd_confirm"`, `"cmd_skip"`. Phone-seitig 1:1-Routing auf vorhandene `WorkoutNotifier`-Methoden (`pause()`, `start()`, `confirmInterval()`, `skip()`) — keine neue Geschäftslogik, nur Weiterleitung. Ungültige Kommandos (z.B. Skip im `finished`-Zustand) laufen ins Leere über die dort bereits bestehenden Guards.

**Neue Vermittlerschicht (Dart):** `WorkoutNotifier` bekommt keine Garmin-Abhängigkeit — stattdessen ein neuer Provider (Arbeitstitel `garminWorkoutSyncNotifier`), der `workoutProvider` beobachtet und bei relevanten Änderungen einen Snapshot über `GarminService` verschickt, sowie den Kommando-Stream von `GarminService` abonniert und auf `workoutProvider.notifier`-Methoden mapped. Damit bleiben Trainingslogik und Garmin-Anbindung getrennt, wie es die bestehende Trennung von `WorkoutNotifier` und `GarminNotifier` heute schon vorgibt. Muss dauerhaft aktiv sein (nicht nur solange z.B. das Einstellungen-Fenster offen ist) — wird analog zum Wakelock-Muster in `app.dart` von der App-Wurzel aus gehalten.

---

## Watch-Screens & Button-Zustandsmaschine

Drei Screens, ausschließlich über `screenState` gesteuert:

- **Running** (gewähltes Layout „V2 · Kompaktes Gesamtlayout" aus dem visuellen Brainstorming): aktuelle Übung zweizeilig (`line1`/`line2`), Reps- bzw. Zeit-Zahl groß mittig, Timer darunter (inkl. Überzeit-Format), Next-Preview (`nextText`) als kompakte dritte Zeile. Phasenfarbe als Fortschrittsring um den Bildschirmrand, lokal aus `minute` berechnet. Aktiv bei `screenState` = `paused`, `running`, `hold_waiting` oder `holding`.
- **Bestätigung:** eigener Übergangs-Screen, groß „NÄCHSTE ÜBUNG" plus `nextText`-Vorschau, deutlich abgesetzt vom laufenden Training. Aktiv bei `screenState == confirming`.
- **Fertig:** eigener Screen mit `totalReps`, letzter absolvierter Übung (`line1`/`line2` desselben, finalen Snapshots — `currentMinute` bleibt beim letzten Intervall stehen statt darüber hinaus zu zählen, der Fertig-Snapshot beschreibt also bereits korrekt die zuletzt absolvierte Übung, kein separates Nachhalten nötig) und Hinweis „Training beendet". Aktiv bei `screenState == finished`.

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
| `garmin_watch_app/source/garmin_watch_appDelegate.mc` | `onKey()`-Handling für die zwei physischen Buttons, mapped auf `cmd_*`-Strings |
| `garmin_watch_app/source/StateSnapshotListener.mc` (neu) | Empfang der `state_snapshot`-Nachrichten vom Handy über `Communications.registerForPhoneAppMessages()` (exakte API bei Implementierung verifizieren) |
| `android/app/src/main/kotlin/.../GarminBridge.kt` | neue Methode `sendStateSnapshot(payload, callback)` über `ConnectIQ.sendMessage()` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | `MethodChannel` um neuen Call (z.B. `sendStateSnapshot`) erweitert; bestehender `EventChannel` liefert zusätzlich die vier neuen `cmd_*`-Werte |
| `lib/core/services/garmin_service.dart` | neue Methode `Future<void> sendStateSnapshot(Map)`; `watchAppRunningEvents()`-Pendant für Kommandos (z.B. `Stream<String> watchCommands()`) |
| `lib/features/workout/garmin_workout_sync_notifier.dart` (neu) | Vermittlerschicht zwischen `workoutProvider` und `GarminService`, siehe Architektur-Abschnitt |
| `lib/app.dart` | hält `garminWorkoutSyncNotifier` dauerhaft aktiv, analog zum bestehenden Wakelock-`WidgetsBindingObserver` |
| `test/features/workout/garmin_workout_sync_notifier_test.dart` (neu) | Unit-Tests für Snapshot-Serialisierung (alle sechs `screenState`-Fälle) und Kommando-Dispatch |

---

## Fehlerbehandlung / Risiken

- **API-Signaturen nicht primärquellenverifiziert:** `ConnectIQ.sendMessage()` (Kotlin) und `Communications.registerForPhoneAppMessages()` (Monkey C) sind aus bestehendem Connect-IQ-SDK-Wissen abgeleitet, nicht wie die übrige Doku dieses Projekts per Live-Abruf von `developer.garmin.com` gegengeprüft — die entsprechenden Seiten sind clientseitig gerendert (SPA) und ließen sich mit den verfügbaren Recherche-Werkzeugen nicht abrufen. Vor der Implementierung gegen die SDK-Referenz bzw. den Simulator verifizieren, analog zur bereits etablierten Praxis in diesem Projekt (siehe z.B. die primärquellenbelegten Korrekturen im Rückkanal-Spec).
- **Nachrichten-Zustellung bleibt best-effort:** wie beim bestehenden Rückkanal kein Retry, kein Heartbeat (Scope-Entscheidung 3). Geht ein `state_snapshot` verloren, zeigt die Uhr den letzten bekannten Stand, bis die nächste Zustandsänderung einen neuen Push auslöst — kein explizites „veraltet"-Signal in v1, gleiche akzeptierte Trade-off-Linie wie beim Kaltstart-Unbekannt-Fall des bestehenden Rückkanals.
- **Payload-Größe:** das `state_snapshot`-Dictionary ist deutlich größer als die bisherigen einzelnen Strings. Connect-IQ-App-Messages haben eine geräteabhängige Größenbegrenzung; die hier verwendeten Feldlängen (kurze, vorformatierte Strings) sollten unproblematisch sein, ist aber früh auf echter Hardware zu verifizieren statt erst spät im Implementierungsprozess.
- **Ungültige Kommandos laufen ins Leere:** z.B. Skip im `confirming`- oder `finished`-Zustand — abgefangen durch die bereits bestehenden Guards in `WorkoutNotifier` (`skip()` bricht z.B. bei `isFinished`/`waitingForConfirmation` bereits ab), keine neue Absicherung nötig.
- **Kaltstart ohne laufendes Training:** kein Sonderfall — der Snapshot des Idle-Zustands (`screenState == paused`, Minute 0) wird ganz normal auf dem Running-Screen angezeigt, wenn die Uhr geöffnet wird, bevor am Handy gestartet wurde.

---

## Testing

- **Dart:** Snapshot-Serialisierung (`WorkoutState` → Dictionary) und Kommando-Dispatch (`cmd_*`-String → `WorkoutNotifier`-Methodenaufruf) sind reine Funktionen im neuen `garmin_workout_sync_notifier.dart`, unit-testbar ohne Hardware — inklusive aller sechs `screenState`-Fälle und der Zeit-Übungs-Ambiguität (Pause/Resume vs. Start/Fertig).
- **Kotlin (`GarminBridge`) & Monkey C:** wie bisher im Projekt üblich nicht automatisiert testbar (SDK-/Hardware-gebunden) — Verifikation über Connect-IQ-Simulator (`monkeydo`) und echtes Gerät, analog zur Vorgehensweise bei Tasks 11–13.
- **Manuelle Testmatrix auf echter Venu 4:**
  - Watch öffnen, bevor das Handy-Training gestartet wurde → Idle-Zustand korrekt angezeigt.
  - Watch öffnen, während das Handy-Training bereits mitten im Training läuft → korrekter Snapshot ohne Tap.
  - Jeden Button in jedem der sechs `screenState`-Zustände auslösen, inklusive einer kompletten Zeit-Übung (Start → Halten → Fertig) rein über die Uhr.
  - Pause am Handy auslösen, während die Watch-App offen ist → Uhr zieht ohne Zutun nach.
  - BLE-Verbindung während des Trainings kurz kappen und wiederherstellen → nächste Zustandsänderung bringt die Uhr wieder auf aktuellen Stand.
  - Trainingsende erreichen, während die Watch-App offen ist → Fertig-Screen erscheint automatisch.

---

## Erfolgskriterien

- Watch zeigt beim Öffnen den aktuellen Trainingsstand, unabhängig davon ob und wo im Training das Handy gerade steht — ohne Tap am Handy.
- Pause/Start, Bestätigen und Skip sind über die zwei physischen Buttons der Uhr bedienbar; das Handy bleibt durchgehend Quelle der Wahrheit.
- Eine Zustandsänderung am Handy (z.B. Pause-Tap) zieht die Uhr ohne Zutun nach, und umgekehrt.
- Zeit-Übungen (Halten) sind vollständig über die Uhr bedienbar (Start → Halten → Fertig).
- Bestätigungs- und Fertig-Zustand haben eigene, klar erkennbare Screens auf der Uhr.
- `flutter analyze` und alle Tests bleiben grün.

---

## Nicht im Scope

- Reset über die Uhr (Scope-Entscheidung 6) — weiterhin nur am Handy möglich.
- Periodischer Heartbeat / Selbstheilung bei Nachrichtenverlust (Scope-Entscheidung 3) — Protokoll ist über das `type`-Feld dafür vorbereitet, aber nicht gebaut.
- Eigenes Request/Response-Protokoll für den Kaltstart (verworfener Ansatz B, Scope-Entscheidung 2).
- Sekundengenaue Live-Synchronisierung vom Handy (verworfener Live-Push-Ansatz, Scope-Entscheidung 1) — die Uhr rechnet lokal.
- „Veraltet"-Indikator bei verlorenen Nachrichten oder BLE-Aussetzern.
- Änderungen am bestehenden App-Status-Rückkanal (Task 11–13) selbst — wird nur als Kaltstart-Trigger genutzt, nicht verändert.
