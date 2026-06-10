# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get                          # Install dependencies
flutter run                              # Run on connected device/emulator
flutter analyze                          # Lint
flutter test                             # Run all tests
flutter test test/core/models/settings_test.dart  # Run single test file
flutter build apk                        # Build Android release APK
flutter build apk --debug               # Build Android debug APK
dart run build_runner build             # Regenerate Riverpod .g.dart files (one-shot)
dart run build_runner watch             # Regenerate .g.dart files on change
dart run flutter_launcher_icons         # Regenerate app icon
```

Whenever a `@riverpod`-annotated class or function changes, regenerate the `.g.dart` file with `build_runner`.

## Architecture

Flutter app ("Kettlebell EMOM") — a 30-minute EMOM workout timer for kettlebell, steel mace, and pezziball training. UI labels are in German. State management uses **Riverpod with code generation** (`riverpod_annotation` / `riverpod_generator`). All providers are `keepAlive: true` and async.

### Structure

```
lib/
  main.dart                  # Entry point, wraps app in ProviderScope
  app.dart                   # KettlebellApp (MaterialApp, dark theme)
  core/
    models/
      app_page.dart          # AppPage enum: calendar(0), workout(1), plans(2)
      settings.dart          # AppSettings + Equipment/Exercise/ExerciseSide enums
      training_plan.dart     # TrainingPlan, IntervalConfig, PlanLibrary, PlanLibraryStorage
      workout_history.dart   # WorkoutRecord, IntervalRecord, WorkoutHistory
      calendar_entry.dart    # CalendarEntry, CalendarStorage
    providers/
      settings_provider.dart       # SettingsNotifier (loads/saves AppSettings via SharedPrefs)
      plan_library_notifier.dart   # PlanLibraryNotifier (CRUD on PlanLibrary, JSON file)
      calendar_notifier.dart       # CalendarNotifier (monthly calendar entries)
  features/
    workout/
      workout_screen.dart    # Main screen; owns PageController for 3-page navigation
      workout_notifier.dart  # WorkoutNotifier + WorkoutState (timer, audio, history saving)
      widgets/               # 8 sub-widgets: confirmation_overlay, finished_screen,
                             #   next_minute_preview, overall_progress, plan_indicator,
                             #   reps_card, timer_display, workout_header
    config/
      config_screen.dart     # 2-tab settings: plan config (phaseBased/minuteExact) + feedback/sound
      widgets/               # feedback_tab, sound_picker_dialog
    history/
      history_sheet.dart         # Bottom sheet list of past workouts
      history_detail_sheet.dart  # Per-workout interval breakdown
      history_notifier.dart      # HistoryNotifier (Riverpod)
    plans/
      plan_library_screen.dart   # List/select/delete plans (page 2 in PageView)
      plan_editor_screen.dart    # Edit intervals of a single plan
      widgets/                   # minute_exact_editor, minute_row
    calendar/
      calendar_screen.dart       # Monthly calendar grid (page 0 in PageView)
      widgets/day_editor_sheet.dart  # Assign plan + nutrition note to a day
```

### Navigation

`WorkoutScreen` owns a `PageController` with 3 pages keyed to `AppPage`:
- `AppPage.calendar` (index 0) → `CalendarScreen`
- `AppPage.workout` (index 1) → the timer UI
- `AppPage.plans` (index 2) → `PlanLibraryScreen`

`ConfigScreen` is pushed via `Navigator.push()` (not in the PageView). History is shown as a bottom sheet. Returning from config or plan library may trigger a workout reset dialog if the active plan changed (detected via `TrainingPlan.planKey`).

### Models and Persistence

| Model | Storage | Key non-obvious detail |
|---|---|---|
| `AppSettings` | `SharedPreferences` | Mutable; `save()` called explicitly on swipe-back from config, not on every field change |
| `PlanLibrary` | JSON file: `documents/plans.json` | Always has ≥1 plan; deleting the active plan is blocked |
| `WorkoutHistory` | `SharedPreferences` | Max 300 records; `addOrUpdateRecord` uses workout start timestamp as unique key — partial workouts update in place |
| `CalendarEntry` | `SharedPreferences` via `CalendarStorage` | Keyed by ISO date string |

### Equipment and Exercises

Three equipment categories (expanded from original two):
- **Kettlebell**: `kb16`, `kb20`, `kb24` — exercises: swingBeidarmig, swingEinarmig, snatch, pushPress
- **Steel Mace**: `sm8`, `sm12` — exercise: mace360
- **Pezziball**: `pb0`, `pb2_5`, `pb5`, `pb7_5`, `pb10` — exercise: myotatischerCrunch

One-arm exercises (`swingEinarmig`, `snatch`, `pushPress`) carry an optional `ExerciseSide` (left/right). Each `IntervalConfig` can also be flagged as `isPause`.

`IntervalConfig.fromJson` handles old-format migration (2-value `e` field → new `Equipment`/`Exercise` split).

### WorkoutNotifier / WorkoutState

`WorkoutNotifier` is a Riverpod notifier that owns the timer (`dart:async` `Timer`), two `AudioPlayer` instances (tick + alarm), and wakelock. Key patterns:

- Alarm loops via `_alarmPlayer.onPlayerComplete` listener + 800ms delay, not `ReleaseMode.loop`
- Volume boost on countdown (last 5s): reads current volume and raises it only if below `volumeBoostLevel`
- History saved after each interval advance and on workout finish; minimum 2 intervals required
- `reset()` re-reads `planLibraryNotifierProvider` to pick up any plan change

### Phase color coding

Used in workout screen and history detail — hardcoded by minute index:
- 0–4: `0xFF4CAF50` (green, Warm Up)
- 5–14: `0xFFFF6B00` (orange, Aufbau)
- 15–19: `0xFFFF0000` (red, Peak)
- 20–24: `0xFFFF6B00` (orange, Abbau)
- 25–29: `0xFF4CAF50` (green, Cool Down)

### Sound files

Built-in assets in `assets/sounds/` (`bell.wav`, `tick.wav`, `alarm.wav`, `alarm_low.wav`). Users can import custom audio; copied to `documents/sounds/`. Paths starting with `/` use `DeviceFileSource`; others use `AssetSource('sounds/$f')`.
