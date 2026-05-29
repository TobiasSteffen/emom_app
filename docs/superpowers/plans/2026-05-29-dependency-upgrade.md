# Dependency Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alle direkten Flutter/Dart-Abhängigkeiten auf ihre neueste stabile Version heben und alle daraus entstehenden Breaking Changes beheben.

**Architecture:** Drei Phasen in Risikoreihenfolge: (1) Audio/Volume mit direkten WorkoutNotifier-Änderungen, (2) Riverpod-Ökosystem mit Code-Regenerierung, (3) alle übrigen Pakete. Jede Phase endet mit einem sauberen Commit.

**Tech Stack:** Flutter/Dart, audioplayers 6.x, volume_controller 3.x, flutter_riverpod 3.x, riverpod_annotation 4.x, file_picker 11.x

---

## Phase 1 — audioplayers 5→6 und volume_controller 2→3

### Task 1: pubspec.yaml für Phase 1 aktualisieren

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Versionen in pubspec.yaml anpassen**

In `pubspec.yaml` die beiden Zeilen unter `dependencies` ersetzen:

```yaml
# vorher:
  audioplayers: ^5.2.1
  volume_controller: ^2.0.0

# nachher:
  audioplayers: ^6.7.0
  volume_controller: ^3.5.0
```

- [ ] **Step 2: Abhängigkeiten auflösen**

```
flutter pub get
```

Erwartet: Keine Fehlermeldung. `pubspec.lock` wird aktualisiert.

---

### Task 2: volume_controller-API in WorkoutNotifier anpassen

**Files:**
- Modify: `lib/features/workout/workout_notifier.dart:194-201`

volume_controller 3.x ersetzt den Singleton `VolumeController()` durch `VolumeController.instance`.

- [ ] **Step 1: Tests laufen lassen (Baseline rot/grün prüfen)**

```
flutter test
```

Erwartet: Aktuell laufen alle 73 Tests durch. Falls Compile-Fehler → erst Step 2.

- [ ] **Step 2: _raiseVolume in WorkoutNotifier anpassen**

`lib/features/workout/workout_notifier.dart`, Methode `_raiseVolume` (Z. 194–201):

```dart
// VORHER:
Future<void> _raiseVolume() async {
  if (!_settings.volumeBoostEnabled || _settings.volumeBoostLevel <= 0) return;
  try {
    final current = await VolumeController().getVolume();
    if (current < _settings.volumeBoostLevel) {
      VolumeController().setVolume(_settings.volumeBoostLevel, showSystemUI: false);
    }
  } catch (_) {}
}

// NACHHER:
Future<void> _raiseVolume() async {
  if (!_settings.volumeBoostEnabled || _settings.volumeBoostLevel <= 0) return;
  try {
    final current = await VolumeController.instance.getVolume();
    if (current < _settings.volumeBoostLevel) {
      VolumeController.instance.setVolume(_settings.volumeBoostLevel, showSystemUI: false);
    }
  } catch (_) {}
}
```

- [ ] **Step 3: Analyse ausführen**

```
flutter analyze
```

Erwartet: 0 Fehler. Falls weitere Fehler durch audioplayers 6.x → Step 4.

- [ ] **Step 4: audioplayers-Compile-Fehler beheben (falls vorhanden)**

audioplayers 6.x ist API-kompatibel zu 5.x für alle im Projekt genutzten Methoden:
- `AudioPlayer()` — unverändert
- `play()`, `stop()`, `dispose()` — unverändert
- `setReleaseMode(ReleaseMode.release)` — unverändert
- `onPlayerComplete` — unverändert
- `AssetSource()`, `DeviceFileSource()` — unverändert

Falls `flutter analyze` trotzdem Fehler zeigt: Fehlermeldung lesen und gezielt beheben.

- [ ] **Step 5: Tests ausführen**

```
flutter test
```

Erwartet: 73/73 grün.

- [ ] **Step 6: Commit**

```
git add pubspec.yaml pubspec.lock lib/features/workout/workout_notifier.dart
git commit -m "chore: upgrade audioplayers 5→6, volume_controller 2→3"
```

---

## Phase 2 — Riverpod-Ökosystem (flutter_riverpod 2→3, riverpod_annotation 2→4, riverpod_generator 2→4)

### Task 3: pubspec.yaml für Phase 2 aktualisieren

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Riverpod-Versionen in pubspec.yaml anpassen**

```yaml
# vorher:
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.3.5

# nachher:
  flutter_riverpod: ^3.3.1
  riverpod_annotation: ^4.0.2
```

Und unter `dev_dependencies`:

```yaml
# vorher:
  riverpod_generator: ^2.4.3

# nachher:
  riverpod_generator: ^4.0.3
```

- [ ] **Step 2: Abhängigkeiten auflösen**

```
flutter pub get
```

Erwartet: Keine Fehlermeldung.

---

### Task 4: .g.dart-Dateien neu generieren und Fehler beheben

**Files:**
- Modify: `lib/core/providers/settings_provider.g.dart`
- Modify: `lib/core/providers/plan_library_notifier.g.dart`
- Modify: `lib/core/providers/calendar_notifier.g.dart`
- Modify: `lib/features/history/history_notifier.g.dart`
- Modify: `lib/features/workout/workout_notifier.g.dart`

- [ ] **Step 1: Code neu generieren**

```
dart run build_runner build --delete-conflicting-outputs
```

Erwartet: Alle 5 `.g.dart`-Dateien werden neu geschrieben. Abschluss mit „Succeeded after ...".

- [ ] **Step 2: Analyse ausführen**

```
flutter analyze
```

Erwartet: 0 Fehler. Falls Fehler in Provider-Klassen → Step 3.

- [ ] **Step 3: Provider-Quellcode anpassen (falls Fehler)**

riverpod 3.x ist für `@Riverpod(keepAlive: true)` und `AsyncNotifier` weitgehend API-kompatibel. Typische Breaking Changes:

**a) Falls `ref.listenSelf` verwendet wird** (wird im Projekt nicht genutzt — skip):
```dart
// Entfernen — in v3 nicht mehr verfügbar
```

**b) Falls generierter `_$XNotifier`-Typ nicht mehr passt:**
Die `extends`-Anweisung in jeder Notifier-Klasse bleibt unverändert:
```dart
class SettingsNotifier extends _$SettingsNotifier { ... }
class PlanLibraryNotifier extends _$PlanLibraryNotifier { ... }
class CalendarNotifier extends _$CalendarNotifier { ... }
class WorkoutNotifier extends _$WorkoutNotifier { ... }
```
Der generierte Basistyp wird durch `build_runner` korrekt erzeugt.

**c) Falls weitere Compile-Fehler:** Fehlermeldung lesen und beheben.

- [ ] **Step 4: Tests ausführen**

```
flutter test
```

Erwartet: 73/73 grün.

- [ ] **Step 5: Commit**

```
git add pubspec.yaml pubspec.lock lib/core/providers/settings_provider.g.dart lib/core/providers/plan_library_notifier.g.dart lib/core/providers/calendar_notifier.g.dart lib/features/history/history_notifier.g.dart lib/features/workout/workout_notifier.g.dart
git commit -m "chore: upgrade flutter_riverpod 2→3, riverpod_annotation/generator 2→4, regenerate .g.dart"
```

---

## Phase 3 — Verbleibende Pakete

### Task 5: pubspec.yaml für Phase 3 aktualisieren

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Restliche Versionen in pubspec.yaml anpassen**

```yaml
# vorher:
  vibration: ^2.0.0
  file_picker: ^8.0.0
  wakelock_plus: ^1.0.0

# nachher:
  vibration: ^3.1.8
  file_picker: ^11.0.2
  wakelock_plus: ^1.6.1
```

Und unter `dev_dependencies`:

```yaml
# vorher:
  build_runner: ^2.4.9

# nachher:
  build_runner: ^2.15.0
```

- [ ] **Step 2: Abhängigkeiten auflösen**

```
flutter pub get
```

Erwartet: Keine Fehlermeldung.

---

### Task 6: Compile-Fehler aus Phase 3 beheben

**Files:**
- Modify: `lib/features/config/widgets/sound_picker_dialog.dart` (falls file_picker API geändert)
- Modify: `lib/features/workout/workout_notifier.dart` (falls wakelock_plus oder vibration API geändert)

- [ ] **Step 1: Analyse ausführen**

```
flutter analyze
```

Erwartet: 0 Fehler. Falls Fehler → Steps 2–4.

- [ ] **Step 2: file_picker-Fehler beheben (falls vorhanden)**

`lib/features/config/widgets/sound_picker_dialog.dart`, aktuelle Nutzung (Z. 54–68):

```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.audio,
  allowMultiple: false,
);
if (result == null || result.files.isEmpty) return;
final sourcePath = result.files.first.path;
if (sourcePath == null) return;
final filename = result.files.first.name;
```

`FilePicker.platform.pickFiles()` und `FileType.audio` sind in file_picker 11.x unverändert. Falls trotzdem Fehler: Fehlermeldung lesen, gezielt beheben.

- [ ] **Step 3: vibration-Fehler beheben (falls vorhanden)**

`lib/features/workout/workout_notifier.dart`, aktuelle Nutzung:

```dart
_hasVibrator = await Vibration.hasVibrator();
Vibration.vibrate(duration: 800);
Vibration.vibrate(duration: durationMs);
```

In vibration 3.x gilt: `Vibration.hasVibrator()` → `Future<bool?>` (unverändert). `Vibration.vibrate()` → unverändert. Falls Fehler: Fehlermeldung lesen.

- [ ] **Step 4: wakelock_plus-Fehler beheben (falls vorhanden)**

Aktuelle Nutzung in `workout_notifier.dart`:

```dart
WakelockPlus.enable();
WakelockPlus.disable();
```

wakelock_plus 1.6.x ist ein Minor-Bump, keine Breaking Changes erwartet.

- [ ] **Step 5: Tests ausführen**

```
flutter test
```

Erwartet: 73/73 grün.

- [ ] **Step 6: Debug-APK bauen**

```
flutter build apk --debug
```

Erwartet: BUILD SUCCESSFUL. KGP-Warnung sollte nicht mehr erscheinen (da audioplayers 6.x und volume_controller 3.x bereits KGP-kompatibel sind).

- [ ] **Step 7: Commit**

```
git add pubspec.yaml pubspec.lock lib/features/config/widgets/sound_picker_dialog.dart lib/features/workout/workout_notifier.dart
git commit -m "chore: upgrade file_picker 8→11, vibration 2→3, wakelock_plus, build_runner — all deps on latest"
```

---

## Abschluss-Checkliste

- [ ] `flutter analyze` zeigt 0 Fehler
- [ ] `flutter test` zeigt 73/73 grün
- [ ] `flutter build apk --debug` baut durch
- [ ] KGP-Warnung nicht mehr im Build-Output
- [ ] 3 Commits (einer pro Phase) in git history
