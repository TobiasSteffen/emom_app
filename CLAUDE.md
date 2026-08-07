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

`WorkoutNotifier` is a Riverpod notifier that owns the timer (`dart:async` `Timer`) and two `AudioPlayer` instances (tick + alarm). Wakelock is **not** owned here — `KettlebellApp` (`app.dart`) holds it for the whole app via `WidgetsBindingObserver`: enabled while `AppLifecycleState.resumed`, released when backgrounded, so the screen stays awake whenever the app is in the foreground. Key patterns:

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

## Garmin Watch Integration (in progress)

Connects the app to a Garmin Venu 4 via Garmin's native **Connect IQ Mobile SDK** (Android-only, no Flutter package — see `docs/superpowers/specs/2026-08-07-garmin-connect-spike-design.md` for why). Two independent codebases, connected only at runtime over Bluetooth. The Hello-World spike (open a watch app from the phone, react to its connection state) is done and verified end-to-end on real hardware; a return channel (watch → phone App Messages, for live "is it actually running" state) is the planned next iteration.

1. **Phone side** (this Flutter/Android app):
   - `android/app/src/main/kotlin/com/example/emom_app/GarminBridge.kt` — wraps `com.garmin.android.connectiq.ConnectIQ` (Gradle dep `com.garmin.connectiq:ciq-companion-app-sdk`, Maven Central), exposes `isWatchConnected()` / `openWatchApp()`.
   - `MainActivity.kt` registers a `MethodChannel("com.example.emom_app/garmin")` for the bridge.
   - `lib/core/services/garmin_service.dart` — Dart wrapper around the channel; also owns the `garminHasEverConnected` SharedPreferences flag (set once a connection ever succeeds, never reset — separate from `AppSettings` because it must persist immediately, not on the config screen's save-on-navigate-back cycle).
   - `lib/features/config/garmin_notifier.dart` — `@riverpod` `GarminNotifier` (provider name `garminProvider`, codegen strips the `Notifier` suffix), state `GarminConnectionStatus { connected, everConnected }`.
   - `lib/features/workout/widgets/garmin_header_icon.dart` — traffic-light-colored watch icon in the workout header (grey = never connected, red = not connected now, green = connected); tap on grey navigates to Settings via `WorkoutHeader`'s existing `onSettings` callback (never a separate `Navigator.push`, or it skips `_openConfig()`'s post-return settings sync in `workout_screen.dart`); tap on red/green calls `openWatchApp()`.
   - `AppSettings.garminHeaderIconVisible` — toggle in `ConfigScreen`'s "GARMIN-UHR" section; icon is hidden by default.
   - No live polling: `garminProvider` is `keepAlive` like every provider here, so the icon only re-checks on first build or after a tap — see the design spec's "Fehlerbehandlung / Risiken" for the accepted trade-off.
   - **Bluetooth runtime permissions (Android 12+/API 31+):** `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN` are declared in `AndroidManifest.xml` (Task 4) but that alone does nothing on API 31+ — they must also be requested at runtime, or the Connect IQ SDK's device discovery silently finds nothing (no exception, no log, just an empty device list). `GarminService._ensureBluetoothPermissions()` (via the `permission_handler` package) requests both before every `isWatchConnected()`/`openWatchApp()` call. Found by hard evidence during on-device debugging: `adb shell dumpsys package com.example.emom_app | grep -A2 BLUETOOTH` showed `granted=false` for both despite the manifest entries. Requesting this permission needed `compileSdk = 37` in `android/app/build.gradle.kts` (explicitly overriding `flutter.compileSdkVersion`, which resolves lower) — `permission_handler_android` requires it, build otherwise fails with "Could not determine the dependencies of task `:permission_handler_android:generateDebugRFile`".
   - **`ConnectIQ.initialize()` must only be called once, ever.** The naive approach — calling `connectIQ.initialize(context, true, listener)` fresh inside both `isWatchConnected()` and `openWatchApp()` — works for the first call but the second call's `initialize()` never invokes its listener at all (no `onSdkReady`, no `onInitializeError`, no exception; it just hangs forever). `GarminBridge.ensureSdkReady()` fixes this: it tracks `sdkReady`/`initializing` state and calls `connectIQ.initialize()` at most once, queuing callbacks (`pendingCallbacks`) for any calls that arrive while initialization is in flight, and serving already-ready calls immediately without touching `initialize()` again. Confirmed by on-device logcat: `isWatchConnected()` (the first call) got its `onSdkReady` callback fine; the very next `openWatchApp()` call hung indefinitely at `connectIQ.initialize()` until this fix.
   - Real device connectivity to a paired-but-idle watch can also be eventually-consistent: `connectedDevices` returned an empty list immediately after the very first `onSdkReady()` even though Garmin Connect Mobile already showed the watch as connected, then correctly populated a few seconds later. Not specifically worked around (the retry inherent in tapping the header icon again was enough) — worth remembering if `connectedDevices` looks emptier than expected right after app start.

2. **Watch side** — `garmin_watch_app/`, a **separate Connect IQ (Monkey C) project**, not part of the Flutter/Gradle build at all. Entry classes are named after the folder (VS Code's project wizard names them after the project, not after what you type as "class name"): `garmin_watch_appApp` / `garmin_watch_appView` / `garmin_watch_appDelegate`, in `garmin_watch_app/source/`. `manifest.xml` Application-ID `ddb356dd-6f3c-4f7a-bb62-3664460edba8` (must match the constant in `GarminBridge.kt`). Target device: `venu445mm` (Venu 4, 45mm — Connect IQ's internal product ID, not "venu4").

   **Building/running `garmin_watch_app/` via VS Code's GUI ("Monkey C: Run") does not work in this repo** — fails with "Connect IQ project not found. Be sure your project has a jungle file and the project's Jungle Files setting is correct." Root cause: the open VS Code workspace is the Flutter repo root, not `garmin_watch_app/` itself, and no `.vscode/settings.json` with `monkeyC.jungleFiles` has been set up to bridge that. **Use the SDK's CLI tools directly instead** — reliable, and is how this was actually built and verified working end-to-end:

   ```bash
   # Java is required but not on PATH by default; Android Studio bundles one:
   export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"

   SDK="$HOME/AppData/Roaming/Garmin/ConnectIQ/Sdks/<installed-version>/bin"   # find exact folder name under Sdks/
   KEY="$HOME/AppData/Roaming/Garmin/ConnectIQ/developer_key.der"             # generate once, see below — NEVER commit this

   # One-time: generate a developer signing key (must be RSA 4096-bit, 2048 fails with "Signature check failed")
   openssl genpkey -algorithm RSA -out developer_key.pem -outform PEM -pkeyopt rsa_keygen_bits:4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt

   # Build (run from garmin_watch_app/)
   "$SDK/monkeyc.bat" -f monkey.jungle -d venu445mm -o bin/garmin_watch_app.prg -y "$KEY" -w

   # Run in the simulator: start the simulator GUI first, THEN push the build to it
   #   (PowerShell) Start-Process "$SDK\simulator.exe"
   "$SDK/monkeydo.bat" bin/garmin_watch_app.prg venu445mm
   ```

   `garmin_watch_app/bin/` (build output) is gitignored — never commit `.prg` files or the developer key.

   **Sideloading to the real watch:** the Venu 4 connects via MTP (no drive letter on Windows, no Mass Storage USB mode available on this model) — copy the built `.prg` into `GARMIN\Apps\` on the device manually via File Explorer; cannot be scripted from the CLI/an agent.

Full task-by-task history: `docs/superpowers/plans/2026-08-07-garmin-connect-spike.md`. Design rationale: `docs/superpowers/specs/2026-08-07-garmin-connect-spike-design.md`.
