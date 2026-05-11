# Riverpod Refactor — Design Spec

**Datum:** 2026-05-11  
**Status:** Approved  
**Ziel:** `main.dart` (~1000 Zeilen) und `config_screen.dart` (~1000 Zeilen) in eine saubere, feature-basierte Struktur mit Riverpod (code-generated) aufteilen.

---

## Kontext

Die App hat aktuell 4 Dateien, zwei davon mit ~1000 Zeilen. Die gesamte Workout-Logik (Timer, Audio, Vibration, Wakelock, State Machine) sitzt in `_WorkoutScreenState`. Config-Widgets sind private Klassen in einer einzigen Datei. Das macht Änderungen schwer lokalisierbar.

---

## Entscheidungen

| Frage | Entscheidung |
|-------|--------------|
| State Management | Riverpod mit Code-Generation (`@riverpod`) |
| Struktur | Feature-based (`features/workout/`, `features/config/`, `features/history/`) |
| Lokaler UI-State | Bleibt in `ConsumerStatefulWidget` (PageController, AnimationController, Tab-Index, etc.) |
| Navigation | PageView bleibt — kein Router nötig |

---

## Ziel-Ordnerstruktur

```
lib/
├── main.dart                              # ProviderScope + runApp, initializeDateFormatting
├── app.dart                               # KettlebellApp (MaterialApp + Theme)
│
├── core/
│   ├── models/
│   │   ├── settings.dart                  # AppSettings, PlanMode, Equipment, phaseColorForMinute()
│   │   └── workout_history.dart           # WorkoutRecord, IntervalRecord, WorkoutHistory
│   └── providers/
│       └── settings_provider.dart         # @riverpod SettingsNotifier
│
└── features/
    ├── workout/
    │   ├── workout_screen.dart             # ConsumerStatefulWidget — PageView + Komposition
    │   ├── workout_notifier.dart           # @riverpod WorkoutNotifier + WorkoutState
    │   └── widgets/
    │       ├── workout_header.dart         # "EMOM 30", Phasenlabel, History-Icon, Settings-Icon
    │       ├── overall_progress.dart       # "Minute X/30"-Zeile + Fortschrittsbalken
    │       ├── reps_card.dart              # Große Reps-Karte mit Icon + ScaleTransition
    │       ├── timer_display.dart          # Countdown-Zeit + sekündlicher Fortschrittsbalken
    │       ├── next_minute_preview.dart    # "Nächste Minute: X Reps"
    │       ├── confirmation_overlay.dart   # Zwischen-Intervall-Overlay (WEITER)
    │       └── finished_screen.dart        # "WORKOUT DONE!" Abschlussscreen
    │
    ├── config/
    │   ├── config_screen.dart              # ConsumerStatefulWidget — TabBar + TabBarView
    │   └── widgets/
    │       ├── plan_mode_selector.dart     # Phasen-basiert / Minuten-genau Toggle
    │       ├── equipment_selector.dart     # Kettlebell / Steel Mace Toggle
    │       ├── phase_based_editor.dart     # Phasen-Tabelle mit _inlineStepRow
    │       ├── minute_exact_editor.dart    # 30-Minuten-Liste + Gesamt-Footer
    │       ├── minute_row.dart             # Einzelne Zeile (war _MinuteRow)
    │       ├── feedback_tab.dart           # Lautstärke, Warntöne, Alarm, Vibration
    │       └── sound_picker_dialog.dart    # Sound-Auswahl-Dialog (war _SoundPickerDialog)
    │
    └── history/
        ├── history_notifier.dart           # @riverpod HistoryNotifier
        ├── history_sheet.dart              # DraggableScrollableSheet — Liste
        └── history_detail_sheet.dart       # DraggableScrollableSheet — Detail
```

---

## Provider-Architektur

### SettingsNotifier (`core/providers/settings_provider.dart`)

Shared zwischen Workout und Config. Lädt async aus SharedPreferences.

```dart
@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<AppSettings> build() => AppSettings.load();

  void update(AppSettings settings) => state = AsyncData(settings);
  Future<void> save() async => state.value?.save();
}
```

- `WorkoutScreen` und `ConfigScreen` lesen beide via `ref.watch(settingsNotifierProvider)`
- `ConfigScreen` schreibt via `ref.read(settingsNotifierProvider.notifier).update()`
- Beim Zurückwischen im WorkoutScreen: `notifier.save()` aufrufen

### WorkoutState (`features/workout/workout_notifier.dart`)

Unveränderlicher Snapshot — wird bei jeder Änderung neu erzeugt:

```dart
class WorkoutState {
  final List<int> plan;           // 30 Reps
  final List<int> durations;      // 30 Sekunden-Werte
  final int currentMinute;
  final int secondsLeft;
  final bool isRunning;
  final bool isFinished;
  final bool waitingForConfirmation;
  final int totalRepsDone;
  final List<IntervalRecord> completedIntervals;
  final DateTime? workoutStartTime;
}
```

### WorkoutNotifier (`features/workout/workout_notifier.dart`)

Enthält die gesamte Timer-/Audio-/Vibration-/Wakelock-Logik (aktuell in `_WorkoutScreenState`). Private Felder für Lifecycle-Objekte:

```dart
@riverpod
class WorkoutNotifier extends _$WorkoutNotifier {
  Timer? _timer;
  AudioPlayer _tickPlayer;
  AudioPlayer _alarmPlayer;
  StreamSubscription? _alarmLoopSub;
  bool? _hasVibrator;

  @override
  WorkoutState build() { ... }   // initialisiert mit Settings aus ref.read

  void start();
  void pause();
  void reset(AppSettings settings);
  void confirmInterval();
  void resetIfPlanChanged(AppSettings newSettings);  // prüft + setzt zurück, falls Plan geändert
}
```

Der `WorkoutNotifier` liest Settings via `ref.watch(settingsNotifierProvider).requireValue` im `build()` — das setzt voraus, dass `ProviderScope` Settings bereits geladen hat (der `WorkoutScreen` wartet auf `AsyncValue.when` bevor er den Notifier initialisiert). Er schreibt History intern via `ref.read(historyNotifierProvider.notifier).addOrUpdate(record)`.

Die Hilfsfunktion `Source _soundSource(String f)` (DeviceFileSource vs. AssetSource) lebt als private Methode im `WorkoutNotifier` für Tick/Alarm-Playback, und als private Methode in `_SoundPickerDialogState` für die Vorschau.

### HistoryNotifier (`features/history/history_notifier.dart`)

```dart
@riverpod
class HistoryNotifier extends _$HistoryNotifier {
  @override
  Future<List<WorkoutRecord>> build() => WorkoutHistory.load();

  Future<void> addOrUpdate(WorkoutRecord record) async {
    await WorkoutHistory.addOrUpdateRecord(record);
    ref.invalidateSelf();   // neu laden
  }
}
```

---

## Datenfluss

```
App-Start
  └── ProviderScope init
        └── settingsNotifierProvider → AppSettings.load() (async)
              └── WorkoutScreen zeigt Loading bis bereit

Settings ändern (Config)
  └── ConfigScreen: ref.read(settingsNotifier).update(newSettings)
        └── WorkoutScreen reagiert via ref.watch → zeigt neue Reps-Vorschau
              └── Beim Zurückwischen:
                    ├── notifier.save()
                    └── workoutNotifier.resetIfPlanChanged(newSettings)

Intervall abgeschlossen
  └── WorkoutNotifier._onMinuteComplete()
        └── ref.read(historyNotifier).addOrUpdate(record)
              └── historyNotifierProvider invalidiert sich → Liste aktualisiert
```

---

## Lokaler vs. Provider-State

| State | Wo |
|-------|----|
| Timer, Audio, Wakelock, Workout-State-Machine | `WorkoutNotifier` |
| AppSettings laden/speichern | `SettingsNotifier` |
| History-Liste | `HistoryNotifier` |
| `PageController`, `AnimationController` | Lokal in `WorkoutScreen` |
| Config Tab-Index, Selected-MinuteRow | Lokal in `ConfigScreen` |
| Sound-Picker Auswahl, importierte Sounds | Lokal in `SoundPickerDialog` |

---

## Neue Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.3.5

dev_dependencies:
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.9
```

Build-Befehl:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Migrationsstrategie (8 Schritte)

Jeder Schritt lässt die App compilierbar. Nach jedem Schritt: `flutter analyze`.

| Schritt | Was | Dateien |
|---------|-----|---------|
| 1 | Dependencies hinzufügen, `ProviderScope` in `main.dart` | `pubspec.yaml`, `main.dart` |
| 2 | Models nach `core/models/` verschieben, Imports anpassen | `settings.dart`, `workout_history.dart` |
| 3 | `SettingsNotifier` erstellen, Config + Workout umstellen | `settings_provider.dart` |
| 4 | `HistoryNotifier` + History-Sheets auslagern | `history_notifier.dart`, `history_sheet.dart`, `history_detail_sheet.dart` |
| 5 | `WorkoutNotifier` + `WorkoutState` erstellen (größter Schritt) | `workout_notifier.dart` |
| 6 | Workout-Widgets aufteilen | 7 Widget-Dateien in `features/workout/widgets/` |
| 7 | Config-Widgets aufteilen | 7 Widget-Dateien in `features/config/widgets/` |
| 8 | `build_runner` run, generierten Code committen, alte Dateien löschen | `*.g.dart` |

---

## Nicht im Scope

- Keine Routing-Bibliothek (GoRouter etc.) — PageView bleibt
- Keine Tests (kein bestehender Test-Coverage)
- Kein UI-Redesign — nur strukturelle Änderungen
- Kein Upgrade der anderen Dependencies (audioplayers, vibration etc.)
