# Trainingshistorie – Editierbarkeit: Design Spec
**Datum:** 2026-05-29  
**Ansatz:** Option B — Widget-Extraktion (shared `IntervalEditForm`)

---

## Ziel

Abgeschlossene Workout-Einträge in der Trainingshistorie nachträglich bearbeitbar machen. Alle Felder eines Intervalls (Gerät, Übung, Seite, Wiederholungen, Dauer, Pause-Flag) sollen editierbar sein — identisch mit dem Plan-Editor.

---

## Architektur

Das bestehende Edit-Form aus `PlanMinuteRow` wird in ein eigenständiges `IntervalEditForm`-Widget extrahiert und sowohl im Plan-Editor als auch im History-Detail-Sheet wiederverwendet. `IntervalConfig` bleibt das kanonische Edit-Modell; für History-Einträge wird `IntervalRecord` vor dem Editieren in `IntervalConfig` konvertiert und nach dem Speichern zurückkonvertiert.

---

## Abschnitt 1 — Modell: `IntervalRecord` erweitern

**Datei:** `lib/core/models/workout_history.dart`

`IntervalRecord` bekommt zwei neue Felder:
- `ExerciseSide? side` — bisher nicht gespeichert
- `bool isPause` (default: `false`)

Serialisierung rückwärtskompatibel:
- `toJson`: neue Keys `'s'` (side index oder null) und `'p'` (isPause als bool)
- `fromJson`: fehlende Keys ergeben `side = null`, `isPause = false`

**Datei:** `lib/features/workout/workout_notifier.dart`

`_onMinuteComplete` schreibt beim Abschluss eines Intervalls `side` und `isPause` aus dem zugehörigen `IntervalConfig` in den neuen `IntervalRecord`.

---

## Abschnitt 2 — Widget-Extraktion: `IntervalEditForm`

**Neue Datei:** `lib/features/shared/widgets/interval_edit_form.dart`

Extrahiert aus `PlanMinuteRow._expandedForm`. Enthält:
- Das gesamte Form-Layout (Gerät, Übung, Seite, Reps, Sekunden, Pause-Toggle)
- Alle privaten Hilfswidgets: `_stepButton`, `_pickerChip`, `_equipmentGroup`, `_stepper`, `_formRow`, `_formSectionHeader`

**Schnittstelle:**
```dart
class IntervalEditForm extends StatefulWidget {
  final IntervalConfig iv;
  final VoidCallback onChanged;
  // ...
}
```

Mutation-basiert — mutiert direkt `iv`-Felder und ruft `onChanged()` auf. Identisches Verhalten wie bisher in `PlanMinuteRow`.

**Datei:** `lib/features/plans/widgets/minute_row.dart`

`_expandedForm` wird zu:
```dart
Widget _expandedForm(IntervalConfig iv) => IntervalEditForm(
  iv: iv,
  onChanged: () => _update(() {}),
);
```

Kein Verhaltensunterschied für den Plan-Editor.

---

## Abschnitt 3 — History-Editing-UI

**Datei:** `lib/features/history/history_detail_sheet.dart`

### Conversion-Helpers (lokal in der Datei)

```dart
IntervalConfig _toConfig(IntervalRecord r) => IntervalConfig(
  equipment: r.equipment,
  exercise: r.exercise,
  reps: r.reps,
  durationSeconds: r.durationSeconds,
  side: r.side,
  isPause: r.isPause,
);

IntervalRecord _toRecord(IntervalConfig c) => IntervalRecord(
  equipment: c.equipment,
  exercise: c.exercise,
  reps: c.reps,
  durationSeconds: c.durationSeconds,
  side: c.side,
  isPause: c.isPause,
);
```

### State

`HistoryDetailSheet` wird zu einem `StatefulWidget`. State:
- `late List<IntervalConfig> _editIntervals` — mutable Kopie aller Intervalle (aus `WorkoutRecord` konvertiert)
- `int? _selectedRow` — welche Zeile gerade aufgeklappt ist
- `bool _isDirty` — ob Änderungen vorliegen (steuert Sichtbarkeit des Speichern-Buttons)

### UX

- Jede Intervall-Zeile ist tappbar → klappt das `IntervalEditForm` per `AnimatedCrossFade` auf (gleiche Logik wie `PlanMinuteRow`)
- Nur eine Zeile gleichzeitig offen
- Solange `_isDirty == false`: kein Speichern-Button sichtbar
- Sobald eine Änderung erfolgt: `_isDirty = true`, Speichern-Button erscheint am unteren Rand des Sheets
- **Speichern:** alle `_editIntervals` werden via `_toRecord` zurückkonvertiert, ein neuer `WorkoutRecord` mit identischem `timestamp` und `planMode` wird via `HistoryNotifier.updateRecord` gespeichert; Sheet schließt sich
- **Schließen ohne Speichern:** Sheet wird einfach geschlossen, keine Rückfrage, Änderungen verworfen

---

## Abschnitt 4 — `HistoryNotifier` erweitern

**Datei:** `lib/features/history/history_notifier.dart`

Neue Methode:
```dart
Future<void> updateRecord(WorkoutRecord updated) async {
  await WorkoutHistory.addOrUpdateRecord(updated);
  state = AsyncData(await WorkoutHistory.load());
}
```

`WorkoutHistory.addOrUpdateRecord` hat bereits Upsert-Semantik via `timestamp`-Key — kein weiterer Aufwand.

---

## Dateistruktur

| Datei | Änderung |
|---|---|
| `lib/core/models/workout_history.dart` | `IntervalRecord` + `side`, `isPause` |
| `lib/features/workout/workout_notifier.dart` | `side` + `isPause` beim Aufzeichnen |
| `lib/features/shared/widgets/interval_edit_form.dart` | **Neu** — extrahiertes Form-Widget |
| `lib/features/plans/widgets/minute_row.dart` | `_expandedForm` → delegiert an `IntervalEditForm` |
| `lib/features/history/history_notifier.dart` | `updateRecord()` |
| `lib/features/history/history_detail_sheet.dart` | Inline-Edit + Speichern-Button |

---

## Erfolgskriterien

- Plan-Editor verhält sich nach der Extraktion identisch wie vorher
- History-Einträge können editiert und gespeichert werden
- Bestehende History-Einträge (ohne `side`/`isPause`) laden fehlerfrei
- `flutter test` grün, `flutter analyze` 0 Fehler
- Neue Felder werden bei neuen Workouts korrekt aufgezeichnet

---

## Nicht im Scope

- Reihenfolge von History-Intervallen ändern (kein Reorder in der History)
- Intervalle in der History hinzufügen oder löschen
- Undo/Redo
