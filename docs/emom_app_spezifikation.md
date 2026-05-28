# Kettlebell EMOM App – Spezifikation

## Übersicht

Die **Kettlebell EMOM App** ist eine Flutter-basierte Trainings-Timer-App für Android. Sie führt den Nutzer durch ein 30-minütiges EMOM-Protokoll (Every Minute On the Minute). Pro Intervall ist ein Sportgerät wählbar: **Kettlebell** (16/20/24 kg), **Steel Mace** (8/12 kg) oder **Pezziball** (ohne Gewicht / +2,5 / +5 / +7,5 / +10 kg). Bei einarmigen Kettlebell-Übungen (Swing einarmig, Snatch, Push Press) ist zusätzlich die Seite (Links/Rechts) pro Intervall konfigurierbar. Einzelne Intervalle können als **Pause** markiert werden — dann entfällt die Gerät-/Übungs-/Reps-Konfiguration; der Countdown läuft, aber keine Reps werden gezählt.

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
- **Vorschau**: Nächste Minute wird kompakt angezeigt — Gerät-Icon, Gerätebezeichnung, Übung (inkl. Seite bei einarmigen Übungen), Reps und Dauer. Bei Pause-Intervallen: `PAUSE · Xs`. Nicht angezeigt nach dem letzten Intervall.
- **Phasen-Anzeige**: Aktuelle Phase (Warm Up / Aufbau / Peak / Abbau / Cool Down) wird farblich hervorgehoben
- **Haptic Feedback**: Vibration bei Intervallwechsel (konfigurierbar)
- **Countdown-Warntöne**: In den letzten 5 Sekunden eines Intervalls erklingt jede Sekunde ein kurzer Warnton (konfigurierbar)
- **Intervall-Abschluss-Signal**: Am Ende jedes Intervalls (außer dem letzten) ertönt ein Wecker-Signal in Dauerschleife. Das nächste Intervall startet erst nach aktiver Bestätigung durch den Nutzer. Nach dem letzten Intervall wechselt die App direkt in den Abschluss-Screen ohne Alarm.
- **Pause/Resume**: Workout kann pausiert und fortgesetzt werden
- **Reset**: Workout kann jederzeit neu gestartet werden
- **Abschluss-Screen**: Zeigt Gesamtzahl der Wiederholungen nach Beendigung
- **Config Screen**: Einstellungen erreichbar über Zahnrad-Icon oben rechts oder Wischgeste nach links auf dem Hauptscreen
- **Sportgerät-Auswahl**: Kettlebell (16/20/24 kg), Steel Mace (8/12 kg) oder Pezziball (0–10 kg); beeinflusst Übungsbezeichnung in der gesamten UI
- **Übungs-Auswahl**: Kettlebell → Swing beidarmig / Swing einarmig / Snatch / Push Press; Steel Mace → 360s; Pezziball → Myotatischer Crunch
- **Seite-Auswahl**: Bei einarmigen Kettlebell-Übungen (Swing einarmig, Snatch, Push Press) ist die Seite (Links/Rechts) pro Intervall konfigurierbar
- **Pause-Intervall**: Einzelne Intervalle können als „Pause" markiert werden — kein Gerät, keine Übung, keine Reps; nur Countdown. Im Workout-Screen grau dargestellt mit „PAUSE"-Label statt Reps
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
- **Pause-Intervall-Farbe**: Grau `Colors.white24` — ersetzt die Phasenfarbe in allen Anzeigen (Phasenpunkt, Rep-Card, Fortschrittsbalken) wenn das aktive Intervall eine Pause ist
- **Pause-Toggle-Button** (Plan-Editor): Einzelner Button rechts oben in der aufgeklappten Zeile. Aktiv (Pause): blauer Hintergrund `#1565C0`, weißer fetter Text. Inaktiv: dunkler Hintergrund `#222222`, `Colors.white12`-Border, gedimmter Text `Colors.white38`. Ein-/Ausblenden des Gerät/Übung/Reps-Formulars mit `AnimatedCrossFade` (220 ms, fade + Höhenübergang simultan).
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
| State Management | Riverpod 2.x (`flutter_riverpod`, `riverpod_annotation`, Code-Generierung via `riverpod_generator`) |
| Deployment | ADB over WiFi |

### Dependencies

| Paket | Version | Zweck |
|---|---|---|
| `vibration` | ^2.0.0 | Haptisches Feedback |
| `audioplayers` | ^5.2.1 | Abspielen von Audiodateien |
| `flutter/gestures` | (built-in) | `DragStartBehavior` für sofortige Swipe-Erkennung |
| `flutter/services` | (built-in) | `SystemSound` als Fallback |
| `shared_preferences` | ^2.0.0 | Persistente Speicherung der Einstellungen |
| `flutter_riverpod` | ^2.6.1 | State Management (Provider, Notifier) |
| `riverpod_annotation` | ^2.3.5 | Annotationen für Code-Generierung |
| `flutter_launcher_icons` | ^0.14.0 | Generierung des App-Icons für alle Android-Auflösungen (dev) |
| `file_picker` | ^8.0.0 | Nativer Dateiauswahl-Dialog für den Import eigener Sounddateien |
| `path_provider` | ^2.0.0 | Zugriff auf das app-interne Dokumentenverzeichnis |
| `wakelock_plus` | ^1.0.0 | Bildschirm-Wachhalten während des Workouts |
| `volume_controller` | ^2.0.0 | Medien-Lautstärke auf den konfigurierten Zielwert erhöhen (nur wenn aktuell niedriger); wird nicht wiederhergestellt |
| `intl` | ^0.20.2 | Lokalisierte Datumsformatierung (Deutsch) für die Trainingshistorie |
| `riverpod_generator` | ^2.4.3 | Code-Generierung für Riverpod-Notifier (dev) |
| `build_runner` | ^2.4.9 | Dart-Code-Generierung (dev) |

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

Die Icons `kettlebell.png`, `steelmace.png` und `pezziball.png` (256×256, transparenter Hintergrund) sowie `icon.png` (1024×1024, dunkler Hintergrund) werden per Python-Skript programmatisch als PNG generiert. Quellskript: `docs/generate_icons.py`. Abhängigkeiten: nur Python-Stdlib (`zlib`, `struct`, `math`, `os`).

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
│   ├── main.dart                    # App-Einstieg (runApp, ProviderScope)
│   ├── app.dart                     # MaterialApp, PageView (WorkoutScreen / PlanLibraryScreen)
│   ├── core/
│   │   ├── models/
│   │   │   ├── app_page.dart        # AppPage enum: calendar(0), workout(1), plans(2)
│   │   │   ├── settings.dart        # AppSettings, Equipment/Exercise-Enums, Persistierung
│   │   │   ├── training_plan.dart   # TrainingPlan, IntervalConfig, PlanLibrary, PlanLibraryStorage
│   │   │   ├── workout_history.dart # IntervalRecord, WorkoutRecord, WorkoutHistory
│   │   │   └── calendar_entry.dart  # CalendarEntry, CalendarStorage
│   │   └── providers/
│   │       ├── plan_library_notifier.dart    # PlanLibraryNotifier (Riverpod)
│   │       ├── plan_library_notifier.g.dart  # generated
│   │       ├── settings_provider.dart        # SettingsNotifier (Riverpod)
│   │       ├── settings_provider.g.dart      # generated
│   │       ├── calendar_notifier.dart        # CalendarNotifier (Riverpod)
│   │       └── calendar_notifier.g.dart      # generated
│   └── features/
│       ├── calendar/
│       │   ├── calendar_screen.dart          # Kalender-Monatsansicht (Seite 0 im PageView)
│       │   └── widgets/
│       │       └── day_editor_sheet.dart     # Modal Bottom Sheet – Plan & Ernährung pro Tag
│       ├── config/
│       │   ├── config_screen.dart            # Einstellungsseite (zwei Tabs)
│       │   └── widgets/
│       │       ├── feedback_tab.dart         # Tab „FEEDBACK" (Töne, Vibration, Lautstärke)
│       │       └── sound_picker_dialog.dart  # Modaler Sound-Auswahl-Dialog
│       ├── history/
│       │   ├── history_notifier.dart         # HistoryNotifier (Riverpod)
│       │   ├── history_notifier.g.dart       # generated
│       │   ├── history_sheet.dart            # Modal Bottom Sheet – Verlauf-Übersicht
│       │   └── history_detail_sheet.dart     # Modal Bottom Sheet – Verlauf-Detail
│       ├── plans/
│       │   ├── plan_library_screen.dart      # Seite 1 im PageView; Plan-Liste & Navigation
│       │   ├── plan_editor_screen.dart       # Plan-Editor (Tabs: Phasenbasiert / Minuten-genau)
│       │   └── widgets/
│       │       ├── minute_exact_editor.dart  # Liste der 30 Intervall-Zeilen
│       │       └── minute_row.dart           # PlanMinuteRow (kompakt + editierbar)
│       └── workout/
│           ├── workout_notifier.dart         # WorkoutNotifier, WorkoutState (Riverpod)
│           ├── workout_notifier.g.dart       # generated
│           ├── workout_screen.dart           # Hauptscreen (Timer-UI)
│           └── widgets/
│               ├── confirmation_overlay.dart # Bestätigungs-Overlay nach Intervall-Ende
│               ├── finished_screen.dart      # Abschluss-Screen
│               ├── next_minute_preview.dart  # Vorschau nächste Minute
│               ├── overall_progress.dart     # Gesamt-Fortschrittsbalken
│               ├── plan_indicator.dart       # Phasen-Indikator
│               ├── reps_card.dart            # Große Rep-Anzeige (inkl. Pause-Darstellung)
│               ├── timer_display.dart        # Countdown-Anzeige
│               └── workout_header.dart       # Header mit Icons
├── assets/
│   ├── sounds/
│   │   ├── bell.wav
│   │   ├── tick.wav
│   │   ├── alarm.wav
│   │   └── alarm_low.wav
│   └── icon/
│       ├── icon.png           # App-Icon (1024×1024)
│       ├── kettlebell.png     # Kettlebell-Icon (256×256)
│       ├── steelmace.png      # Steel-Mace-Icon (256×256)
│       └── pezziball.png      # Pezziball-Icon (256×256)
├── docs/
│   ├── emom_app_spezifikation.md
│   ├── generate_sounds.py
│   └── generate_icons.py
├── android/
├── pubspec.yaml
└── build/app/outputs/flutter-apk/
```

---

## Datenmodell: Training

### `Equipment`-Enum (10 Varianten)

| Wert | Label | Gruppe |
|---|---|---|
| `kb16` | Kettlebell 16kg | Kettlebell |
| `kb20` | Kettlebell 20kg | Kettlebell |
| `kb24` | Kettlebell 24kg | Kettlebell |
| `sm8` | Steel Mace 8kg | Steel Mace |
| `sm12` | Steel Mace 12kg | Steel Mace |
| `pb0` | Pezziball | Pezziball |
| `pb2_5` | Pezziball + 2,5kg | Pezziball |
| `pb5` | Pezziball + 5kg | Pezziball |
| `pb7_5` | Pezziball + 7,5kg | Pezziball |
| `pb10` | Pezziball + 10kg | Pezziball |

### `Exercise`-Enum (6 Varianten)

| Wert | Label | Gültig für |
|---|---|---|
| `swingBeidarmig` | Swing beidarmig | Kettlebell |
| `swingEinarmig` | Swing einarmig | Kettlebell (einarmig) |
| `snatch` | Snatch | Kettlebell (einarmig) |
| `pushPress` | Push Press | Kettlebell (einarmig) |
| `mace360` | 360s | Steel Mace |
| `myotatischerCrunch` | Myotatischer Crunch | Pezziball |

Einarmige Übungen (`swingEinarmig`, `snatch`, `pushPress`) aktivieren die **Seite-Auswahl** (Links/Rechts) pro Intervall.

### `TrainingPlan` – Konstanten

| Konstante | Wert | Bedeutung |
|---|---|---|
| `minIntervals` | `3` | Mindestanzahl Intervalle; Löschen ist geblockt wenn nur noch 3 vorhanden |
| `maxIntervals` | `30` | Maximalanzahl Intervalle; „Intervall hinzufügen"-Button verschwindet bei 30 |

### `IntervalConfig` (Laufzeit-Modell, nicht direkt persistiert)

| Feld | Typ | Beschreibung |
|---|---|---|
| `equipment` | `Equipment` | Gewähltes Sportgerät |
| `exercise` | `Exercise` | Gewählte Übung |
| `side` | `ExerciseSide?` | Seite (nur bei einarmigen Übungen) |
| `reps` | `int` | Wiederholungen |
| `durationSeconds` | `int` | Intervalldauer in Sekunden (min. 30) |
| `isPause` | `bool` | Pause-Intervall (kein Gerät/Übung/Reps) |

JSON-Kurzschlüssel: `e` (equipment index), `x` (exercise index), `s` (side index), `r` (reps), `d` (duration), `p` (1 wenn Pause, sonst weggelassen — rückwärtskompatibel).

---

## Workout-Logik

Die Trainingslogik ist in `WorkoutNotifier` (Riverpod `@riverpod`-Annotierung, Code-generiert) implementiert. Der `WorkoutState` enthält das aktive `TrainingPlan`-Objekt mit allen 30 `IntervalConfig`-Einträgen sowie Laufzeitvariablen (aktuelle Minute, Countdown, Status).

Im **Phasen-Modus** werden Reps und Dauer pro Phase konfiguriert; Aufbau/Abbau-Reps werden linear interpoliert.

Im **Minuten-Modus** werden Reps, Dauer, Sportgerät, Übung, Seite und Pause-Flag direkt aus den 30 `IntervalConfig`-Einträgen geladen.

Ein `Timer.periodic` mit 1-Sekunden-Intervall zählt den Countdown herunter.

**Pause-Intervall-Logik:**
- `WorkoutState.currentReps`: `0` wenn `isPause`, sonst `intervals[currentMinute].reps`
- `WorkoutState.totalReps`: Summe aller nicht-Pause-Intervalle
- `workoutLabelForMinute`: gibt `'Pause'` zurück wenn `isPause`

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

Kalender, Hauptscreen und Plan-Bibliothek sind als **drei Seiten eines `PageView`** implementiert (`AppPage`-Enum: `calendar(0)`, `workout(1)`, `plans(2)`). Der initiale Start erfolgt auf Seite 1 (Workout). Config Screen und Plan-Editor verwenden `Navigator.push`.

| Aspekt | Wert |
|---|---|
| Widget | `PageView` mit `PageController` |
| Physik | `BouncingScrollPhysics(parent: PageScrollPhysics())` |
| Swipe-Erkennung | `DragStartBehavior.down` (kein Erkennungs-Delay) |
| Übergangsanimation | `animateToPage`, 380 ms, `Curves.easeInOutCubic` |
| Seite 0 | Kalender (`CalendarScreen`) |
| Seite 1 | Hauptscreen / Workout (`WorkoutScreen`) |
| Seite 2 | Plan-Bibliothek (`PlanLibraryScreen`) |

**Navigationsauslöser Hauptscreen → Kalender:**
- Wischgeste nach rechts
- Tippen auf den Kalender-Chevron links in der AppBar des Kalender-Screens (Rückrichtung)

**Navigationsauslöser Hauptscreen → Plan-Bibliothek:**
- Wischgeste nach links
- Tippen auf den Plan-Indikator (Planname) im Workout-Screen

**Navigationsauslöser Plan-Bibliothek → Hauptscreen:**
- Wischgeste nach rechts
- Zurück-Pfeil oben links (speichert Einstellungen)

**Navigationsauslöser Kalender → Hauptscreen:**
- Wischgeste nach links
- Tippen auf `Icons.chevron_right` (oben links im Kalender-Screen)

**Config Screen**: Wird über `Navigator.push` geöffnet (nicht Teil des PageView). Erreichbar über `Icons.settings` oben rechts im Workout-Header.

**Plan-Editor** (`PlanEditorScreen`): Wird von der Plan-Bibliothek über `Navigator.push` geöffnet.

**Verhalten beim Rückwechsel (Plan-Bibliothek → Hauptscreen):**
- Einstellungen werden automatisch gespeichert
- War das Workout beim Öffnen aktiv und hat sich der Plan nicht geändert: Workout wird automatisch fortgesetzt
- Hat sich der Plan geändert: Bestätigungs-Dialog „Training zurücksetzen?" erscheint

**Verhalten beim Wechsel zu Kalender und zurück:**
- Wenn das Workout aktiv war, wird es beim Öffnen des Kalenders pausiert und beim Zurückkehren automatisch fortgesetzt

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
| Sportgerät | RadioButton | `kb24` | Nur im Phasen-Modus sichtbar; pro Minute im Minuten-Modus |

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

Variable Anzahl Intervalle (**min. 3, max. 30**), je eine Zeile pro Intervall. Standard beim Anlegen eines neuen Plans: 30 Intervalle.

**Selektions-Modell:** Immer nur eine Zeile ist gleichzeitig editierbar. Tippen auf eine nicht-ausgewählte Zeile selektiert sie; Tippen auf die bereits ausgewählte Zeile de-selektiert sie. Der Inhalt der Zeile wechselt zwischen kompakter Anzeige und erweiterter Editier-Ansicht mit `AnimatedCrossFade` für das Gerät/Übung/Reps-Formular.

**Nicht ausgewählte Zeile** (kompakt, normale Übung):
```
[●] [Min X]  ···  [eq-icon 14px]  [Gerät]  [Übung]  [NR]  [Ns]
```

**Nicht ausgewählte Zeile** (kompakt, Pause):
```
[●] [Min X]  ···  PAUSE  [Ns]
```
Der Phasenpunkt ist bei Pause-Intervallen grau (`Colors.white24`) statt farbig.

**Ausgewählte Zeile** (editierbar):

Oben rechts: **Pause-Toggle-Button** — blau wenn aktiv (`#1565C0`), gedimmt wenn inaktiv. Tippen aktiviert/deaktiviert das Pause-Flag. Beim Aktivieren werden offene Picker geschlossen und die Seite zurückgesetzt.

Darunter (nur sichtbar wenn nicht Pause, animiert mit `AnimatedCrossFade` 220 ms):

- **Gerät**: Aufklappbarer Abschnitt mit Gruppen-Auswahl. Kettlebell-Chips (16/20/24 kg), Steel-Mace-Chips (8/12 kg), Pezziball-Chips (ohne/+2,5/+5/+7,5/+10 kg) — je Gruppe mit Gruppen-Icon links.
- **Übung**: Aufklappbarer Abschnitt; zeigt nur die für das gewählte Gerät gültigen Übungen als Chips.
- **Seite** *(nur bei einarmigen Übungen)*: Links/Rechts-Chips.
- **Wiederholungen**: Stepper (min. 1, Schrittweite 1).

Immer sichtbar (unabhängig von Pause):
- **Sekunden**: Stepper (min. 30, Schrittweite 5).

**Drag-to-Reorder:** Intervalle können per Drag-and-Drop umsortiert werden. Langes Gedrückthalten einer Zeile startet den Drag-Modus (`ReorderableDelayedDragStartListener`). Beim Loslassen wird die neue Reihenfolge sofort übernommen. Die Selektion (`_selectedRow`) folgt der verschobenen Zeile automatisch.

**Swipe-to-Delete:** Nach rechts swipen zeigt einen roten Hintergrund-Streifen mit Trash-Icon (`Icons.delete_outline`). Beim Loslassen wird das Intervall gelöscht — sofern danach noch mindestens 3 Intervalle verbleiben. Bei weniger als 3 verbleibenden Intervallen wird der Swipe geblockt (kein Löschen möglich).

**Bestätigungsdialog bei aktivem Plan:** Ist der bearbeitete Plan der aktuell aktive Trainingsplan, erscheint vor dem Löschen ein `AlertDialog` mit den Optionen „Abbrechen" und „Löschen" (rot). Nur nach Bestätigung wird das Intervall entfernt. Bei nicht-aktivem Plan wird direkt gelöscht.

**Intervall hinzufügen:** Unterhalb der Liste (oberhalb der Fußzeile) erscheint ein orangefarbener „Intervall hinzufügen"-Button, solange die Anzahl der Intervalle unter dem Maximum (30) liegt. Das neue Intervall ist eine Kopie des letzten vorhandenen Intervalls.

**Fußzeile (GESAMT):** Unterhalb der Liste (bzw. des Add-Buttons) wird live die Summe aller Reps (Pause-Intervalle nicht mitgezählt) sowie die Gesamtdauer (formatiert als `Xm XXs`) angezeigt.

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
| `equipment` | int (index) | `2` (kb24) |
| `warmUpReps` | int | `5` |
| `peakReps` | int | `15` |
| `coolDownReps` | int | `10` |
| `phaseDurations` | JSON `List<int>` | `[60,60,60,60,60]` |
| `customIntervals` | JSON `List<IntervalConfig>` | Pyramiden-Defaultwerte |

### Verhalten

- Jede Einstellungsänderung im Config Screen wird beim Verlassen automatisch gespeichert
- Wenn sich der Workout-Plan geändert hat und das Workout aktiv war: Bestätigungs-Dialog
- Der Config Screen öffnet bei jedem Besuch auf Tab 1 (WORKOUT-PLAN); der zuletzt gespeicherte Plan-Modus ist aktiv

---

## Kalenderplanung

### Übersicht

Der Kalender-Screen (`CalendarScreen`, Seite 0 im PageView) zeigt eine Monatsansicht. Pro Tag kann ein **Trainingsplan** sowie optionale **Ernährungsnotizen** für den Vortag und Nachtag hinterlegt werden.

### Kalender-Grid

- **Spalten**: Mo–So (7 Spalten), Wochentag-Kürzel oben
- **Navigation**: `‹` / `›`-Buttons wechseln den angezeigten Monat; Titel zeigt „Monat Jahr" (Deutsch)
- **Heute**: orange Rahmen (`#FF6B00`, 1 px) um die aktuelle Tageszelle
- **Vergangene Tage**: gedimmter Text (`Colors.white24`)
- **Eintrags-Indikator**: orangefarbener Punkt (4 px, `#FF6B00`) unterhalb der Tageszahl, wenn ein Eintrag vorhanden ist
- Tippen auf einen Tag öffnet den `DayEditorSheet`

### DayEditorSheet

Öffnet sich als Modal Bottom Sheet beim Tippen auf einen Kalendertag.

**Felder:**

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| Trainingsplan | Chip-Auswahl | Ja (Pflicht zum Speichern) | Auswahl aus allen vorhandenen Plänen der Plan-Bibliothek |
| Ernährung Vortag | Freitext (2 Zeilen) | Nein | Notizen zur Ernährung am Tag vor dem Training |
| Ernährung Nachtag | Freitext (2 Zeilen) | Nein | Notizen zur Ernährung am Tag nach dem Training |

**Buttons:**
- **Speichern**: Orangefarbener Button (aktiv wenn Plan ausgewählt, sonst gedimmt)
- **Eintrag entfernen**: Nur sichtbar wenn bereits ein Eintrag für den Tag existiert; löscht den Eintrag

### Datenmodell: `CalendarEntry`

| Feld | Typ | JSON-Schlüssel | Beschreibung |
|---|---|---|---|
| `date` | `DateTime` | `d` (ISO: `YYYY-MM-DD`) | Datum des Eintrags |
| `planId` | `String` | `p` | ID des zugeordneten Trainingsplans |
| `preNutrition` | `String` | `pre` (nur wenn nicht leer) | Ernährungsnotiz Vortag |
| `postNutrition` | `String` | `post` (nur wenn nicht leer) | Ernährungsnotiz Nachtag |

### Persistierung

- Schlüssel in `shared_preferences`: `calendarEntries`
- Format: JSON-Array von `CalendarEntry`-Objekten
- Implementiert in `lib/core/models/calendar_entry.dart` (`CalendarStorage.load()` / `CalendarStorage.save()`)
- State Management: `CalendarNotifier` (Riverpod `@Riverpod(keepAlive: true)`)

---

## Trainingshistorie

### Datenmodell

Jedes gespeicherte Workout besteht aus einem `WorkoutRecord` mit einer Liste von `IntervalRecord`-Objekten (eines pro abgeschlossenem Intervall).

**`IntervalRecord`** (Felder):

| Feld | Typ | Beschreibung |
|---|---|---|
| `reps` | int | Wiederholungen dieses Intervalls |
| `durationSeconds` | int | Geplante Dauer dieses Intervalls in Sekunden |
| `equipment` | `Equipment` | Gewähltes Sportgerät (voller 10-Varianten-Enum) |
| `exercise` | `Exercise` | Gewählte Übung (Standard: `swingBeidarmig`) |

JSON-Kurzschlüssel: `r`, `d`, `e` (Equipment-Index), `x` (Exercise-Index; weggelassen → 0 = swingBeidarmig, rückwärtskompatibel).

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
- Implementiert in `lib/core/models/workout_history.dart`, Klasse `WorkoutHistory` mit den statischen Methoden `load()` und `addOrUpdateRecord(record)`

### Speicherzeitpunkt

Ein Workout wird **erstmals gespeichert, wenn das zweite Intervall abgeschlossen wurde**. Nach jeder weiteren Intervall-Bestätigung sowie am Ende des letzten Intervalls wird der bestehende Eintrag (identifiziert über `timestamp`) aktualisiert. Ein abgebrochenes Workout mit nur einem abgeschlossenen Intervall wird nicht gespeichert.

Der `timestamp` wird beim ersten Aufruf von `_start()` gesetzt. Bei `_reset()` wird der Timestamp zurückgesetzt.

### UI: Verlauf-Übersicht

Öffnet sich als `DraggableScrollableSheet` (Modal Bottom Sheet) beim Tippen auf `Icons.history` im Hauptscreen-Header.

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
- Farbiger Phasenpunkt (6 px) gemäß `phaseColorForMinute(index)`
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

- **Benutzerdefinierte Sportarten**: Der Nutzer soll eigene Sportgeräte anlegen können (Name, zugehörige Übungen, Icon). Diese erscheinen dann im Plan-Editor gleichwertig neben den eingebauten Geräten (Kettlebell, Steel Mace, Pezziball). Technische Grundvoraussetzung: `Equipment`-Enum muss zu einem dynamischen Datenmodell migriert werden, das zur Laufzeit erweiterbar ist und via JSON persistiert wird (SharedPreferences oder Datei). Der `IntervalConfig`-Typ muss auf das neue Modell umgestellt werden.
  - **Icon-Auswahl**: Emoji-Picker als einfachste Offline-Variante (kein Netzwerk, keine Abhängigkeiten).
  - **Icon-Generierung via KI** *(offen)*: Optional könnte beim Anlegen einer neuen Sportart ein SVG-Icon automatisch per Anfrage an die Claude API generiert werden (Prompt: Gerätename → SVG-Code → gerendert via `flutter_svg`). Erfordert einen Anthropic-API-Key, den der Nutzer einmalig in den App-Einstellungen hinterlegt. Kein Free-Tier — Kosten ca. $0.001–0.002 pro Anfrage (Haiku-Modell). Noch nicht geplant.

- **Plan-Kommentare**: Einzelne Phasen oder Intervalle innerhalb eines Plans sollen mit Freitext-Kommentaren versehbar sein (z.B. Technikhinweise, Intensitätsvorgaben).

- **Kalenderplanung**: Trainingspläne sollen an konkreten Tagen im Kalender geplant werden können. Pro geplantem Trainingstag sind Ernährungshinweise für den Tag vor und den Tag nach dem Training erfassbar und anzeigbar.

- **Mehrsprachigkeit**: Die App soll mehrere Sprachen unterstützen (zunächst Deutsch und Englisch). Alle UI-Texte, Labels und Fehlermeldungen sollen über ein Lokalisierungssystem (Flutter `intl` / ARB-Dateien) verwaltet werden. Sprache folgt der Systemeinstellung des Geräts, mit manueller Override-Option in den Einstellungen.

- **Onboarding-Wizard**: Beim ersten App-Start wird ein Wizard angezeigt, der die wichtigsten Funktionen erklärt: Trainingsplan auswählen/erstellen, Workout starten, Intervall bestätigen, Trainingshistorie. Der Wizard soll überspringbar sein und jederzeit in den Einstellungen erneut aufrufbar sein.

- ~~**Pause-Intervall**: Ein Intervall soll als "Pause" markierbar sein~~ ✅ Umgesetzt: Intervalle können als Pause markiert werden (kein Gerät/Übung/Reps, nur Countdown). Im Workout-Screen grau dargestellt mit „PAUSE"-Label. Im Plan-Editor über blauen Toggle-Button oben rechts schaltbar, Ein-/Ausblenden des Formulars mit `AnimatedCrossFade`.

- **Langfristige Architektur**: Mit wachsender Datenkomplexität (Kalender, Ernährung, mehrere Sportarten) ist eine Migration der Persistenzschicht auf eine lokale SQLite-Datenbank (`drift`-Paket) zu evaluieren.

- **Garmin-Integration** *(Voraussetzung: Garmin Watch kaufen — Garmin ist einer der offensten Anbieter)*:

  Garmin-Apps werden in **Monkey C** (JS-ähnlich) über die **Connect IQ**-Plattform entwickelt (VS Code + Monkey C Extension + Connect IQ SDK + Java 8). Flutter kann nicht portiert werden, aber Flutter und Monkey C können über Bluetooth kommunizieren.

  **Kommunikations-Architektur (Flutter ↔ Uhr):**
  ```
  Flutter App (Phone)
       ↕  Platform Channel (Dart ↔ Kotlin/Java)
  Garmin Mobile SDK (nativ)
       ↕  Bluetooth
  Monkey C App (Uhr)
  ```
  Fertiger Flutter-Wrapper: `watch_connectivity_garmin` (pub.dev). Beide Richtungen funktionieren: Phone startet Training → Uhr zeigt es an; Uhr misst Herzrate → Flutter zeigt Statistiken.

  **Weg 1 – Live-Daten direkt von der Uhr (Connect IQ):** Monkey C sendet per Bluetooth an Flutter: Herzrate, HRV, GPS/Pace, Kalorien, Schritte, SpO2, Stress-Level, Schlaf (je nach Modell).

  **Weg 2 – Garmin Health API / Connect API** *(empfohlen für Trainingshistorie)*:
  ```
  Garmin Uhr → (automatische Sync) → Garmin Connect (Cloud) → (Health API) → Flutter App
  ```
  Verfügbare Daten: Aktivitäts-Zusammenfassungen, HRV, VO2max, Schlafanalyse, Body Battery, Langzeit-Trends.

  API-Zugang: Für persönliche Nutzung (OAuth mit eigenem Garmin-Account) problemlos. Für öffentliche App mit vielen Nutzern: offizielle Garmin-Partnerschaft nötig. Da die App aktuell nur für den persönlichen Einsatz gedacht ist → Weg 2 direkt zugänglich.
