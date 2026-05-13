# Weitere Sportarten & Gewichte — Design

## Ziel

Erweiterung des Geräte- und Übungsmodells: von zwei hardcodierten Typen (Kettlebell / Steel Mace) auf fünf Gewichtsvarianten und fünf Übungen, wählbar pro Intervall.

## Neue Werte

**Geräte (Equipment):**
| Enum-Wert | Label | Icon |
|-----------|-------|------|
| `kb16` | KB 16kg | `assets/icon/kettlebell.png` |
| `kb20` | KB 20kg | `assets/icon/kettlebell.png` |
| `kb24` | KB 24kg | `assets/icon/kettlebell.png` |
| `sm8` | SM 8kg | `assets/icon/steelmace.png` |
| `sm12` | SM 12kg | `assets/icon/steelmace.png` |

**Übungen (Exercise):**
| Enum-Wert | Label | Gültig für |
|-----------|-------|------------|
| `swingBeidarmig` | Swing beidarmig | KB |
| `swingEinarmig` | Swing einarmig | KB |
| `snatch` | Snatch | KB |
| `pushPress` | Push Press | KB |
| `mace360` | 360s | SM |

## Datenmodell

### `lib/core/models/settings.dart`

`Equipment` enum wird auf 5 Varianten erweitert (Reihenfolge: kb16=0, kb20=1, kb24=2, sm8=3, sm12=4). Neues `Exercise` enum (swingBeidarmig=0, swingEinarmig=1, snatch=2, pushPress=3, mace360=4).

Extension `EquipmentX` auf `Equipment`:
- `bool get isKettlebell` → `index < 3`
- `String get label` → z.B. `'KB 16kg'`
- `String get iconPath` → kettlebell.png oder steelmace.png
- `Exercise get defaultExercise` → `swingBeidarmig` (KB) oder `mace360` (SM)
- `List<Exercise> get validExercises` → KB: [swingBeidarmig, swingEinarmig, snatch, pushPress]; SM: [mace360]

Extension `ExerciseX` auf `Exercise`:
- `String get label` → z.B. `'Swing beidarmig'`

### `lib/core/models/training_plan.dart`

`IntervalConfig` bekommt ein neues Pflichtfeld `Exercise exercise`.

Serialisierung: `exercise` wird als `j['x']` (int-Index) gespeichert und geladen.

Migration (rückwärtskompatibel): Fehlt `j['x']` im JSON (alter Datensatz), wird automatisch `equipment.defaultExercise` gesetzt. Fehlt auch `j['e']` als neuer Index, wird das alte Format migriert: `e == 0` (alt: Kettlebell) → `Equipment.kb24`; `e == 1` (alt: Steel Mace) → `Equipment.sm12`.

`IntervalConfig.copyWith` wird um `exercise` erweitert.

`TrainingPlan.pyramid()` (Default für neue Pläne): verwendet `Equipment.kb24` + `Exercise.swingBeidarmig`.

### `lib/core/models/workout_history.dart`

`IntervalRecord` bekommt ein neues Feld `final int exercise` (Index, 0 = swingBeidarmig usw.).

`kettlebellReps`: Bedingung ändert sich von `equipment == 0` auf `equipment < 3` (alle KB-Varianten).

`steelMaceReps`: Bedingung ändert sich von `equipment == 1` auf `equipment >= 3`.

Serialisierung: `exercise` wird als `'x'`-Key gespeichert; fehlt der Key (alte Einträge), wird 0 (`swingBeidarmig`) als Default verwendet.

## UI — Plan-Editor (MinuteRow)

`lib/features/plans/widgets/minute_row.dart`

Jede selektierte Zeile zeigt zwei tappable Chips:
1. **Gerät-Chip** — zeigt `equipment.label` (z.B. `KB 20kg`). Tap öffnet Inline-Picker darunter:
   - Zeile 1 (KB-Icon): Buttons für 16kg / 20kg / 24kg
   - Zeile 2 (SM-Icon): Buttons für 8kg / 12kg
   - Aktive Auswahl orange hervorgehoben.
   - Wechsel KB↔SM setzt `exercise` auf `newEquipment.defaultExercise` zurück.
2. **Übungs-Chip** — zeigt `exercise.label`. Tap öffnet Inline-Picker mit `equipment.validExercises` (gefiltert nach Gerätetyp).

Nur einer der beiden Picker ist gleichzeitig offen. Tap auf anderen Chip schließt den ersten.

Nicht-selektierte Zeilen zeigen Gerät und Übung weiterhin als kompakte, nicht-tappable Labels.

## UI — Workout-Screen

### `lib/features/workout/workout_notifier.dart`

- `exerciseLabelForMinute(int minute)` → gibt `exercise.label` zurück (statt Hardcode).
- Neue Methode `workoutLabelForMinute(int minute)` → gibt `'${equipment.label} · ${exercise.label}'` zurück (z.B. `'KB 20kg · Swing beidarmig'`).

### `lib/features/workout/workout_screen.dart`

`iconPath`-Berechnung: statt `== Equipment.kettlebell` → `equipment.iconPath`.

### `lib/features/workout/widgets/reps_card.dart`

Unterhalb der Reps-Zahl: statt `exerciseLabel` alleine → `workoutLabel` (`'KB 20kg · Swing beidarmig'`).

## UI — History

### `lib/features/history/history_detail_sheet.dart`

Eigene `isKb`-Prüfung (`iv.equipment == 0`) auf `iv.equipment < 3` ändern.

**Pro Intervall** (Listenzeile): zeigt zusätzlich Gewicht und Übungsname:
`[Icon] 20kg · Swing beidarmig · 18 Reps · 60s`

**Zusammenfassung** (Header-Zeile): Aufschlüsselung nach verwendeten Gewichtsvarianten:
`80× KB 24kg / 40× KB 20kg / 60× SM 12kg`
Bei nur einer Variante: `120 Reps` (wie bisher).

## Betroffene Dateien

| Datei | Art der Änderung |
|-------|-----------------|
| `lib/core/models/settings.dart` | Equipment enum erweitern, Exercise enum + Extensions neu |
| `lib/core/models/training_plan.dart` | IntervalConfig: exercise-Feld, Migration, copyWith |
| `lib/core/models/workout_history.dart` | IntervalRecord: exercise-Feld, kettlebellReps/steelMaceReps fix |
| `lib/features/plans/widgets/minute_row.dart` | Zwei Chips + Inline-Picker |
| `lib/features/workout/workout_notifier.dart` | exerciseLabelForMinute, workoutLabelForMinute |
| `lib/features/workout/workout_screen.dart` | iconPath via extension |
| `lib/features/workout/widgets/reps_card.dart` | workoutLabel statt exerciseLabel |
| `lib/features/history/history_detail_sheet.dart` | Gewicht + Übung pro Zeile, Breakdown-Summary |

## Migration bestehender Daten

| Altes Format | Neues Format |
|-------------|--------------|
| `e: 0` (Kettlebell), kein `x` | `Equipment.kb24` + `Exercise.swingBeidarmig` |
| `e: 1` (Steel Mace), kein `x` | `Equipment.sm12` + `Exercise.mace360` |

Keine Datenbankmigrierung nötig — Migration erfolgt lazy beim Laden via `fromJson`.
