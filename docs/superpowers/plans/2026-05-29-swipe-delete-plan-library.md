# Swipe-to-Reveal Delete in Plan Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the confirmation-dialog delete in `PlanLibraryScreen` with the same swipe-to-reveal trash button already used in the plan editor.

**Architecture:** Extract the private `_SwipeToRevealRow` widget from `minute_exact_editor.dart` into a shared widget file, update `minute_exact_editor.dart` to use it, then wire it into `plan_library_screen.dart` replacing the existing `Dismissible`. The only guard is `canDelete: library.plans.length > 1` — deleting the active plan is allowed, deleting the last plan is not (swipe simply does nothing).

**Tech Stack:** Flutter, Dart, Riverpod (`planLibraryProvider`)

---

## File Structure

| File | Change |
|---|---|
| `lib/features/shared/widgets/swipe_to_reveal_row.dart` | **New** — public `SwipeToRevealRow` widget extracted from `_SwipeToRevealRow` |
| `lib/features/plans/widgets/minute_exact_editor.dart` | Remove `_SwipeToRevealRow` class, import and use shared widget |
| `lib/features/plans/plan_library_screen.dart` | Remove `Dismissible` + `_confirmDelete`, use `SwipeToRevealRow` |

---

### Task 1: Extract SwipeToRevealRow to shared widget

**Files:**
- Create: `lib/features/shared/widgets/swipe_to_reveal_row.dart`
- Modify: `lib/features/plans/widgets/minute_exact_editor.dart`

The existing `_SwipeToRevealRow` (lines 67–182 in `minute_exact_editor.dart`) is extracted verbatim into a public widget. The only API change: `rowKey` → standard Flutter `key` parameter (`super.key`); `deleteKey` stays as an optional named parameter for the inner trash button.

- [ ] **Step 1: Create the shared widget file**

Create `lib/features/shared/widgets/swipe_to_reveal_row.dart` with this exact content:

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
    _ctrl.value =
        (_ctrl.value + d.delta.dx / _revealWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.canDelete) return;
    if (_ctrl.value > 0.45 || d.velocity.pixelsPerSecond.dx > 250) {
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
                  left: 0,
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
                offset: Offset(offset, 0),
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

- [ ] **Step 2: Update `minute_exact_editor.dart` to use the shared widget**

In `lib/features/plans/widgets/minute_exact_editor.dart`:

a) Add import after existing imports:
```dart
import '../../shared/widgets/swipe_to_reveal_row.dart';
```

b) Delete the entire `_SwipeToRevealRow` class (lines 67–182 — everything from `// ---------------------------------------------------------------------------` to the end of the file).

c) In `PlanMinuteExactEditor.build`, replace the `_SwipeToRevealRow(` call with `SwipeToRevealRow(` and change `rowKey:` to `key:`:

```dart
child: SwipeToRevealRow(
  key: ValueKey('swipe_row_$i'),
  deleteKey: ValueKey('delete_$i'),
  canDelete: plan.intervals.length > TrainingPlan.minIntervals,
  onDeleteTap: () async {
    if (onConfirmDelete != null) {
      final confirmed = await onConfirmDelete!(i);
      if (!confirmed) return;
    }
    onDelete(i);
  },
  child: PlanMinuteRow(
    index: i,
    plan: plan,
    isSelected: selectedRow == i,
    onSelect: () => onRowSelected(selectedRow == i ? null : i),
    onChanged: onChanged,
  ),
),
```

- [ ] **Step 3: Verify no analysis errors**

```
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```
git add lib/features/shared/widgets/swipe_to_reveal_row.dart lib/features/plans/widgets/minute_exact_editor.dart
git commit -m "refactor: extract _SwipeToRevealRow to shared SwipeToRevealRow widget"
```

---

### Task 2: Wire SwipeToRevealRow into PlanLibraryScreen

**Files:**
- Modify: `lib/features/plans/plan_library_screen.dart`

Current state: each plan row is wrapped in `GestureDetector(onTap: navigate) > Dismissible(confirmDismiss: _confirmDelete)`. The `_confirmDelete` method (lines 104–153) shows a confirmation dialog for normal plans and an info dialog for active/last plan.

New state: `GestureDetector(onTap: navigate) > SwipeToRevealRow(canDelete: ..., onDeleteTap: ...)` wrapping the `Container` card. No dialogs.

- [ ] **Step 1: Add import**

At the top of `lib/features/plans/plan_library_screen.dart`, add:
```dart
import '../shared/widgets/swipe_to_reveal_row.dart';
```

- [ ] **Step 2: Delete `_confirmDelete` method**

Remove the entire `_confirmDelete` method (lines 104–153):
```dart
Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, TrainingPlan plan,
    {required bool isActive, required bool isLast}) async {
  // ... entire method body ...
}
```

- [ ] **Step 3: Replace Dismissible with SwipeToRevealRow**

In `build`, the `itemBuilder` currently returns:
```dart
GestureDetector(
  onTap: () => Navigator.push(...),
  child: Dismissible(
    key: ValueKey(plan.id),
    direction: DismissDirection.endToStart,
    confirmDismiss: (_) async {
      await _confirmDelete(...);
      return false;
    },
    background: Container(...),
    child: Container(  // the plan card
      margin: ...,
      ...
    ),
  ),
)
```

Replace with:
```dart
GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) => PlanEditorScreen(plan: plan)),
  ),
  child: SwipeToRevealRow(
    key: ValueKey(plan.id),
    canDelete: library.plans.length > 1,
    onDeleteTap: () async {
      await ref
          .read(planLibraryProvider.notifier)
          .deletePlan(plan.id);
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref
                .read(planLibraryProvider.notifier)
                .setActivePlan(plan.id),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFF6B00)
                        : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _renamePlan(context, ref, plan),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 15,
                      color: isActive
                          ? Colors.white70
                          : Colors.white38,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${plan.intervals.length} Intervalle · ${_formatDuration(plan.totalDurationSeconds)}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white24),
                  ),
                ],
              ),
            ),
          ),
          const Icon(Icons.chevron_right,
              color: Colors.white24, size: 20),
        ],
      ),
    ),
  ),
)
```

- [ ] **Step 4: Verify no analysis errors**

```
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 5: Run tests**

```
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```
git add lib/features/plans/plan_library_screen.dart
git commit -m "feat: swipe-to-reveal delete in plan library, no confirmation dialog"
```
