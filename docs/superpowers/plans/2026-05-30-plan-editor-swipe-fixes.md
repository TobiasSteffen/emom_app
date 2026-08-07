# Plan Editor Swipe Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two swipe UX issues in the plan editor: enable smooth swipe-back to close `PlanEditorScreen`, and move the delete gesture from right-swipe to left-swipe on interval rows.

**Architecture:** Two independent fixes. (1) `PlanEditorScreen.PopScope` wechselt von `canPop: false` + manuelles Pop zu `canPop: true` + fire-and-forget save — das erlaubt native Predictive-Back-Animation. (2) `SwipeToRevealRow` invertiert die Swipe-Richtung: negativer dx (Links-Wischen) öffnet, Delete-Button erscheint rechts, Zeile schiebt sich nach links.

**Tech Stack:** Flutter, Dart, Riverpod (keepAlive: true Provider für fire-and-forget save), GestureDetector horizontal drag, AnimationController

---

## Betroffene Dateien

| Datei | Änderung |
|---|---|
| `lib/features/plans/plan_editor_screen.dart` | PopScope canPop: true, AppBar-Button vereinfacht |
| `lib/features/shared/widgets/swipe_to_reveal_row.dart` | Swipe-Richtung invertiert, Delete-Button rechts |

---

### Task 1: PlanEditorScreen — Smooth Swipe-Back

**Files:**
- Modify: `lib/features/plans/plan_editor_screen.dart`

Aktuell hat `PlanEditorScreen` `PopScope(canPop: false)` mit einem async `onPopInvokedWithResult`-Handler, der `await _save()` aufruft und dann manuell `Navigator.pop()` auslöst. Das unterbricht die Android Predictive-Back-Animation (die Route-Peek-Animation springt zurück, dann startet eine neue Pop-Animation). Außerdem ruft der AppBar-Back-Button `_save()` + `Navigator.pop()` auf — die Save-Logik ist doppelt.

Fix: `canPop: true` erlaubt der nativen Animation ungehindert zu laufen. `onPopInvokedWithResult(didPop: true)` speichert fire-and-forget — das ist sicher, weil `planLibraryProvider` `keepAlive: true` hat und der Notifier nach Widget-Dispose weiterlebt. Der AppBar-Button ruft nur noch `Navigator.pop()` auf.

- [ ] **Step 1: PopScope und AppBar-Button in `plan_editor_screen.dart` anpassen**

  Ersetze in `lib/features/plans/plan_editor_screen.dart` den `build`-Methodenrumpf ab `return PopScope(`:

  ```dart
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _save(); // fire-and-forget — planLibraryProvider ist keepAlive
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white38),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _plan.name.toUpperCase(),
            style: const TextStyle(
                fontSize: 15, letterSpacing: 4, color: Colors.white38),
          ),
          actions: [
            if (_undoManager.canUndo)
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white38),
                onPressed: _undo,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: PlanMinuteExactEditor(
                plan: _plan,
                selectedRow: _selectedRow,
                onRowSelected: (i) => setState(() => _selectedRow = i),
                onChanged: () => setState(() {}),
                onBeforeFieldChange: () =>
                    _undoManager.pushDebounced(_plan.intervals),
                onReorder: _onReorder,
                onDelete: _onDelete,
                onConfirmDelete: _confirmDelete,
              ),
            ),
            if (_plan.intervals.length < TrainingPlan.maxIntervals)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: GestureDetector(
                  onTap: _onAdd,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: Color(0xFFFF6B00), size: 16),
                        SizedBox(width: 6),
                        Text('Intervall hinzufügen',
                            style: TextStyle(
                                color: Color(0xFFFF6B00),
                                fontSize: 13,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GESAMT',
                        style: TextStyle(
                            fontSize: 10, letterSpacing: 3, color: Colors.white24)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${_plan.totalReps} Wdh.',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white38)),
                        Text(_formatDuration(_plan.totalDurationSeconds),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white24)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  ```

- [ ] **Step 2: Analysieren**

  ```
  flutter analyze lib/features/plans/plan_editor_screen.dart
  ```

  Erwartet: `No issues found!`

- [ ] **Step 3: Commit**

  ```
  git add lib/features/plans/plan_editor_screen.dart
  git commit -m "fix: smooth swipe-back in PlanEditorScreen via canPop: true + fire-and-forget save"
  ```

---

### Task 2: SwipeToRevealRow — Delete auf Links-Swipe

**Files:**
- Modify: `lib/features/shared/widgets/swipe_to_reveal_row.dart`

Aktuell reagiert `SwipeToRevealRow` auf positiven `dx` (Rechts-Wischen): `_ctrl.value + d.delta.dx / _revealWidth`. Der Delete-Button erscheint links (`Positioned(left: 0)`), die Zeile verschiebt sich nach rechts (`Offset(offset, 0)` mit positivem offset).

Neu: negativer `dx` (Links-Wischen) öffnet die Reveal-Animation. Die Formel wird `_ctrl.value - d.delta.dx / _revealWidth` (negativer delta → positiver Beitrag → ctrl steigt). Der Delete-Button erscheint rechts (`Positioned(right: 0)`), die Zeile verschiebt sich nach links (`Offset(-offset, 0)` mit negativem offset).

Zusätzlich: Guard in `_onDragUpdate` — wenn `_ctrl.value <= 0` und `d.delta.dx > 0` (Rechts-Wischen bei geschlossener Zeile), ignorieren. Das verhindert, dass ein Rechts-Wischen die Zeile leicht nach rechts driftet bevor sie aufhört.

- [ ] **Step 1: `swipe_to_reveal_row.dart` komplett ersetzen**

  Ersetze den gesamten Inhalt von `lib/features/shared/widgets/swipe_to_reveal_row.dart`:

  ```dart
  import 'package:flutter/material.dart';

  class SwipeToRevealRow extends StatefulWidget {
    final bool canDelete;
    final Future<void> Function() onDeleteTap;
    final Widget child;
    final Key? deleteKey;

    const SwipeToRevealRow({
      super.key,
      required this.canDelete,
      required this.onDeleteTap,
      required this.child,
      this.deleteKey,
    });

    @override
    State<SwipeToRevealRow> createState() => _SwipeToRevealRowState();
  }

  class _SwipeToRevealRowState extends State<SwipeToRevealRow>
      with SingleTickerProviderStateMixin {
    late final AnimationController _ctrl;
    static const double _revealWidth = 64.0;
    bool _busy = false;

    @override
    void initState() {
      super.initState();
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
    }

    @override
    void dispose() {
      _ctrl.dispose();
      super.dispose();
    }

    void _onDragUpdate(DragUpdateDetails d) {
      if (!widget.canDelete) return;
      // Ignore rightward drag when closed — prevents accidental micro-drift.
      if (d.delta.dx > 0 && _ctrl.value <= 0) return;
      _ctrl.value =
          (_ctrl.value - d.delta.dx / _revealWidth).clamp(0.0, 1.0);
    }

    void _onDragEnd(DragEndDetails d) {
      if (!widget.canDelete) return;
      if (_ctrl.value > 0.45 || d.velocity.pixelsPerSecond.dx < -250) {
        _ctrl.animateTo(1.0);
      } else {
        _ctrl.animateTo(0.0);
      }
    }

    Future<void> _handleDeleteTap() async {
      if (_busy) return;
      _busy = true;
      try {
        await widget.onDeleteTap();
      } finally {
        _busy = false;
        if (mounted) _ctrl.animateTo(0.0);
      }
    }

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: () {
          if (_ctrl.value != 0.0) _ctrl.animateTo(0.0);
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final offset = _ctrl.value * _revealWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (widget.canDelete)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: offset.clamp(0.0, _revealWidth),
                    child: GestureDetector(
                      key: widget.deleteKey,
                      onTap: _handleDeleteTap,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: offset > 24
                            ? const Icon(Icons.delete_outline,
                                color: Colors.white, size: 22)
                            : null,
                      ),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(-offset, 0),
                  child: child,
                ),
              ],
            );
          },
          child: widget.child,
        ),
      );
    }
  }
  ```

- [ ] **Step 2: Analysieren**

  ```
  flutter analyze lib/features/shared/widgets/swipe_to_reveal_row.dart
  ```

  Erwartet: `No issues found!`

- [ ] **Step 3: Manuell testen**

  App starten (`flutter run`). Im Plan-Editor eine Zeile nach **links** wischen → roter Delete-Button erscheint auf der **rechten** Seite. Tippen auf Delete-Button → Zeile wird gelöscht (mit Bestätigungs-Dialog falls aktiver Plan). Rechts-Wischen → keine ungewollte Animation, Zeile bleibt an Position.

  Gleiches in der Plan-Bibliothek testen (auch `SwipeToRevealRow` verwendet).

- [ ] **Step 4: Commit**

  ```
  git add lib/features/shared/widgets/swipe_to_reveal_row.dart
  git commit -m "fix: move swipe-to-delete from right to left swipe in SwipeToRevealRow"
  ```
