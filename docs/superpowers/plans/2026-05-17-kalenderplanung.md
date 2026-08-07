# Kalenderplanung — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Einen Kalender-Screen als neue dritte Seite im PageView einführen (Wischen nach rechts vom Workout-Screen), auf dem der Nutzer pro Tag einen Trainingsplan aus der Plan-Bibliothek einplanen und Ernährungshinweise für Vor- und Nachtag erfassen kann.

**Architecture:** Der bestehende 2-seitige PageView (`WorkoutScreen` ← → `PlanLibraryScreen`) wird auf 3 Seiten erweitert: `CalendarScreen` (Index 0) ← `WorkoutScreen` (Index 1, initialPage) → `PlanLibraryScreen` (Index 2). Alle bisherigen Magic-Number-Referenzen auf Seitenindizes werden durch ein neues `AppPage`-Enum ersetzt. Das Kalender-Datenmodell (`CalendarEntry`) wird via `shared_preferences` persistiert und über einen Riverpod-Notifier (`CalendarNotifier`) bereitgestellt. Der Calendar-Screen zeigt ein Monats-Grid; Tippen auf einen Tag öffnet ein Bottom-Sheet zum Bearbeiten des Eintrags.

**Tech Stack:** Flutter/Dart, Riverpod 2.x (`@Riverpod(keepAlive: true)`), `shared_preferences`, `dart:convert`, keine neuen Dependencies.

---

## File Map

| File | Change |
|------|--------|
| `lib/core/models/app_page.dart` | NEU — `AppPage`-Enum |
| `lib/features/workout/workout_screen.dart` | `PageController(initialPage: AppPage.workout.index)`, Magic Numbers durch Enum ersetzen, CalendarScreen als Seite 0 einhängen |
| `lib/core/models/calendar_entry.dart` | NEU — `CalendarEntry`-Datenklasse + `CalendarStorage` |
| `lib/core/providers/calendar_notifier.dart` | NEU — `CalendarNotifier` (Riverpod, keepAlive) |
| `lib/core/providers/calendar_notifier.g.dart` | generiert via `build_runner` |
| `lib/features/calendar/calendar_screen.dart` | NEU — `CalendarScreen` mit Monats-Grid |
| `lib/features/calendar/widgets/day_editor_sheet.dart` | NEU — Bottom-Sheet für Plan-Zuweisung + Ernährungshinweise |
| `test/core/models/calendar_entry_test.dart` | NEU — Tests für CalendarEntry-Serialisierung |

---

### Task 1: `AppPage`-Enum + PageView-Refactoring

**Files:**
- Create: `lib/core/models/app_page.dart`
- Modify: `lib/features/workout/workout_screen.dart`

**Kontext:** Aktuell hat der PageView in `workout_screen.dart` zwei Seiten (Index 0 = Workout, Index 1 = Plans). Nach dem Refactoring: Index 0 = Kalender, Index 1 = Workout, Index 2 = Plans. `PageController` muss mit `initialPage: AppPage.workout.index` (= 1) initialisiert werden. Der `CalendarScreen` wird zunächst als Stub eingehängt.

- [ ] **Step 1: `app_page.dart` anlegen**

```dart
// lib/core/models/app_page.dart
enum AppPage {
  calendar, // index 0
  workout,  // index 1
  plans,    // index 2
}
```

- [ ] **Step 2: `workout_screen.dart` anpassen**

Importe ergänzen und `PageController` + `onPageChanged` + `animateToPage`-Aufrufe + PageView-children aktualisieren. Hier die vollständige neue `_WorkoutScreenState`-Klasse (nur die relevanten Methoden):

Importe oben in `workout_screen.dart` ergänzen:
```dart
import '../../core/models/app_page.dart';
import '../calendar/calendar_screen.dart';
```

`initState()` ändern:
```dart
_pageController = PageController(initialPage: AppPage.workout.index);
```

`onPageChanged`-Callback in `_buildPageView` ersetzen (war `page == 1` / `page == 0`):
```dart
onPageChanged: (page) {
  if (page == AppPage.plans.index) {
    final lib = ref.read(planLibraryNotifierProvider).requireValue;
    setState(() {
      _planLibWasOpened = true;
      _wasRunningBeforePlanLib = state.isRunning || state.waitingForConfirmation;
      _planKeySnapshot = lib.activePlan.planKey;
    });
    if (state.isRunning) notifier.pause();
  }
  if (page == AppPage.workout.index && _planLibWasOpened) {
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

`PlanIndicator`-`onTap` ändern (war `animateToPage(1)`):
```dart
onTap: () => _pageController.animateToPage(
  AppPage.plans.index,
  duration: const Duration(milliseconds: 380),
  curve: Curves.easeInOutCubic,
),
```

`PlanLibraryScreen`-`onBack`-Callback ändern (war `animateToPage(0)`):
```dart
PlanLibraryScreen(
  onBack: () => _pageController.animateToPage(
    AppPage.workout.index,
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeInOutCubic,
  ),
),
```

PageView-`children`-Liste: CalendarScreen als erstes Kind (Index 0) voranstellen:
```dart
children: [
  CalendarScreen(
    onBack: () => _pageController.animateToPage(
      AppPage.workout.index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    ),
  ),
  Scaffold(
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          state.isFinished
              ? _buildFinishedScreen(state)
              : _buildWorkoutScreen(state),
          if (state.waitingForConfirmation) _buildConfirmationOverlay(state),
        ],
      ),
    ),
  ),
  PlanLibraryScreen(
    onBack: () => _pageController.animateToPage(
      AppPage.workout.index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    ),
  ),
],
```

- [ ] **Step 3: CalendarScreen-Stub anlegen** (damit der Import nicht bricht)

```dart
// lib/features/calendar/calendar_screen.dart
import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const CalendarScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        leading: IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white38),
          onPressed: onBack,
        ),
        title: const Text('Kalender',
            style: TextStyle(fontSize: 14, letterSpacing: 1, color: Colors.white54)),
      ),
      body: const Center(
        child: Text('Kalender — coming soon',
            style: TextStyle(color: Colors.white24)),
      ),
    );
  }
}
```

- [ ] **Step 4: `flutter analyze` ausführen**

```powershell
flutter analyze lib/core/models/app_page.dart lib/features/workout/workout_screen.dart lib/features/calendar/calendar_screen.dart
```

Erwartet: `No issues found!`

- [ ] **Step 5: Tests ausführen**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 6: Commit**

```powershell
git add lib/core/models/app_page.dart lib/features/workout/workout_screen.dart lib/features/calendar/calendar_screen.dart
git commit -m "refactor: introduce AppPage enum, extend PageView to 3 pages (calendar/workout/plans)"
```

---

### Task 2: `CalendarEntry`-Datenmodell + `CalendarStorage`

**Files:**
- Create: `lib/core/models/calendar_entry.dart`
- Create: `test/core/models/calendar_entry_test.dart`

**Kontext:** `CalendarEntry` speichert das Datum (nur Tag, kein Uhrzeit), eine Plan-ID (referenziert `TrainingPlan.id`) und zwei optionale Ernährungshinweis-Strings. `CalendarStorage` ist eine statische Klasse analog zu `PlanLibraryStorage`, die via `shared_preferences` serialisiert/deserialisiert. Das Datum wird als ISO-8601-String gespeichert (`yyyy-MM-dd`).

- [ ] **Step 1: Failing tests schreiben**

```dart
// test/core/models/calendar_entry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/calendar_entry.dart';

void main() {
  group('CalendarEntry', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 5, 17),
        planId: 'plan-abc',
        preNutrition: 'Haferflocken',
        postNutrition: 'Proteinshake',
      );
      final restored = CalendarEntry.fromJson(entry.toJson());
      expect(restored.date, DateTime(2026, 5, 17));
      expect(restored.planId, 'plan-abc');
      expect(restored.preNutrition, 'Haferflocken');
      expect(restored.postNutrition, 'Proteinshake');
    });

    test('toJson omits empty nutrition fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 1, 1),
        planId: 'p1',
      );
      final json = entry.toJson();
      expect(json.containsKey('pre'), isFalse);
      expect(json.containsKey('post'), isFalse);
    });

    test('fromJson with missing nutrition fields defaults to empty string', () {
      final entry = CalendarEntry.fromJson({'d': '2026-03-15', 'p': 'plan-x'});
      expect(entry.preNutrition, '');
      expect(entry.postNutrition, '');
    });

    test('copyWith overrides only specified fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 6, 10),
        planId: 'old-plan',
        preNutrition: 'Müsli',
        postNutrition: '',
      );
      final copy = entry.copyWith(planId: 'new-plan');
      expect(copy.planId, 'new-plan');
      expect(copy.date, DateTime(2026, 6, 10));
      expect(copy.preNutrition, 'Müsli');
    });
  });
}
```

- [ ] **Step 2: Tests ausführen — müssen scheitern**

```powershell
flutter test test/core/models/calendar_entry_test.dart
```

Erwartet: FAIL mit `Target of URI doesn't exist: 'package:emom_app/core/models/calendar_entry.dart'`

- [ ] **Step 3: `calendar_entry.dart` implementieren**

```dart
// lib/core/models/calendar_entry.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarEntry {
  final DateTime date;
  final String planId;
  final String preNutrition;
  final String postNutrition;

  const CalendarEntry({
    required this.date,
    required this.planId,
    this.preNutrition = '',
    this.postNutrition = '',
  });

  Map<String, dynamic> toJson() => {
    'd': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'p': planId,
    if (preNutrition.isNotEmpty) 'pre': preNutrition,
    if (postNutrition.isNotEmpty) 'post': postNutrition,
  };

  factory CalendarEntry.fromJson(Map<String, dynamic> j) {
    final parts = (j['d'] as String).split('-');
    return CalendarEntry(
      date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      planId: j['p'] as String,
      preNutrition: j['pre'] as String? ?? '',
      postNutrition: j['post'] as String? ?? '',
    );
  }

  CalendarEntry copyWith({
    DateTime? date,
    String? planId,
    String? preNutrition,
    String? postNutrition,
  }) => CalendarEntry(
    date: date ?? this.date,
    planId: planId ?? this.planId,
    preNutrition: preNutrition ?? this.preNutrition,
    postNutrition: postNutrition ?? this.postNutrition,
  );
}

class CalendarStorage {
  static const _key = 'calendarEntries';

  static Future<List<CalendarEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((j) => CalendarEntry.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<CalendarEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
```

- [ ] **Step 4: Tests ausführen — müssen bestehen**

```powershell
flutter test test/core/models/calendar_entry_test.dart
```

Erwartet: All tests passed.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/models/calendar_entry.dart test/core/models/calendar_entry_test.dart
git commit -m "feat: add CalendarEntry model and CalendarStorage persistence"
```

---

### Task 3: `CalendarNotifier` (Riverpod)

**Files:**
- Create: `lib/core/providers/calendar_notifier.dart`
- Run `build_runner` to generate `calendar_notifier.g.dart`

**Kontext:** Der Notifier lädt beim ersten Zugriff alle Einträge aus `CalendarStorage`. Er stellt Methoden bereit zum Setzen (`setEntry`), Entfernen (`removeEntry`) und Lesen (`entryFor`) von Einträgen. `keepAlive: true` damit die Daten nicht bei Seiten-Wechseln verworfen werden. Zwei Daten gelten als gleicher Tag wenn Jahr/Monat/Tag übereinstimmen (kein Uhrzeit-Vergleich).

- [ ] **Step 1: `calendar_notifier.dart` anlegen**

```dart
// lib/core/providers/calendar_notifier.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/calendar_entry.dart';

part 'calendar_notifier.g.dart';

@Riverpod(keepAlive: true)
class CalendarNotifier extends _$CalendarNotifier {
  @override
  Future<List<CalendarEntry>> build() => CalendarStorage.load();

  Future<void> setEntry(CalendarEntry entry) async {
    final entries = [...state.requireValue];
    final idx = entries.indexWhere((e) => _sameDay(e.date, entry.date));
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    await CalendarStorage.save(entries);
    state = AsyncData(entries);
  }

  Future<void> removeEntry(DateTime date) async {
    final entries =
        state.requireValue.where((e) => !_sameDay(e.date, date)).toList();
    await CalendarStorage.save(entries);
    state = AsyncData(entries);
  }

  CalendarEntry? entryFor(DateTime date) {
    final entries = state.valueOrNull ?? [];
    for (final e in entries) {
      if (_sameDay(e.date, date)) return e;
    }
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
```

- [ ] **Step 2: Code-Generierung ausführen**

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Erwartet: `lib/core/providers/calendar_notifier.g.dart` wird generiert.

- [ ] **Step 3: `flutter analyze` ausführen**

```powershell
flutter analyze lib/core/providers/calendar_notifier.dart
```

Erwartet: `No issues found!`

- [ ] **Step 4: Alle Tests ausführen**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/providers/calendar_notifier.dart lib/core/providers/calendar_notifier.g.dart
git commit -m "feat: add CalendarNotifier (Riverpod) for calendar entry state management"
```

---

### Task 4: `CalendarScreen` — Monats-Grid

**Files:**
- Modify: `lib/features/calendar/calendar_screen.dart` (Stub aus Task 1 ersetzen)

**Kontext:** Der CalendarScreen zeigt ein Monats-Grid mit 7 Spalten (Mo–So). Der Nutzer kann mit `<` / `>` zwischen Monaten navigieren. Tage mit einem Kalender-Eintrag zeigen einen kleinen orangen Punkt unter der Tageszahl. Tippen auf einen Tag öffnet den `DayEditorSheet`. Der heutige Tag wird mit einem Rahmen hervorgehoben. Vergangene Tage werden leicht gedimmt (`Colors.white24` statt `Colors.white70`).

Die `CalendarScreen`-Klasse ist jetzt ein `ConsumerStatefulWidget` (braucht Riverpod für `calendarNotifierProvider` und `planLibraryNotifierProvider`). Der lokale State enthält nur `_displayMonth` (erster Tag des angezeigten Monats).

- [ ] **Step 1: `calendar_screen.dart` komplett ersetzen**

```dart
// lib/features/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/calendar_notifier.dart';
import '../../core/providers/plan_library_notifier.dart';
import 'widgets/day_editor_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const CalendarScreen({super.key, this.onBack});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() => setState(() {
        _displayMonth =
            DateTime(_displayMonth.year, _displayMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _displayMonth =
            DateTime(_displayMonth.year, _displayMonth.month + 1);
      });

  void _openDay(DateTime date) {
    final calendarAsync = ref.read(calendarNotifierProvider);
    final libAsync = ref.read(planLibraryNotifierProvider);
    if (!calendarAsync.hasValue || !libAsync.hasValue) return;
    final plans = libAsync.requireValue.plans;
    if (plans.isEmpty) return;
    final existing = ref.read(calendarNotifierProvider.notifier).entryFor(date);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DayEditorSheet(
        date: date,
        plans: plans,
        existing: existing,
        onSave: (entry) {
          ref.read(calendarNotifierProvider.notifier).setEntry(entry);
          Navigator.pop(context);
        },
        onDelete: existing == null
            ? null
            : () {
                ref
                    .read(calendarNotifierProvider.notifier)
                    .removeEntry(date);
                Navigator.pop(context);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(calendarNotifierProvider);
    final entries = entriesAsync.valueOrNull ?? [];

    final monthNames = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];

    final today = DateTime.now();
    final firstDay = _displayMonth;
    final daysInMonth =
        DateTime(firstDay.year, firstDay.month + 1, 0).day;
    // weekday: 1=Mon..7=Sun, we want Mon=0
    final startOffset = firstDay.weekday - 1;
    final totalCells =
        ((startOffset + daysInMonth) / 7).ceil() * 7;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        leading: IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white38),
          onPressed: widget.onBack,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white38, size: 20),
              onPressed: _prevMonth,
            ),
            Text(
              '${monthNames[_displayMonth.month]} ${_displayMonth.year}',
              style: const TextStyle(
                  fontSize: 14, letterSpacing: 1, color: Colors.white54),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
              onPressed: _nextMonth,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Weekday header
            Row(
              children: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white24,
                                  letterSpacing: 1)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            // Day grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.9,
              ),
              itemCount: totalCells,
              itemBuilder: (_, i) {
                final dayNumber = i - startOffset + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox();
                }
                final date = DateTime(
                    firstDay.year, firstDay.month, dayNumber);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isPast = date.isBefore(
                    DateTime(today.year, today.month, today.day));
                final hasEntry = entries
                    .any((e) => _sameDay(e.date, date));

                return GestureDetector(
                  onTap: () => _openDay(date),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      border: isToday
                          ? Border.all(
                              color: const Color(0xFFFF6B00), width: 1)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13,
                            color: isPast
                                ? Colors.white24
                                : Colors.white70,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (hasEntry)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B00),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
```

- [ ] **Step 2: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/calendar/calendar_screen.dart
```

Erwartet: `No issues found!` (der Import `day_editor_sheet.dart` fehlt noch, daher zunächst nur auf fehlenden Import-Fehler prüfen; das wird in Task 5 behoben)

- [ ] **Step 3: Commit (Stub für day_editor_sheet.dart anlegen, damit analyze nicht bricht)**

Zunächst `day_editor_sheet.dart`-Stub anlegen (wird in Task 5 ersetzt):

```dart
// lib/features/calendar/widgets/day_editor_sheet.dart
import 'package:flutter/material.dart';
import '../../../core/models/calendar_entry.dart';
import '../../../core/models/training_plan.dart';

class DayEditorSheet extends StatelessWidget {
  final DateTime date;
  final List<TrainingPlan> plans;
  final CalendarEntry? existing;
  final void Function(CalendarEntry) onSave;
  final VoidCallback? onDelete;

  const DayEditorSheet({
    super.key,
    required this.date,
    required this.plans,
    required this.existing,
    required this.onSave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

```powershell
flutter analyze lib/features/calendar/
```

Erwartet: `No issues found!`

```powershell
flutter test
```

Erwartet: All tests passed.

```powershell
git add lib/features/calendar/calendar_screen.dart lib/features/calendar/widgets/day_editor_sheet.dart
git commit -m "feat: add CalendarScreen with monthly grid and day entry indicator"
```

---

### Task 5: `DayEditorSheet` — Plan-Zuweisung + Ernährungshinweise

**Files:**
- Modify: `lib/features/calendar/widgets/day_editor_sheet.dart` (Stub aus Task 4 ersetzen)

**Kontext:** Das Bottom-Sheet öffnet sich wenn der Nutzer auf einen Tag im Grid tippt. Es zeigt:
- Datum als Kopfzeile
- Plan-Auswahl: alle Pläne aus der Plan-Bibliothek als `_pickerChip`-artige Chips (oranges Highlight für ausgewählten Plan, konsistent mit dem restlichen UI-Stil)
- Zwei `TextField`s für Ernährungshinweise (Vortag / Nachtag)
- „Speichern"-Button (orange, disabled wenn kein Plan ausgewählt)
- „Eintrag entfernen"-Button (nur wenn `existing != null`)

Das Sheet ist ein `StatefulWidget`. Initial-State: `_selectedPlanId = existing?.planId` und Text-Controller mit existierenden Werten befüllt.

- [ ] **Step 1: `day_editor_sheet.dart` komplett ersetzen**

```dart
// lib/features/calendar/widgets/day_editor_sheet.dart
import 'package:flutter/material.dart';
import '../../../core/models/calendar_entry.dart';
import '../../../core/models/training_plan.dart';

class DayEditorSheet extends StatefulWidget {
  final DateTime date;
  final List<TrainingPlan> plans;
  final CalendarEntry? existing;
  final void Function(CalendarEntry) onSave;
  final VoidCallback? onDelete;

  const DayEditorSheet({
    super.key,
    required this.date,
    required this.plans,
    required this.existing,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<DayEditorSheet> {
  String? _selectedPlanId;
  late TextEditingController _preController;
  late TextEditingController _postController;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.existing?.planId;
    _preController =
        TextEditingController(text: widget.existing?.preNutrition ?? '');
    _postController =
        TextEditingController(text: widget.existing?.postNutrition ?? '');
  }

  @override
  void dispose() {
    _preController.dispose();
    _postController.dispose();
    super.dispose();
  }

  Widget _planChip(TrainingPlan plan) {
    final selected = _selectedPlanId == plan.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = plan.id),
      child: Container(
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B00) : const Color(0xFF222222),
          borderRadius: BorderRadius.circular(6),
          border: selected ? null : Border.all(color: Colors.white12),
        ),
        child: Text(
          plan.name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.black : Colors.white54,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const weekdays = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const months = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return '${weekdays[d.weekday]}, ${d.day}. ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedPlanId != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Date header
          Text(
            _formatDate(widget.date),
            style: const TextStyle(
                fontSize: 14, color: Colors.white54, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          // Plan selector
          const Text('Trainingsplan',
              style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(
            children: widget.plans.map(_planChip).toList(),
          ),
          const SizedBox(height: 16),
          // Pre-nutrition
          const Text('Ernährung Vortag',
              style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 6),
          TextField(
            controller: _preController,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'z.B. Kohlenhydrate erhöhen, wenig Fett',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Color(0xFF111111),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Color(0xFFFF6B00)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          // Post-nutrition
          const Text('Ernährung Nachtag',
              style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 6),
          TextField(
            controller: _postController,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'z.B. Protein erhöhen, Regeneration',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Color(0xFF111111),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Color(0xFFFF6B00)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 20),
          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: GestureDetector(
              onTap: canSave
                  ? () => widget.onSave(CalendarEntry(
                        date: widget.date,
                        planId: _selectedPlanId!,
                        preNutrition: _preController.text.trim(),
                        postNutrition: _postController.text.trim(),
                      ))
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: canSave
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Speichern',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canSave ? Colors.black : Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Delete button (only if entry exists)
          if (widget.onDelete != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onDelete,
                child: const Text(
                  'Eintrag entfernen',
                  style: TextStyle(fontSize: 13, color: Colors.white24),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/calendar/
```

Erwartet: `No issues found!`

- [ ] **Step 3: Gesamte Test-Suite**

```powershell
flutter test
```

Erwartet: All tests passed.

- [ ] **Step 4: Commit**

```powershell
git add lib/features/calendar/widgets/day_editor_sheet.dart
git commit -m "feat: add DayEditorSheet for plan assignment and nutrition notes"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|---|---|
| Kalender-Screen erreichbar durch Wischen nach rechts | Task 1 (Seite 0 im PageView) |
| Magic Numbers durch Enum ersetzen | Task 1 (AppPage enum) |
| Trainingsplan an konkreten Tagen einplanbar | Task 5 (DayEditorSheet Plan-Chips) |
| Ernährungshinweise Vortag + Nachtag | Task 5 (zwei TextFields) |
| Persistierung der Einträge | Task 2 (CalendarStorage) + Task 3 (CalendarNotifier) |
| Monats-Grid mit Navigation | Task 4 (CalendarScreen) |
| Eingetragene Tage im Grid sichtbar | Task 4 (oranger Dot-Indikator) |
| Heutiger Tag hervorgehoben | Task 4 (Orange-Rahmen) |
| Eintrag löschbar | Task 5 (onDelete → `removeEntry`) |

**Placeholder-Scan:** Keine — vollständiger Code in jedem Schritt.

**Type-Konsistenz:**
- `CalendarEntry.planId: String` — referenziert `TrainingPlan.id: String` ✅
- `CalendarNotifier.entryFor(DateTime): CalendarEntry?` — korrekt verwendet in `_openDay` ✅
- `DayEditorSheet.onSave: void Function(CalendarEntry)` — korrekt in `CalendarScreen._openDay` übergeben ✅
- `AppPage.workout.index == 1` — korrekt in `PageController(initialPage: AppPage.workout.index)` ✅
