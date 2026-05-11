# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Lint
flutter test             # Run tests
flutter test test/foo_test.dart  # Run single test file
flutter build apk        # Build Android release APK
flutter build apk --debug  # Build Android debug APK
dart run flutter_launcher_icons  # Regenerate app icon (after changing assets/icon/icon.png)
```

## Architecture

Single-screen Flutter app ("Kettlebell EMOM") — a 30-minute Every Minute on the Minute workout timer for kettlebell and steel mace training. UI labels are in German.

**4 source files in `lib/`:**

- `main.dart` — Entry point + `WorkoutScreen` (the full timer UI). Manages the countdown timer, audio playback (two `AudioPlayer` instances: tick sound and alarm), vibration, wakelock, and workout state machine.
- `settings.dart` — `AppSettings` data class with `load()`/`save()` via `SharedPreferences`. Contains plan-building logic: `buildPlan()` and `buildDurations()` generate the 30-element arrays consumed by the workout screen.
- `config_screen.dart` — Two-tab settings UI (Workout-Plan tab + Feedback/Sound tab). Accessed via swipe/button from the workout screen. Contains `_MinuteRow` and `_SoundPickerDialog` as private widget classes.
- `workout_history.dart` — `WorkoutRecord` / `IntervalRecord` data models + `WorkoutHistory` static class for SharedPreferences persistence (max 300 records).

**Navigation:** `PageView` with two pages — page 0 is the workout screen, page 1 is `ConfigScreen`. Swiping back from config triggers `settings.save()` and checks whether the plan changed (via `_planKey()` snapshot), prompting a reset dialog if the workout was active.

**Two plan modes (`PlanMode` enum):**
- `phaseBased` — reps computed from `warmUpReps`/`peakReps`/`coolDownReps` with linear interpolation across 5 phases (Warm Up 5min → Aufbau 10min → Peak 5min → Abbau 5min → Cool Down 5min). Duration per phase set via `phaseDurations[5]`; phase minute counts are hardcoded as `[5, 10, 5, 5, 5]`.
- `minuteExact` — each of the 30 minutes has independently configured reps, duration (min 30s, step 5s), and equipment type stored in `customPlan[30]`, `customDurations[30]`, `customEquipment[30]`.

**Two equipment types (`Equipment` enum):** `kettlebell` (exercise name "Swings") and `steelmace` (exercise name "360s"). In `minuteExact` mode each minute can have a different equipment type.

**Phase color coding** (reused in both workout screen and history detail):
- Min 0–4: `0xFF4CAF50` (green, Warm Up)
- Min 5–14: `0xFFFF6B00` (orange, Aufbau)
- Min 15–19: `0xFFFF0000` (red, Peak)
- Min 20–24: `0xFFFF6B00` (orange, Abbau)
- Min 25–29: `0xFF4CAF50` (green, Cool Down)

**Sound files:** Built-in assets in `assets/sounds/` (`bell.wav`, `tick.wav`, `alarm.wav`, `alarm_low.wav`). Users can import custom audio files; these are copied to `getApplicationDocumentsDirectory()/sounds/` and referenced by absolute path (paths starting with `/` use `DeviceFileSource`, others use `AssetSource`).

**Workout state machine** in `_WorkoutScreenState`:
- `_isRunning` / `_isFinished` / `_waitingForConfirmation` are the three main state flags
- After each minute completes: alarm plays in a loop, screen shows confirmation overlay — user taps to advance to the next minute
- History is saved after each interval advance (so partial workouts are recorded); minimum 2 intervals required

**Key non-obvious patterns:**
- `AppSettings` is mutable and mutated in-place by `ConfigScreen`. `save()` is only called when the user swipes back to the workout screen, not on every field change.
- Plan change detection uses `_planKey()` — a comma-joined string of all plan-relevant settings, snapshotted when entering config and compared on return. If it changed and the workout was active, a reset dialog is shown.
- The alarm loops by listening to `_alarmPlayer.onPlayerComplete` (stream subscription stored in `_alarmLoopSub`) and replaying after an 800ms delay, rather than using `ReleaseMode.loop`. This gives the configurable gap between repetitions.
- History records use the workout start timestamp as a unique key. Calling `addOrUpdateRecord` with the same timestamp replaces the existing entry — this is how partial workouts get updated as intervals complete.
- `ConfigScreen` receives a `visitCount` int that increments each time config is opened; `didUpdateWidget` uses this to reset the tab to 0 and clear `_selectedMinuteRow` on each fresh open.
