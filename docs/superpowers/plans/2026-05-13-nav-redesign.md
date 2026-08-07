# Navigation Redesign: Swipe Left → PlanLibrary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the swipe-left ConfigScreen page with PlanLibraryScreen; move Settings to gear-icon Navigator.push.

**Architecture:** WorkoutScreen's PageView page 1 switches from ConfigScreen to PlanLibraryScreen. ConfigScreen is always opened via `Navigator.push` (gear icon in WorkoutHeader). PlanLibraryScreen gains a `VoidCallback? onBack` so it can animate the PageController back to page 0 when embedded. Plan-change detection and workout pause/resume logic move from `_openPlanLibrary()` into `onPageChanged`. No new files, no new providers.

**Tech Stack:** Flutter/Dart, Riverpod 2.x, PageView/PageController, Navigator.

---

## File Map

| File | Change |
|------|--------|
| `lib/features/plans/plan_library_screen.dart` | Add `VoidCallback? onBack` constructor param; AppBar back button uses callback or falls back to pop |
| `lib/features/workout/workout_screen.dart` | Swap page 1 to PlanLibraryScreen; rewrite `_openConfig()` → Navigator.push; rewrite `onPageChanged`; delete `_openPlanLibrary()`; update PlanIndicator.onTap; rename config state fields to planLib |

---

### Task 1: PlanLibraryScreen — add `onBack` parameter

**Files:**
- Modify: `lib/features/plans/plan_library_screen.dart:7-9, 161-164`

**Context:**  
`PlanLibraryScreen` is a `ConsumerWidget`. When embedded in PageView (page 1), the AppBar back button must call `onBack` (to animate the PageController). When it has no `onBack` (future Navigator.push uses), it falls back to `Navigator.pop`. The trick: `onBack ?? () => Navigator.of(context).pop()` as the `onPressed` value.

- [ ] **Step 1: Add `onBack` field and update AppBar back button**

In `lib/features/plans/plan_library_screen.dart`, replace:

```dart
class PlanLibraryScreen extends ConsumerWidget {
  const PlanLibraryScreen({super.key});
```

with:

```dart
class PlanLibraryScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  const PlanLibraryScreen({super.key, this.onBack});
```

Then replace the AppBar leading button `onPressed`:

```dart
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: () => Navigator.of(context).pop(),
        ),
```

with:

```dart
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
```

- [ ] **Step 2: Run analyze**

```
flutter analyze lib/features/plans/plan_library_screen.dart
```

Expected: No issues.

- [ ] **Step 3: Run tests**

```
flutter test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/plans/plan_library_screen.dart
git commit -m "feat: PlanLibraryScreen accepts onBack callback for embedded PageView use"
```

---

### Task 2: WorkoutScreen — rewire navigation

**Files:**
- Modify: `lib/features/workout/workout_screen.dart`

**Context:**  
Six surgical changes to `workout_screen.dart`:
1. Rename config state fields to planLib equivalents.
2. Rewrite `_openConfig()` to `Navigator.push(ConfigScreen)`.
3. Delete `_openPlanLibrary()` — its pause/planKey/resume logic moves into `onPageChanged`.
4. Rewrite `onPageChanged` to handle PlanLibrary enter/exit instead of Config enter/exit.
5. Swap page 1 in PageView children from `ConfigScreen(...)` to `PlanLibraryScreen(onBack: ...)`.
6. Update `PlanIndicator.onTap` from `_openPlanLibrary(state)` to `_pageController.animateToPage(1, ...)`.

- [ ] **Step 1: Update state fields**

In `lib/features/workout/workout_screen.dart`, replace:

```dart
  bool _configWasOpened = false;
  bool _wasRunningBeforeConfig = false;
  int _configVisitCount = 0;
  String _planKeySnapshot = '';
```

with:

```dart
  bool _planLibWasOpened = false;
  bool _wasRunningBeforePlanLib = false;
  String _planKeySnapshot = '';
```

- [ ] **Step 2: Rewrite `_openConfig()`**

Replace:

```dart
  void _openConfig() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }
```

with:

```dart
  void _openConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigScreen(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Delete `_openPlanLibrary()`**

Remove the entire method:

```dart
  Future<void> _openPlanLibrary(WorkoutState state) async {
    final lib = ref.read(planLibraryNotifierProvider).requireValue;
    _planKeySnapshot = lib.activePlan.planKey;
    final wasRunning = state.isRunning;
    if (wasRunning) ref.read(workoutNotifierProvider.notifier).pause();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlanLibraryScreen()),
    );

    if (!mounted) return;
    final newLib = ref.read(planLibraryNotifierProvider).requireValue;
    final planChanged = newLib.activePlan.planKey != _planKeySnapshot;

    if (planChanged) {
      final wasActive = wasRunning || state.currentMinute > 0;
      if (wasActive) {
        _showResetConfirmDialog();
      } else {
        ref.read(workoutNotifierProvider.notifier).reset();
      }
    } else if (wasRunning && !state.isFinished) {
      ref.read(workoutNotifierProvider.notifier).start();
    }
  }
```

- [ ] **Step 4: Rewrite `onPageChanged` in `_buildPageView`**

Replace:

```dart
      onPageChanged: (page) {
        if (page == 1) {
          setState(() {
            _configWasOpened = true;
            _wasRunningBeforeConfig = state.isRunning || state.waitingForConfirmation;
            _configVisitCount++;
          });
          if (state.isRunning) notifier.pause();
        }
        if (page == 0 && _configWasOpened) {
          _configWasOpened = false;
          final newSettings = ref.read(settingsNotifierProvider).requireValue;
          notifier.updateSettings(newSettings);
          if (_wasRunningBeforeConfig && !state.isFinished) notifier.start();
        }
      },
```

with:

```dart
      onPageChanged: (page) {
        if (page == 1) {
          final lib = ref.read(planLibraryNotifierProvider).requireValue;
          setState(() {
            _planLibWasOpened = true;
            _wasRunningBeforePlanLib = state.isRunning || state.waitingForConfirmation;
            _planKeySnapshot = lib.activePlan.planKey;
          });
          if (state.isRunning) notifier.pause();
        }
        if (page == 0 && _planLibWasOpened) {
          setState(() => _planLibWasOpened = false);
          final newLib = ref.read(planLibraryNotifierProvider).requireValue;
          final planChanged = newLib.activePlan.planKey != _planKeySnapshot;
          if (planChanged) {
            final wasActive = _wasRunningBeforePlanLib || state.currentMinute > 0;
            if (wasActive) {
              _showResetConfirmDialog();
            } else {
              ref.read(workoutNotifierProvider.notifier).reset();
            }
          } else if (_wasRunningBeforePlanLib && !state.isFinished) {
            notifier.start();
          }
        }
      },
```

- [ ] **Step 5: Swap page 1 in PageView children**

Replace:

```dart
        ConfigScreen(
          visitCount: _configVisitCount,
          onBack: () => _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
          ),
        ),
```

with:

```dart
        PlanLibraryScreen(
          onBack: () => _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
          ),
        ),
```

- [ ] **Step 6: Update `PlanIndicator.onTap`**

Replace:

```dart
          PlanIndicator(
            planName: ref.watch(planLibraryNotifierProvider).valueOrNull?.activePlan.name ?? '',
            onTap: () => _openPlanLibrary(state),
          ),
```

with:

```dart
          PlanIndicator(
            planName: ref.watch(planLibraryNotifierProvider).valueOrNull?.activePlan.name ?? '',
            onTap: () => _pageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
            ),
          ),
```

- [ ] **Step 7: Run analyze**

```
flutter analyze lib/features/workout/workout_screen.dart lib/features/plans/plan_library_screen.dart
```

Expected: No issues.

- [ ] **Step 8: Run tests**

```
flutter test
```

Expected: All tests pass.

- [ ] **Step 9: Commit**

```bash
git add lib/features/workout/workout_screen.dart
git commit -m "feat: swipe left opens PlanLibrary, Settings accessible via gear icon only"
```
