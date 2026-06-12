# Kalenderplanung: Serien, Erinnerungen & Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den Kalender-Bereich zur Trainings-Kommandozentrale ausbauen: regelbasierte Serien (z.B. Di/Do/Sa), optionale lokale Erinnerungen zu globaler Uhrzeit, ein Notizfeld statt zwei Ernährungsfeldern, „Monat + Agenda"-Redesign mit Heute-Karte und 1-Tap-Plan-Aktivierung.

**Architecture:** Neues Modell `TrainingSeries` (SharedPreferences) + pure Resolver-Funktion `resolveDay` (Einzeleintrag > jüngste Serie). Ein `NotificationService` (flutter_local_notifications) plant nach jeder Änderung die nächsten 30 Trainingstage als rollierendes Fenster neu. UI: `CalendarScreen` komplett neu (Grid + Agenda), `DayEditorSheet` komplett neu (Plan-Liste, Serien-Toggle, Serientag-Aktionen), Chip im `WorkoutScreen`.

**Tech Stack:** Flutter/Dart, Riverpod 3 mit Codegen (`@Riverpod(keepAlive: true)`), shared_preferences, NEU: flutter_local_notifications + timezone + flutter_timezone.

**Spec:** `docs/superpowers/specs/2026-06-13-kalenderplanung-serien-redesign.md`

**Wichtige Codebase-Fakten (nicht raten):**
- Generierte Provider-Namen (riverpod_generator 4 entfernt das „Notifier"-Suffix): `CalendarNotifier` → `calendarProvider`, `PlanLibraryNotifier` → `planLibraryProvider`, `SettingsNotifier` → `settingsProvider`, `WorkoutNotifier` → `workoutProvider`. Neu: `SeriesNotifier` → `seriesProvider`.
- Nach jeder Änderung an `@riverpod`-Klassen: `dart run build_runner build --delete-conflicting-outputs`.
- App-Akzentfarbe `Color(0xFFFF6B00)`, Hintergrund `Color(0xFF000000)`, Sheets `Color(0xFF0D0D0D)`.
- `WorkoutState` hat `isRunning`, `waitingForConfirmation`, `currentMinute` (alle in `lib/features/workout/workout_notifier.dart`).
- `flutter analyze` und `flutter test` müssen nach jedem Task grün sein.

---

## File Map

| File | Change |
|------|--------|
| `lib/core/models/calendar_entry.dart` | `note` ersetzt `preNutrition`/`postNutrition`, Migration |
| `test/core/models/calendar_entry_test.dart` | Tests neu (note + Migration) |
| `lib/core/models/training_series.dart` | NEU — `TrainingSeries` + `SeriesStorage` |
| `test/core/models/training_series_test.dart` | NEU |
| `lib/core/models/planned_day.dart` | NEU — `PlannedDay` + `resolveDay` |
| `test/core/models/planned_day_test.dart` | NEU |
| `lib/core/providers/series_notifier.dart` | NEU — `SeriesNotifier` |
| `lib/core/models/reminder_planner.dart` | NEU — pure Terminberechnung |
| `test/core/models/reminder_planner_test.dart` | NEU |
| `pubspec.yaml` | + flutter_local_notifications, timezone, flutter_timezone |
| `android/app/src/main/AndroidManifest.xml` | Permissions + Receiver |
| `android/app/build.gradle.kts` | Core library desugaring |
| `lib/core/models/settings.dart` | + `trainingReminderEnabled`, `trainingReminderMinutes` |
| `lib/core/services/notification_service.dart` | NEU — Service + `rescheduleReminders` |
| `lib/core/providers/calendar_notifier.dart` | Reschedule nach Änderungen |
| `lib/app.dart` | ConsumerStatefulWidget + Reminder-Init beim Start |
| `lib/features/config/widgets/feedback_tab.dart` | ConsumerWidget + Erinnerungs-Sektion |
| `lib/features/calendar/widgets/day_editor_sheet.dart` | Komplett neu |
| `lib/features/calendar/calendar_screen.dart` | Komplett neu (Monat + Agenda) |
| `lib/features/workout/widgets/planned_today_chip.dart` | NEU |
| `lib/features/workout/workout_screen.dart` | Chip einhängen + Aktivierungslogik |

---

### Task 1: `CalendarEntry` — ein `note`-Feld mit Migration

**Files:**
- Modify: `lib/core/models/calendar_entry.dart`
- Modify: `lib/features/calendar/widgets/day_editor_sheet.dart` (minimal, damit es kompiliert — kompletter Umbau in Task 8)
- Test: `test/core/models/calendar_entry_test.dart` (komplett ersetzen)

- [ ] **Step 1: Tests komplett ersetzen** — `test/core/models/calendar_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/calendar_entry.dart';

void main() {
  group('CalendarEntry', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 5, 17),
        planId: 'plan-abc',
        note: 'Abends Kohlenhydrate auffüllen',
      );
      final restored = CalendarEntry.fromJson(entry.toJson());
      expect(restored.date, DateTime(2026, 5, 17));
      expect(restored.planId, 'plan-abc');
      expect(restored.note, 'Abends Kohlenhydrate auffüllen');
    });

    test('toJson omits empty note', () {
      final entry = CalendarEntry(date: DateTime(2026, 1, 1), planId: 'p1');
      expect(entry.toJson().containsKey('n'), isFalse);
    });

    test('fromJson without note defaults to empty string', () {
      final entry = CalendarEntry.fromJson({'d': '2026-03-15', 'p': 'plan-x'});
      expect(entry.note, '');
    });

    test('fromJson migrates legacy pre/post fields into note', () {
      final entry = CalendarEntry.fromJson({
        'd': '2026-03-15',
        'p': 'plan-x',
        'pre': 'Haferflocken',
        'post': 'Proteinshake',
      });
      expect(entry.note, 'Haferflocken\nProteinshake');
    });

    test('fromJson migrates single legacy field without newline', () {
      final entry = CalendarEntry.fromJson({
        'd': '2026-03-15',
        'p': 'plan-x',
        'post': 'Proteinshake',
      });
      expect(entry.note, 'Proteinshake');
    });

    test('copyWith overrides only specified fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 6, 10),
        planId: 'old-plan',
        note: 'Müsli',
      );
      final copy = entry.copyWith(planId: 'new-plan');
      expect(copy.planId, 'new-plan');
      expect(copy.date, DateTime(2026, 6, 10));
      expect(copy.note, 'Müsli');
    });
  });
}
```

- [ ] **Step 2: Tests ausführen — müssen scheitern**

```powershell
flutter test test/core/models/calendar_entry_test.dart
```

Erwartet: FAIL (Compile-Fehler: `note` existiert nicht).

- [ ] **Step 3: Modell umbauen** — in `lib/core/models/calendar_entry.dart` die Klasse `CalendarEntry` ersetzen (Klasse `CalendarStorage` bleibt unverändert):

```dart
class CalendarEntry {
  final DateTime date;
  final String planId;
  final String note;

  const CalendarEntry({
    required this.date,
    required this.planId,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'd': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'p': planId,
    if (note.isNotEmpty) 'n': note,
  };

  factory CalendarEntry.fromJson(Map<String, dynamic> j) {
    final parts = (j['d'] as String).split('-');
    // Migration altes Format: 'pre'/'post' (Ernährung Vor-/Nachtag) → eine Notiz
    final legacy = [j['pre'] as String? ?? '', j['post'] as String? ?? '']
        .where((s) => s.isNotEmpty)
        .join('\n');
    return CalendarEntry(
      date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      planId: j['p'] as String,
      note: j['n'] as String? ?? legacy,
    );
  }

  CalendarEntry copyWith({
    DateTime? date,
    String? planId,
    String? note,
  }) => CalendarEntry(
    date: date ?? this.date,
    planId: planId ?? this.planId,
    note: note ?? this.note,
  );
}
```

- [ ] **Step 4: `day_editor_sheet.dart` minimal anpassen** (kompiliert wieder; volles Redesign in Task 8). Vier Änderungen:

(a) Felder ersetzen — aus

```dart
  late TextEditingController _preController;
  late TextEditingController _postController;
```

wird

```dart
  late TextEditingController _noteController;
```

(b) `initState` — aus

```dart
    _preController =
        TextEditingController(text: widget.existing?.preNutrition ?? '');
    _postController =
        TextEditingController(text: widget.existing?.postNutrition ?? '');
```

wird

```dart
    _noteController =
        TextEditingController(text: widget.existing?.note ?? '');
```

(c) `dispose` — aus

```dart
    _preController.dispose();
    _postController.dispose();
```

wird

```dart
    _noteController.dispose();
```

(d) In `build`: den gesamten Block von `// Pre-nutrition` bis zum Ende des zweiten `TextField` (inkl. `const SizedBox(height: 12),` dazwischen) ersetzen durch **ein** Feld:

```dart
          // Notiz
          const Text('Notiz',
              style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'z.B. Ernährung: abends Kohlenhydrate auffüllen',
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
```

und im Save-Button-`onTap` aus

```dart
                  ? () => widget.onSave(CalendarEntry(
                        date: widget.date,
                        planId: _selectedPlanId!,
                        preNutrition: _preController.text.trim(),
                        postNutrition: _postController.text.trim(),
                      ))
```

wird

```dart
                  ? () => widget.onSave(CalendarEntry(
                        date: widget.date,
                        planId: _selectedPlanId!,
                        note: _noteController.text.trim(),
                      ))
```

- [ ] **Step 5: Tests + Analyze**

```powershell
flutter test
flutter analyze
```

Erwartet: All tests passed, No issues found.

- [ ] **Step 6: Commit**

```powershell
git add lib/core/models/calendar_entry.dart lib/features/calendar/widgets/day_editor_sheet.dart test/core/models/calendar_entry_test.dart
git commit -m "feat: replace calendar nutrition fields with single note (with migration)"
```

---

### Task 2: `TrainingSeries` + `SeriesStorage`

**Files:**
- Create: `lib/core/models/training_series.dart`
- Test: `test/core/models/training_series_test.dart`

- [ ] **Step 1: Failing Tests schreiben** — `test/core/models/training_series_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_series.dart';

void main() {
  group('TrainingSeries', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final series = TrainingSeries(
        id: 'abc',
        planId: 'plan-1',
        weekdays: {DateTime.tuesday, DateTime.thursday, DateTime.saturday},
        startDate: DateTime(2026, 6, 13),
        exceptions: {'2026-06-16'},
      );
      final restored = TrainingSeries.fromJson(series.toJson());
      expect(restored.id, 'abc');
      expect(restored.planId, 'plan-1');
      expect(restored.weekdays, {2, 4, 6});
      expect(restored.startDate, DateTime(2026, 6, 13));
      expect(restored.exceptions, {'2026-06-16'});
    });

    test('toJson omits empty exceptions', () {
      final series = TrainingSeries(
        id: 'a',
        planId: 'p',
        weekdays: {1},
        startDate: DateTime(2026, 1, 1),
      );
      expect(series.toJson().containsKey('ex'), isFalse);
    });

    group('occursOn', () {
      final series = TrainingSeries(
        id: 'a',
        planId: 'p',
        weekdays: {DateTime.tuesday, DateTime.thursday},
        startDate: DateTime(2026, 6, 13), // Samstag
        exceptions: {'2026-06-18'},
      );

      test('matches weekday on/after startDate', () {
        // Di 16.06.2026
        expect(series.occursOn(DateTime(2026, 6, 16)), isTrue);
      });

      test('does not match other weekdays', () {
        // Mo 15.06.2026
        expect(series.occursOn(DateTime(2026, 6, 15)), isFalse);
      });

      test('does not match before startDate', () {
        // Di 09.06.2026 — vor dem 13.06.
        expect(series.occursOn(DateTime(2026, 6, 9)), isFalse);
      });

      test('does not match excepted dates', () {
        // Do 18.06.2026 steht in exceptions
        expect(series.occursOn(DateTime(2026, 6, 18)), isFalse);
      });
    });

    test('dateKey formats with zero padding', () {
      expect(TrainingSeries.dateKey(DateTime(2026, 3, 5)), '2026-03-05');
    });
  });
}
```

- [ ] **Step 2: Tests ausführen — müssen scheitern**

```powershell
flutter test test/core/models/training_series_test.dart
```

Erwartet: FAIL (`Target of URI doesn't exist`).

- [ ] **Step 3: Implementieren** — `lib/core/models/training_series.dart`:

```dart
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Wiederkehrende Trainings-Serie: Plan + Wochentage, gilt unendlich ab
/// [startDate]. Einzelne Tage können über [exceptions] ausgenommen werden.
class TrainingSeries {
  final String id;
  final String planId;
  final Set<int> weekdays; // 1=Mo … 7=So (DateTime.weekday)
  final DateTime startDate; // nur Datum, keine Uhrzeit
  final Set<String> exceptions; // ISO-Daten 'yyyy-MM-dd'

  const TrainingSeries({
    required this.id,
    required this.planId,
    required this.weekdays,
    required this.startDate,
    this.exceptions = const {},
  });

  static String newId() {
    final r = Random();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Trifft die Serie auf [date] zu? (Wochentag passt, startDate erreicht,
  /// Datum nicht ausgenommen.)
  bool occursOn(DateTime date) {
    if (!weekdays.contains(date.weekday)) return false;
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (day.isBefore(start)) return false;
    return !exceptions.contains(dateKey(date));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'p': planId,
    'wd': (weekdays.toList()..sort()),
    's': dateKey(startDate),
    if (exceptions.isNotEmpty) 'ex': (exceptions.toList()..sort()),
  };

  factory TrainingSeries.fromJson(Map<String, dynamic> j) {
    final parts = (j['s'] as String).split('-');
    return TrainingSeries(
      id: j['id'] as String,
      planId: j['p'] as String,
      weekdays: (j['wd'] as List).cast<int>().toSet(),
      startDate: DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      exceptions: ((j['ex'] as List?) ?? const []).cast<String>().toSet(),
    );
  }

  TrainingSeries copyWith({Set<String>? exceptions}) => TrainingSeries(
    id: id,
    planId: planId,
    weekdays: weekdays,
    startDate: startDate,
    exceptions: exceptions ?? this.exceptions,
  );
}

class SeriesStorage {
  static const _key = 'trainingSeries';

  static Future<List<TrainingSeries>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => TrainingSeries.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<TrainingSeries> series) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(series.map((s) => s.toJson()).toList()),
    );
  }
}
```

- [ ] **Step 4: Tests ausführen — müssen bestehen**

```powershell
flutter test test/core/models/training_series_test.dart
```

- [ ] **Step 5: Commit**

```powershell
git add lib/core/models/training_series.dart test/core/models/training_series_test.dart
git commit -m "feat: add TrainingSeries model with SeriesStorage persistence"
```

---

### Task 3: `PlannedDay` + `resolveDay`

**Files:**
- Create: `lib/core/models/planned_day.dart`
- Test: `test/core/models/planned_day_test.dart`

- [ ] **Step 1: Failing Tests schreiben** — `test/core/models/planned_day_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/calendar_entry.dart';
import 'package:emom_app/core/models/planned_day.dart';
import 'package:emom_app/core/models/training_series.dart';

void main() {
  // Di 16.06.2026
  final date = DateTime(2026, 6, 16);

  TrainingSeries series({
    String id = 's1',
    String planId = 'series-plan',
    Set<String> exceptions = const {},
  }) => TrainingSeries(
    id: id,
    planId: planId,
    weekdays: {DateTime.tuesday},
    startDate: DateTime(2026, 6, 1),
    exceptions: exceptions,
  );

  group('resolveDay', () {
    test('returns null when nothing is planned', () {
      expect(resolveDay(date, [], []), isNull);
    });

    test('returns entry data for a single entry', () {
      final entry =
          CalendarEntry(date: date, planId: 'entry-plan', note: 'Notiz');
      final result = resolveDay(date, [entry], []);
      expect(result!.planId, 'entry-plan');
      expect(result.note, 'Notiz');
      expect(result.fromSeries, isFalse);
      expect(result.seriesId, isNull);
    });

    test('returns series occurrence when no entry exists', () {
      final result = resolveDay(date, [], [series()]);
      expect(result!.planId, 'series-plan');
      expect(result.fromSeries, isTrue);
      expect(result.seriesId, 's1');
      expect(result.note, '');
    });

    test('entry overrides series on the same day', () {
      final entry = CalendarEntry(date: date, planId: 'entry-plan');
      final result = resolveDay(date, [entry], [series()]);
      expect(result!.planId, 'entry-plan');
      expect(result.fromSeries, isFalse);
    });

    test('excepted series day resolves to null', () {
      final s = series(exceptions: {'2026-06-16'});
      expect(resolveDay(date, [], [s]), isNull);
    });

    test('newest series wins on collision', () {
      final older = series(id: 'old', planId: 'old-plan');
      final newer = series(id: 'new', planId: 'new-plan');
      final result = resolveDay(date, [], [older, newer]);
      expect(result!.planId, 'new-plan');
      expect(result.seriesId, 'new');
    });
  });
}
```

- [ ] **Step 2: Tests ausführen — müssen scheitern**

```powershell
flutter test test/core/models/planned_day_test.dart
```

- [ ] **Step 3: Implementieren** — `lib/core/models/planned_day.dart`:

```dart
import 'calendar_entry.dart';
import 'training_series.dart';

/// Aufgelöstes Tagesergebnis: welches Training ist an einem Tag geplant.
class PlannedDay {
  final String planId;
  final String note;
  final bool fromSeries;
  final String? seriesId;

  const PlannedDay({
    required this.planId,
    this.note = '',
    this.fromSeries = false,
    this.seriesId,
  });
}

/// Löst auf, welches Training an [date] geplant ist.
/// Vorrang: Einzeleintrag > jüngste passende Serie > nichts (max. ein
/// Training pro Tag). Serien gelten an ihren Wochentagen ab startDate,
/// außer das Datum ist ausgenommen.
PlannedDay? resolveDay(
  DateTime date,
  List<CalendarEntry> entries,
  List<TrainingSeries> series,
) {
  for (final e in entries) {
    if (e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day) {
      return PlannedDay(planId: e.planId, note: e.note);
    }
  }
  // Listen sind in Anlege-Reihenfolge — rückwärts = jüngste Serie zuerst.
  for (final s in series.reversed) {
    if (s.occursOn(date)) {
      return PlannedDay(planId: s.planId, fromSeries: true, seriesId: s.id);
    }
  }
  return null;
}
```

- [ ] **Step 4: Tests ausführen — müssen bestehen**

```powershell
flutter test test/core/models/planned_day_test.dart
```

- [ ] **Step 5: Commit**

```powershell
git add lib/core/models/planned_day.dart test/core/models/planned_day_test.dart
git commit -m "feat: add resolveDay with entry-over-series precedence"
```

---

### Task 4: `SeriesNotifier` (Riverpod)

**Files:**
- Create: `lib/core/providers/series_notifier.dart`
- Generate: `lib/core/providers/series_notifier.g.dart` (build_runner)

- [ ] **Step 1: Notifier anlegen** — `lib/core/providers/series_notifier.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/training_series.dart';

part 'series_notifier.g.dart';

@Riverpod(keepAlive: true)
class SeriesNotifier extends _$SeriesNotifier {
  @override
  Future<List<TrainingSeries>> build() => SeriesStorage.load();

  Future<void> addSeries(TrainingSeries series) async {
    final list = [...state.requireValue, series];
    await SeriesStorage.save(list);
    state = AsyncData(list);
  }

  Future<void> removeSeries(String id) async {
    final list = state.requireValue.where((s) => s.id != id).toList();
    await SeriesStorage.save(list);
    state = AsyncData(list);
  }

  Future<void> addException(String id, DateTime date) async {
    final list = state.requireValue.map((s) {
      if (s.id != id) return s;
      return s.copyWith(
          exceptions: {...s.exceptions, TrainingSeries.dateKey(date)});
    }).toList();
    await SeriesStorage.save(list);
    state = AsyncData(list);
  }
}
```

- [ ] **Step 2: Code-Generierung + Analyze + Tests**

```powershell
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Erwartet: `series_notifier.g.dart` generiert (Provider heißt `seriesProvider`), keine Issues, alle Tests grün.

- [ ] **Step 3: Commit**

```powershell
git add lib/core/providers/series_notifier.dart lib/core/providers/series_notifier.g.dart
git commit -m "feat: add SeriesNotifier for training series state"
```

---

### Task 5: Reminder-Terminberechnung (pure)

**Files:**
- Create: `lib/core/models/reminder_planner.dart`
- Test: `test/core/models/reminder_planner_test.dart`

- [ ] **Step 1: Failing Tests schreiben** — `test/core/models/reminder_planner_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/calendar_entry.dart';
import 'package:emom_app/core/models/reminder_planner.dart';
import 'package:emom_app/core/models/training_series.dart';

void main() {
  // Sa 13.06.2026, 10:00 Uhr
  final now = DateTime(2026, 6, 13, 10, 0);
  const eightAm = 8 * 60;
  const sixPm = 18 * 60;

  group('upcomingReminders', () {
    test('empty when nothing is planned', () {
      expect(
        upcomingReminders(
            now: now, reminderMinutes: eightAm, entries: [], series: []),
        isEmpty,
      );
    });

    test('skips today when reminder time already passed', () {
      final entry =
          CalendarEntry(date: DateTime(2026, 6, 13), planId: 'p1');
      final result = upcomingReminders(
          now: now, reminderMinutes: eightAm, entries: [entry], series: []);
      expect(result, isEmpty);
    });

    test('includes today when reminder time is still ahead', () {
      final entry =
          CalendarEntry(date: DateTime(2026, 6, 13), planId: 'p1');
      final result = upcomingReminders(
          now: now, reminderMinutes: sixPm, entries: [entry], series: []);
      expect(result, hasLength(1));
      expect(result.first.dateTime, DateTime(2026, 6, 13, 18, 0));
      expect(result.first.planId, 'p1');
    });

    test('expands series within the window', () {
      final series = TrainingSeries(
        id: 's1',
        planId: 'sp',
        weekdays: {DateTime.tuesday, DateTime.thursday},
        startDate: DateTime(2026, 6, 13),
      );
      final result = upcomingReminders(
          now: now,
          reminderMinutes: eightAm,
          entries: [],
          series: [series],
          windowDays: 14);
      // Di 16., Do 18., Di 23., Do 25. — 4 Termine in 14 Tagen
      expect(result, hasLength(4));
      expect(result.first.dateTime, DateTime(2026, 6, 16, 8, 0));
      expect(result.last.dateTime, DateTime(2026, 6, 25, 8, 0));
    });

    test('respects window limit', () {
      final entry =
          CalendarEntry(date: DateTime(2026, 7, 20), planId: 'p1');
      final result = upcomingReminders(
          now: now,
          reminderMinutes: eightAm,
          entries: [entry],
          series: [],
          windowDays: 30);
      expect(result, isEmpty); // 20.07. liegt außerhalb von 30 Tagen
    });
  });
}
```

- [ ] **Step 2: Tests ausführen — müssen scheitern**

```powershell
flutter test test/core/models/reminder_planner_test.dart
```

- [ ] **Step 3: Implementieren** — `lib/core/models/reminder_planner.dart`:

```dart
import 'calendar_entry.dart';
import 'planned_day.dart';
import 'training_series.dart';

class ReminderOccurrence {
  final DateTime dateTime;
  final String planId;

  const ReminderOccurrence({required this.dateTime, required this.planId});
}

/// Berechnet die anstehenden Erinnerungstermine: für jeden geplanten
/// Trainingstag im Fenster von [windowDays] Tagen ab heute ein Termin zur
/// Uhrzeit [reminderMinutes] (Minuten seit Mitternacht). Termine, die vor
/// [now] liegen, entfallen.
List<ReminderOccurrence> upcomingReminders({
  required DateTime now,
  required int reminderMinutes,
  required List<CalendarEntry> entries,
  required List<TrainingSeries> series,
  int windowDays = 30,
}) {
  final result = <ReminderOccurrence>[];
  for (var i = 0; i < windowDays; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    final planned = resolveDay(day, entries, series);
    if (planned == null) continue;
    final at = DateTime(
        day.year, day.month, day.day, reminderMinutes ~/ 60, reminderMinutes % 60);
    if (!at.isAfter(now)) continue;
    result.add(ReminderOccurrence(dateTime: at, planId: planned.planId));
  }
  return result;
}
```

- [ ] **Step 4: Tests ausführen — müssen bestehen**

```powershell
flutter test test/core/models/reminder_planner_test.dart
```

- [ ] **Step 5: Commit**

```powershell
git add lib/core/models/reminder_planner.dart test/core/models/reminder_planner_test.dart
git commit -m "feat: add pure reminder occurrence planner"
```

---

### Task 6: Notifications — Dependencies, Android-Setup, Settings, Service, Wiring

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/build.gradle.kts`
- Modify: `lib/core/models/settings.dart`
- Create: `lib/core/services/notification_service.dart`
- Modify: `lib/core/providers/calendar_notifier.dart`
- Modify: `lib/core/providers/series_notifier.dart`
- Modify: `lib/app.dart`

- [ ] **Step 1: Dependencies hinzufügen** (pub add wählt aktuelle kompatible Versionen):

```powershell
flutter pub add flutter_local_notifications timezone flutter_timezone
```

Erwartet: drei neue Einträge in `pubspec.yaml` unter `dependencies`, `pub get` läuft fehlerfrei.

- [ ] **Step 2: AndroidManifest erweitern** — `android/app/src/main/AndroidManifest.xml`. Direkt nach den bestehenden `<uses-permission …>`-Zeilen (nach `READ_MEDIA_AUDIO`) einfügen:

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Innerhalb von `<application>` (direkt vor `</application>`, nach dem `flutterEmbedding`-`<meta-data>`) einfügen — nötig, damit geplante Notifications feuern und Geräte-Neustarts überleben:

```xml
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
```

- [ ] **Step 3: Core Library Desugaring aktivieren** (von flutter_local_notifications gefordert) — `android/app/build.gradle.kts`:

`compileOptions`-Block ersetzen:

```kotlin
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
```

Und am Dateiende (nach dem `flutter { … }`-Block) anfügen:

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

- [ ] **Step 4: `AppSettings` erweitern** — `lib/core/models/settings.dart`:

Felder ergänzen (nach `alarmSoundFile`):

```dart
  bool trainingReminderEnabled;
  int trainingReminderMinutes; // Minuten seit Mitternacht, Default 08:00
```

Konstruktor ergänzen:

```dart
    this.trainingReminderEnabled = false,
    this.trainingReminderMinutes = 480,
```

In `load()` ergänzen:

```dart
      trainingReminderEnabled: prefs.getBool('trainingReminderEnabled') ?? false,
      trainingReminderMinutes: prefs.getInt('trainingReminderMinutes') ?? 480,
```

In `save()` ergänzen:

```dart
    await prefs.setBool('trainingReminderEnabled', trainingReminderEnabled);
    await prefs.setInt('trainingReminderMinutes', trainingReminderMinutes);
```

- [ ] **Step 5: `NotificationService` anlegen** — `lib/core/services/notification_service.dart` (neues Verzeichnis `lib/core/services/`):

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/calendar_entry.dart';
import '../models/reminder_planner.dart';
import '../models/settings.dart';
import '../models/training_plan.dart';
import '../models/training_series.dart';
import '../providers/calendar_notifier.dart';
import '../providers/plan_library_notifier.dart';
import '../providers/series_notifier.dart';
import '../providers/settings_provider.dart';

/// Plant lokale Erinnerungen für geplante Trainingstage. Rollierendes
/// 30-Tage-Fenster, weil Serien unendlich sind: bei jedem App-Start und
/// nach jeder Änderung wird alles storniert und neu geplant.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      _initialized = true;
    } catch (_) {
      // Plattform ohne Notification-Support (Tests, Desktop) — still bleiben.
    }
    return _initialized;
  }

  /// Fragt die Android-13+-Notification-Permission an. true, wenn erteilt
  /// oder die Plattform keine Anfrage kennt.
  Future<bool> requestPermission() async {
    if (!await _ensureInitialized()) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? true;
  }

  Future<void> rescheduleAll({
    required AppSettings settings,
    required List<CalendarEntry> entries,
    required List<TrainingSeries> series,
    required List<TrainingPlan> plans,
  }) async {
    if (!await _ensureInitialized()) return;
    await _plugin.cancelAll();
    if (!settings.trainingReminderEnabled) return;

    final occurrences = upcomingReminders(
      now: DateTime.now(),
      reminderMinutes: settings.trainingReminderMinutes,
      entries: entries,
      series: series,
    );
    var id = 0;
    for (final occ in occurrences) {
      var planName = 'Training';
      for (final p in plans) {
        if (p.id == occ.planId) {
          planName = p.name;
          break;
        }
      }
      await _plugin.zonedSchedule(
        id++,
        'Training geplant',
        'Heute geplant: $planName',
        tz.TZDateTime.from(occ.dateTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'training_reminder',
            'Trainings-Erinnerung',
            channelDescription: 'Erinnert an geplante Trainings',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Plant alle Erinnerungen anhand der aktuellen Provider-Zustände neu.
/// Funktioniert mit `ref.read` aus Notifiern und Widgets.
Future<void> rescheduleReminders(ProviderReader read) async {
  final settings = read(settingsProvider).valueOrNull;
  if (settings == null) return;
  final entries = read(calendarProvider).valueOrNull ?? const <CalendarEntry>[];
  final series = read(seriesProvider).valueOrNull ?? const <TrainingSeries>[];
  final plans =
      read(planLibraryProvider).valueOrNull?.plans ?? const <TrainingPlan>[];
  await NotificationService.instance.rescheduleAll(
    settings: settings,
    entries: entries,
    series: series,
    plans: plans,
  );
}
```

- [ ] **Step 6: Notifier verdrahten.**

`lib/core/providers/calendar_notifier.dart` — Import ergänzen:

```dart
import '../services/notification_service.dart';
```

und in `setEntry` **und** `removeEntry` jeweils als letzte Zeile (nach `state = AsyncData(entries);`) anfügen:

```dart
    await rescheduleReminders(ref.read);
```

`lib/core/providers/series_notifier.dart` — Import ergänzen:

```dart
import '../services/notification_service.dart';
```

und in `addSeries`, `removeSeries` und `addException` jeweils als letzte Zeile (nach `state = AsyncData(list);`) anfügen:

```dart
    await rescheduleReminders(ref.read);
```

- [ ] **Step 7: App-Start-Hook** — `lib/app.dart` auf Riverpod umstellen und Reminder beim Start planen. Kompletter neuer Dateiinhalt:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'core/providers/calendar_notifier.dart';
import 'core/providers/plan_library_notifier.dart';
import 'core/providers/series_notifier.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/notification_service.dart';
import 'features/workout/workout_screen.dart';

class KettlebellApp extends ConsumerStatefulWidget {
  const KettlebellApp({super.key});

  @override
  ConsumerState<KettlebellApp> createState() => _KettlebellAppState();
}

class _KettlebellAppState extends ConsumerState<KettlebellApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the screen awake while the app is in the foreground.
    WakelockPlus.enable();
    _initReminders();
  }

  Future<void> _initReminders() async {
    // Erst alle Provider laden — beim Kaltstart sind sie noch leer.
    await ref.read(settingsProvider.future);
    await ref.read(calendarProvider.future);
    await ref.read(seriesProvider.future);
    await ref.read(planLibraryProvider.future);
    await rescheduleReminders(ref.read);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hold the wakelock only while resumed; release it when backgrounded so
    // the screen can sleep normally when the app isn't visible.
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kettlebell EMOM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B00),
          secondary: Color(0xFFFF6B00),
        ),
      ),
      home: const WorkoutScreen(),
    );
  }
}
```

- [ ] **Step 8: Analyze + Tests + Android-Build prüfen**

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Erwartet: keine Issues, alle Tests grün (der Service schluckt MissingPluginException in Tests), Debug-APK baut (verifiziert Desugaring + Manifest).

- [ ] **Step 9: Commit**

```powershell
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml android/app/build.gradle.kts lib/core/models/settings.dart lib/core/services/notification_service.dart lib/core/providers/calendar_notifier.dart lib/core/providers/series_notifier.dart lib/app.dart
git commit -m "feat: add training reminder notifications with rolling 30-day window"
```

---

### Task 7: Erinnerungs-Einstellungen im FeedbackTab

**Files:**
- Modify: `lib/features/config/widgets/feedback_tab.dart`

- [ ] **Step 1: Auf `ConsumerWidget` umstellen.** Imports ergänzen:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
```

Klassensignatur ändern — aus

```dart
class FeedbackTab extends StatelessWidget {
```

wird

```dart
class FeedbackTab extends ConsumerWidget {
```

und die `build`-Signatur — aus

```dart
  @override
  Widget build(BuildContext context) {
```

wird

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

- [ ] **Step 2: Hilfs-Widgets ergänzen** (in der Klasse, z.B. nach `_soundPickerRow`):

```dart
  String _formatMinutes(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  Widget _reminderTimeRow(BuildContext context, WidgetRef ref) => InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: settings.trainingReminderMinutes ~/ 60,
              minute: settings.trainingReminderMinutes % 60,
            ),
          );
          if (picked == null) return;
          settings.trainingReminderMinutes = picked.hour * 60 + picked.minute;
          onChanged();
          onSaved?.call();
          await rescheduleReminders(ref.read);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Uhrzeit',
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
              Row(
                children: [
                  Text(
                    _formatMinutes(settings.trainingReminderMinutes),
                    style: const TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right,
                      color: Colors.white12, size: 18),
                ],
              ),
            ],
          ),
        ),
      );
```

- [ ] **Step 3: Sektion einhängen.** In `build` am Ende der `Column`-`children` (nach dem Vibration-Toggle) ergänzen:

```dart
        _toggleRow('Trainings-Erinnerung', s.trainingReminderEnabled, (v) async {
          if (v && !await NotificationService.instance.requestPermission()) {
            return; // Permission verweigert — Toggle bleibt aus
          }
          s.trainingReminderEnabled = v;
          onChanged();
          onSaved?.call();
          await rescheduleReminders(ref.read);
        }),
        if (s.trainingReminderEnabled)
          _indentedGroup([
            _reminderTimeRow(context, ref),
          ]),
```

- [ ] **Step 4: Analyze + Tests**

```powershell
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```powershell
git add lib/features/config/widgets/feedback_tab.dart
git commit -m "feat: training reminder toggle and time picker in settings"
```

---

### Task 8: `DayEditorSheet` — Redesign (Plan-Liste, Serien-Toggle, Serientag)

**Files:**
- Modify: `lib/features/calendar/widgets/day_editor_sheet.dart` (komplett ersetzen)

**Kontext:** Drei Zustände: (1) normaler Tag ohne Eintrag, (2) Tag mit Einzeleintrag (auch Override eines Serientags — dann verhält er sich wie ein normaler Eintrag), (3) Serientag ohne Override (`seriesForDay != null`, nur dann sind `onExcludeDay`/`onDeleteSeries` gesetzt und der Serien-Toggle ist ausgeblendet). Plan-Auswahl ist eine vertikale Liste mit Radio-Ringen (max. ~4 sichtbar, scrollt intern).

- [ ] **Step 1: Datei komplett ersetzen:**

```dart
// lib/features/calendar/widgets/day_editor_sheet.dart
import 'package:flutter/material.dart';
import '../../../core/models/calendar_entry.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/training_series.dart';

class DayEditorSheet extends StatefulWidget {
  final DateTime date;
  final List<TrainingPlan> plans;
  final CalendarEntry? existing;

  /// Serie, die diesen Tag trifft — nur gesetzt, wenn KEIN Einzeleintrag
  /// existiert (Override-Tage verhalten sich wie normale Einträge).
  final TrainingSeries? seriesForDay;
  final void Function(CalendarEntry entry) onSaveEntry;
  final void Function(TrainingSeries series, String note) onCreateSeries;
  final VoidCallback? onDeleteEntry;
  final VoidCallback? onExcludeDay;
  final VoidCallback? onDeleteSeries;

  const DayEditorSheet({
    super.key,
    required this.date,
    required this.plans,
    required this.existing,
    required this.onSaveEntry,
    required this.onCreateSeries,
    this.seriesForDay,
    this.onDeleteEntry,
    this.onExcludeDay,
    this.onDeleteSeries,
  });

  @override
  State<DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<DayEditorSheet> {
  static const _orange = Color(0xFFFF6B00);
  static const _weekdayLabels = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  String? _selectedPlanId;
  late TextEditingController _noteController;
  bool _repeatWeekly = false;
  late Set<int> _weekdays;

  bool get _isSeriesDay => widget.seriesForDay != null;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.existing?.planId ?? widget.seriesForDay?.planId;
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _weekdays = {widget.date.weekday};
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return '${_weekdayLabels[d.weekday]}, ${d.day}. ${months[d.month]} ${d.year}';
  }

  String _seriesBadgeText(TrainingSeries s) {
    final days = s.weekdays.toList()..sort();
    return 'SERIE · ${days.map((d) => _weekdayLabels[d].toUpperCase()).join('/')}';
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11, color: Colors.white38, letterSpacing: 2));

  Widget _planRow(TrainingPlan plan) {
    final selected = _selectedPlanId == plan.id;
    final minutes = (plan.totalDurationSeconds / 60).round();
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = plan.id),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A1505) : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _orange.withValues(alpha: 0.6)
                : const Color(0xFF242424),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$minutes min · ${plan.intervals.length} Intervalle',
                    style: const TextStyle(fontSize: 10, color: Colors.white30),
                  ),
                ],
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _orange : const Color(0xFF333333),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: _orange, shape: BoxShape.circle),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekdayCircle(int wd) {
    final on = _weekdays.contains(wd);
    return GestureDetector(
      onTap: () => setState(() {
        if (on) {
          if (_weekdays.length > 1) _weekdays.remove(wd); // min. ein Tag
        } else {
          _weekdays.add(wd);
        }
      }),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? _orange : const Color(0xFF1A1A1A),
          border: Border.all(color: on ? _orange : const Color(0xFF2A2A2A)),
        ),
        child: Center(
          child: Text(
            _weekdayLabels[wd],
            style: TextStyle(
              fontSize: 11,
              fontWeight: on ? FontWeight.bold : FontWeight.normal,
              color: on ? Colors.black : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSeries() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Serie löschen?',
          style: TextStyle(
              color: Colors.white54, fontSize: 15, letterSpacing: 1),
        ),
        content: const Text(
          'Alle zukünftigen Serientage werden entfernt. Einzelne Tages-Einträge bleiben erhalten.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Abbrechen', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen',
                style: TextStyle(color: Color(0xFFFF5050))),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDeleteSeries?.call();
  }

  void _save() {
    final planId = _selectedPlanId;
    if (planId == null) return;
    final note = _noteController.text.trim();
    if (_repeatWeekly && !_isSeriesDay) {
      widget.onCreateSeries(
        TrainingSeries(
          id: TrainingSeries.newId(),
          planId: planId,
          weekdays: {..._weekdays},
          startDate: widget.date,
        ),
        note,
      );
    } else {
      widget.onSaveEntry(
        CalendarEntry(date: widget.date, planId: planId, note: note),
      );
    }
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
      child: SingleChildScrollView(
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
            // Datum + Serien-Badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(widget.date),
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white54, letterSpacing: 1),
                  ),
                ),
                if (_isSeriesDay)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🔁 ${_seriesBadgeText(widget.seriesForDay!)}',
                      style: const TextStyle(fontSize: 9, color: _orange),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Plan-Auswahl: vertikale Liste mit Radio-Ringen
            _label('TRAININGSPLAN'),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: widget.plans.map(_planRow).toList(),
              ),
            ),
            if (_isSeriesDay) ...[
              const SizedBox(height: 6),
              const Text(
                'Änderungen gelten nur für diesen Tag.',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
            if (!_isSeriesDay) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🔁 Wöchentlich wiederholen',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  Switch(
                    value: _repeatWeekly,
                    onChanged: (v) => setState(() => _repeatWeekly = v),
                    activeThumbColor: _orange,
                  ),
                ],
              ),
              if (_repeatWeekly) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var wd = 1; wd <= 7; wd++) _weekdayCircle(wd),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            // Notiz
            _label('NOTIZ'),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'z.B. Ernährung: abends Kohlenhydrate auffüllen',
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),
            // Speichern
            SizedBox(
              width: double.infinity,
              height: 48,
              child: GestureDetector(
                onTap: canSave ? _save : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: canSave ? _orange : const Color(0xFF222222),
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
            // Einzeleintrag entfernen
            if (widget.onDeleteEntry != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onDeleteEntry,
                  child: const Text(
                    'Eintrag entfernen',
                    style: TextStyle(fontSize: 13, color: Colors.white24),
                  ),
                ),
              ),
            ],
            // Serientag-Aktionen
            if (_isSeriesDay) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton(
                  onPressed: widget.onExcludeDay,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2A2A2A)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Diesen Tag ausnehmen',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _confirmDeleteSeries,
                  child: const Text(
                    'Serie löschen',
                    style: TextStyle(
                        fontSize: 12, color: Color(0x99FF5050)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze** — der `CalendarScreen` ruft das Sheet noch mit alter Signatur (`onSave`/`onDelete`) auf und bricht jetzt:

```powershell
flutter analyze
```

Erwartet: Fehler NUR in `lib/features/calendar/calendar_screen.dart` (alte Parameter). Das wird in Task 9 behoben — beide Tasks gehören zu einem Commit-Paar, aber wir committen erst, wenn Task 9 das Projekt wieder grün macht. **Kein Commit in diesem Task.**

---

### Task 9: `CalendarScreen` — Redesign „Monat + Agenda"

**Files:**
- Modify: `lib/features/calendar/calendar_screen.dart` (komplett ersetzen)

- [ ] **Step 1: Datei komplett ersetzen:**

```dart
// lib/features/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/calendar_entry.dart';
import '../../core/models/planned_day.dart';
import '../../core/models/settings.dart';
import '../../core/models/training_plan.dart';
import '../../core/models/training_series.dart';
import '../../core/providers/calendar_notifier.dart';
import '../../core/providers/plan_library_notifier.dart';
import '../../core/providers/series_notifier.dart';
import '../../core/providers/settings_provider.dart';
import '../workout/workout_notifier.dart';
import 'widgets/day_editor_sheet.dart';

const _orange = Color(0xFFFF6B00);
const _monthNames = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];
const _weekdayShort = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

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
        _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
      });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  TrainingSeries? _seriesFor(DateTime date, List<TrainingSeries> seriesList) {
    for (final s in seriesList.reversed) {
      if (s.occursOn(date)) return s;
    }
    return null;
  }

  String _planName(PlanLibrary? lib, String planId) {
    if (lib == null) return '';
    for (final p in lib.plans) {
      if (p.id == planId) return p.name;
    }
    return 'Unbekannter Plan';
  }

  String _dateLabel(DateTime d) =>
      '${_weekdayShort[d.weekday].toUpperCase()} ${d.day}. ${_monthNames[d.month].toUpperCase()}';

  // ───────────────────────── Tag-Editor ─────────────────────────

  void _openDay(DateTime date) {
    final libAsync = ref.read(planLibraryProvider);
    if (!libAsync.hasValue) return;
    final plans = libAsync.requireValue.plans;
    final existing = ref.read(calendarProvider.notifier).entryFor(date);
    final seriesList =
        ref.read(seriesProvider).valueOrNull ?? const <TrainingSeries>[];
    final seriesForDay = existing == null ? _seriesFor(date, seriesList) : null;

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
        seriesForDay: seriesForDay,
        onSaveEntry: (entry) {
          ref.read(calendarProvider.notifier).setEntry(entry);
          Navigator.pop(context);
        },
        onCreateSeries: (series, note) async {
          await ref.read(seriesProvider.notifier).addSeries(series);
          final cal = ref.read(calendarProvider.notifier);
          // Bestehender Einzeleintrag wird durch die Serie ersetzt;
          // eine Notiz bleibt als Tages-Override erhalten.
          if (existing != null) await cal.removeEntry(date);
          if (note.isNotEmpty) {
            await cal.setEntry(
                CalendarEntry(date: date, planId: series.planId, note: note));
          }
          if (context.mounted) Navigator.pop(context);
        },
        onDeleteEntry: existing == null
            ? null
            : () {
                ref.read(calendarProvider.notifier).removeEntry(date);
                Navigator.pop(context);
              },
        onExcludeDay: seriesForDay == null
            ? null
            : () {
                ref
                    .read(seriesProvider.notifier)
                    .addException(seriesForDay.id, date);
                Navigator.pop(context);
              },
        onDeleteSeries: seriesForDay == null
            ? null
            : () {
                ref.read(seriesProvider.notifier).removeSeries(seriesForDay.id);
                Navigator.pop(context);
              },
      ),
    );
  }

  // ─────────────────────── Training starten ───────────────────────

  Future<void> _startToday(PlannedDay planned) async {
    final lib = ref.read(planLibraryProvider).valueOrNull;
    if (lib == null) return;
    if (lib.activePlanId != planned.planId) {
      final workout = ref.read(workoutProvider).valueOrNull;
      final workoutActive = workout != null &&
          (workout.isRunning ||
              workout.waitingForConfirmation ||
              workout.currentMinute > 0);
      if (workoutActive) {
        final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
                title: const Text(
                  'Plan wechseln?',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 15, letterSpacing: 1),
                ),
                content: const Text(
                  'Das laufende Training wird zurückgesetzt.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Abbrechen',
                        style: TextStyle(color: Colors.white38)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Wechseln',
                        style: TextStyle(color: _orange)),
                  ),
                ],
              ),
            ) ??
            false;
        if (!ok) return;
      }
      await ref.read(planLibraryProvider.notifier).setActivePlan(planned.planId);
      await ref.read(workoutProvider.notifier).reset();
    }
    widget.onBack?.call();
  }

  // ───────────────────────── UI-Bausteine ─────────────────────────

  Widget _header() => Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                text: _monthNames[_displayMonth.month],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                children: [
                  TextSpan(
                    text: ' ${_displayMonth.year}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w300, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white38, size: 22),
            onPressed: _prevMonth,
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right, color: Colors.white38, size: 22),
            onPressed: _nextMonth,
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: Colors.white12,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white38, size: 20),
            tooltip: 'Zum Training',
            onPressed: widget.onBack,
          ),
        ],
      );

  Widget _todayCard(
    DateTime day,
    PlannedDay planned,
    String planName,
    List<TrainingSeries> seriesList,
    AppSettings? settings,
  ) {
    final metaParts = <String>[];
    if (planned.fromSeries) {
      for (final s in seriesList) {
        if (s.id == planned.seriesId) {
          final days = s.weekdays.toList()..sort();
          metaParts.add(
              '🔁 Serie · ${days.map((d) => _weekdayShort[d]).join(' / ')}');
          break;
        }
      }
    }
    if (settings != null && settings.trainingReminderEnabled) {
      final h = (settings.trainingReminderMinutes ~/ 60).toString().padLeft(2, '0');
      final m = (settings.trainingReminderMinutes % 60).toString().padLeft(2, '0');
      metaParts.add('🔔 $h:$m');
    }

    return GestureDetector(
      onTap: () => _openDay(day),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1505), Color(0xFF1A0D02)],
          ),
          border: Border.all(color: _orange.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HEUTE · ${_dateLabel(day)}',
              style: const TextStyle(
                  fontSize: 9, letterSpacing: 2, color: _orange),
            ),
            const SizedBox(height: 4),
            Text(
              planName,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            if (metaParts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                metaParts.join('  ·  '),
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
            if (planned.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📝 ${planned.note}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _startToday(planned),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.black, size: 20),
                      SizedBox(width: 4),
                      Text(
                        'Training starten',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upcomingCard(DateTime day, PlannedDay planned, String planName) {
    final suffix = planned.fromSeries ? ' 🔁' : '';
    final noteSuffix =
        planned.note.isNotEmpty ? '  ·  📝 ${planned.note}' : '';
    return GestureDetector(
      onTap: () => _openDay(day),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(color: const Color(0xFF222222)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateLabel(day),
              style: const TextStyle(
                  fontSize: 9, letterSpacing: 2, color: Colors.white24),
            ),
            const SizedBox(height: 2),
            Text(
              '$planName$suffix$noteSuffix',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _agendaCards(
    DateTime now,
    List<CalendarEntry> entries,
    List<TrainingSeries> seriesList,
    PlanLibrary? lib,
    AppSettings? settings,
  ) {
    final cards = <Widget>[];
    for (var i = 0; i < 14; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final planned = resolveDay(day, entries, seriesList);
      if (planned == null) continue;
      final planName = _planName(lib, planned.planId);
      cards.add(i == 0
          ? _todayCard(day, planned, planName, seriesList, settings)
          : _upcomingCard(day, planned, planName));
    }
    if (cards.isEmpty) {
      cards.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Tippe auf einen Tag, um ein Training zu planen.',
            style: TextStyle(fontSize: 12, color: Colors.white24),
          ),
        ),
      ));
    }
    return cards;
  }

  // ───────────────────────────── Build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final entries =
        ref.watch(calendarProvider).valueOrNull ?? const <CalendarEntry>[];
    final seriesList =
        ref.watch(seriesProvider).valueOrNull ?? const <TrainingSeries>[];
    final lib = ref.watch(planLibraryProvider).valueOrNull;
    final settings = ref.watch(settingsProvider).valueOrNull;

    final today = DateTime.now();
    final firstDay = _displayMonth;
    final daysInMonth = DateTime(firstDay.year, firstDay.month + 1, 0).day;
    // weekday: 1=Mon..7=Sun, we want Mon=0
    final startOffset = firstDay.weekday - 1;
    final totalCells = ((startOffset + daysInMonth) / 7).ceil() * 7;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _header(),
            const SizedBox(height: 10),
            // Weekday header
            Row(
              children: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white24,
                                letterSpacing: 1),
                          ),
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
                final date =
                    DateTime(firstDay.year, firstDay.month, dayNumber);
                final isToday = _sameDay(date, today);
                final isPast = date.isBefore(
                    DateTime(today.year, today.month, today.day));
                final planned = resolveDay(date, entries, seriesList);

                final dot = planned == null
                    ? const SizedBox(height: 7)
                    : Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.black
                              : planned.fromSeries
                                  ? _orange.withValues(alpha: 0.45)
                                  : _orange,
                          shape: BoxShape.circle,
                        ),
                      );

                final content = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 13,
                        color: isToday
                            ? Colors.black
                            : isPast
                                ? Colors.white24
                                : Colors.white70,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    dot,
                  ],
                );

                return GestureDetector(
                  onTap: () => _openDay(date),
                  behavior: HitTestBehavior.opaque,
                  child: isToday
                      ? Center(
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                                color: _orange, shape: BoxShape.circle),
                            child: content,
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.all(3), child: content),
                );
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'ANSTEHEND',
              style: TextStyle(
                  fontSize: 10, letterSpacing: 2, color: Colors.white38),
            ),
            const SizedBox(height: 8),
            ..._agendaCards(today, entries, seriesList, lib, settings),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze + Tests**

```powershell
flutter analyze
flutter test
```

Erwartet: No issues found, alle Tests grün (Task-8-Fehler sind jetzt behoben).

- [ ] **Step 3: Manuelle Sichtprüfung** (Emulator/Gerät):

```powershell
flutter run
```

Checkliste: Monat+Agenda sichtbar; Tag antippen öffnet neues Sheet; Serie anlegen (Toggle + Wochentage) → gedimmte Punkte an Serientagen; Serientag antippen → Badge + „Diesen Tag ausnehmen"/„Serie löschen"; Heute-Karte mit Start-Button erscheint, wenn heute ein Training geplant ist; Start-Button aktiviert Plan und wechselt zum Workout.

- [ ] **Step 4: Commit (Task 8 + 9 zusammen)**

```powershell
git add lib/features/calendar/widgets/day_editor_sheet.dart lib/features/calendar/calendar_screen.dart
git commit -m "feat: redesign calendar as month+agenda with series support in day editor"
```

---

### Task 10: „Heute geplant"-Chip im Workout-Screen

**Files:**
- Create: `lib/features/workout/widgets/planned_today_chip.dart`
- Modify: `lib/features/workout/workout_screen.dart`

- [ ] **Step 1: Chip-Widget anlegen** — `lib/features/workout/widgets/planned_today_chip.dart`:

```dart
import 'package:flutter/material.dart';

/// Dezenter Hinweis auf dem Workout-Screen: heute ist ein anderer Plan
/// geplant als der aktive. Tap aktiviert den geplanten Plan.
class PlannedTodayChip extends StatelessWidget {
  static const _orange = Color(0xFFFF6B00);

  final String planName;
  final VoidCallback onTap;

  const PlannedTodayChip({
    super.key,
    required this.planName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _orange.withValues(alpha: 0.12),
          border: Border.all(color: _orange.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available, size: 14, color: _orange),
            const SizedBox(width: 6),
            Text(
              'Heute geplant: $planName',
              style: const TextStyle(fontSize: 12, color: _orange),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: `workout_screen.dart` erweitern.**

Imports ergänzen (zu den bestehenden Imports):

```dart
import '../../core/models/planned_day.dart';
import '../../core/providers/calendar_notifier.dart';
import '../../core/providers/series_notifier.dart';
import 'widgets/planned_today_chip.dart';
```

Methode in `_WorkoutScreenState` ergänzen (z.B. nach `_showResetConfirmDialog`):

```dart
  Future<void> _activatePlannedPlan(String planId, WorkoutState state) async {
    final active = state.isRunning ||
        state.waitingForConfirmation ||
        state.currentMinute > 0;
    if (active) {
      final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Plan wechseln?',
                style: TextStyle(
                    color: Colors.white54, fontSize: 15, letterSpacing: 1),
              ),
              content: const Text(
                'Das laufende Training wird zurückgesetzt.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen',
                      style: TextStyle(color: Colors.white38)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Wechseln',
                      style: TextStyle(color: Color(0xFFFF6B00))),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
    }
    await ref.read(planLibraryProvider.notifier).setActivePlan(planId);
    await ref.read(workoutProvider.notifier).reset();
  }
```

In `_buildWorkoutScreen` direkt **vor** `return Padding(` einfügen:

```dart
    final entries =
        ref.watch(calendarProvider).valueOrNull ?? const [];
    final seriesList =
        ref.watch(seriesProvider).valueOrNull ?? const [];
    final lib = ref.watch(planLibraryProvider).valueOrNull;
    final planned = resolveDay(DateTime.now(), entries, seriesList);
    final plannedPlanName = (planned != null &&
            lib != null &&
            planned.planId != lib.activePlanId)
        ? lib.plans
            .where((p) => p.id == planned.planId)
            .map((p) => p.name)
            .firstOrNull
        : null;
```

Dafür oben in der Datei zusätzlich importieren:

```dart
import 'package:collection/collection.dart';
```

(`collection` ist transitive Flutter-Dependency, kein pubspec-Eintrag nötig.)

Und in der `children`-Liste direkt **nach** dem `PlanIndicator(...)`-Block einfügen:

```dart
          if (plannedPlanName != null) ...[
            const SizedBox(height: 8),
            PlannedTodayChip(
              planName: plannedPlanName,
              onTap: () => _activatePlannedPlan(planned!.planId, state),
            ),
          ],
```

- [ ] **Step 3: Analyze + Tests**

```powershell
flutter analyze
flutter test
```

- [ ] **Step 4: Commit**

```powershell
git add lib/features/workout/widgets/planned_today_chip.dart lib/features/workout/workout_screen.dart
git commit -m "feat: show planned-today chip on workout screen with 1-tap activation"
```

---

### Task 11: Endabnahme

- [ ] **Step 1: Volle Verifikation**

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Erwartet: No issues found, alle Tests grün, APK baut.

- [ ] **Step 2: Manueller Durchstich auf dem Gerät** (`flutter run`):

1. Serie Di/Do/Sa anlegen → gedimmte Punkte erscheinen, Agenda zeigt kommende Termine.
2. Einzelnen Serientag überschreiben (anderer Plan) → voller Punkt, Agenda zeigt Override.
3. Serientag ausnehmen → Punkt verschwindet.
4. Erinnerung in den Einstellungen aktivieren (Permission-Dialog erscheint auf Android 13+), Uhrzeit z.B. 2 Minuten in die Zukunft setzen, App in den Hintergrund → Notification „Heute geplant: …" kommt (inexakt, ±einige Minuten möglich).
5. „Training starten" auf der Heute-Karte → Plan aktiv, Workout-Seite.
6. Workout-Screen zeigt Chip, wenn der heutige geplante Plan nicht aktiv ist; Tap wechselt (mit Dialog, falls Training läuft).
7. Alte Ernährungsnotizen (falls vorhanden) erscheinen zusammengeführt im Notizfeld.

- [ ] **Step 3: Plan-Datei abhaken und committen**

```powershell
git add docs/superpowers/plans/2026-06-13-kalenderplanung-serien-redesign.md
git commit -m "docs: implementation plan for calendar series, reminders and redesign"
```

---

## Self-Review

**Spec-Abgleich:**

| Spec-Anforderung | Task |
|---|---|
| `TrainingSeries` (Plan, Wochentage, startDate, exceptions) + Persistenz | Task 2 |
| `CalendarEntry.note` + Migration pre/post | Task 1 |
| `resolveDay`: Einzeleintrag > jüngste Serie, Exceptions, startDate | Task 3 |
| `SeriesNotifier` (addSeries, removeSeries, addException) | Task 4 |
| Kalender: Monat + Agenda, Heute = oranger Kreis, volle/gedimmte Punkte | Task 9 |
| Heute-Karte mit Serie-Badge, 🔔-Zeit, Notiz, „Training starten" | Task 9 |
| Agenda 14 Tage, Folge-Karten, Leerzustand | Task 9 |
| Tag-Editor: vertikale Plan-Liste mit Radio-Ringen, scrollbar | Task 8 |
| Serien-Toggle + Wochentag-Kreise, angetippter Tag vorausgewählt | Task 8 |
| Serientag: Badge, Override-Hinweis, „Tag ausnehmen", „Serie löschen" + Dialog | Task 8 |
| Einzeleintrag → Serie ersetzt Eintrag, Notiz bleibt als Override | Task 9 (`onCreateSeries`) |
| Workout-Chip „Heute geplant" + 1-Tap-Aktivierung mit Reset-Dialog | Task 10 |
| Einstellungen: Toggle + Uhrzeit (Default 08:00), AppSettings-Felder | Tasks 6+7 |
| NotificationService, 30-Tage-Fenster, inexakt, POST_NOTIFICATIONS | Task 6 |
| Reschedule bei App-Start und jeder Änderung | Task 6 (Notifier-Wiring + app.dart) |
| Tests: Serialisierung, Migration, resolveDay, Terminberechnung | Tasks 1, 2, 3, 5 |

**Placeholder-Scan:** Vollständiger Code in jedem Schritt, keine TBDs.

**Type-Konsistenz:**
- `TrainingSeries.newId()` / `dateKey()` (Task 2) — verwendet in Tasks 4, 8 ✅
- `resolveDay(DateTime, List<CalendarEntry>, List<TrainingSeries>)` (Task 3) — verwendet in Tasks 5, 9, 10 ✅
- `seriesProvider` + Methoden `addSeries/removeSeries/addException` (Task 4) — verwendet in Tasks 6, 9 ✅
- `rescheduleReminders(ref.read)` mit `ProviderReader`-Typedef (Task 6) — aufgerufen aus Notifiern (Task 6) und Widgets (Task 7) ✅
- `DayEditorSheet`-Signatur (Task 8) — alle Parameter in Task 9 bedient ✅
- `AppSettings.trainingReminderEnabled/-Minutes` (Task 6) — verwendet in Tasks 7, 9 ✅
