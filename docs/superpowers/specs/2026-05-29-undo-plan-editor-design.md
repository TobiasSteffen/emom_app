# Design: Undo-Funktion im Plan-Editor

**Datum:** 2026-05-29
**Feature:** Undo-Stack für den Plan-Editor (`PlanEditorScreen`)

---

## Zusammenfassung

Während ein Plan bearbeitet wird, soll der Nutzer bis zu 90 Aktionen rückgängig machen können. Sobald eine Änderung vorliegt, erscheint oben rechts in der AppBar ein Undo-Icon. Ein Tap stellt den vorherigen Zustand wieder her. Redo ist nicht vorgesehen.

---

## Betroffene Dateien

| Datei | Änderung |
|---|---|
| `lib/features/plans/undo_manager.dart` | Neu erstellen |
| `lib/features/plans/plan_editor_screen.dart` | `UndoManager` integrieren, Undo-Button in AppBar |
| `lib/features/plans/widgets/minute_exact_editor.dart` | `onFieldChanged`-Callback hinzufügen |
| `lib/features/plans/widgets/minute_row.dart` | `onFieldChanged` an `IntervalEditForm` weiterleiten |

---

## Komponente: `UndoManager`

**Datei:** `lib/features/plans/undo_manager.dart`

Eine einfache Dart-Klasse (kein Widget, kein Riverpod-Provider) mit folgender Schnittstelle:

```dart
class UndoManager {
  UndoManager({this.maxSteps = 90});

  final int maxSteps;

  bool get canUndo;

  // Sofortiger Snapshot (vor delete / add / reorder)
  void push(List<IntervalConfig> intervals);

  // Debounced Snapshot (800ms nach letzter Feld-Änderung)
  // Cancelt einen laufenden Timer und startet ihn neu.
  void pushDebounced(List<IntervalConfig> intervals);

  // Stellt den letzten Snapshot wieder her; gibt ihn zurück.
  // Wirft StateError wenn Stack leer ist.
  List<IntervalConfig> undo();

  // Muss in dispose() des aufrufenden Widgets aufgerufen werden.
  void dispose();
}
```

**Interna:**
- Stack: `ListQueue<List<IntervalConfig>>` (LIFO via `addLast` / `removeLast`)
- Wenn Stack voll (`length >= maxSteps`): ältester Eintrag (`removeFirst`) wird verworfen
- Snapshots sind Tiefkopien: `intervals.map((iv) => iv.copyWith()).toList()`
- `push()` cancelt einen laufenden Debounce-Timer und pusht sofort
- `pushDebounced()` startet einen `Timer(Duration(milliseconds: 800), ...)` der bei Ablauf pushed

---

## Integration in `_PlanEditorScreenState`

### Lifecycle

```dart
late final UndoManager _undoManager;

@override
void initState() {
  super.initState();
  _plan = ...; // bisherige Logik
  _undoManager = UndoManager();
}

@override
void dispose() {
  _undoManager.dispose();
  super.dispose();
}
```

### Vor strukturellen Mutationen (sofortiger Snapshot)

```dart
void _onDelete(int index) {
  _undoManager.push(_plan.intervals);
  // ... bisherige Logik
}

void _onAdd() {
  _undoManager.push(_plan.intervals);
  // ... bisherige Logik
}

void _onReorder(int oldIndex, int newIndex) {
  _undoManager.push(_plan.intervals);
  // ... bisherige Logik
}
```

### Undo-Aktion

```dart
void _undo() {
  setState(() {
    _plan = TrainingPlan(
      id: _plan.id,
      name: _plan.name,
      intervals: _undoManager.undo(),
    );
    // Selektion zurücksetzen um inkonsistente expanded-State zu vermeiden
    _selectedRow = null;
  });
}
```

### AppBar

```dart
actions: [
  if (_undoManager.canUndo)
    IconButton(
      icon: const Icon(Icons.undo, color: Colors.white38),
      onPressed: _undo,
    ),
],
```

---

## Callback-Erweiterung für Feld-Änderungen

`IntervalEditForm` mutiert `iv`-Felder direkt in `_update(fn)`. Der Snapshot muss **vor** `setState(fn)` aufgenommen werden. Dafür bekommt `IntervalEditForm` einen optionalen `onBeforeChange`-Callback.

### `IntervalEditForm`

Neuer Parameter:
```dart
final VoidCallback? onBeforeChange;
```

`_update` in `_IntervalEditFormState`:
```dart
void _update(VoidCallback fn) {
  widget.onBeforeChange?.call(); // vor der Mutation
  setState(fn);
  widget.onChanged();
}
```

### `UndoManager.pushDebounced` — First-Push-Semantik

- Erster Aufruf im Debounce-Fenster: Snapshot wird **sofort** gepusht (pre-mutation Zustand), Cooldown-Timer startet
- Weitere Aufrufe innerhalb 800ms: nur Timer zurücksetzen, kein neuer Snapshot
- Timer-Ablauf: Cooldown-Zustand zurücksetzen (bereit für nächste Sequenz)

### `PlanMinuteExactEditor`

Neuer Parameter:
```dart
final VoidCallback onBeforeFieldChange;
```

Wird an `PlanMinuteRow` weitergereicht.

### `PlanMinuteRow`

Neuer Parameter:
```dart
final VoidCallback onBeforeFieldChange;
```

`IntervalEditForm` erhält:
```dart
IntervalEditForm(
  iv: iv,
  onBeforeChange: widget.onBeforeFieldChange,
  onChanged: widget.onChanged,
  ...
)
```

### `_PlanEditorScreenState` ruft den Editor so auf:

```dart
PlanMinuteExactEditor(
  ...
  onChanged: () => setState(() {}),
  onBeforeFieldChange: () => _undoManager.pushDebounced(_plan.intervals),
)
```

---

## Snapshot-Zeitpunkt und Debounce-Invariante

- Snapshot wird **vor** der Mutation gepusht
- Debounce: 5× Tap auf "+" → Timer wird jedes Mal zurückgesetzt → ein einziger Snapshot nach 800ms Stille (enthält Zustand vor dem ersten Tap)
- Strukturelle Änderung während laufendem Debounce-Timer: `push()` flusht den Timer sofort → zwei saubere Schritte im Stack

---

## Nicht im Scope

- Redo
- Persistenz des Undo-Stacks über Sessions
- Undo außerhalb des Plan-Editors (z.B. Plan-Bibliothek)
