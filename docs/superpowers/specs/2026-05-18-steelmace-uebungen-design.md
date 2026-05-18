# Design: Steel Mace Übungen + Wiederholung-Label

**Datum:** 2026-05-18

## Ziel

Drei unabhängige Verbesserungen am Plan-Editor und der Planübersicht:

1. Wiederholungs-Label `R` → `W` (deutsch: Wiederholung)
2. Steel Mace `mace360` bekommt Links/Rechts-Seitenauswahl
3. Neue Steel-Mace-Übung `schulterHeben` mit Links/Rechts-Auswahl

## Architektur-Entscheidungen

### isOneArm für Steel Mace

`isOneArm` steuert die Seiten-Auswahl im gesamten App (Plan-Editor + Workout-Anzeige). `mace360` ist technisch zweiarmig, hat aber eine Richtung (links/rechts). Statt einen neuen Getter `hasSide` einzuführen, wird `isOneArm` um `mace360` und `schulterHeben` erweitert. Die Logik ist identisch.

### Enum-Reihenfolge (JSON-Kompatibilität)

`schulterHeben` wird ans **Ende** des `Exercise`-Enums gehängt (nach `myotatischerCrunch`), damit bestehende gespeicherte Pläne korrekt bleiben. Die `fromJson`-Migration mappt auf Index — ein Index-Shift würde `myotatischerCrunch`-Pläne korrumpieren.

Neue Reihenfolge:
```
0: swingBeidarmig
1: swingEinarmig
2: snatch
3: pushPress
4: mace360
5: myotatischerCrunch
6: schulterHeben  ← neu
```

## Änderungen

### `lib/core/models/settings.dart`

- `Exercise`-Enum: `schulterHeben` nach `myotatischerCrunch` anhängen
- `isOneArm`: `mace360` und `schulterHeben` auf `true`
- `label` für `schulterHeben`: `"Schulterheben"`
- Steel-Mace `validExercises`: `schulterHeben` ergänzen

### `lib/features/plans/widgets/minute_row.dart`

- Zeile mit `'${iv.reps}R'` → `'${iv.reps}W'`

### `lib/features/plans/widgets/minute_exact_editor.dart`

- `'${plan.totalReps} Reps'` → `'${plan.totalReps} Wdh.'`

### `test/core/models/settings_test.dart`

- `mace360.isOneArm` → `isTrue`
- `schulterHeben.isOneArm` → `isTrue` hinzufügen
- Test-Beschreibung aktualisieren

## Nicht im Scope

- UI-Änderungen am Workout-Screen (Side-Anzeige funktioniert bereits generisch via `isOneArm`)
- Migrationslogik für alte Pläne (kein bestehender Plan hat `schulterHeben`)

## Offene TODOs / Folge-Features

- **Zeilen-Sortierung im Trainingsplan:** Gedrückt halten einer Minuten-Zeile im Plan-Editor soll diese verschiebbar machen (Drag & Drop Reorder).
