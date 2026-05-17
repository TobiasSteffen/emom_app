# Kettlebell EMOM App – Spezifikation

## Übersicht

Die **Kettlebell EMOM App** ist eine Flutter-basierte Trainings-Timer-App für Android. Sie führt den Nutzer durch ein 30-minütiges EMOM-Protokoll (Every Minute On the Minute) mit Kettlebell Swings oder Steel Mace 360s – das Trainingsgerät ist in den Einstellungen wählbar.

---

## Trainingsprotokoll

Das Workout folgt einer Pyramiden-Struktur über 30 Minuten.

| Phase | Minuten | Reps (Standard) | Beschreibung |
|---|---|---|---|
| Warm Up | 1–5 | 5 | Konstant |
| Aufbau | 6–15 | 6–15 | +1 Rep pro Minute (interpoliert) |
| Peak | 16–20 | 15 | Konstant |
| Abbau | 21–25 | 14–10 | −1 Rep pro Minute (interpoliert) |
| Cool Down | 26–30 | 10 | Konstant |

Reps und Dauer sind vollständig konfigurierbar (phasenbasiert oder minutengenau, siehe Config Screen).

---

## Features

- **EMOM-Timer**: Countdown je Intervall (konfigurierbare Dauer, Standard 60 s)
- **Rep-Anzeige**: Aktuelle Wiederholungszahl wird groß angezeigt, begleitet vom Icon des gewählten Sportgeräts
- **Gesamtfortschritt**: Fortschrittsbalken zeigt Minute und absolvierte Wiederholungen
- **Vorschau**: Nächste Minute mit Rep-Anzahl wird angezeigt
- **Phasen-Anzeige**: Aktuelle Phase (Warm Up / Aufbau / Peak / Abbau / Cool Down) wird farblich hervorgehoben
- **Haptic Feedback**: Vibration bei Intervallwechsel (konfigurierbar)
- **Countdown-Warntöne**: In den letzten 5 Sekunden eines Intervalls erklingt jede Sekunde ein kurzer Warnton (konfigurierbar)
- **Intervall-Abschluss-Signal**: Am Ende jedes Intervalls (außer dem letzten) ertönt ein Wecker-Signal in Dauerschleife. Das nächste Intervall startet erst nach aktiver Bestätigung durch den Nutzer. Nach dem letzten Intervall wechselt die App direkt in den Abschluss-Screen ohne Alarm.
- **Pause/Resume**: Workout kann pausiert und fortgesetzt werden
- **Reset**: Workout kann jederzeit neu gestartet werden
- **Abschluss-Screen**: Zeigt Gesamtzahl der Wiederholungen nach Beendigung
- **Config Screen**: Einstellungen erreichbar über Zahnrad-Icon oben rechts oder Wischgeste nach links auf dem Hauptscreen
- **Sportgerät-Auswahl**: Kettlebell (Swings) oder Steel Mace (360s) – beeinflusst Übungsbezeichnung in der gesamten UI
- **Editierbarer Workout-Plan**: Wiederholungen und Intervalldauer je Intervall konfigurierbar (phasenbasiert oder minutengenau)
- **Bildschirm-Wachhalten**: Die App verhindert, dass der Bildschirm während eines laufenden Workouts in den Ruhezustand geht (Wake Lock via `wakelock_plus`). Der Wake Lock wird beim Starten aktiviert (`_start()`), beim Pausieren (`_pause()`) und beim Beenden des Workouts deaktiviert.
- **Trainingshistorie**: Vergangene Workouts werden automatisch gespeichert und sind über ein History-Icon im Hauptscreen abrufbar

---

## UI & Design

- **App-Icon**: Kettlebell-Silhouette in Orange (`#FF6B00`) auf dunklem Hintergrund (`#0D0D0D`), für alle Android-Auflösungen generiert via `flutter_launcher_icons`
- **Hintergrund**: Absolutes Schwarz `#000000` (Hauptscreen und Config Screen)
- **Sportgerät-Icon im Hauptscreen**: Neben der Rep-Zahl wird ein kleines Icon des gewählten Geräts angezeigt. Das Icon wechselt automatisch je nach Einstellung.
- **Akzentfarbe** variiert je nach Phase:
  - 🟢 Grün `#4CAF50` – Warm Up & Cool Down
  - 🟠 Orange `#FF6B00` – Aufbau & Abbau
  - 🔴 Rot `#FF0000` – Peak
- **Puls-Animation** bei Intervallwechsel (kurze Scale-Animation auf der Rep-Card)
- **Zwei Fortschrittsbalken**: Gesamt-Workout und aktueller Minuten-Countdown
- **Zahnrad-Icon** (`Icons.settings`) oben rechts öffnet den Config Screen
- **History-Icon** (`Icons.history`) links neben dem Zahnrad öffnet den Trainingsverlauf

---

## Technischer Stack

| Eigenschaft | Wert |
|---|---|
| Framework | Flutter |
| Sprache | Dart |
| Zielplattform | Android |
| Deployment | ADB over WiFi |

### Dependencies

| Paket | Version | Zweck |
|---|---|---|
| `vibration` | ^2.0.0 | Haptisches Feedback |
| `audioplayers` | ^5.2.1 | Abspielen von Audiodateien |
| `flutter/gestures` | (built-in) | `DragStartBehavior` für sofortige Swipe-Erkennung |
| `flutter/services` | (built-in) | `SystemSound` als Fallback |
| `shared_preferences` | ^2.0.0 | Persistente Speicherung der Einstellungen |
| `flutter_launcher_icons` | ^0.14.0 | Generierung des App-Icons für alle Android-Auflösungen (dev) |
| `file_picker` | ^8.0.0 | Nativer Dateiauswahl-Dialog für den Import eigener Sounddateien |
| `path_provider` | ^2.0.0 | Zugriff auf das app-interne Dokumentenverzeichnis |
| `wakelock_plus` | ^1.0.0 | Bildschirm-Wachhalten während des Workouts |
| `volume_controller` | ^2.0.0 | Medien-Lautstärke auf den konfigurierten Zielwert erhöhen (nur wenn aktuell niedriger); wird nicht wiederhergestellt |
| `intl` | ^0.20.2 | Lokalisierte Datumsformatierung (Deutsch) für die Trainingshistorie |

### Icon-Generierung

#### App-Launcher-Icon

Konfiguration in `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#0D0D0D"
  adaptive_icon_foreground: "assets/icon/icon.png"
```

Ausführen nach jeder Icon-Änderung:

```bash
dart run flutter_launcher_icons
```

#### In-App-Icons

Die Icons `kettlebell.png` und `steelmace.png` (256×256, transparenter Hintergrund) sowie `icon.png` (1024×1024, dunkler Hintergrund) werden per Python-Skript programmatisch als PNG generiert. Quellskript: `docs/generate_icons.py`. Abhängigkeiten: nur Python-Stdlib (`zlib`, `struct`, `math`, `os`).

#### Alarm-Sounds

Die Alarm-Sounds werden per Python-Skript programmatisch als 16-bit PCM WAV-Dateien generiert. Quellskript: `docs/generate_sounds.py`.

Ausführen aus dem Projektroot:

```bash
python docs/generate_sounds.py
```

**Klangdesign (beide Varianten):**

Jede Alarm-Datei hat eine Länge von 2,5 Sekunden und folgt dem gleichen Beep-Muster:
- 3 Gruppen à 2 kurze Beeps (~180 ms je Beep, 40 ms Pause innerhalb der Gruppe)
- 400 ms Stille zwischen den Gruppen
- ~500 ms Stille am Ende (Loop-Puffer; zusätzlich 800 ms Delay via `Future.delayed` im Code)

Jeder Beep besteht aus Grundton + 1. Oberton (0,25× Amplitude) für mehr Klangcharakter. Die Hüllkurve hat 10 ms Attack und 50 ms Decay. Der zweite Beep jeder Gruppe ist minimal lauter (Amplitudenramp).

| Datei | Frequenz | Charakter |
|---|---|---|
| `alarm.wav` | 880 Hz (A5) | Scharf, durchdringend – gut wahrnehmbar auch bei Umgebungslärm |
| `alarm_low.wav` | 440 Hz (A4) | Eine Oktave tiefer, angenehmer für sensible Ohren |

Das Skript überschreibt `alarm.wav` nicht automatisch; zum Neuerzeugen muss der entsprechende Block im Skript auskommentiert werden (siehe Kommentar am Ende von `generate_sounds.py`). Abhängigkeiten: nur Python-Stdlib (`struct`, `math`, `os`).

---

## Projektstruktur

```
emom_app/
├── lib/
│   ├── main.dart             # App-Einstieg, WorkoutScreen, gesamte Trainingslogik und UI
│   ├── config_screen.dart    # Einstellungsseite (ConfigScreen, _MinuteRow, _SoundPickerDialog)
│   ├── settings.dart         # AppSettings-Klasse, Persistierung via shared_preferences
│   └── workout_history.dart  # IntervalRecord, WorkoutRecord, WorkoutHistory (Persistierung)
├── assets/
│   ├── sounds/
│   │   ├── bell.wav          # Alternativer Ton (auswählbar als Countdown-Sound)
│   │   ├── tick.wav          # Standard-Warnton für die letzten 5 Sekunden (je Sekunde)
│   │   ├── alarm.wav         # Wecker-Signal (880 Hz, scharf/durchdringend)
│   │   └── alarm_low.wav     # Wecker-Signal, tiefere Variante (440 Hz, angenehmer)
│   └── icon/
│       ├── icon.png          # Kettlebell-Icon (1024×1024, Quelle für flutter_launcher_icons)
│       ├── kettlebell.png    # Kettlebell-Icon für Hauptscreen-Anzeige (256×256)
│       └── steelmace.png     # Steel-Mace-Icon für Hauptscreen-Anzeige (256×256)
├── docs/
│   ├── emom_app_spezifikation.md  # Diese Datei
│   ├── generate_sounds.py         # Erzeugt alarm_low.wav (440 Hz)
│   └── generate_icons.py          # Erzeugt kettlebell.png, steelmace.png, icon.png
├── android/                  # Android-spezifische Konfiguration
├── pubspec.yaml              # Dependencies
└── build/
    └── app/outputs/
        └── flutter-apk/      # Generierte APK
```

---

## Workout-Logik

Die Rep-Anzahl und Intervalldauer pro Minute werden beim App-Start sowie nach jeder Konfigurationsänderung als Listen berechnet (`buildPlan()`, `buildDurations()`) und zur Laufzeit nur noch indexiert.

Im **Phasen-Modus** (`PlanMode.phaseBased`) werden Reps und Dauer pro Phase konfiguriert. Warm Up, Peak und Cool Down Reps werden direkt eingegeben, Aufbau/Abbau automatisch interpoliert.

Im **Minuten-Modus** (`PlanMode.minuteExact`) werden Reps, Dauer und Sportgerät direkt aus den 30 gespeicherten Wertepaaren geladen:

```
Reps:    [5,5,5,5,5, 6,7,8,9,10,11,12,13,14,15, 15,15,15,15,15, 14,13,12,11,10, 10,10,10,10,10]
Sekunden:[60,60,...] (je Intervall individuell konfigurierbar, min. 30)
```

Ein `Timer.periodic` mit 1-Sekunden-Intervall zählt den Countdown herunter.

### Warntöne & Intervall-Abschluss

Es gibt **keinen** Ton bei der vollen Minute / beim Intervallwechsel. Die Töne sind:

- **Letzte 5 Sekunden**: Sobald der Countdown auf ≤ 5 Sekunden fällt, wird jede Sekunde ein kurzer Warnton abgespielt (Countdown-Sound, konfigurierbar). Kann über „Warntöne" deaktiviert werden. Ist „Lautstärke erhöhen" aktiviert, wird gleichzeitig die Medien-Lautstärke des Geräts auf den konfigurierten Zielwert gesetzt (via `volume_controller`) — jedoch nur wenn die aktuelle Lautstärke niedriger ist. Die Lautstärke wird danach nicht wiederhergestellt.
- **Intervall-Ende (nicht letztes Intervall)**: Bei Erreichen von 0 stoppt der Timer. Es folgt eine 800 ms Vibration (falls aktiviert), dann wird das Wecker-Signal in Dauerschleife abgespielt. Das Workout pausiert automatisch.
- **Bestätigung erforderlich**: Das Wecker-Signal läuft bis zur aktiven Bestätigung (Tippen auf den „Weiter"-Button oder die gesamte Overlay-Anzeige). Erst dann stoppt der Alarm, der Minutenzähler erhöht sich, und das nächste Intervall startet.
- **Letztes Intervall**: Bei Erreichen von 0 stoppt der Timer. Es folgt eine 600 ms Vibration (falls aktiviert). Kein Alarm, kein Bestätigungs-Overlay — die App wechselt direkt in den Abschluss-Screen.

### Haptic Feedback

- **Intervall-Ende (nicht letztes Intervall)**: 800 ms Vibration — ausgelöst am Anfang von `_playAlarm()`, bevor der Alarm-Ton spielt
- **Intervall-Ende (letztes Intervall)**: 600 ms Vibration — ausgelöst direkt in `_onMinuteComplete()` beim Übergang in den Abschluss-Screen
- **Intervall-Bestätigung (Weiter)**: 400 ms Vibration — ausgelöst in `_confirmInterval()`

---

## Navigation & Übergänge

Hauptscreen und Config Screen sind als zwei Seiten eines `PageView` implementiert. Es gibt keine Navigator-Push/Pop-Navigation.

| Aspekt | Wert |
|---|---|
| Widget | `PageView` mit `PageController` |
| Physik | `BouncingScrollPhysics(parent: PageScrollPhysics())` |
| Swipe-Erkennung | `DragStartBehavior.down` (kein Erkennungs-Delay) |
| Übergangsanimation | `animateToPage`, 380 ms, `Curves.easeInOutCubic` |
| Seite 0 | Hauptscreen (WorkoutScreen) |
| Seite 1 | Config Screen |

**Navigationsauslöser Hauptscreen → Config:**
- Wischgeste nach links
- Tippen auf das Zahnrad-Icon oben rechts

**Navigationsauslöser Config → Hauptscreen:**
- Wischgeste nach rechts
- Zurück-Pfeil oben links (speichert Einstellungen)

**Verhalten beim Rückwechsel (Config → Hauptscreen):**
- Einstellungen werden automatisch gespeichert (`settings.save()`)
- War das Workout beim Öffnen des Config Screens aktiv und hat sich der Plan nicht geändert: Workout wird automatisch fortgesetzt
- Hat sich der Plan geändert: Bestätigungs-Dialog „Training zurücksetzen?" erscheint

---

## Config Screen

### Navigation

Der Config Screen ist in zwei Tabs gegliedert, sichtbar in der AppBar. Beim Öffnen des Config Screens wird immer Tab 1 (WORKOUT-PLAN) angezeigt.

| Tab | Akzentfarbe (Indicator) |
|---|---|
| WORKOUT-PLAN | Orange `#FF6B00` |
| FEEDBACK | Orange `#FF6B00` |

Zwischen den Tabs kann per Tippen oder Wischgeste gewechselt werden.

### Einstellungen

**Tab WORKOUT-PLAN:**

| Einstellung | Typ | Standardwert | Beschreibung |
|---|---|---|---|
| Plan-Modus | RadioButton | `phaseBased` | Umschalten zwischen Phasen-basiert und Minuten-genau |
| Sportgerät | RadioButton | `kettlebell` | Nur im Phasen-Modus sichtbar; pro Minute im Minuten-Modus |

Der Plan-Modus wird persistiert und beim App-Start wiederhergestellt. Standard: `phaseBased`.

**Tab FEEDBACK:**

Einstellungen in folgender Reihenfolge. Eingerückte Punkte (→) sind Unteroptionen und nur sichtbar wenn der übergeordnete Toggle aktiv ist.

| Einstellung | Typ | Standardwert | Beschreibung |
|---|---|---|---|
| Lautstärke erhöhen | Toggle (bool) | `true` | Medien-Lautstärke beim Countdown und Alarm erhöhen |
| → Ziellautstärke | Slider (0–100 %) | `100 %` | Zielwert; nur gesetzt wenn aktuell niedriger |
| Warntöne (letzte 5 s) | Toggle (bool) | `true` | Kurze Tick-Töne in den letzten 5 Sekunden an/aus |
| → Countdown-Sound | Auswahl | `tick.wav` | Tippen öffnet den Sound-Auswahl-Dialog |
| Wecker-Signal | Toggle (bool) | `true` | Alarm-Ton am Intervall-Ende an/aus |
| → Sound | Auswahl | `alarm.wav` | Tippen öffnet den Sound-Auswahl-Dialog |
| Vibration | Toggle (bool) | `true` | Vibration bei Intervallwechsel an/aus |

### Sound-Auswahl-Dialog

Öffnet sich als modaler Dialog beim Tippen auf eine der Sound-Zeilen.

**Eingebaute Sounds:**

| Datei | Beschreibung |
|---|---|
| `bell.wav` | Glockenton |
| `tick.wav` | Kurzer Tick (Standard Countdown) |
| `alarm.wav` | Wecker-Beep 880 Hz, scharf |
| `alarm_low.wav` | Wecker-Beep 440 Hz, angenehmer |

**Funktionen des Dialogs:**
- Liste eingebauter + importierter Sounds; aktuell ausgewählter Eintrag hervorgehoben
- Play-Button je Eintrag zum Vorhören
- **„Aus Dateisystem wählen"**: Öffnet nativen Android-Dateiauswahl-Dialog, gefiltert auf Audiodateien. Die gewählte Datei wird als Kopie in `getApplicationDocumentsDirectory()/sounds/` gespeichert; bei Namenskollision wird ein Suffix angehängt. Die neue Datei erscheint sofort in der Liste und wird automatisch ausgewählt.
- **„Abbrechen"**: Schließt ohne Änderung
- **„Übernehmen"**: Speichert die Auswahl

### Workout-Plan bearbeiten

#### Modus 1: Phasen-basiert (Standard beim App-Start)

Jede Phase als Zeile: **Phase | Dauer (s) | Reps** mit +/−-Buttons.

| Phase | Dauer | Reps |
|---|---|---|
| Warm Up | Eingabe (min. 30 s, Schrittweite 5) | Eingabe |
| Aufbau | Eingabe (min. 30 s, Schrittweite 5) | – (automatisch interpoliert) |
| Peak | Eingabe (min. 30 s, Schrittweite 5) | Eingabe |
| Abbau | Eingabe (min. 30 s, Schrittweite 5) | – (automatisch interpoliert) |
| Cool Down | Eingabe (min. 30 s, Schrittweite 5) | Eingabe |

Standardwerte: Dauer `60` s, Warm Up `5`, Peak `15`, Cool Down `10` Reps.

#### Modus 2: Minuten-genau

30 Zeilen – je eine pro Intervall. Die Liste ist in einen äußeren `ScrollView` eingebettet (`shrinkWrap: true`, `NeverScrollableScrollPhysics`, `itemExtent: 42`).

**Selektions-Modell:** Immer nur eine Zeile ist gleichzeitig editierbar. Tippen auf eine nicht-ausgewählte Zeile selektiert sie; Tippen auf die bereits ausgewählte Zeile de-selektiert sie. Der Inhalt der Zeile wechselt zwischen kompakter Anzeige (nicht ausgewählt) und erweiterter Editier-Ansicht (ausgewählt) — ohne Animations-Übergang.

**Nicht ausgewählte Zeile** (kompakt):
```
[●] [Min X]  ···  [eq-icon 14 px]  [NR]  [Ns]
```
Werte werden als reiner Text angezeigt, keine Buttons.

**Ausgewählte Zeile** (editierbar):
```
[●] [Min X]  ···  [eq-dropdown]  R  [−][wert][+]  s  [−][wert][+]
```

- **Phasenpunkt**: Farbiger Kreis (6 px) gemäß Phase (Warm Up/Aufbau/Peak/Abbau/Cool Down)
- **Sportart-Dropdown**: Zeigt das Icon des gewählten Geräts (16 px); öffnet beim Tippen ein Popup mit Kettlebell- und Steel-Mace-Option
- **R-Stepper**: Reps, Minimalwert 1, Schrittweite 1
- **S-Stepper**: Sekunden, Minimalwert 30, Schrittweite 5

**Fußzeile (GESAMT):** Unterhalb der Liste wird live die Summe aller Reps sowie die Gesamtdauer (formatiert als `Xm XXs`) angezeigt. Wird bei jeder Änderung sofort aktualisiert.

### Persistierung

Folgende Felder werden über `shared_preferences` gespeichert und beim App-Start geladen:

| Schlüssel | Typ | Standardwert |
|---|---|---|
| `planMode` | int (index) | `0` (phaseBased) |
| `vibrationEnabled` | bool | `true` |
| `warningTonesEnabled` | bool | `true` |
| `alarmEnabled` | bool | `true` |
| `volumeBoostEnabled` | bool | `true` |
| `volumeBoostLevel` | double | `1.0` |
| `countdownSoundFile` | String | `tick.wav` |
| `alarmSoundFile` | String | `alarm.wav` |
| `equipment` | int (index) | `0` (kettlebell) |
| `warmUpReps` | int | `5` |
| `peakReps` | int | `15` |
| `coolDownReps` | int | `10` |
| `phaseDurations` | JSON `List<int>` | `[60,60,60,60,60]` |
| `customPlan` | JSON `List<int>` | Pyramiden-Defaultwerte |
| `customDurations` | JSON `List<int>` | `[60,60,...×30]` |
| `customEquipment` | JSON `List<int>` | `[0,0,...×30]` |


### Verhalten

- Jede Einstellungsänderung im Config Screen wird beim Verlassen (Wischgeste oder Zurück-Pfeil) automatisch gespeichert
- Wenn sich der Workout-Plan geändert hat und das Workout aktiv war: Bestätigungs-Dialog
- Der Config Screen öffnet bei jedem Besuch auf Tab 1 (WORKOUT-PLAN); der zuletzt gespeicherte Plan-Modus ist aktiv

---

## Trainingshistorie

### Datenmodell

Jedes gespeicherte Workout besteht aus einem `WorkoutRecord` mit einer Liste von `IntervalRecord`-Objekten (eines pro abgeschlossenem Intervall).

**`IntervalRecord`** (Felder):

| Feld | Typ | Beschreibung |
|---|---|---|
| `reps` | int | Wiederholungen dieses Intervalls |
| `durationSeconds` | int | Geplante Dauer dieses Intervalls in Sekunden |
| `equipment` | int | `0` = Kettlebell, `1` = Steel Mace |

JSON-Kurzschlüssel: `r`, `d`, `e`.

**`WorkoutRecord`** (Felder):

| Feld | Typ | Beschreibung |
|---|---|---|
| `timestamp` | int | Startzeitpunkt des Workouts in Millisekunden seit Epoch |
| `planMode` | int | `0` = phaseBased, `1` = minuteExact |
| `intervals` | `List<IntervalRecord>` | Alle abgeschlossenen Intervalle in Reihenfolge |

JSON-Kurzschlüssel: `t`, `pm`, `iv`.

Berechnete Getter (nicht gespeichert): `totalReps`, `totalDurationSeconds`, `kettlebellReps`, `steelMaceReps`.

### Speicherung

- Schlüssel in `shared_preferences`: `workoutHistory`
- Format: JSON-String, Array von `WorkoutRecord`-Objekten, neueste Einträge zuerst
- Maximale Eintragsanzahl: **300**; bei Überschreitung wird der älteste Eintrag entfernt
- Implementiert in `lib/workout_history.dart`, Klasse `WorkoutHistory` mit den statischen Methoden `load()` und `addOrUpdateRecord(record)`

### Speicherzeitpunkt

Ein Workout wird **erstmals gespeichert, wenn das zweite Intervall abgeschlossen wurde** (d.h. der Timer des zweiten Intervalls auf 0 läuft; `_completedIntervals.length >= 2`). Nach jeder weiteren Intervall-Bestätigung sowie am Ende des letzten Intervalls wird der bestehende Eintrag (identifiziert über `timestamp`) aktualisiert. Ein abgebrochenes Workout mit nur einem abgeschlossenen Intervall wird nicht gespeichert.

Der `timestamp` wird beim ersten Aufruf von `_start()` gesetzt (`_workoutStartTime ??= DateTime.now()`). Bei `_reset()` wird `_workoutStartTime` auf `null` und `_completedIntervals` auf leer zurückgesetzt.

### UI: Verlauf-Übersicht

Öffnet sich als `DraggableScrollableSheet` (Modal Bottom Sheet) beim Tippen auf `Icons.history` im Hauptscreen-Header. Die Daten werden vor dem Öffnen des Sheets geladen (`WorkoutHistory.load()` wird `await`-ed, danach erst `showModalBottomSheet` aufgerufen).

Jeder Eintrag zeigt:
```
Mi, 1. April 2026  14:22              ← DateFormat("EE, d. MMMM yyyy  HH:mm", 'de')
Kettlebell · Phasenbasiert · 18/30 Intervalle
198 Reps  ·  18m 05s  ·  12× KB  /  6× SM
```

- Datum/Uhrzeit: via `intl`-Paket, Locale `de`
- Gerät-Zusammenfassung: „Kettlebell", „Steel Mace" oder „Kettlebell + Steel Mace" (je nachdem welche `equipment`-Werte vorkommen)
- KB/SM-Aufschlüsselung in der Rep-Zeile nur wenn beide Geräte verwendet wurden
- Ist der Verlauf leer: Text „Noch keine Trainings gespeichert"

### UI: Detailansicht

Tippen auf einen Verlauf-Eintrag öffnet ein zweites `DraggableScrollableSheet` (über dem ersten) mit allen Intervallen als Liste.

Pro Intervall-Zeile:
```
[●]  Min X   [eq-icon 14px]   N Reps   ···   Xs
```
- Farbiger Phasenpunkt (6 px) gemäß `_phaseColorForMinute(index)`
- Gerät-Icon 14 px, eingefärbt `Colors.white38`
- Reps in Phasenfarbe, fett
- Dauer rechts in `Colors.white24`

Kopfzeile der Detailansicht: Datum, `X/30 Intervalle`, Gesamtreps-Aufschlüsselung und Gesamtdauer.

---

## Bekannte Einschränkungen

- iOS wird aktuell nicht unterstützt

---

## TODO

- **Trainingshistorie – Editierbarkeit**: Historische Einträge sollen nachträglich bearbeitbar sein (z.B. einzelne Intervall-Werte korrigieren).
- **Trainingshistorie – Kommentar**: Pro Workout-Eintrag soll ein freier Kommentar erfassbar und editierbar sein (z.B. Notizen zur Session).

- **Mehrere Sportarten & Icons**: Neben Kettlebell und Steel Mace sollen weitere Sportarten hinzufügbar sein, jeweils mit eigenem Icon. In einem Plan können beliebig viele Sportarten gemischt auftreten (pro Intervall wählbar).

- **Plan-Kommentare**: Einzelne Phasen oder Intervalle innerhalb eines Plans sollen mit Freitext-Kommentaren versehbar sein (z.B. Technikhinweise, Intensitätsvorgaben).

- **Kalenderplanung**: Trainingspläne sollen an konkreten Tagen im Kalender geplant werden können. Pro geplantem Trainingstag sind Ernährungshinweise für den Tag vor und den Tag nach dem Training erfassbar und anzeigbar.

- **Mehrsprachigkeit**: Die App soll mehrere Sprachen unterstützen (zunächst Deutsch und Englisch). Alle UI-Texte, Labels und Fehlermeldungen sollen über ein Lokalisierungssystem (Flutter `intl` / ARB-Dateien) verwaltet werden. Sprache folgt der Systemeinstellung des Geräts, mit manueller Override-Option in den Einstellungen.

- **Onboarding-Wizard**: Beim ersten App-Start wird ein Wizard angezeigt, der die wichtigsten Funktionen erklärt: Trainingsplan auswählen/erstellen, Workout starten, Intervall bestätigen, Trainingshistorie. Der Wizard soll überspringbar sein und jederzeit in den Einstellungen erneut aufrufbar sein.

- **Pause-Intervall**: Ein Intervall soll als "Pause" markierbar sein — kein Gerät, keine Übung, nur ein Countdown. Im Workout-Screen wird eine Pause anders dargestellt (z.B. graue Farbe, "PAUSE"-Label statt Reps-Anzeige). Im Plan-Editor ist Pause als eigene Option neben Gerät/Übung wählbar.

- **Langfristige Architektur**: Mit wachsender Datenkomplexität (Kalender, Ernährung, mehrere Sportarten) ist eine Migration der Persistenzschicht auf eine lokale SQLite-Datenbank (`drift`-Paket) zu evaluieren.

