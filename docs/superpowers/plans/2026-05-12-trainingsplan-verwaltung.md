# Trainingsplan-Verwaltung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ersetze den phasenbasierten Plan-Modus durch eine vollständige Trainingsplan-Verwaltung mit benannten Plänen, einem dedizierten PlanLibraryScreen und einem Plan-Indikator auf dem Hauptscreen.

**Architecture:** Neuer `PlanLibraryNotifier` (Riverpod, keepAlive) liest/schreibt Pläne aus `plans.json` im App-Dokumentenverzeichnis. `WorkoutNotifier` liest den aktiven Plan aus `PlanLibraryNotifier` statt aus `AppSettings`. `AppSettings` und `SettingsNotifier` bleiben für Feedback-Einstellungen (Sound, Vibration) zuständig.

**Tech Stack:** Flutter, Riverpod 2.x mit `@riverpod` Code-Generierung, `path_provider` (bereits vorhanden), `dart:io` + `dart:convert` für JSON-Datei-Persistenz.

---

## Dateiübersicht

| Datei | Aktion |
|---|---|
| `lib/core/models/training_plan.dart` | NEU |
| `lib/core/providers/plan_library_notifier.dart` | NEU |
| `lib/core/providers/plan_library_notifier.g.dart` | NEU (build_runner) |
| `lib/features/plans/plan_library_screen.dart` | NEU |
| `lib/features/plans/plan_editor_screen.dart` | NEU |
| `lib/features/plans/widgets/minute_exact_editor.dart` | NEU (aus config/widgets/ adaptiert) |
| `lib/features/plans/widgets/minute_row.dart` | NEU (aus config/widgets/ adaptiert) |
| `lib/features/workout/widgets/plan_indicator.dart` | NEU |
| `lib/features/workout/workout_notifier.dart` | ÄND |
| `lib/features/workout/workout_screen.dart` | ÄND |
| `lib/features/config/config_screen.dart` | ÄND |
| `lib/core/models/settings.dart` | ÄND |
| `lib/features/config/widgets/phase_based_editor.dart` | DEL |
| `lib/features/config/widgets/plan_mode_selector.dart` | DEL |
| `lib/features/config/widgets/equipment_selector.dart` | DEL |
| `lib/features/config/widgets/minute_row.dart` | DEL |
| `lib/features/config/widgets/minute_exact_editor.dart` | DEL |

---

## Task 1: TrainingPlan-Datenmodell

**Files:**
- Create: `lib/core/models/training_plan.dart`
- Create: `test/core/models/training_plan_test.dart`

- [ ] **Schritt 1: Datei anlegen**

Erstelle `lib/core/models/training_plan.dart`:

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

  IntervalConfig({
    required this.reps,
    required this.durationSeconds,
    required this.equipment,
  });

  Map<String, dynamic> toJson() => {
    'r': reps,
    'd': durationSeconds,
    'e': equipment.index,
  };

  factory IntervalConfig.fromJson(Map<String, dynamic> j) => IntervalConfig(
    reps: j['r'] as int,
    durationSeconds: j['d'] as int,
    equipment: Equipment.values[j['e'] as int],
  );

  IntervalConfig copyWith({int? reps, int? durationSeconds, Equipment? equipment}) =>
      IntervalConfig(
        reps: reps ?? this.reps,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        equipment: equipment ?? this.equipment,
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
      .map((iv) => '${iv.reps},${iv.durationSeconds},${iv.equipment.index}')
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
        equipment: Equipment.kettlebell,
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

  TrainingPlan get activePlan =>
      plans.firstWhere((p) => p.id == activePlanId, orElse: () => plans.first);

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
    final file = await _file();
    await file.writeAsString(jsonEncode(library.toJson()));
  }
}
```

- [ ] **Schritt 2: Tests schreiben**

Erstelle `test/core/models/training_plan_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
  group('IntervalConfig', () {
    test('serializes and deserializes correctly', () {
      final iv = IntervalConfig(reps: 10, durationSeconds: 45, equipment: Equipment.steelmace);
      final restored = IntervalConfig.fromJson(iv.toJson());
      expect(restored.reps, 10);
      expect(restored.durationSeconds, 45);
      expect(restored.equipment, Equipment.steelmace);
    });

    test('copyWith overrides only specified fields', () {
      final iv = IntervalConfig(reps: 5, durationSeconds: 60, equipment: Equipment.kettlebell);
      final copy = iv.copyWith(reps: 8);
      expect(copy.reps, 8);
      expect(copy.durationSeconds, 60);
      expect(copy.equipment, Equipment.kettlebell);
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

    test('serializes and deserializes correctly', () {
      final plan = TrainingPlan.pyramid('Mein Plan');
      final restored = TrainingPlan.fromJson(plan.toJson());
      expect(restored.id, plan.id);
      expect(restored.name, 'Mein Plan');
      expect(restored.intervals.length, 30);
      expect(restored.intervals[0].reps, plan.intervals[0].reps);
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
  });
}
```

- [ ] **Schritt 3: Tests ausführen**

```
flutter test test/core/models/training_plan_test.dart -v
```

Erwartetes Ergebnis: alle Tests grün.

- [ ] **Schritt 4: Commit**

```
git add lib/core/models/training_plan.dart test/core/models/training_plan_test.dart
git commit -m "feat: add TrainingPlan data model with IntervalConfig, PlanLibrary, PlanLibraryStorage"
```

---

## Task 2: PlanLibraryNotifier

**Files:**
- Create: `lib/core/providers/plan_library_notifier.dart`
- Generated: `lib/core/providers/plan_library_notifier.g.dart`

- [ ] **Schritt 1: Notifier schreiben**

Erstelle `lib/core/providers/plan_library_notifier.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/training_plan.dart';

part 'plan_library_notifier.g.dart';

@Riverpod(keepAlive: true)
class PlanLibraryNotifier extends _$PlanLibraryNotifier {
  @override
  Future<PlanLibrary> build() => PlanLibraryStorage.load();

  Future<void> setActivePlan(String id) async {
    final lib = state.requireValue;
    if (lib.activePlanId == id) return;
    final updated = PlanLibrary(plans: lib.plans, activePlanId: id);
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }

  Future<void> addPlan(TrainingPlan plan) async {
    final lib = state.requireValue;
    final updated = PlanLibrary(
      plans: [...lib.plans, plan],
      activePlanId: lib.activePlanId,
    );
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }

  Future<void> updatePlan(TrainingPlan plan) async {
    final lib = state.requireValue;
    final updatedPlans = lib.plans.map((p) => p.id == plan.id ? plan : p).toList();
    final updated = PlanLibrary(plans: updatedPlans, activePlanId: lib.activePlanId);
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }

  Future<void> deletePlan(String id) async {
    final lib = state.requireValue;
    if (lib.plans.length <= 1 || lib.activePlanId == id) return;
    final updatedPlans = lib.plans.where((p) => p.id != id).toList();
    final updated = PlanLibrary(plans: updatedPlans, activePlanId: lib.activePlanId);
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }

  Future<void> renamePlan(String id, String name) async {
    final lib = state.requireValue;
    final updatedPlans = lib.plans.map((p) {
      if (p.id != id) return p;
      return TrainingPlan(id: p.id, name: name, intervals: p.intervals);
    }).toList();
    final updated = PlanLibrary(plans: updatedPlans, activePlanId: lib.activePlanId);
    await PlanLibraryStorage.save(updated);
    state = AsyncData(updated);
  }
}
```

- [ ] **Schritt 2: build_runner ausführen**

```
dart run build_runner build --delete-conflicting-outputs
```

Erwartetes Ergebnis: `lib/core/providers/plan_library_notifier.g.dart` wird erstellt, keine Fehler.

- [ ] **Schritt 3: Analyze**

```
flutter analyze
```

Erwartetes Ergebnis: keine neuen Fehler.

- [ ] **Schritt 4: Commit**

```
git add lib/core/providers/plan_library_notifier.dart lib/core/providers/plan_library_notifier.g.dart
git commit -m "feat: add PlanLibraryNotifier with keepAlive Riverpod provider"
```

---

## Task 3: Plan-Editor-Widgets (neue Versionen in features/plans/)

Die bestehenden `MinuteRow` und `MinuteExactEditor` aus `config/widgets/` arbeiten mit `AppSettings`. Neue Versionen in `features/plans/widgets/` arbeiten mit `TrainingPlan` und `IntervalConfig`.

**Files:**
- Create: `lib/features/plans/widgets/minute_row.dart`
- Create: `lib/features/plans/widgets/minute_exact_editor.dart`

- [ ] **Schritt 1: `minute_row.dart` erstellen**

Erstelle `lib/features/plans/widgets/minute_row.dart`:

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
  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  Widget _smallStepBtn(IconData icon, VoidCallback? onTap) =>
      _stepButton(icon, onTap, size: 32);

  @override
  Widget build(BuildContext context) {
    final iv = widget.plan.intervals[widget.index];
    final i = widget.index;
    final iconPath = iv.equipment == Equipment.kettlebell
        ? 'assets/icon/kettlebell.png'
        : 'assets/icon/steelmace.png';
    final color = phaseColorForMinute(i);

    return GestureDetector(
      onTap: widget.onSelect,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(
              width: 42,
              child: Text(
                'Min ${i + 1}',
                style: TextStyle(
                    fontSize: 11,
                    color: widget.isSelected ? Colors.white38 : Colors.white24,
                    letterSpacing: 1),
              ),
            ),
            const Spacer(),
            if (widget.isSelected) ...[
              SizedBox(
                width: 26,
                height: 26,
                child: PopupMenuButton<int>(
                  initialValue: iv.equipment.index,
                  onSelected: (v) => _update(() => iv.equipment = Equipment.values[v]),
                  color: const Color(0xFF1E1E1E),
                  padding: EdgeInsets.zero,
                  tooltip: '',
                  child: Center(
                      child: Image.asset(iconPath,
                          width: 16, height: 16, color: Colors.white54)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 0,
                      child: Row(children: [
                        Image.asset('assets/icon/kettlebell.png',
                            width: 18, height: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        const Text('Kettlebell',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: Row(children: [
                        Image.asset('assets/icon/steelmace.png',
                            width: 18, height: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        const Text('Steel Mace',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('R', style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _smallStepBtn(Icons.remove,
                  iv.reps > 1 ? () => _update(() => iv.reps--) : null),
              SizedBox(
                width: 30,
                child: Center(
                  child: Text('${iv.reps}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white54)),
                ),
              ),
              _smallStepBtn(Icons.add, () => _update(() => iv.reps++)),
              const SizedBox(width: 8),
              const Text('s', style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _smallStepBtn(
                  Icons.remove,
                  iv.durationSeconds > 30
                      ? () => _update(() =>
                          iv.durationSeconds = (iv.durationSeconds - 5).clamp(30, 9999))
                      : null),
              SizedBox(
                width: 34,
                child: Center(
                  child: Text('${iv.durationSeconds}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white54)),
                ),
              ),
              _smallStepBtn(Icons.add, () => _update(() => iv.durationSeconds += 5)),
            ] else ...[
              Image.asset(iconPath, width: 14, height: 14, color: Colors.white24),
              const SizedBox(width: 8),
              Text('${iv.reps}R',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
              const SizedBox(width: 6),
              Text('${iv.durationSeconds}s',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Schritt 2: `minute_exact_editor.dart` erstellen**

Erstelle `lib/features/plans/widgets/minute_exact_editor.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import 'minute_row.dart';

class PlanMinuteExactEditor extends StatelessWidget {
  final TrainingPlan plan;
  final int? selectedRow;
  final ValueChanged<int?> onRowSelected;
  final VoidCallback onChanged;

  const PlanMinuteExactEditor({
    super.key,
    required this.plan,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
  });

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder(
          key: const PageStorageKey<String>('planMinuteExactList'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemExtent: 42,
          itemCount: 30,
          itemBuilder: (_, i) => PlanMinuteRow(
            key: ValueKey(i),
            index: i,
            plan: plan,
            isSelected: selectedRow == i,
            onSelect: () => onRowSelected(selectedRow == i ? null : i),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GESAMT',
                  style: TextStyle(fontSize: 10, letterSpacing: 3, color: Colors.white24)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${plan.totalReps} Reps',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white38)),
                  Text(_formatDuration(plan.totalDurationSeconds),
                      style: const TextStyle(fontSize: 13, color: Colors.white24)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Schritt 3: Analyze**

```
flutter analyze
```

Erwartetes Ergebnis: keine Fehler.

- [ ] **Schritt 4: Commit**

```
git add lib/features/plans/
git commit -m "feat: add plan editor widgets (PlanMinuteRow, PlanMinuteExactEditor) using TrainingPlan"
```

---

## Task 4: PlanEditorScreen

**Files:**
- Create: `lib/features/plans/plan_editor_screen.dart`

- [ ] **Schritt 1: Screen erstellen**

Erstelle `lib/features/plans/plan_editor_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/training_plan.dart';
import '../../core/providers/plan_library_notifier.dart';
import 'widgets/minute_exact_editor.dart';

class PlanEditorScreen extends ConsumerStatefulWidget {
  final TrainingPlan plan;
  const PlanEditorScreen({super.key, required this.plan});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  late TrainingPlan _plan;
  int? _selectedRow;

  @override
  void initState() {
    super.initState();
    _plan = TrainingPlan(
      id: widget.plan.id,
      name: widget.plan.name,
      intervals: widget.plan.intervals.map((iv) => iv.copyWith()).toList(),
    );
  }

  Future<void> _save() async {
    await ref.read(planLibraryNotifierProvider.notifier).updatePlan(_plan);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _save();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white38),
            onPressed: () async {
              await _save();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Text(
            _plan.name.toUpperCase(),
            style: const TextStyle(
                fontSize: 15, letterSpacing: 4, color: Colors.white38),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            PlanMinuteExactEditor(
              plan: _plan,
              selectedRow: _selectedRow,
              onRowSelected: (i) => setState(() => _selectedRow = i),
              onChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Schritt 2: Analyze**

```
flutter analyze
```

Erwartetes Ergebnis: keine Fehler.

- [ ] **Schritt 3: Commit**

```
git add lib/features/plans/plan_editor_screen.dart
git commit -m "feat: add PlanEditorScreen — 30-row editor, saves on back via PlanLibraryNotifier"
```

---

## Task 5: PlanLibraryScreen

**Files:**
- Create: `lib/features/plans/plan_library_screen.dart`

- [ ] **Schritt 1: Screen erstellen**

Erstelle `lib/features/plans/plan_library_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/training_plan.dart';
import '../../core/providers/plan_library_notifier.dart';
import 'plan_editor_screen.dart';

class PlanLibraryScreen extends ConsumerWidget {
  const PlanLibraryScreen({super.key});

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Future<void> _addPlan(BuildContext context, WidgetRef ref, int planCount) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: 'Plan ${planCount + 1}');
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Neuer Plan',
              style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white70),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF6B00))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen',
                  style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Erstellen',
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final plan = TrainingPlan.pyramid(name);
    await ref.read(planLibraryNotifierProvider.notifier).addPlan(plan);
    if (!context.mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => PlanEditorScreen(plan: plan)));
  }

  Future<void> _renamePlan(
      BuildContext context, WidgetRef ref, TrainingPlan plan) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: plan.name);
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Plan umbenennen',
              style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white70),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF6B00))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen',
                  style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Speichern',
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    await ref.read(planLibraryNotifierProvider.notifier).renamePlan(plan.id, name);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TrainingPlan plan,
      {required bool isActive, required bool isLast}) async {
    if (isActive || isLast) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Nicht möglich',
              style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
          content: Text(
            isActive
                ? 'Der aktive Plan kann nicht gelöscht werden.'
                : 'Der letzte Plan kann nicht gelöscht werden.',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Plan löschen?',
            style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
        content: Text('„${plan.name}" wird permanent gelöscht.',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    if (confirm) {
      await ref.read(planLibraryNotifierProvider.notifier).deletePlan(plan.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(planLibraryNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('TRAININGSPLÄNE',
            style: TextStyle(fontSize: 15, letterSpacing: 4, color: Colors.white38)),
      ),
      body: libraryAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: Colors.white38))),
        data: (library) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: GestureDetector(
                onTap: () => _addPlan(context, ref, library.plans.length),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Color(0xFFFF6B00), size: 18),
                      SizedBox(width: 8),
                      Text('Neuer Plan',
                          style: TextStyle(
                              color: Color(0xFFFF6B00),
                              fontSize: 14,
                              letterSpacing: 2)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                itemCount: library.plans.length,
                itemBuilder: (_, i) {
                  final plan = library.plans[i];
                  final isActive = plan.id == library.activePlanId;
                  return GestureDetector(
                    onLongPress: () => _renamePlan(context, ref, plan),
                    child: Dismissible(
                      key: ValueKey(plan.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _confirmDelete(context, ref, plan,
                            isActive: isActive,
                            isLast: library.plans.length == 1);
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          await ref
                              .read(planLibraryNotifierProvider.notifier)
                              .setActivePlan(plan.id);
                          if (!context.mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PlanEditorScreen(plan: plan)),
                          );
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
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFFFF6B00)
                                      : Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
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
                              const Icon(Icons.chevron_right,
                                  color: Colors.white24, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Schritt 2: Analyze**

```
flutter analyze
```

Erwartetes Ergebnis: keine Fehler.

- [ ] **Schritt 3: Commit**

```
git add lib/features/plans/plan_library_screen.dart
git commit -m "feat: add PlanLibraryScreen — plan list with add, rename, delete, activate"
```

---

## Task 6: WorkoutNotifier + WorkoutState + WorkoutScreen Kern-Refactor

**Files:**
- Modify: `lib/features/workout/workout_notifier.dart`
- Modify: `lib/features/workout/workout_screen.dart`

**Hinweis:** Nach diesem Task liest `WorkoutNotifier` den aktiven Plan aus `PlanLibraryNotifier`. `ConfigScreen` zeigt noch den alten Plan-Editor — das ist ein bewusst akzeptierter Zwischenzustand, der in Task 7 behoben wird.

- [ ] **Schritt 1: `workout_notifier.dart` ersetzen**

Ersetze den kompletten Inhalt von `lib/features/workout/workout_notifier.dart`:

```dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vibration/vibration.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/models/settings.dart';
import '../../core/models/training_plan.dart';
import '../../core/models/workout_history.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/plan_library_notifier.dart';
import '../history/history_notifier.dart';

part 'workout_notifier.g.dart';

@immutable
class WorkoutState {
  final List<IntervalConfig> intervals;
  final int currentMinute;
  final int secondsLeft;
  final bool isRunning;
  final bool isFinished;
  final bool waitingForConfirmation;
  final int totalRepsDone;
  final List<IntervalRecord> completedIntervals;
  final DateTime? workoutStartTime;

  const WorkoutState({
    required this.intervals,
    required this.currentMinute,
    required this.secondsLeft,
    required this.isRunning,
    required this.isFinished,
    required this.waitingForConfirmation,
    required this.totalRepsDone,
    required this.completedIntervals,
    this.workoutStartTime,
  });

  int get totalMinutes => intervals.length;
  int get currentReps => intervals[currentMinute].reps;
  int get currentDuration => intervals[currentMinute].durationSeconds;
  int get totalReps => intervals.fold(0, (a, iv) => a + iv.reps);

  WorkoutState copyWith({
    List<IntervalConfig>? intervals,
    int? currentMinute,
    int? secondsLeft,
    bool? isRunning,
    bool? isFinished,
    bool? waitingForConfirmation,
    int? totalRepsDone,
    List<IntervalRecord>? completedIntervals,
    DateTime? workoutStartTime,
    bool clearWorkoutStartTime = false,
  }) =>
      WorkoutState(
        intervals: intervals ?? this.intervals,
        currentMinute: currentMinute ?? this.currentMinute,
        secondsLeft: secondsLeft ?? this.secondsLeft,
        isRunning: isRunning ?? this.isRunning,
        isFinished: isFinished ?? this.isFinished,
        waitingForConfirmation:
            waitingForConfirmation ?? this.waitingForConfirmation,
        totalRepsDone: totalRepsDone ?? this.totalRepsDone,
        completedIntervals: completedIntervals ?? this.completedIntervals,
        workoutStartTime: clearWorkoutStartTime
            ? null
            : (workoutStartTime ?? this.workoutStartTime),
      );
}

@riverpod
class WorkoutNotifier extends _$WorkoutNotifier {
  Timer? _timer;
  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  StreamSubscription? _alarmLoopSub;
  bool? _hasVibrator;
  late AppSettings _settings;
  late TrainingPlan _activePlan;

  @override
  Future<WorkoutState> build() async {
    _settings = await ref.read(settingsNotifierProvider.future);
    final library = await ref.read(planLibraryNotifierProvider.future);
    _activePlan = library.activePlan;
    _hasVibrator = await Vibration.hasVibrator();

    ref.onDispose(() {
      _timer?.cancel();
      _alarmLoopSub?.cancel();
      _tickPlayer.dispose();
      _alarmPlayer.dispose();
      WakelockPlus.disable();
    });

    return WorkoutState(
      intervals: _activePlan.intervals,
      currentMinute: 0,
      secondsLeft: _activePlan.intervals[0].durationSeconds,
      isRunning: false,
      isFinished: false,
      waitingForConfirmation: false,
      totalRepsDone: 0,
      completedIntervals: const [],
    );
  }

  WorkoutState get _s => state.requireValue;

  void start() {
    final now = _s.workoutStartTime == null ? DateTime.now() : null;
    state = AsyncData(_s.copyWith(isRunning: true, workoutStartTime: now));
    WakelockPlus.enable();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void pause() {
    _timer?.cancel();
    WakelockPlus.disable();
    state = AsyncData(_s.copyWith(isRunning: false));
  }

  Future<void> reset() async {
    _timer?.cancel();
    _alarmLoopSub?.cancel();
    _alarmLoopSub = null;
    _alarmPlayer.stop();
    WakelockPlus.disable();
    final library = await ref.read(planLibraryNotifierProvider.future);
    _activePlan = library.activePlan;
    state = AsyncData(WorkoutState(
      intervals: _activePlan.intervals,
      currentMinute: 0,
      secondsLeft: _activePlan.intervals[0].durationSeconds,
      isRunning: false,
      isFinished: false,
      waitingForConfirmation: false,
      totalRepsDone: 0,
      completedIntervals: const [],
    ));
  }

  void confirmInterval() {
    _alarmLoopSub?.cancel();
    _alarmLoopSub = null;
    _alarmPlayer.stop();
    final nextMinute = _s.currentMinute + 1;
    state = AsyncData(_s.copyWith(
      waitingForConfirmation: false,
      currentMinute: nextMinute,
      secondsLeft: _s.intervals[nextMinute].durationSeconds,
    ));
    _vibrate(400);
    _saveHistory();
    start();
  }

  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
  }

  Equipment equipmentForMinute(int minute) =>
      _activePlan.intervals[minute].equipment;

  String exerciseLabelForMinute(int minute) =>
      equipmentForMinute(minute) == Equipment.kettlebell ? 'Swings' : '360s';

  void _tick(Timer timer) {
    final newSeconds = _s.secondsLeft - 1;
    if (newSeconds <= 0) {
      state = AsyncData(_s.copyWith(secondsLeft: 0));
      _onMinuteComplete();
    } else {
      state = AsyncData(_s.copyWith(secondsLeft: newSeconds));
      if (newSeconds <= 5 && _settings.warningTonesEnabled) {
        if (newSeconds == 5) _raiseVolume();
        _playTickSound();
      }
    }
  }

  Future<void> _raiseVolume() async {
    if (!_settings.volumeBoostEnabled || _settings.volumeBoostLevel <= 0) return;
    try {
      final current = await VolumeController().getVolume();
      if (current < _settings.volumeBoostLevel) {
        VolumeController().setVolume(_settings.volumeBoostLevel, showSystemUI: false);
      }
    } catch (_) {}
  }

  void _onMinuteComplete() {
    _timer?.cancel();
    final s = _s;
    final newTotalReps = s.totalRepsDone + s.currentReps;
    final newIntervals = [
      ...s.completedIntervals,
      IntervalRecord(
        reps: s.currentReps,
        durationSeconds: s.currentDuration,
        equipment: equipmentForMinute(s.currentMinute).index,
      ),
    ];

    if (s.currentMinute >= s.totalMinutes - 1) {
      state = AsyncData(s.copyWith(
        isFinished: true,
        isRunning: false,
        totalRepsDone: newTotalReps,
        completedIntervals: newIntervals,
      ));
      WakelockPlus.disable();
      _vibrate(600);
      _saveHistory(intervals: newIntervals, startTime: s.workoutStartTime);
    } else {
      state = AsyncData(s.copyWith(
        isRunning: false,
        waitingForConfirmation: true,
        totalRepsDone: newTotalReps,
        completedIntervals: newIntervals,
      ));
      _playAlarm();
    }
  }

  Source _soundSource(String f) =>
      f.startsWith('/') ? DeviceFileSource(f) : AssetSource('sounds/$f');

  Future<void> _playTickSound() async {
    try {
      await _tickPlayer.play(_soundSource(_settings.countdownSoundFile));
    } catch (_) {}
  }

  Future<void> _playAlarm() async {
    if (_hasVibrator == true && _settings.vibrationEnabled) {
      Vibration.vibrate(duration: 800);
    }
    if (!_settings.alarmEnabled) return;

    Future<void> playOnce() async {
      try {
        await _alarmPlayer.setReleaseMode(ReleaseMode.release);
        await _alarmPlayer.play(_soundSource(_settings.alarmSoundFile));
      } catch (_) {
        SystemSound.play(SystemSoundType.click);
      }
    }

    await _alarmLoopSub?.cancel();
    _alarmLoopSub = _alarmPlayer.onPlayerComplete.listen((_) async {
      if (!_s.waitingForConfirmation) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (_s.waitingForConfirmation) await playOnce();
    });
    await playOnce();
  }

  void _vibrate(int durationMs) {
    if (!_settings.vibrationEnabled || _hasVibrator != true) return;
    Vibration.vibrate(duration: durationMs);
  }

  Future<void> _saveHistory({
    List<IntervalRecord>? intervals,
    DateTime? startTime,
  }) async {
    final ivs = intervals ?? _s.completedIntervals;
    final t = startTime ?? _s.workoutStartTime;
    if (ivs.length < 2 || t == null) return;
    final record = WorkoutRecord(
      timestamp: t.millisecondsSinceEpoch,
      planMode: 1, // immer minuteExact nach der Migration
      intervals: List.from(ivs),
    );
    await ref.read(historyNotifierProvider.notifier).addOrUpdate(record);
  }
}
```

- [ ] **Schritt 2: `workout_screen.dart` anpassen**

Folgende Stellen in `lib/features/workout/workout_screen.dart` ändern:

**a) Feld `_planKeySnapshot` entfernen** (wird in Task 8 neu eingeführt):
```dart
// ENTFERNEN: String _planKeySnapshot = '';
```

**b) In `onPageChanged` — `page == 1` Block: Zeile mit `_planKeySnapshot` entfernen:**
```dart
// ALT:
if (page == 1) {
  setState(() {
    _configWasOpened = true;
    _wasRunningBeforeConfig = state.isRunning || state.waitingForConfirmation;
    _planKeySnapshot = ref.read(settingsNotifierProvider).requireValue.planKey;
    _configVisitCount++;
  });
  if (state.isRunning) notifier.pause();
}

// NEU:
if (page == 1) {
  setState(() {
    _configWasOpened = true;
    _wasRunningBeforeConfig = state.isRunning || state.waitingForConfirmation;
    _configVisitCount++;
  });
  if (state.isRunning) notifier.pause();
}
```

**c) `_showResetConfirmDialog` — Parameter entfernen:**
```dart
// ALT:
Future<void> _showResetConfirmDialog(AppSettings newSettings) async {
  ...
  if (doReset) ref.read(workoutNotifierProvider.notifier).reset(newSettings);
}

// NEU:
Future<void> _showResetConfirmDialog() async {
  final doReset = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text(
        'Training zurücksetzen?',
        style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1),
      ),
      content: const Text(
        'Die Einstellungen wurden geändert. Das laufende Training zurücksetzen?',
        style: TextStyle(color: Colors.white38, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Weiter', style: TextStyle(color: Colors.white38)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Zurücksetzen',
              style: TextStyle(color: Color(0xFFFF6B00))),
        ),
      ],
    ),
  ) ?? false;
  if (doReset) ref.read(workoutNotifierProvider.notifier).reset();
}
```

**d) PageView `onPageChanged` — Plan-Change-Logik vereinfachen:**
```dart
// ALT (der gesamte `if (page == 0 && _configWasOpened)` Block):
if (page == 0 && _configWasOpened) {
  _configWasOpened = false;
  final newSettings = ref.read(settingsNotifierProvider).requireValue;
  ref.read(settingsNotifierProvider.notifier).save();
  final changed = newSettings.planKey != _planKeySnapshot;
  if (!changed) {
    notifier.updateSettings(newSettings);
    if (_wasRunningBeforeConfig && !state.isFinished) notifier.start();
  } else {
    final wasActive = _wasRunningBeforeConfig || state.currentMinute > 0;
    if (wasActive) {
      _showResetConfirmDialog(newSettings);
    } else {
      notifier.reset(newSettings);
    }
  }
}

// NEU:
if (page == 0 && _configWasOpened) {
  _configWasOpened = false;
  final newSettings = ref.read(settingsNotifierProvider).requireValue;
  ref.read(settingsNotifierProvider.notifier).save();
  notifier.updateSettings(newSettings);
  if (_wasRunningBeforeConfig && !state.isFinished) notifier.start();
}
```

**e) `_buildWorkoutScreen` — `state.plan[...]` durch `state.intervals[...].reps` ersetzen:**
```dart
// ALT:
NextMinutePreview(nextReps: state.plan[state.currentMinute + 1]),

// NEU:
NextMinutePreview(nextReps: state.intervals[state.currentMinute + 1].reps),
```

**f) `_buildConfirmationOverlay` — `state.plan[nextMinute]` ersetzen:**
```dart
// ALT:
ConfirmationOverlay(
  nextReps: state.plan[nextMinute],
  ...
)

// NEU:
ConfirmationOverlay(
  nextReps: state.intervals[nextMinute].reps,
  ...
)
```

- [ ] **Schritt 3: build_runner ausführen**

```
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Schritt 4: Analyze**

```
flutter analyze
```

Erwartetes Ergebnis: keine Fehler. Falls `AppSettings` noch `planKey` importiert wird irgendwo — jetzt entfernen.

- [ ] **Schritt 5: Build-Test**

```
flutter build apk --debug
```

Erwartetes Ergebnis: ✓ Built.

- [ ] **Schritt 6: Commit**

```
git add lib/features/workout/workout_notifier.dart lib/features/workout/workout_notifier.g.dart lib/features/workout/workout_screen.dart
git commit -m "refactor: WorkoutNotifier reads active plan from PlanLibraryNotifier, WorkoutState uses List<IntervalConfig>"
```

---

## Task 7: ConfigScreen vereinfachen + AppSettings bereinigen

**Files:**
- Modify: `lib/features/config/config_screen.dart`
- Modify: `lib/core/models/settings.dart`
- Delete: `lib/features/config/widgets/phase_based_editor.dart`
- Delete: `lib/features/config/widgets/plan_mode_selector.dart`
- Delete: `lib/features/config/widgets/equipment_selector.dart`
- Delete: `lib/features/config/widgets/minute_row.dart`
- Delete: `lib/features/config/widgets/minute_exact_editor.dart`

- [ ] **Schritt 1: `config_screen.dart` ersetzen**

Ersetze den kompletten Inhalt von `lib/features/config/config_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/settings.dart';
import '../../core/providers/settings_provider.dart';
import 'widgets/feedback_tab.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  final int visitCount;
  const ConfigScreen({super.key, this.visitCount = 0});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  late AppSettings _s;

  @override
  void initState() {
    super.initState();
    _s = ref.read(settingsNotifierProvider).requireValue;
  }

  @override
  void didUpdateWidget(ConfigScreen old) {
    super.didUpdateWidget(old);
    if (old.visitCount != widget.visitCount) {
      _s = ref.read(settingsNotifierProvider).requireValue;
    }
  }

  void _save() {
    ref.read(settingsNotifierProvider.notifier).replace(_s);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    if (settingsAsync.valueOrNull == null) return const SizedBox();
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: _save,
        ),
        title: const Text(
          'EINSTELLUNGEN',
          style: TextStyle(fontSize: 15, letterSpacing: 4, color: Colors.white38),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          FeedbackTab(
            settings: _s,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Schritt 2: `settings.dart` bereinigen**

Ersetze den kompletten Inhalt von `lib/core/models/settings.dart`:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Equipment { kettlebell, steelmace }

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

**Hinweis:** `PlanMode` enum wird ebenfalls entfernt. Falls irgendwo noch referenziert: alle Stellen auf Fehler prüfen und bereinigen.

- [ ] **Schritt 3: Alte Config-Widgets löschen**

```
git rm lib/features/config/widgets/phase_based_editor.dart
git rm lib/features/config/widgets/plan_mode_selector.dart
git rm lib/features/config/widgets/equipment_selector.dart
git rm lib/features/config/widgets/minute_row.dart
git rm lib/features/config/widgets/minute_exact_editor.dart
```

- [ ] **Schritt 4: Analyze**

```
flutter analyze
```

Falls Fehler: verbleibende Imports auf gelöschte Dateien oder entfernte Symbole (`PlanMode`, `planKey` auf `AppSettings`) bereinigen.

- [ ] **Schritt 5: Build-Test**

```
flutter build apk --debug
```

Erwartetes Ergebnis: ✓ Built.

- [ ] **Schritt 6: Commit**

```
git add lib/features/config/config_screen.dart lib/core/models/settings.dart
git commit -m "refactor: remove phase-based plan mode, slim down AppSettings to feedback-only, simplify ConfigScreen"
```

---

## Task 8: PlanIndicator + WorkoutScreen Planwechsel-Navigation

**Files:**
- Create: `lib/features/workout/widgets/plan_indicator.dart`
- Modify: `lib/features/workout/workout_screen.dart`

- [ ] **Schritt 1: `plan_indicator.dart` erstellen**

Erstelle `lib/features/workout/widgets/plan_indicator.dart`:

```dart
import 'package:flutter/material.dart';

class PlanIndicator extends StatelessWidget {
  final String planName;
  final VoidCallback onTap;

  const PlanIndicator({super.key, required this.planName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 11, color: Colors.white24),
            const SizedBox(width: 5),
            Text(planName,
                style: const TextStyle(
                    fontSize: 11, color: Colors.white24, letterSpacing: 1)),
            const SizedBox(width: 3),
            const Icon(Icons.chevron_right, size: 13, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Schritt 2: `workout_screen.dart` anpassen**

**a) Imports ergänzen** (am Anfang von `workout_screen.dart`):
```dart
import '../../core/providers/plan_library_notifier.dart';
import '../plans/plan_library_screen.dart';
import 'widgets/plan_indicator.dart';
```

**b) Feld `_planKeySnapshot` wieder einführen** (jetzt für PlanLibraryScreen):
```dart
// In _WorkoutScreenState — Felder:
String _planKeySnapshot = '';
```

**c) Methode `_openPlanLibrary` hinzufügen:**
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

**d) In `_buildWorkoutScreen`: `PlanIndicator` zwischen `OverallProgress` und `RepsCard` einfügen:**

```dart
// ALT:
OverallProgress(...),
const SizedBox(height: 48),
RepsCard(...),

// NEU:
OverallProgress(...),
const SizedBox(height: 8),
PlanIndicator(
  planName: ref.watch(planLibraryNotifierProvider).valueOrNull?.activePlan.name ?? '',
  onTap: () => _openPlanLibrary(state),
),
const SizedBox(height: 40),
RepsCard(...),
```

- [ ] **Schritt 3: Analyze**

```
flutter analyze
```

Erwartetes Ergebnis: keine Fehler.

- [ ] **Schritt 4: Build-Test**

```
flutter build apk --debug
```

Erwartetes Ergebnis: ✓ Built.

- [ ] **Schritt 5: Commit**

```
git add lib/features/workout/widgets/plan_indicator.dart lib/features/workout/workout_screen.dart
git commit -m "feat: add PlanIndicator pill on WorkoutScreen, navigate to PlanLibraryScreen with plan-change detection"
```

---

## Task 9: Abschluss-Verifikation

- [ ] **Schritt 1: build_runner (sauber)**

```
dart run build_runner build --delete-conflicting-outputs
```

Erwartetes Ergebnis: keine Fehler, alle `.g.dart`-Dateien aktuell.

- [ ] **Schritt 2: Alle Tests**

```
flutter test
```

Erwartetes Ergebnis: alle Tests grün.

- [ ] **Schritt 3: Analyze**

```
flutter analyze
```

Erwartetes Ergebnis: `No issues found.`

- [ ] **Schritt 4: Release-APK bauen**

```
flutter build apk --debug
```

Erwartetes Ergebnis: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Schritt 5: Abschluss-Commit**

```
git add .
git commit -m "chore: Trainingsplan-Verwaltung vollständig — PlanLibrary, PlanLibraryNotifier, PlanLibraryScreen, PlanEditorScreen, PlanIndicator"
```
