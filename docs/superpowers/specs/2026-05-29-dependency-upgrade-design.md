# Dependency Upgrade — Design Spec
**Datum:** 2026-05-29  
**Scope:** Alle direkten Flutter/Dart-Abhängigkeiten auf ihre jeweils neueste stabile Version heben

---

## Ziel

Alle in `pubspec.yaml` deklarierten Pakete auf die neueste stabile Version aktualisieren, inklusive Major-Version-Bumps. Transitive Abhängigkeiten folgen automatisch. Die KGP-Warnung (Kotlin Gradle Plugin) soll damit beseitigt werden.

---

## Upgrade-Scope

| Paket | Von | Nach | Risiko |
|---|---|---|---|
| `audioplayers` | 5.2.1 | 6.7.0 | Hoch — direkte API-Nutzung in `WorkoutNotifier` |
| `volume_controller` | 2.0.8 | 3.5.0 | Hoch — `_volumeBoost` in `WorkoutNotifier` |
| `flutter_riverpod` | 2.6.1 | 3.3.1 | Mittel — alle Provider-Klassen |
| `riverpod_annotation` | 2.6.1 | 4.0.2 | Mittel — alle `@riverpod`-Annotationen |
| `riverpod_generator` | 2.6.5 | 4.0.3 | Mittel — Codegen, alle `.g.dart` |
| `file_picker` | 8.3.7 | 11.0.2 | Niedrig–Mittel |
| `vibration` | 2.1.0 | 3.1.8 | Niedrig |
| `wakelock_plus` | 1.5.2 | 1.6.1 | Niedrig (Minor-Bump) |
| `build_runner` | 2.5.4 | 2.15.0 | Niedrig |

**Nicht enthalten:** `file_picker` 12.x (noch Beta), `intl`, `path_provider`, `shared_preferences`, `cupertino_icons` (kein Major-Bump nötig).

---

## Phasen

### Phase 1 — Audio & Volume (WorkoutNotifier-kritisch)

Pakete: `audioplayers` 5→6, `volume_controller` 2→3

Betroffene Datei: `lib/features/workout/workout_notifier.dart`

Bekannte Breaking-Change-Risiken:
- `AudioPlayer.onPlayerComplete` — Event-Stream-API könnte sich geändert haben
- Playback-Methoden (`play`, `setSource`, `setReleaseMode`)
- `volume_controller` — Getter/Setter-API für Lautstärke

Vorgehen: pubspec.yaml anpassen → `flutter pub get` → Compile-Fehler beheben → `flutter analyze` → `flutter test` → commit

### Phase 2 — Riverpod-Ökosystem

Pakete: `flutter_riverpod` 2→3, `riverpod_annotation` 2→4, `riverpod_generator` 2→4

Betroffene Dateien: alle `*.dart`-Dateien mit `@riverpod`-Annotationen und alle `*.g.dart`

Bekannte Breaking-Change-Risiken:
- Provider-Syntax und `keepAlive`-Handling könnten sich geändert haben
- Alle `.g.dart`-Dateien müssen mit `dart run build_runner build` neu generiert werden
- `AsyncNotifier`/`Notifier`-Basisklassen könnten umbenannt sein

Vorgehen: pubspec.yaml anpassen → `flutter pub get` → `dart run build_runner build` → Compile-Fehler beheben → `flutter analyze` → `flutter test` → commit

### Phase 3 — Restliche Pakete

Pakete: `file_picker` 8→11, `vibration` 2→3, `wakelock_plus` 1.5→1.6, `build_runner` 2→2.15

Betroffene Dateien: `config_screen.dart` (file_picker), `workout_notifier.dart` (wakelock_plus)

Vorgehen: pubspec.yaml anpassen → `flutter pub get` → Compile-Fehler beheben → `flutter analyze` → `flutter test` → commit

---

## Erfolgskriterien

- `flutter analyze` zeigt 0 Fehler nach jeder Phase
- `flutter test` (73 Tests) laufen grün nach jeder Phase
- `flutter build apk --debug` baut ohne Fehler nach Phase 3
- KGP-Warnung ist nach Phase 1 nicht mehr im Build-Output

---

## Nicht im Scope

- Neue Features oder API-Nutzung der neuen Paketversionen
- Migration auf `file_picker` 12.x (Beta)
- SQLite-Migration oder andere Architekturänderungen
