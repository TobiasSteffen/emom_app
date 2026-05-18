# Design: Variable Intervalllänge im Plan-Editor

**Datum:** 2026-05-18

## Ziel

Zeilen im Plan-Editor per Rechts-Wischen löschen; neue Zeile per "+" hinzufügen. Pläne können 5–30 Intervalle haben statt genau 30.

## Constraints

- Minimum: 5 Intervalle
- Maximum: 30 Intervalle
- Neues Intervall: Kopie des letzten Intervalls

## Architektur

### `lib/core/models/training_plan.dart`

- `assert(intervals.length == 30)` entfernen
- Konstanten hinzufügen: `static const int minIntervals = 5` und `static const int maxIntervals = 30`
- `_pyramidReps()` und `TrainingPlan.pyramid()` bleiben unverändert (erzeugen weiterhin 30-Intervalle-Plan als Default)

### `lib/features/plans/widgets/minute_exact_editor.dart`

- `itemCount: plan.intervals.length` statt `itemCount: 30`
- Neuer Pflicht-Parameter: `final void Function(int index) onDelete`
- Jedes Item in `Dismissible` wrappen:
  - `direction: DismissDirection.startToEnd` (rechts wischen)
  - Roter Hintergrund mit Mülleimer-Icon links
  - `confirmDismiss`: gibt `false` zurück wenn `plan.intervals.length <= TrainingPlan.minIntervals` (Wischen blockiert)
  - `onDismissed`: ruft `onDelete(i)` auf

### `lib/features/plans/plan_editor_screen.dart`

- `_onDelete(int index)`: entfernt `_plan.intervals[index]`, prüft `>= minIntervals`
- `_onAdd()`: kopiert letztes Intervall via `copyWith()`, fügt ans Ende an, prüft `<= maxIntervals`
- "+" Button: erscheint zwischen Liste und GESAMT-Box, sichtbar nur wenn `intervals.length < maxIntervals`; gleicher visueller Stil wie "Neuer Plan" Button in `PlanLibraryScreen` (orange Border, `Icons.add`)

### Workout-Kompatibilität

`WorkoutNotifier` iteriert über `plan.intervals` ohne feste 30er-Annahme — keine Änderung nötig. Phasenfarben basieren auf Minute-Index und funktionieren weiterhin korrekt.

### Tests

- `training_plan.dart`: Konstanten `minIntervals = 5`, `maxIntervals = 30` vorhanden
- `plan_editor_screen` (Logik): Delete entfernt korrekte Zeile; Add kopiert letztes Intervall; min/max-Grenzen werden eingehalten

## Nicht im Scope

- Änderungen am Workout-Screen
- Änderungen an History oder Calendar
- Undo/Redo für Delete
