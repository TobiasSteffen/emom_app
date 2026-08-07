# Weitere Sportarten & Gewichte — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the equipment/exercise model from 2 hardcoded types to 5 weight variants and 5 exercises selectable per interval, surfaced in the plan editor, workout screen, and history view.

**Architecture:** Expand `Equipment` enum from 2 to 5 values, add a new `Exercise` enum with extension methods, add `exercise` fields to `IntervalConfig` and `IntervalRecord`, replace the PopupMenu in `PlanMinuteRow` with a two-chip inline picker, and update the workout and history UIs to show the combined weight+exercise label.

**Tech Stack:** Flutter/Dart, Riverpod 2.x, SharedPreferences, json serialization via `toJson`/`fromJson`.

---

## File Map

| File | Change |
|------|--------|
| `lib/core/models/settings.dart` | Equipment 5 variants, Exercise enum, EquipmentX+ExerciseX extensions |
| `lib/core/models/training_plan.dart` | IntervalConfig.exercise field, migration, copyWith, pyramid(), planKey |
| `lib/core/models/workout_history.dart` | IntervalRecord.exercise field, kettlebellReps/steelMaceReps fix |
| `lib/features/plans/widgets/minute_row.dart` | Replace PopupMenu with two-chip inline picker |
| `lib/features/workout/workout_notifier.dart` | exerciseLabelForMinute, workoutLabelForMinute, IntervalRecord creation |
| `lib/features/workout/workout_screen.dart` | iconPath via equipment.iconPath |
| `lib/features/workout/widgets/reps_card.dart` | workoutLabel parameter instead of exerciseLabel |
| `lib/features/history/history_detail_sheet.dart` | isKb fix, per-interval weight+exercise, summary breakdown |
| `test/core/models/settings_test.dart` | New — enum extension tests |
| `test/core/models/training_plan_test.dart` | Update old Equipment refs, add exercise migration tests |
| `test/core/models/workout_history_test.dart` | Update equipment indices, add exercise field tests |

---

### Task 1: Equipment & Exercise enums + extensions (`settings.dart`)

**Files:**
- Modify: `lib/core/models/settings.dart`
- Create: `test/core/models/settings_test.dart`
- Modify: `test/core/models/training_plan_test.dart` (fix compile errors from enum rename)
- Modify: `test/core/models/workout_history_test.dart` (fix compile errors from enum rename)

- [ ] **Step 1: Write failing tests for the new enums**

Create `test/core/models/settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
  group('EquipmentX', () {
    test('isKettlebell: kb16/kb20/kb24 → true; sm8/sm12 → false', () {
      expect(Equipment.kb16.isKettlebell, isTrue);
      expect(Equipment.kb20.isKettlebell, isTrue);
      expect(Equipment.kb24.isKettlebell, isTrue);
      expect(Equipment.sm8.isKettlebell, isFalse);
      expect(Equipment.sm12.isKettlebell, isFalse);
    });

    test('label returns correct German string', () {
      expect(Equipment.kb16.label, 'KB 16kg');
      expect(Equipment.kb20.label, 'KB 20kg');
      expect(Equipment.kb24.label, 'KB 24kg');
      expect(Equipment.sm8.label, 'SM 8kg');
      expect(Equipment.sm12.label, 'SM 12kg');
    });

    test('iconPath returns kettlebell.png for KB variants, steelmace.png for SM', () {
      expect(Equipment.kb16.iconPath, 'assets/icon/kettlebell.png');
      expect(Equipment.kb24.iconPath, 'assets/icon/kettlebell.png');
      expect(Equipment.sm8.iconPath, 'assets/icon/steelmace.png');
      expect(Equipment.sm12.iconPath, 'assets/icon/steelmace.png');
    });

    test('defaultExercise: KB → swingBeidarmig; SM → mace360', () {
      expect(Equipment.kb16.defaultExercise, Exercise.swingBeidarmig);
      expect(Equipment.kb24.defaultExercise, Exercise.swingBeidarmig);
      expect(Equipment.sm8.defaultExercise, Exercise.mace360);
      expect(Equipment.sm12.defaultExercise, Exercise.mace360);
    });

    test('validExercises: KB has 4 exercises; SM has 1', () {
      expect(Equipment.kb20.validExercises, [
        Exercise.swingBeidarmig,
        Exercise.swingEinarmig,
        Exercise.snatch,
        Exercise.pushPress,
      ]);
      expect(Equipment.sm8.validExercises, [Exercise.mace360]);
    });
  });

  group('ExerciseX', () {
    test('label returns correct string', () {
      expect(Exercise.swingBeidarmig.label, 'Swing beidarmig');
      expect(Exercise.swingEinarmig.label, 'Swing einarmig');
      expect(Exercise.snatch.label, 'Snatch');
      expect(Exercise.pushPress.label, 'Push Press');
      expect(Exercise.mace360.label, '360s');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails to compile**

```powershell
flutter test test/core/models/settings_test.dart
```

Expected: compile error — `Equipment.kb16`, `Exercise` not defined yet.

- [ ] **Step 3: Implement the new enums and extensions in `settings.dart`**

Replace the current `enum Equipment { kettlebell, steelmace }` with the full implementation. The complete file:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Equipment { kb16, kb20, kb24, sm8, sm12 }

enum Exercise { swingBeidarmig, swingEinarmig, snatch, pushPress, mace360 }

extension EquipmentX on Equipment {
  bool get isKettlebell => index < 3;

  String get label {
    switch (this) {
      case Equipment.kb16: return 'KB 16kg';
      case Equipment.kb20: return 'KB 20kg';
      case Equipment.kb24: return 'KB 24kg';
      case Equipment.sm8:  return 'SM 8kg';
      case Equipment.sm12: return 'SM 12kg';
    }
  }

  String get iconPath =>
      isKettlebell ? 'assets/icon/kettlebell.png' : 'assets/icon/steelmace.png';

  Exercise get defaultExercise =>
      isKettlebell ? Exercise.swingBeidarmig : Exercise.mace360;

  List<Exercise> get validExercises => isKettlebell
      ? [Exercise.swingBeidarmig, Exercise.swingEinarmig, Exercise.snatch, Exercise.pushPress]
      : [Exercise.mace360];
}

extension ExerciseX on Exercise {
  String get label {
    switch (this) {
      case Exercise.swingBeidarmig: return 'Swing beidarmig';
      case Exercise.swingEinarmig:  return 'Swing einarmig';
      case Exercise.snatch:         return 'Snatch';
      case Exercise.pushPress:      return 'Push Press';
      case Exercise.mace360:        return '360s';
    }
  }
}

Color phaseColorForMinute(int minute) {
  if (minute < 5) return const Color(0xFF4CAF50);
  if (minute < 15) return const Color(0xFFFF6B00);
  if (minute < 20) return const Color(0xFFFF0000);
  if (minute < 25) return const Color(0xFFFF6B00);
  return const Color(0xFF4CAF50);
}

class AppSettings {
  bool vibrationEnabled;
  bool warningTonesEnabled;
  bool alarmEnabled;
  bool volumeBoostEnabled;
  double volumeBoostLevel;
  String countdownSoundFile;
  String alarmSoundFile;

  AppSettings({
    this.vibrationEnabled = true,
    this.warningTonesEnabled = true,
    this.alarmEnabled = true,
    this.volumeBoostEnabled = true,
    this.volumeBoostLevel = 1.0,
    this.countdownSoundFile = 'tick.wav',
    this.alarmSoundFile = 'alarm.wav',
  });

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      vibrationEnabled: prefs.getBool('vibrationEnabled') ?? true,
      warningTonesEnabled: prefs.getBool('warningTonesEnabled') ?? true,
      alarmEnabled: prefs.getBool('alarmEnabled') ?? true,
      volumeBoostEnabled: prefs.getBool('volumeBoostEnabled') ?? true,
      volumeBoostLevel: prefs.getDouble('volumeBoostLevel') ?? 1.0,
      countdownSoundFile: prefs.getString('countdownSoundFile') ?? 'tick.wav',
      alarmSoundFile: prefs.getString('alarmSoundFile') ?? 'alarm.wav',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrationEnabled', vibrationEnabled);
    await prefs.setBool('warningTonesEnabled', warningTonesEnabled);
    await prefs.setBool('alarmEnabled', alarmEnabled);
    await prefs.setBool('volumeBoostEnabled', volumeBoostEnabled);
    await prefs.setDouble('volumeBoostLevel', volumeBoostLevel);
    await prefs.setString('countdownSoundFile', countdownSoundFile);
    await prefs.setString('alarmSoundFile', alarmSoundFile);
  }
}
```

- [ ] **Step 4: Fix compile errors in existing test files**

`test/core/models/training_plan_test.dart` references `Equipment.steelmace` and `Equipment.kettlebell`. Replace both occurrences:

In `IntervalConfig serializes and deserializes correctly`:
- `Equipment.steelmace` → `Equipment.sm12`

In `IntervalConfig copyWith overrides only specified fields`:
- `Equipment.kettlebell` → `Equipment.kb24`

The full updated test file:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
  group('IntervalConfig', () {
    test('serializes and deserializes correctly', () {
      final iv = IntervalConfig(
        reps: 10,
        durationSeconds: 45,
        equipment: Equipment.sm12,
        exercise: Exercise.mace360,
      );
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.reps, 10);
      expect(restored.durationSeconds, 45);
      expect(restored.equipment, Equipment.sm12);
      expect(restored.exercise, Exercise.mace360);
    });

    test('copyWith overrides only specified fields', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
      );
      final copy = iv.copyWith(reps: 8);
      expect(copy.reps, 8);
      expect(copy.durationSeconds, 60);
      expect(copy.equipment, Equipment.kb24);
      expect(copy.exercise, Exercise.swingBeidarmig);
    });

    test('copyWith can override exercise', () {
      final iv = IntervalConfig(
        reps: 5,
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
      );
      final copy = iv.copyWith(exercise: Exercise.snatch);
      expect(copy.exercise, Exercise.snatch);
      expect(copy.equipment, Equipment.kb24);
    });

    test('migration: old e=0 (kettlebell) → kb24 + swingBeidarmig', () {
      final json = {'r': 12, 'd': 60, 'e': 0}; // old format, no 'x' key
      final iv = IntervalConfig.fromJson(json);
      expect(iv.equipment, Equipment.kb24);
      expect(iv.exercise, Exercise.swingBeidarmig);
    });

    test('migration: old e=1 (steelmace) → sm12 + mace360', () {
      final json = {'r': 8, 'd': 60, 'e': 1}; // old format, no 'x' key
      final iv = IntervalConfig.fromJson(json);
      expect(iv.equipment, Equipment.sm12);
      expect(iv.exercise, Exercise.mace360);
    });

    test('new format with x key reads equipment and exercise correctly', () {
      final json = {'r': 15, 'd': 45, 'e': 1, 'x': 2}; // kb20, snatch
      final iv = IntervalConfig.fromJson(json);
      expect(iv.equipment, Equipment.kb20);
      expect(iv.exercise, Exercise.snatch);
    });
  });

  group('TrainingPlan', () {
    test('pyramid() creates 30 intervals with correct reps', () {
      final plan = TrainingPlan.pyramid('Test');
      expect(plan.intervals.length, 30);
      expect(plan.intervals[0].reps, 5);
      expect(plan.intervals[14].reps, 15);
      expect(plan.intervals[29].reps, 10);
    });

    test('pyramid() uses kb24 + swingBeidarmig as default', () {
      final plan = TrainingPlan.pyramid('Test');
      expect(plan.intervals[0].equipment, Equipment.kb24);
      expect(plan.intervals[0].exercise, Exercise.swingBeidarmig);
    });

    test('totalReps sums all interval reps', () {
      final plan = TrainingPlan.pyramid('Test');
      const expected = 5*5 + (6+7+8+9+10+11+12+13+14+15) + 15*5 + (14+13+12+11+10) + 10*5;
      expect(plan.totalReps, expected);
    });

    test('totalDurationSeconds sums all intervals', () {
      final plan = TrainingPlan.pyramid('Test');
      expect(plan.totalDurationSeconds, 30 * 60);
    });

    test('planKey changes when a rep value changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].reps = 99;
      expect(plan.planKey, isNot(key1));
    });

    test('planKey changes when exercise changes', () {
      final plan = TrainingPlan.pyramid('Test');
      final key1 = plan.planKey;
      plan.intervals[0].exercise = Exercise.snatch;
      expect(plan.planKey, isNot(key1));
    });

    test('serializes and deserializes correctly', () {
      final plan = TrainingPlan.pyramid('Mein Plan');
      final restored = TrainingPlan.fromJson(plan.toJson());
      expect(restored.id, plan.id);
      expect(restored.name, 'Mein Plan');
      expect(restored.intervals.length, 30);
      expect(restored.intervals[0].reps, plan.intervals[0].reps);
      expect(restored.intervals[0].exercise, Exercise.swingBeidarmig);
    });
  });

  group('PlanLibrary', () {
    test('activePlan returns the plan matching activePlanId', () {
      final lib = PlanLibrary.defaultLibrary();
      expect(lib.activePlan.id, lib.activePlanId);
    });

    test('serializes and deserializes correctly', () {
      final lib = PlanLibrary.defaultLibrary();
      final restored = PlanLibrary.fromJson(lib.toJson());
      expect(restored.plans.length, 1);
      expect(restored.activePlanId, lib.activePlanId);
      expect(restored.activePlan.name, 'Standard');
    });

    test('activePlan falls back to first plan when activePlanId unknown', () {
      final plan = TrainingPlan.pyramid('Test');
      final lib = PlanLibrary(plans: [plan], activePlanId: 'unknown-id');
      expect(lib.activePlan.id, plan.id);
    });
  });
}
```

`test/core/models/workout_history_test.dart` — the test `'totalReps, kettlebellReps, steelMaceReps computed correctly'` uses `equipment: 1` for steel mace. With the new enum, index 1 = kb20 (kettlebell). Update that test to use `equipment: 3` (sm8) for steel mace. Also update the serialization round-trip test which uses `equipment: 1`. The full updated file:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emom_app/core/models/workout_history.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkoutHistory', () {
    test('load returns empty list when no data stored', () async {
      final records = await WorkoutHistory.load();
      expect(records, isEmpty);
    });

    test('addOrUpdateRecord saves and load retrieves it', () async {
      final record = WorkoutRecord(
        timestamp: 1000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 10, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 12, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      );

      await WorkoutHistory.addOrUpdateRecord(record);
      final records = await WorkoutHistory.load();

      expect(records.length, 1);
      expect(records[0].timestamp, 1000);
      expect(records[0].intervals.length, 2);
      expect(records[0].totalReps, 22);
    });

    test('addOrUpdateRecord updates existing record with same timestamp', () async {
      const t = 2000;
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: t,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 6, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      ));
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: t,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 6, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 7, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      ));

      final records = await WorkoutHistory.load();
      expect(records.length, 1);
      expect(records[0].intervals.length, 3);
    });

    test('newest record appears first', () async {
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: 1000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 5, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      ));
      await WorkoutHistory.addOrUpdateRecord(WorkoutRecord(
        timestamp: 2000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 8, durationSeconds: 60, equipment: 0, exercise: 0),
          IntervalRecord(reps: 8, durationSeconds: 60, equipment: 0, exercise: 0),
        ],
      ));

      final records = await WorkoutHistory.load();
      expect(records[0].timestamp, 2000);
      expect(records[1].timestamp, 1000);
    });

    test('totalReps, kettlebellReps, steelMaceReps computed correctly', () async {
      final record = WorkoutRecord(
        timestamp: 3000,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 10, durationSeconds: 60, equipment: 2, exercise: 0), // kb24
          IntervalRecord(reps: 8, durationSeconds: 60, equipment: 3, exercise: 4),  // sm8
          IntervalRecord(reps: 6, durationSeconds: 60, equipment: 2, exercise: 0),  // kb24
        ],
      );

      expect(record.totalReps, 24);
      expect(record.kettlebellReps, 16); // equipment < 3
      expect(record.steelMaceReps, 8);   // equipment >= 3
      expect(record.totalDurationSeconds, 180);
    });

    test('serialization round-trip preserves all fields including exercise', () {
      final original = WorkoutRecord(
        timestamp: 9999,
        planMode: 1,
        intervals: [
          IntervalRecord(reps: 15, durationSeconds: 45, equipment: 4, exercise: 4), // sm12, mace360
          IntervalRecord(reps: 10, durationSeconds: 60, equipment: 1, exercise: 2), // kb20, snatch
        ],
      );
      final restored = WorkoutRecord.fromJson(original.toJson());

      expect(restored.timestamp, 9999);
      expect(restored.planMode, 1);
      expect(restored.intervals.length, 2);
      expect(restored.intervals[0].reps, 15);
      expect(restored.intervals[0].equipment, 4);
      expect(restored.intervals[0].exercise, 4);
      expect(restored.intervals[1].exercise, 2);
    });

    test('fromJson with missing exercise key defaults to 0 (swingBeidarmig)', () {
      final json = {'r': 10, 'd': 60, 'e': 2}; // old record without 'x'
      final iv = IntervalRecord.fromJson(json);
      expect(iv.exercise, 0);
    });
  });
}
```

- [ ] **Step 5: Run all tests — expect compile errors in training_plan_test.dart**

```powershell
flutter test test/core/models/
```

Expected: compile errors because `training_plan.dart` still references the old `IntervalConfig` constructor (no `exercise` field yet). The `settings_test.dart` should now pass since settings.dart is done.

- [ ] **Step 6: Commit settings.dart changes and updated test files**

```powershell
git add lib/core/models/settings.dart test/core/models/settings_test.dart test/core/models/training_plan_test.dart test/core/models/workout_history_test.dart
git commit -m "feat: Equipment 5 variants, Exercise enum + EquipmentX/ExerciseX extensions; update test files"
```

---

### Task 2: Add `exercise` field to `IntervalConfig` (`training_plan.dart`)

**Files:**
- Modify: `lib/core/models/training_plan.dart`

The tests for this task were already written in the updated `training_plan_test.dart` in Task 1.

- [ ] **Step 1: Run the training_plan tests to confirm current failures**

```powershell
flutter test test/core/models/training_plan_test.dart
```

Expected: compile errors — `IntervalConfig` constructor missing `exercise`, `Equipment.sm12` etc. exists now (from Task 1) but `IntervalConfig` still lacks the field.

- [ ] **Step 2: Implement the updated `training_plan.dart`**

The complete updated file:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'settings.dart';

class IntervalConfig {
  int reps;
  int durationSeconds;
  Equipment equipment;
  Exercise exercise;

  IntervalConfig({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
    required this.exercise,
  });

  Map<String, dynamic> toJson() => {
    'r': reps,
    'd': durationSeconds,
    'e': equipment.index,
    'x': exercise.index,
  };

  factory IntervalConfig.fromJson(Map<String, dynamic> j) {
    final Equipment eq;
    final Exercise ex;
    if (j.containsKey('x')) {
      // New format: e = new Equipment index, x = Exercise index
      eq = Equipment.values.elementAtOrNull(j['e'] as int) ?? Equipment.kb24;
      ex = Exercise.values.elementAtOrNull(j['x'] as int) ?? eq.defaultExercise;
    } else {
      // Old format migration: e=0 → kb24+swingBeidarmig, e=1 → sm12+mace360
      final oldE = j['e'] as int;
      eq = oldE == 0 ? Equipment.kb24 : Equipment.sm12;
      ex = eq.defaultExercise;
    }
    return IntervalConfig(
      reps: j['r'] as int,
      durationSeconds: j['d'] as int,
      equipment: eq,
      exercise: ex,
    );
  }

  IntervalConfig copyWith({
    int? reps,
    int? durationSeconds,
    Equipment? equipment,
    Exercise? exercise,
  }) =>
      IntervalConfig(
        reps: reps ?? this.reps,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        equipment: equipment ?? this.equipment,
        exercise: exercise ?? this.exercise,
      );
}

class TrainingPlan {
  final String id;
  String name;
  List<IntervalConfig> intervals; // immer genau 30 Einträge

  TrainingPlan({
    required this.id,
    required this.name,
    required this.intervals,
  }) : assert(intervals.length == 30);

  int get totalReps => intervals.fold(0, (s, iv) => s + iv.reps);
  int get totalDurationSeconds => intervals.fold(0, (s, iv) => s + iv.durationSeconds);

  String get planKey => intervals
      .map((iv) => '${iv.reps},${iv.durationSeconds},${iv.equipment.index},${iv.exercise.index}')
      .join('|');

  static String _newId() {
    final r = Random();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  static List<int> _pyramidReps() => [
    5,5,5,5,5, 6,7,8,9,10,11,12,13,14,15, 15,15,15,15,15, 14,13,12,11,10, 10,10,10,10,10,
  ];

  factory TrainingPlan.pyramid(String name) {
    final reps = _pyramidReps();
    return TrainingPlan(
      id: _newId(),
      name: name,
      intervals: List.generate(30, (i) => IntervalConfig(
        reps: reps[i],
        durationSeconds: 60,
        equipment: Equipment.kb24,
        exercise: Exercise.swingBeidarmig,
      )),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'intervals': intervals.map((iv) => iv.toJson()).toList(),
  };

  factory TrainingPlan.fromJson(Map<String, dynamic> j) => TrainingPlan(
    id: j['id'] as String,
    name: j['name'] as String,
    intervals: (j['intervals'] as List)
        .map((e) => IntervalConfig.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PlanLibrary {
  final List<TrainingPlan> plans;
  final String activePlanId;

  const PlanLibrary({required this.plans, required this.activePlanId});

  TrainingPlan get activePlan {
    if (plans.isEmpty) throw StateError('PlanLibrary has no plans');
    return plans.firstWhere((p) => p.id == activePlanId, orElse: () => plans.first);
  }

  Map<String, dynamic> toJson() => {
    'plans': plans.map((p) => p.toJson()).toList(),
    'activePlanId': activePlanId,
  };

  factory PlanLibrary.fromJson(Map<String, dynamic> j) {
    final plans = (j['plans'] as List)
        .map((e) => TrainingPlan.fromJson(e as Map<String, dynamic>))
        .toList();
    return PlanLibrary(
      plans: plans,
      activePlanId: j['activePlanId'] as String,
    );
  }

  static PlanLibrary defaultLibrary() {
    final plan = TrainingPlan.pyramid('Standard');
    return PlanLibrary(plans: [plan], activePlanId: plan.id);
  }
}

class PlanLibraryStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/plans.json');
  }

  static Future<PlanLibrary> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return PlanLibrary.defaultLibrary();
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return PlanLibrary.fromJson(json);
    } catch (_) {
      return PlanLibrary.defaultLibrary();
    }
  }

  static Future<void> save(PlanLibrary library) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(library.toJson()));
    } catch (_) {}
  }
}
```

- [ ] **Step 3: Run training_plan tests**

```powershell
flutter test test/core/models/training_plan_test.dart
```

Expected: all tests PASS.

- [ ] **Step 4: Commit**

```powershell
git add lib/core/models/training_plan.dart
git commit -m "feat: IntervalConfig gains exercise field with lazy migration from old format"
```

---

### Task 3: Add `exercise` field to `IntervalRecord` (`workout_history.dart`)

**Files:**
- Modify: `lib/core/models/workout_history.dart`

Tests were already updated in Task 1.

- [ ] **Step 1: Run the workout_history tests to see current failures**

```powershell
flutter test test/core/models/workout_history_test.dart
```

Expected: compile errors — `IntervalRecord` constructor doesn't have `exercise` parameter yet; `kettlebellReps`/`steelMaceReps` still use old logic.

- [ ] **Step 2: Implement the updated `workout_history.dart`**

Complete file:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class IntervalRecord {
  final int reps;
  final int durationSeconds;
  final int equipment; // Equipment enum index
  final int exercise;  // Exercise enum index, 0 = swingBeidarmig

  IntervalRecord({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
    this.exercise = 0,
  });

  Map<String, dynamic> toJson() => {
    'r': reps,
    'd': durationSeconds,
    'e': equipment,
    'x': exercise,
  };

  factory IntervalRecord.fromJson(Map<String, dynamic> j) => IntervalRecord(
    reps: j['r'] as int,
    durationSeconds: j['d'] as int,
    equipment: j['e'] as int,
    exercise: (j['x'] as int?) ?? 0,
  );
}

class WorkoutRecord {
  final int timestamp; // milliseconds since epoch
  final int planMode; // 0 = phaseBased, 1 = minuteExact
  final List<IntervalRecord> intervals;

  WorkoutRecord({
    required this.timestamp,
    required this.planMode,
    required this.intervals,
  });

  int get totalReps => intervals.fold(0, (a, b) => a + b.reps);
  int get totalDurationSeconds => intervals.fold(0, (a, b) => a + b.durationSeconds);
  int get kettlebellReps => intervals.where((i) => i.equipment < 3).fold(0, (a, b) => a + b.reps);
  int get steelMaceReps => intervals.where((i) => i.equipment >= 3).fold(0, (a, b) => a + b.reps);

  Map<String, dynamic> toJson() => {
    't': timestamp,
    'pm': planMode,
    'iv': intervals.map((i) => i.toJson()).toList(),
  };

  factory WorkoutRecord.fromJson(Map<String, dynamic> j) => WorkoutRecord(
    timestamp: j['t'] as int,
    planMode: j['pm'] as int,
    intervals: (j['iv'] as List)
        .map((e) => IntervalRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class WorkoutHistory {
  static const _key = 'workoutHistory';
  static const _maxEntries = 300;

  static Future<List<WorkoutRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => WorkoutRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addOrUpdateRecord(WorkoutRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await load();
    final idx = records.indexWhere((r) => r.timestamp == record.timestamp);
    if (idx >= 0) {
      records[idx] = record;
    } else {
      records.insert(0, record);
      if (records.length > _maxEntries) records.removeLast();
    }
    await prefs.setString(
      _key,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }
}
```

- [ ] **Step 3: Run workout_history tests**

```powershell
flutter test test/core/models/workout_history_test.dart
```

Expected: all tests PASS.

- [ ] **Step 4: Run all model tests**

```powershell
flutter test test/core/models/
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/models/workout_history.dart
git commit -m "feat: IntervalRecord gains exercise field; fix kettlebellReps/steelMaceReps for 5-variant enum"
```

---

### Task 4: Two-chip inline picker in `PlanMinuteRow` (`minute_row.dart`)

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`

This is a UI widget — no unit tests. Verify manually by running the app.

- [ ] **Step 1: Implement the new `minute_row.dart`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';

Widget _stepButton(IconData icon, VoidCallback? onTap, {double size = 26}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(size / 4),
        ),
        child: Icon(icon,
            size: size / 2,
            color: onTap != null ? Colors.white38 : Colors.white12),
      ),
    );

class PlanMinuteRow extends StatefulWidget {
  final int index;
  final TrainingPlan plan;
  final VoidCallback onChanged;
  final bool isSelected;
  final VoidCallback onSelect;

  const PlanMinuteRow({
    super.key,
    required this.index,
    required this.plan,
    required this.onChanged,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<PlanMinuteRow> createState() => _PlanMinuteRowState();
}

class _PlanMinuteRowState extends State<PlanMinuteRow> {
  // null | 'equipment' | 'exercise'
  String? _openPicker;

  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  void _togglePicker(String picker) {
    setState(() {
      _openPicker = _openPicker == picker ? null : picker;
    });
  }

  Widget _smallStepBtn(IconData icon, VoidCallback? onTap) =>
      _stepButton(icon, onTap, size: 32);

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF6B00) : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(4),
            border: active ? null : Border.all(color: Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? Colors.black : Colors.white54,
            ),
          ),
        ),
      );

  Widget _pickerBtn({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF6B00) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(6),
            border: selected ? null : Border.all(color: Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.black : Colors.white54,
            ),
          ),
        ),
      );

  Widget _equipmentPicker(IntervalConfig iv) {
    void selectEquipment(Equipment eq) => _update(() {
      final wasKb = iv.equipment.isKettlebell;
      iv.equipment = eq;
      if (wasKb != eq.isKettlebell) {
        iv.exercise = eq.defaultExercise;
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Image.asset('assets/icon/kettlebell.png',
                width: 14, height: 14, color: Colors.white38),
            const SizedBox(width: 8),
            _pickerBtn(label: '16 kg', selected: iv.equipment == Equipment.kb16,
                onTap: () => selectEquipment(Equipment.kb16)),
            const SizedBox(width: 6),
            _pickerBtn(label: '20 kg', selected: iv.equipment == Equipment.kb20,
                onTap: () => selectEquipment(Equipment.kb20)),
            const SizedBox(width: 6),
            _pickerBtn(label: '24 kg', selected: iv.equipment == Equipment.kb24,
                onTap: () => selectEquipment(Equipment.kb24)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Image.asset('assets/icon/steelmace.png',
                width: 14, height: 14, color: Colors.white38),
            const SizedBox(width: 8),
            _pickerBtn(label: '8 kg', selected: iv.equipment == Equipment.sm8,
                onTap: () => selectEquipment(Equipment.sm8)),
            const SizedBox(width: 6),
            _pickerBtn(label: '12 kg', selected: iv.equipment == Equipment.sm12,
                onTap: () => selectEquipment(Equipment.sm12)),
          ]),
        ],
      ),
    );
  }

  Widget _exercisePicker(IntervalConfig iv) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: iv.equipment.validExercises.map((ex) {
            return _pickerBtn(
              label: ex.label,
              selected: iv.exercise == ex,
              onTap: () => _update(() => iv.exercise = ex),
            );
          }).toList(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final iv = widget.plan.intervals[widget.index];
    final i = widget.index;
    final color = phaseColorForMinute(i);

    return GestureDetector(
      onTap: widget.onSelect,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    'Min ${i + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        color: widget.isSelected
                            ? Colors.white38
                            : Colors.white24,
                        letterSpacing: 1),
                  ),
                ),
                const Spacer(),
                if (widget.isSelected) ...[
                  _chip(
                    label: iv.equipment.label,
                    active: _openPicker == 'equipment',
                    onTap: () => _togglePicker('equipment'),
                  ),
                  const SizedBox(width: 6),
                  _chip(
                    label: iv.exercise.label,
                    active: _openPicker == 'exercise',
                    onTap: () => _togglePicker('exercise'),
                  ),
                  const SizedBox(width: 8),
                  const Text('R',
                      style: TextStyle(fontSize: 13, color: Colors.white38)),
                  const SizedBox(width: 3),
                  _smallStepBtn(Icons.remove,
                      iv.reps > 1 ? () => _update(() => iv.reps--) : null),
                  SizedBox(
                    width: 30,
                    child: Center(
                      child: Text('${iv.reps}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54)),
                    ),
                  ),
                  _smallStepBtn(Icons.add, () => _update(() => iv.reps++)),
                  const SizedBox(width: 8),
                  const Text('s',
                      style: TextStyle(fontSize: 13, color: Colors.white38)),
                  const SizedBox(width: 3),
                  _smallStepBtn(
                      Icons.remove,
                      iv.durationSeconds > 30
                          ? () => _update(() => iv.durationSeconds =
                              (iv.durationSeconds - 5).clamp(30, 9999))
                          : null),
                  SizedBox(
                    width: 34,
                    child: Center(
                      child: Text('${iv.durationSeconds}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54)),
                    ),
                  ),
                  _smallStepBtn(
                      Icons.add, () => _update(() => iv.durationSeconds += 5)),
                ] else ...[
                  Image.asset(iv.equipment.iconPath,
                      width: 14, height: 14, color: Colors.white24),
                  const SizedBox(width: 4),
                  Text(iv.equipment.label,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white24)),
                  const SizedBox(width: 6),
                  Text(iv.exercise.label,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white24)),
                  const SizedBox(width: 6),
                  Text('${iv.reps}R',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white24)),
                  const SizedBox(width: 6),
                  Text('${iv.durationSeconds}s',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white24)),
                ],
              ],
            ),
          ),
          if (widget.isSelected && _openPicker == 'equipment')
            _equipmentPicker(iv),
          if (widget.isSelected && _openPicker == 'exercise')
            _exercisePicker(iv),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run `flutter analyze` to check for compile errors**

```powershell
flutter analyze lib/features/plans/widgets/minute_row.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```powershell
git add lib/features/plans/widgets/minute_row.dart
git commit -m "feat: replace equipment PopupMenu with two-chip inline picker (equipment + exercise)"
```

---

### Task 5: Update `workout_notifier.dart`

**Files:**
- Modify: `lib/features/workout/workout_notifier.dart`

- [ ] **Step 1: Update the three affected parts of `workout_notifier.dart`**

**Part A** — `exerciseLabelForMinute`: was hardcoded to 'Swings'/'360s', now uses `exercise.label`.

**Part B** — add `workoutLabelForMinute` returning combined label.

**Part C** — `_onMinuteComplete`: pass `exercise.index` to `IntervalRecord`.

Make the following three edits:

Replace the `exerciseLabelForMinute` method (currently at line ~169–171):
```dart
// OLD:
String exerciseLabelForMinute(int minute) =>
    equipmentForMinute(minute) == Equipment.kettlebell ? 'Swings' : '360s';

// NEW:
String exerciseLabelForMinute(int minute) =>
    _activePlan.intervals[minute].exercise.label;

String workoutLabelForMinute(int minute) {
  final iv = _activePlan.intervals[minute];
  return '${iv.equipment.label} · ${iv.exercise.label}';
}
```

Replace the `IntervalRecord(...)` construction in `_onMinuteComplete` (currently at lines ~200–206):
```dart
// OLD:
IntervalRecord(
  reps: s.currentReps,
  durationSeconds: s.currentDuration,
  equipment: equipmentForMinute(s.currentMinute).index,
),

// NEW:
IntervalRecord(
  reps: s.currentReps,
  durationSeconds: s.currentDuration,
  equipment: equipmentForMinute(s.currentMinute).index,
  exercise: _activePlan.intervals[s.currentMinute].exercise.index,
),
```

- [ ] **Step 2: Run `flutter analyze`**

```powershell
flutter analyze lib/features/workout/workout_notifier.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```powershell
git add lib/features/workout/workout_notifier.dart
git commit -m "feat: exerciseLabelForMinute uses exercise.label; add workoutLabelForMinute; record exercise in history"
```

---

### Task 6: `workout_screen.dart` — iconPath via extension

**Files:**
- Modify: `lib/features/workout/workout_screen.dart`

- [ ] **Step 1: Update `_buildWorkoutScreen` to use `equipment.iconPath`**

In `_buildWorkoutScreen` (around line 207), replace the iconPath calculation:

```dart
// OLD:
final iconPath = notifier.equipmentForMinute(state.currentMinute) == Equipment.kettlebell
    ? 'assets/icon/kettlebell.png'
    : 'assets/icon/steelmace.png';

// NEW:
final iconPath = notifier.equipmentForMinute(state.currentMinute).iconPath;
```

- [ ] **Step 2: Update RepsCard call to use `workoutLabel` instead of `exerciseLabel`**

In `_buildWorkoutScreen`, update the `exerciseLabel` variable name and the `RepsCard` call:

```dart
// OLD (around line 206):
final exerciseLabel = notifier.exerciseLabelForMinute(state.currentMinute);
// ...
RepsCard(
  currentMinute: state.currentMinute,
  currentReps: state.currentReps,
  exerciseLabel: exerciseLabel,
  iconPath: iconPath,
  pulseAnimation: _pulseAnimation,
),

// NEW:
final exerciseLabel = notifier.exerciseLabelForMinute(state.currentMinute);
final workoutLabel = notifier.workoutLabelForMinute(state.currentMinute);
// ...
RepsCard(
  currentMinute: state.currentMinute,
  currentReps: state.currentReps,
  workoutLabel: workoutLabel,
  iconPath: iconPath,
  pulseAnimation: _pulseAnimation,
),
```

Note: `exerciseLabel` is still needed for `OverallProgress`. Keep it, just add `workoutLabel` alongside.

- [ ] **Step 3: Run `flutter analyze`**

```powershell
flutter analyze lib/features/workout/workout_screen.dart
```

Expected: error about `workoutLabel` not being a named parameter of `RepsCard` — that's fine, we fix it in Task 7.

- [ ] **Step 4: Commit after Task 7 resolves the compile error** (skip separate commit here, batch with Task 7)

---

### Task 7: `reps_card.dart` — `workoutLabel` parameter

**Files:**
- Modify: `lib/features/workout/widgets/reps_card.dart`

- [ ] **Step 1: Rename `exerciseLabel` to `workoutLabel` in `RepsCard`**

Complete updated file:

```dart
import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class RepsCard extends StatelessWidget {
  final int currentMinute;
  final int currentReps;
  final String workoutLabel;
  final String iconPath;
  final Animation<double> pulseAnimation;

  const RepsCard({
    super.key,
    required this.currentMinute,
    required this.currentReps,
    required this.workoutLabel,
    required this.iconPath,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final phaseColor = phaseColorForMinute(currentMinute);
    return ScaleTransition(
      scale: pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: phaseColor.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            Image.asset(iconPath, width: 48, height: 48, color: phaseColor),
            const SizedBox(height: 4),
            Text('REPS',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    letterSpacing: 4)),
            const SizedBox(height: 8),
            Text('$currentReps',
                style: TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: phaseColor,
                    height: 1)),
            const SizedBox(height: 8),
            Text(workoutLabel,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run `flutter analyze` across all changed files**

```powershell
flutter analyze lib/
```

Expected: no issues.

- [ ] **Step 3: Run all tests**

```powershell
flutter test test/core/models/
```

Expected: all PASS.

- [ ] **Step 4: Commit Tasks 6 and 7 together**

```powershell
git add lib/features/workout/workout_screen.dart lib/features/workout/widgets/reps_card.dart
git commit -m "feat: workout screen uses equipment.iconPath and shows combined workoutLabel in RepsCard"
```

---

### Task 8: History detail — weight+exercise per interval, breakdown summary

**Files:**
- Modify: `lib/features/history/history_detail_sheet.dart`

- [ ] **Step 1: Implement the updated `history_detail_sheet.dart`**

Three changes:
1. `isKb` check: `iv.equipment == 0` → `iv.equipment < 3`
2. Per-interval row: add equipment label and exercise name
3. Summary `repBreakdown`: breakdown by weight variant instead of simple KB/SM split

Complete updated file:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/workout_history.dart';
import '../../core/models/settings.dart';

class HistoryDetailSheet extends StatelessWidget {
  final WorkoutRecord record;
  const HistoryDetailSheet({super.key, required this.record});

  String _formatDateTime(DateTime dt) =>
      DateFormat("EE, d. MMMM yyyy  HH:mm", 'de').format(dt);

  String _repBreakdown() {
    final Map<int, int> byEquipment = {};
    for (final iv in record.intervals) {
      byEquipment[iv.equipment] = (byEquipment[iv.equipment] ?? 0) + iv.reps;
    }
    if (byEquipment.length == 1) return '${record.totalReps} Reps';
    return byEquipment.entries
        .map((e) {
          final eq = Equipment.values.elementAtOrNull(e.key);
          final label = eq?.label ?? 'Unbekannt';
          return '${e.value}× $label';
        })
        .join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final totalSecs = record.totalDurationSeconds;
    final durStr =
        '${totalSecs ~/ 60}m ${(totalSecs % 60).toString().padLeft(2, '0')}s';
    final repBreakdown = _repBreakdown();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDateTime(dt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${record.intervals.length}/30 Intervalle',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text('$repBreakdown  ·  $durStr',
                        style: const TextStyle(
                            color: Color(0xFFFF6B00), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: record.intervals.length,
              itemBuilder: (ctx, i) {
                final iv = record.intervals[i];
                final color = phaseColorForMinute(i);
                final isKb = iv.equipment < 3;
                final eq = Equipment.values.elementAtOrNull(iv.equipment);
                final ex = Exercise.values.elementAtOrNull(iv.exercise);
                final eqLabel = eq?.label ?? '';
                final exLabel = ex?.label ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 52,
                        child: Text('Min ${i + 1}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ),
                      Image.asset(
                        isKb
                            ? 'assets/icon/kettlebell.png'
                            : 'assets/icon/steelmace.png',
                        width: 14,
                        height: 14,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Text(eqLabel,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      const SizedBox(width: 4),
                      Text('· $exLabel',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('${iv.reps} Reps',
                          style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${iv.durationSeconds}s',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run `flutter analyze`**

```powershell
flutter analyze lib/features/history/history_detail_sheet.dart
```

Expected: no issues.

- [ ] **Step 3: Run full test suite**

```powershell
flutter test
```

Expected: all tests PASS.

- [ ] **Step 4: Commit**

```powershell
git add lib/features/history/history_detail_sheet.dart
git commit -m "feat: history detail shows equipment+exercise per interval and weight-variant breakdown in summary"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Implemented in |
|-----------------|----------------|
| Equipment 5 variants (kb16–sm12) | Task 1 |
| Exercise 5 variants (swingBeidarmig–mace360) | Task 1 |
| EquipmentX.isKettlebell, label, iconPath, defaultExercise, validExercises | Task 1 |
| ExerciseX.label | Task 1 |
| IntervalConfig.exercise field + serialization `j['x']` | Task 2 |
| Migration: old e=0 → kb24+swingBeidarmig | Task 2 |
| Migration: old e=1 → sm12+mace360 | Task 2 |
| copyWith updated with exercise | Task 2 |
| pyramid() uses kb24+swingBeidarmig | Task 2 |
| planKey includes exercise.index | Task 2 |
| IntervalRecord.exercise field + serialization | Task 3 |
| kettlebellReps: equipment < 3 | Task 3 |
| steelMaceReps: equipment >= 3 | Task 3 |
| Two chips in PlanMinuteRow (selected row) | Task 4 |
| Equipment picker: KB row (16/20/24) + SM row (8/12) | Task 4 |
| Exercise picker: filtered by validExercises | Task 4 |
| KB→SM switch resets exercise to defaultExercise | Task 4 |
| Non-selected row shows label + exercise as static text | Task 4 |
| exerciseLabelForMinute uses exercise.label | Task 5 |
| workoutLabelForMinute: "KB 20kg · Swing beidarmig" | Task 5 |
| IntervalRecord creation records exercise.index | Task 5 |
| iconPath via equipment.iconPath | Task 6 |
| RepsCard shows workoutLabel | Tasks 6+7 |
| history_detail_sheet isKb: iv.equipment < 3 | Task 8 |
| Per-interval: shows weight label + exercise name | Task 8 |
| Summary: breakdown by weight variant | Task 8 |

No gaps found.

**Type consistency check:** `workoutLabelForMinute` defined in Task 5, used in Task 6 ✓. `RepsCard.workoutLabel` defined in Task 7, call site in Task 6 ✓. `Exercise.values.elementAtOrNull` used in Task 8 — available via Dart's `List.elementAtOrNull` extension ✓.
