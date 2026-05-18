# Design: Drag-to-Reorder im Plan-Editor

**Datum:** 2026-05-18

## Ziel

Zeilen im Plan-Editor durch langes Drücken verschiebbar machen (Drag & Drop Reorder).

## Ansatz

Flutter's eingebautes `ReorderableListView.builder`. Long-press löst Drag aus, Drop swappt die Reihenfolge. Minimale Code-Änderung, kein Extra-Dependency.

## Architektur

### `PlanEditorScreen` (`plan_editor_screen.dart`)

- `ListView` → `Column` mit `Expanded(child: PlanMinuteExactEditor(...))` + Summary-Widget als fixer Footer
- Neuer `onReorder`-Parameter an `PlanMinuteExactEditor` übergeben
- Reorder-Logik direkt in `PlanEditorScreen._onReorder`:
  ```
  if (newIndex > oldIndex) newIndex--;
  final item = intervals.removeAt(oldIndex);
  intervals.insert(newIndex, item);
  ```
- `_selectedRow` wird beim Reorder mitgeführt:
  - War die expandierte Zeile das verschobene Item → `_selectedRow = newIndex`
  - War `_selectedRow` zwischen old und new → Index um ±1 korrigieren
  - Sonst unverändert

### `PlanMinuteExactEditor` (`minute_exact_editor.dart`)

- Neuer Parameter: `final void Function(int oldIndex, int newIndex) onReorder`
- `ListView.builder` (shrinkWrap + NeverScrollableScrollPhysics) → `ReorderableListView.builder`
- Summary-Widget (`GESAMT`-Box) wandert aus `PlanMinuteExactEditor` raus → Footer in `PlanEditorScreen`

### Phasenfarben

Keine Änderung nötig. Farben basieren auf dem Zeilen-Index — nach dem Reorder zeigt jede Minute automatisch die Farbe ihrer neuen Position (z.B. Zeile 0–4 bleibt grün).

## Nicht im Scope

- Animations-Anpassungen am Drag-Feedback
- Undo/Redo
- Einschränkung welche Zeilen verschiebbar sind
