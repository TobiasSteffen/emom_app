# Trainingsplan-Verwaltung — Design

**Datum:** 2026-05-12
**Status:** Bereit zur Implementierung

---

## Überblick

Der phasenbasierte Plan-Modus wird entfernt. An seine Stelle tritt eine vollständige Trainingsplan-Verwaltung: Nutzer können mehrere benannte Minuten-genaue Pläne anlegen, bearbeiten, umbenennen und löschen. Der aktive Plan wird auf dem Hauptscreen angezeigt und ist per Tippen direkt erreichbar.

---

## Datenmodell

### `IntervalConfig`

Ein einzelnes Intervall innerhalb eines Plans.

```dart
class IntervalConfig {
  int reps;
  int durationSeconds;  // min. 30, Schrittweite 5
  Equipment equipment;  // kettlebell | steelmace
}
```

JSON-Kurzschlüssel: `r`, `d`, `e` (analog zu IntervalRecord).

### `TrainingPlan`

```dart
class TrainingPlan {
  String id;                      // UUID, unveränderlich
  String name;                    // z.B. "Pyramide", "Plan 2"
  List<IntervalConfig> intervals; // immer genau 30 Einträge
}
```

Getter: `totalReps`, `totalDurationSeconds` (berechnet, nicht gespeichert), `planKey` (komma-separierter String aller Reps+Dauern+Equipment-Werte, für Änderungs-Erkennung).

### `PlanLibrary`

```dart
class PlanLibrary {
  List<TrainingPlan> plans;
  String activePlanId;
}
```

Getter: `activePlan` → `plans.firstWhere((p) => p.id == activePlanId)`.

### `PlanLibraryStorage` (statisch, in `training_plan.dart`)

- `load()` → liest `{appDocDir}/plans.json`; legt Default an falls Datei fehlt
- `save(PlanLibrary)` → schreibt `{appDocDir}/plans.json`

**Default beim ersten Start:** Ein Plan „Standard" mit Pyramiden-Defaultwerten (Reps: `[5,5,5,5,5, 6,7,...,10,10,10,10,10]`, alle Dauern 60s, alle Geräte Kettlebell).

---

## Migration

Beim ersten Start nach dem Update existiert `plans.json` noch nicht → `load()` legt den Default-Plan „Standard" an. Alte SharedPreferences-Felder (`planMode`, `customPlan`, `customDurations`, `customEquipment`, `warmUpReps`, `peakReps`, `coolDownReps`, `phaseDurations`, `equipment`) werden nicht mehr gelesen oder geschrieben — sie verbleiben ungenutzt in SharedPreferences und werden stillschweigend ignoriert.

---

## Riverpod-Architektur

### `PlanLibraryNotifier`

```dart
@Riverpod(keepAlive: true)
class PlanLibraryNotifier extends _$PlanLibraryNotifier {
  @override
  Future<PlanLibrary> build() => PlanLibraryStorage.load();

  Future<void> setActivePlan(String id) { ... }
  Future<void> addPlan(TrainingPlan plan) { ... }
  Future<void> updatePlan(TrainingPlan plan) { ... }
  Future<void> deletePlan(String id) { ... }  // wirft wenn aktiver oder einziger Plan
  Future<void> renamePlan(String id, String name) { ... }
}
```

`keepAlive: true` — analog zu `SettingsNotifier`, da global benötigter Zustand.

### `WorkoutNotifier`

Liest den aktiven Plan via `ref.read(planLibraryNotifierProvider.future)` in `build()` (nicht `watch`, damit Plan-Wechsel das laufende Workout nicht automatisch resettet). Plan-Wechsel werden explizit via `notifier.updateSettings(newPlan)` propagiert — analog zur bestehenden Settings-Logik.

### `AppSettings` / `SettingsNotifier`

Verlieren alle Plan-Felder. `SettingsNotifier` und `AppSettings` bleiben strukturell identisch, nur schlanker.

---

## Screens & Navigation

### Plan-Indikator auf `WorkoutScreen`

- Position: unterhalb von `OverallProgress` (Minuten-/Reps-Fortschrittsanzeige)
- Aussehen: dezentes Pill-Label mit Plan-Name, niedrige Opazität (passend zum bestehenden Stil)
- Tippen → `Navigator.push` zu `PlanLibraryScreen`
- Bei Rückkehr: prüfen ob aktiver Plan geändert wurde → Reset-Dialog wenn Workout aktiv war. Erkennungs-Logik: Snapshot des aktiven Plans (`planKey`-Getter, s.u.) beim Öffnen von `PlanLibraryScreen`, Vergleich beim Zurückkehren. Erkennt sowohl Plan-Wechsel (andere ID) als auch Inhaltsänderungen am aktiven Plan.

Neues Widget: `lib/features/workout/widgets/plan_indicator.dart`

### `PlanLibraryScreen`

`lib/features/plans/plan_library_screen.dart` — `ConsumerWidget`

**AppBar:** „TRAININGSPLÄNE", Zurück-Pfeil

**Inhalt:**
- `+ Neuer Plan`-Button oben
- Scrollbare Liste aller Pläne:
  ```
  [●] Pyramide                          ›
      30 Intervalle · 30m 00s
  ```
  - Farbiger Punkt (orange `#FF6B00`) = aktiver Plan; grau = inaktiv
  - Tippen → aktiviert Plan + `Navigator.push` zu `PlanEditorScreen`
  - Langer Druck → Umbenennen-Dialog (TextField, bestehender Name vorausgefüllt)
  - Swipe nach links → Löschen mit Bestätigungs-Dialog
    - Blockiert wenn Plan aktiv ist
    - Blockiert wenn es der einzige Plan ist

**Neuer Plan:**
- Eingabe-Dialog für Plan-Name (Standardname: „Plan N", fortlaufend)
- Plan wird mit Pyramiden-Defaultwerten vorbelegt
- Nach Anlegen: sofort in `PlanEditorScreen` navigieren

### `PlanEditorScreen`

`lib/features/plans/plan_editor_screen.dart` — `ConsumerStatefulWidget`

**AppBar:** Plan-Name als Titel, Zurück-Pfeil speichert Änderungen

**Body:** Bestehender `MinuteExactEditor`, adaptiert für `TrainingPlan` statt `AppSettings`

Änderungen werden beim Verlassen (Zurück) via `planLibraryNotifierProvider.notifier.updatePlan(...)` gespeichert. Kein separater Speichern-Button.

### `ConfigScreen`

TabBar entfällt. Wird zu einem einfachen `ListView` mit nur noch dem Feedback-/Sound-Inhalt (bisher Tab 2). AppBar-Titel bleibt „EINSTELLUNGEN".

---

## Geänderte / gelöschte Dateien

| Datei | Aktion |
|---|---|
| `lib/core/models/training_plan.dart` | NEU — `IntervalConfig`, `TrainingPlan`, `PlanLibrary`, `PlanLibraryStorage` |
| `lib/core/models/settings.dart` | ÄND — alle Plan-Felder entfernt |
| `lib/core/providers/plan_library_notifier.dart` | NEU — `PlanLibraryNotifier` + `.g.dart` |
| `lib/features/plans/plan_library_screen.dart` | NEU |
| `lib/features/plans/plan_editor_screen.dart` | NEU |
| `lib/features/workout/widgets/plan_indicator.dart` | NEU |
| `lib/features/workout/workout_screen.dart` | ÄND — Plan-Indikator, Rückkehr-Logik |
| `lib/features/workout/workout_notifier.dart` | ÄND — liest `PlanLibraryNotifier` |
| `lib/features/config/config_screen.dart` | ÄND — kein TabBar, nur Feedback |
| `lib/features/plans/widgets/minute_row.dart` | VERSCHOBEN + ÄND — `IntervalConfig` statt `AppSettings` |
| `lib/features/plans/widgets/minute_exact_editor.dart` | VERSCHOBEN + ÄND — `TrainingPlan` statt `AppSettings` |
| `lib/features/config/widgets/phase_based_editor.dart` | DEL |
| `lib/features/config/widgets/plan_mode_selector.dart` | DEL |
| `lib/features/config/widgets/equipment_selector.dart` | DEL |

---

## Offene Punkte (nicht in diesem Scope)

- Mehrere Sportarten / weitere Icons (→ `IntervalConfig.equipment` ist heute ein Enum, kann später erweitert werden)
- Kommentare pro Intervall (→ `IntervalConfig` einfach um `String? comment` erweiterbar)
- Kalenderplanung & Ernährungshinweise (eigenes Feature, evtl. SQLite/drift)
