# Klassisches EMOM – Vorlage beim Plan-Erstellen – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Beim Erstellen eines neuen Plans eine Vorlage "Klassisches EMOM" anbieten, die 30 × 60s-Intervalle einer gewählten Übung mit wählbarem Wiederholungs-Schema (Konstant/Aufsteigend/Absteigend/Pyramide) erzeugt.

**Architecture:** Die reine Erzeugungslogik lebt als testbare Fabrik-Funktion im Model (`emomRepSequence` + `TrainingPlan.emom`). Darauf setzt ein neuer Vollbild-Wizard (`EmomWizardScreen`) auf. Der bestehende "Neuer Plan"-Button bekommt ein Auswahl-Sheet vorgeschaltet ("Leer" = heutiger Weg, "Klassisches EMOM" = Wizard). Kein neuer Riverpod-Provider → **kein `build_runner` nötig**.

**Tech Stack:** Flutter, Dart, Riverpod (bestehende Provider), `flutter_test`.

## Global Constraints

- UI-Labels auf Deutsch.
- `flutter analyze` muss ohne Findings durchlaufen.
- Design-Tokens aus `lib/core/theme/app_theme.dart` verwenden (`AppTheme.bg`, `AppTheme.surface`, `AppTheme.surfaceHigh`, `AppTheme.accent`), keine neuen Hex-Literale.
- Vorlage erzeugt **fest 30 Intervalle × 60s**, keine Pausen.
- Wiederholungen linear interpoliert, auf ganze Zahl gerundet, **Minimum 1**.
- Einarmige Übungen (`hasSide == true`): Seite wechselt pro Minute (Minute 1 = links, Minute 2 = rechts, …).
- Zeit-Übungen (`isTimed == true`): Schema/Wdh. entfallen, `reps = 0`.
- Commit-Messages auf Deutsch, jeweils mit `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

## File Structure

- `lib/core/models/training_plan.dart` — **modify**: `EmomRepScheme`-Enum, top-level `emomRepSequence(...)`, `TrainingPlan.emom(...)`-Fabrik.
- `lib/features/plans/emom_wizard_screen.dart` — **create**: Vollbild-Wizard (Name, Übungswahl, Schema, von/bis, "Erstellen").
- `lib/features/plans/plan_library_screen.dart` — **modify**: "Neuer Plan" öffnet Auswahl-Sheet; "Leer" behält heutiges Verhalten, "Klassisches EMOM" pusht den Wizard.
- `test/core/models/emom_template_test.dart` — **create**: Tests für `emomRepSequence` und `TrainingPlan.emom`.
- `test/features/plans/emom_wizard_screen_test.dart` — **create**: Widget-Test des Wizards.
- `test/features/plans/plan_library_chooser_test.dart` — **create**: Widget-Test des Auswahl-Sheets.

---

### Task 1: Wiederholungs-Sequenz (`EmomRepScheme` + `emomRepSequence`)

**Files:**
- Modify: `lib/core/models/training_plan.dart`
- Test: `test/core/models/emom_template_test.dart`

**Interfaces:**
- Produces:
  - `enum EmomRepScheme { konstant, aufsteigend, absteigend, pyramide }`
  - `List<int> emomRepSequence(EmomRepScheme scheme, {required int from, required int to, int count = 30})`

- [ ] **Step 1: Failing test schreiben**

Datei `test/core/models/emom_template_test.dart` anlegen:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';

void main() {
  group('emomRepSequence', () {
    test('konstant liefert überall denselben Wert', () {
      final seq = emomRepSequence(EmomRepScheme.konstant,
          from: 10, to: 10, count: 30);
      expect(seq.length, 30);
      expect(seq.every((r) => r == 10), isTrue);
    });

    test('aufsteigend interpoliert von Start bis Ziel (nicht fallend)', () {
      final seq = emomRepSequence(EmomRepScheme.aufsteigend,
          from: 5, to: 15, count: 30);
      expect(seq.length, 30);
      expect(seq.first, 5);
      expect(seq.last, 15);
      for (var i = 0; i < seq.length - 1; i++) {
        expect(seq[i] <= seq[i + 1], isTrue);
      }
    });

    test('absteigend interpoliert von Start bis Ziel (nicht steigend)', () {
      final seq = emomRepSequence(EmomRepScheme.absteigend,
          from: 15, to: 5, count: 30);
      expect(seq.first, 15);
      expect(seq.last, 5);
      for (var i = 0; i < seq.length - 1; i++) {
        expect(seq[i] >= seq[i + 1], isTrue);
      }
    });

    test('pyramide steigt zum Peak und fällt zurück', () {
      final seq = emomRepSequence(EmomRepScheme.pyramide,
          from: 5, to: 15, count: 30);
      expect(seq.length, 30);
      expect(seq.first, 5);
      expect(seq.last, 5);
      expect(seq.reduce((a, b) => a > b ? a : b), 15);
    });

    test('rundet nie unter 1', () {
      final seq = emomRepSequence(EmomRepScheme.absteigend,
          from: 2, to: 1, count: 30);
      expect(seq.every((r) => r >= 1), isTrue);
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/core/models/emom_template_test.dart`
Expected: FAIL — `emomRepSequence`/`EmomRepScheme` sind nicht definiert (Compile-Fehler).

- [ ] **Step 3: Minimale Implementierung**

In `lib/core/models/training_plan.dart` **oberhalb** von `class TrainingPlan` einfügen:

```dart
/// Wiederholungs-Schema einer klassischen EMOM-Vorlage.
enum EmomRepScheme { konstant, aufsteigend, absteigend, pyramide }

/// Erzeugt [count] Wiederholungs-Werte für ein EMOM nach [scheme].
/// Linear interpoliert, auf ganze Zahl gerundet, minimal 1.
List<int> emomRepSequence(
  EmomRepScheme scheme, {
  required int from,
  required int to,
  int count = 30,
}) {
  if (count <= 0) return const [];

  int lerp(int a, int b, int i, int steps) {
    if (steps <= 0) return a < 1 ? 1 : a;
    final v = a + (b - a) * i / steps;
    final r = v.round();
    return r < 1 ? 1 : r;
  }

  switch (scheme) {
    case EmomRepScheme.konstant:
      final v = from < 1 ? 1 : from;
      return List.filled(count, v);
    case EmomRepScheme.aufsteigend:
    case EmomRepScheme.absteigend:
      // Beide sind eine Gerade von `from` nach `to`; die zwei Chips
      // unterscheiden sich nur in der Default-Vorbelegung (5→15 vs. 15→5).
      return List.generate(count, (i) => lerp(from, to, i, count - 1));
    case EmomRepScheme.pyramide:
      final half = count ~/ 2;
      return List.generate(count, (i) {
        if (i < half) {
          return lerp(from, to, i, half); // Anstieg: Index 0 = from
        }
        // Abstieg: Index `half` = Peak (to), Ende = from.
        return lerp(to, from, i - half, count - 1 - half);
      });
  }
}
```

- [ ] **Step 4: Test laufen lassen, Erfolg prüfen**

Run: `flutter test test/core/models/emom_template_test.dart`
Expected: PASS (5 Tests grün).

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/training_plan.dart test/core/models/emom_template_test.dart
git commit -m "feat: EmomRepScheme und emomRepSequence fuer EMOM-Vorlage

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Fabrik `TrainingPlan.emom(...)`

**Files:**
- Modify: `lib/core/models/training_plan.dart`
- Test: `test/core/models/emom_template_test.dart`

**Interfaces:**
- Consumes: `EmomRepScheme`, `emomRepSequence` (Task 1); `IntervalConfig`, `ExerciseSide` (bestehend).
- Produces:
  ```dart
  factory TrainingPlan.emom({
    required String name,
    required String equipmentTypeId,
    String? variantId,
    required String exerciseTypeId,
    required bool hasSide,
    required bool isTimed,
    required EmomRepScheme scheme,
    required int fromReps,
    required int toReps,
    int intervals = 30,
    int durationSeconds = 60,
  })
  ```

- [ ] **Step 1: Failing test schreiben**

In `test/core/models/emom_template_test.dart` innerhalb von `main()` **nach** der `group('emomRepSequence', …)` folgende Gruppe ergänzen (Import für `ExerciseSide` oben in der Datei hinzufügen):

```dart
  group('TrainingPlan.emom', () {
    test('erzeugt 30 Intervalle der gewählten Übung', () {
      final plan = TrainingPlan.emom(
        name: 'Swings',
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'swing_beidarmig',
        hasSide: false,
        isTimed: false,
        scheme: EmomRepScheme.konstant,
        fromReps: 10,
        toReps: 10,
      );
      expect(plan.name, 'Swings');
      expect(plan.intervals.length, 30);
      expect(plan.intervals.every((iv) => iv.equipmentTypeId == 'kettlebell'),
          isTrue);
      expect(plan.intervals.every((iv) => iv.variantId == 'kb_24'), isTrue);
      expect(
          plan.intervals.every((iv) => iv.exerciseTypeId == 'swing_beidarmig'),
          isTrue);
      expect(plan.intervals.every((iv) => iv.durationSeconds == 60), isTrue);
      expect(plan.intervals.every((iv) => iv.reps == 10), isTrue);
      expect(plan.intervals.every((iv) => iv.side == null), isTrue);
      expect(plan.intervals.every((iv) => iv.isPause == false), isTrue);
    });

    test('wechselt die Seite bei einarmigen Übungen', () {
      final plan = TrainingPlan.emom(
        name: 'Snatch',
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_20',
        exerciseTypeId: 'snatch',
        hasSide: true,
        isTimed: false,
        scheme: EmomRepScheme.konstant,
        fromReps: 8,
        toReps: 8,
      );
      expect(plan.intervals[0].side, ExerciseSide.links);
      expect(plan.intervals[1].side, ExerciseSide.rechts);
      expect(plan.intervals[2].side, ExerciseSide.links);
    });

    test('aufsteigendes Schema landet in den Wiederholungen', () {
      final plan = TrainingPlan.emom(
        name: 'Ramp',
        equipmentTypeId: 'kettlebell',
        variantId: 'kb_24',
        exerciseTypeId: 'swing_beidarmig',
        hasSide: false,
        isTimed: false,
        scheme: EmomRepScheme.aufsteigend,
        fromReps: 5,
        toReps: 15,
      );
      expect(plan.intervals.first.reps, 5);
      expect(plan.intervals.last.reps, 15);
    });

    test('Zeit-Übung ignoriert Schema und setzt reps auf 0', () {
      final plan = TrainingPlan.emom(
        name: 'Plank',
        equipmentTypeId: 'custom_bw',
        variantId: null,
        exerciseTypeId: 'plank',
        hasSide: false,
        isTimed: true,
        scheme: EmomRepScheme.aufsteigend,
        fromReps: 5,
        toReps: 15,
      );
      expect(plan.intervals.length, 30);
      expect(plan.intervals.every((iv) => iv.durationSeconds == 60), isTrue);
      expect(plan.intervals.every((iv) => iv.reps == 0), isTrue);
    });
  });
```

Den Import-Block oben in der Datei auf folgendes erweitern:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/core/models/emom_template_test.dart`
Expected: FAIL — `TrainingPlan.emom` existiert nicht.

- [ ] **Step 3: Minimale Implementierung**

In `lib/core/models/training_plan.dart` innerhalb von `class TrainingPlan`, **direkt nach** der `factory TrainingPlan.fresh(...)`, einfügen:

```dart
  /// Klassisches EMOM: [intervals] gleich lange Intervalle einer Übung mit
  /// Wiederholungen nach [scheme]. Bei [isTimed] werden die Wiederholungen
  /// ignoriert (reps = 0), bei [hasSide] wechselt die Seite pro Minute.
  factory TrainingPlan.emom({
    required String name,
    required String equipmentTypeId,
    String? variantId,
    required String exerciseTypeId,
    required bool hasSide,
    required bool isTimed,
    required EmomRepScheme scheme,
    required int fromReps,
    required int toReps,
    int intervals = 30,
    int durationSeconds = 60,
  }) {
    final reps = isTimed
        ? List.filled(intervals, 0)
        : emomRepSequence(scheme,
            from: fromReps, to: toReps, count: intervals);
    return TrainingPlan(
      id: _newId(),
      name: name,
      intervals: List.generate(
        intervals,
        (i) => IntervalConfig(
          equipmentTypeId: equipmentTypeId,
          variantId: variantId,
          exerciseTypeId: exerciseTypeId,
          side: hasSide
              ? (i % 2 == 0 ? ExerciseSide.links : ExerciseSide.rechts)
              : null,
          reps: reps[i],
          durationSeconds: durationSeconds,
        ),
      ),
    );
  }
```

Hinweis: `ExerciseSide` ist in `training_plan.dart` bereits über `import 'settings.dart';` verfügbar (von `IntervalConfig` genutzt) — kein neuer Import nötig.

- [ ] **Step 4: Test laufen lassen, Erfolg prüfen**

Run: `flutter test test/core/models/emom_template_test.dart`
Expected: PASS (alle Tests grün).

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/training_plan.dart test/core/models/emom_template_test.dart
git commit -m "feat: TrainingPlan.emom-Fabrik fuer klassische EMOM-Plaene

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: EMOM-Wizard-Screen

**Files:**
- Create: `lib/features/plans/emom_wizard_screen.dart`
- Test: `test/features/plans/emom_wizard_screen_test.dart`

**Interfaces:**
- Consumes: `TrainingPlan.emom`, `EmomRepScheme` (Task 1/2); `equipmentCatalogProvider`, `planLibraryProvider` (bestehend); `PlanEditorScreen` (bestehend).
- Produces: `class EmomWizardScreen extends ConsumerStatefulWidget` mit Konstruktor `const EmomWizardScreen({super.key, required this.planCount})`.

- [ ] **Step 1: Failing test schreiben**

Datei `test/features/plans/emom_wizard_screen_test.dart` anlegen:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/equipment_catalog.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/providers/equipment_catalog_notifier.dart';
import 'package:emom_app/core/providers/plan_library_notifier.dart';
import 'package:emom_app/features/plans/emom_wizard_screen.dart';

class _FakeCatalogNotifier extends EquipmentCatalogNotifier {
  @override
  Future<EquipmentCatalog> build() async => EquipmentCatalog.defaultCatalog();
}

class _CapturingPlanLibraryNotifier extends PlanLibraryNotifier {
  final PlanLibrary initial;
  final List<TrainingPlan> added = [];
  _CapturingPlanLibraryNotifier(this.initial);

  @override
  Future<PlanLibrary> build() async => initial;

  @override
  Future<void> addPlan(TrainingPlan plan) async {
    added.add(plan);
    state = AsyncData(PlanLibrary(
      plans: [...initial.plans, plan],
      activePlanId: initial.activePlanId,
    ));
  }
}

void main() {
  testWidgets('Erstellen erzeugt einen 30-Intervall-EMOM-Plan',
      (tester) async {
    final base = TrainingPlan.fresh('Plan 1');
    final library = PlanLibrary(plans: [base], activePlanId: base.id);
    final fake = _CapturingPlanLibraryNotifier(library);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentCatalogProvider.overrideWith(() => _FakeCatalogNotifier()),
          planLibraryProvider.overrideWith(() => fake),
        ],
        child: const MaterialApp(
          home: EmomWizardScreen(planCount: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    expect(fake.added.length, 1);
    expect(fake.added.single.intervals.length, 30);
    expect(
      fake.added.single.intervals.every((iv) => iv.durationSeconds == 60),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/features/plans/emom_wizard_screen_test.dart`
Expected: FAIL — `emom_wizard_screen.dart` existiert nicht.

- [ ] **Step 3: Wizard implementieren**

Datei `lib/features/plans/emom_wizard_screen.dart` anlegen:

```dart
import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/equipment_catalog.dart';
import '../../core/models/training_plan.dart';
import '../../core/providers/equipment_catalog_notifier.dart';
import '../../core/providers/plan_library_notifier.dart';
import 'plan_editor_screen.dart';

/// Wizard zum Anlegen eines klassischen EMOM-Plans (30 × 60s einer Übung).
/// Bearbeiten einzelner Minuten läuft danach über den PlanEditorScreen.
class EmomWizardScreen extends ConsumerStatefulWidget {
  final int planCount;
  const EmomWizardScreen({super.key, required this.planCount});

  @override
  ConsumerState<EmomWizardScreen> createState() => _EmomWizardScreenState();
}

class _EmomWizardScreenState extends ConsumerState<EmomWizardScreen> {
  late final TextEditingController _nameCtrl;
  String? _equipmentTypeId;
  String? _variantId;
  String? _exerciseTypeId;
  EmomRepScheme _scheme = EmomRepScheme.konstant;
  int _from = 10;
  int _to = 10;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: 'Plan ${widget.planCount + 1}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Beim ersten Aufbau die Auswahl aus dem Katalog vorbelegen.
  void _ensureDefaults(EquipmentCatalog catalog) {
    if (_exerciseTypeId != null || catalog.types.isEmpty) return;
    final type = catalog.types.first;
    _equipmentTypeId = type.id;
    _variantId = type.variants.isNotEmpty ? type.variants.first.id : null;
    _exerciseTypeId =
        type.exercises.isNotEmpty ? type.exercises.first.id : null;
  }

  void _applySchemeDefaults(EmomRepScheme scheme) {
    switch (scheme) {
      case EmomRepScheme.konstant:
        _from = 10;
        _to = 10;
      case EmomRepScheme.aufsteigend:
        _from = 5;
        _to = 15;
      case EmomRepScheme.absteigend:
        _from = 15;
        _to = 5;
      case EmomRepScheme.pyramide:
        _from = 5;
        _to = 15;
    }
  }

  ExerciseType? _selectedExercise(EquipmentCatalog catalog) {
    final type = catalog.findType(_equipmentTypeId ?? '');
    if (type == null) return null;
    return type.exercises
        .where((e) => e.id == _exerciseTypeId)
        .cast<ExerciseType?>()
        .firstOrNull;
  }

  void _selectEquipment(EquipmentType type, String? variantId) {
    setState(() {
      _equipmentTypeId = type.id;
      _variantId = variantId;
      if (!type.exercises.any((e) => e.id == _exerciseTypeId)) {
        _exerciseTypeId =
            type.exercises.isNotEmpty ? type.exercises.first.id : null;
      }
    });
  }

  Future<void> _create(EquipmentCatalog catalog) async {
    final type = catalog.findType(_equipmentTypeId ?? '');
    final exercise = _selectedExercise(catalog);
    if (type == null || exercise == null) return;
    final plan = TrainingPlan.emom(
      name: _nameCtrl.text.trim().isEmpty
          ? 'Plan ${widget.planCount + 1}'
          : _nameCtrl.text.trim(),
      equipmentTypeId: type.id,
      variantId: _variantId,
      exerciseTypeId: exercise.id,
      hasSide: exercise.hasSide,
      isTimed: exercise.isTimed,
      scheme: _scheme,
      fromReps: _from,
      toReps: _to,
    );
    await ref.read(planLibraryProvider.notifier).addPlan(plan);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PlanEditorScreen(plan: plan)),
    );
  }

  // ── kleine UI-Bausteine ────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, letterSpacing: 2, color: Colors.white38)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent : AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(6),
            border: selected ? null : Border.all(color: Colors.white12),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.black : Colors.white54)),
        ),
      );

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) => Row(
        children: [
          SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.white38))),
          _stepButton(Icons.remove, value > 1 ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 40,
            child: Center(
              child: Text('$value',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
            ),
          ),
          _stepButton(Icons.add, () => onChanged(value + 1)),
        ],
      );

  Widget _stepButton(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 16, color: onTap != null ? Colors.white38 : Colors.white12),
        ),
      );

  Widget _equipmentPicker(EquipmentCatalog catalog) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final type in catalog.types)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Image.asset(type.iconAsset,
                        width: 14, height: 14, color: Colors.white38),
                  ),
                  Expanded(
                    child: Wrap(
                      children: [
                        if (type.variants.isEmpty)
                          _chip(type.name, _equipmentTypeId == type.id,
                              () => _selectEquipment(type, null))
                        else
                          for (final v in type.variants)
                            _chip(
                              v.shortLabel,
                              _equipmentTypeId == type.id &&
                                  _variantId == v.id,
                              () => _selectEquipment(type, v.id),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _exercisePicker(EquipmentType type) => Wrap(
        children: [
          for (final ex in type.exercises)
            _chip(ex.name, _exerciseTypeId == ex.id,
                () => setState(() => _exerciseTypeId = ex.id)),
        ],
      );

  Widget _schemePicker() {
    const labels = {
      EmomRepScheme.konstant: 'Konstant',
      EmomRepScheme.aufsteigend: 'Aufsteigend',
      EmomRepScheme.absteigend: 'Absteigend',
      EmomRepScheme.pyramide: 'Pyramide',
    };
    return Wrap(
      children: [
        for (final s in EmomRepScheme.values)
          _chip(labels[s]!, _scheme == s, () {
            setState(() {
              _scheme = s;
              _applySchemeDefaults(s);
            });
          }),
      ],
    );
  }

  Widget _repsInputs() {
    if (_scheme == EmomRepScheme.konstant) {
      return _stepper('Wdh./Min', _from, (v) => setState(() {
            _from = v;
            _to = v;
          }));
    }
    final fromLabel =
        _scheme == EmomRepScheme.pyramide ? 'Rand' : 'von';
    final toLabel = _scheme == EmomRepScheme.pyramide ? 'Peak' : 'bis';
    return Column(
      children: [
        _stepper(fromLabel, _from, (v) => setState(() => _from = v)),
        const SizedBox(height: 8),
        _stepper(toLabel, _to, (v) => setState(() => _to = v)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(equipmentCatalogProvider);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('KLASSISCHES EMOM',
            style: TextStyle(
                fontSize: 15, letterSpacing: 4, color: Colors.white38)),
      ),
      body: catalogAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: Colors.white38))),
        data: (catalog) {
          _ensureDefaults(catalog);
          final type = catalog.findType(_equipmentTypeId ?? '');
          final exercise = _selectedExercise(catalog);
          final isTimed = exercise?.isTimed ?? false;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('NAME'),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white70),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.accent)),
                  ),
                ),
                _sectionLabel('GERÄT'),
                _equipmentPicker(catalog),
                _sectionLabel('ÜBUNG'),
                if (type != null) _exercisePicker(type),
                if (isTimed) ...[
                  _sectionLabel('WIEDERHOLUNGEN'),
                  const Text('Zeit-Übung: 30 × 60s, keine Wiederholungen.',
                      style: TextStyle(fontSize: 12, color: Colors.white38)),
                ] else ...[
                  _sectionLabel('SCHEMA'),
                  _schemePicker(),
                  _sectionLabel('WIEDERHOLUNGEN'),
                  _repsInputs(),
                ],
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: exercise == null ? null : () => _create(catalog),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: exercise == null ? Colors.white12 : AppTheme.ok,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Erstellen',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              exercise == null ? Colors.white24 : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Test laufen lassen, Erfolg prüfen**

Run: `flutter test test/features/plans/emom_wizard_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyzer prüfen**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/plans/emom_wizard_screen.dart test/features/plans/emom_wizard_screen_test.dart
git commit -m "feat: EMOM-Wizard-Screen zum Anlegen klassischer EMOM-Plaene

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Auswahl-Sheet am "Neuer Plan"-Button

**Files:**
- Modify: `lib/features/plans/plan_library_screen.dart`
- Test: `test/features/plans/plan_library_chooser_test.dart`

**Interfaces:**
- Consumes: `EmomWizardScreen` (Task 3); bestehende `_addPlan`-Logik.
- Produces: keine — verdrahtet nur den Einstieg.

- [ ] **Step 1: Failing test schreiben**

Datei `test/features/plans/plan_library_chooser_test.dart` anlegen:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/equipment_catalog.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/providers/equipment_catalog_notifier.dart';
import 'package:emom_app/core/providers/plan_library_notifier.dart';
import 'package:emom_app/features/plans/plan_library_screen.dart';

class _FakeCatalogNotifier extends EquipmentCatalogNotifier {
  @override
  Future<EquipmentCatalog> build() async => EquipmentCatalog.defaultCatalog();
}

class _FakePlanLibraryNotifier extends PlanLibraryNotifier {
  final PlanLibrary initial;
  _FakePlanLibraryNotifier(this.initial);
  @override
  Future<PlanLibrary> build() async => initial;
}

void main() {
  testWidgets('Neuer Plan zeigt Auswahl Leer / Klassisches EMOM',
      (tester) async {
    final base = TrainingPlan.fresh('Plan 1');
    final library = PlanLibrary(plans: [base], activePlanId: base.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentCatalogProvider.overrideWith(() => _FakeCatalogNotifier()),
          planLibraryProvider
              .overrideWith(() => _FakePlanLibraryNotifier(library)),
        ],
        child: const MaterialApp(home: PlanLibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Neuer Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('Klassisches EMOM'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/features/plans/plan_library_chooser_test.dart`
Expected: FAIL — "Neuer Plan" öffnet direkt den Namens-Dialog, "Klassisches EMOM" wird nicht gefunden.

- [ ] **Step 3: Auswahl-Sheet einbauen**

In `lib/features/plans/plan_library_screen.dart` den Import ergänzen (nach den bestehenden Imports):

```dart
import 'emom_wizard_screen.dart';
```

Die bestehende Methode `_addPlan` **umbenennen** in `_addEmptyPlan` (Signatur und Body bleiben identisch — nur der Name in der Deklaration ändert sich):

```dart
  Future<void> _addEmptyPlan(BuildContext context, int planCount) async {
```

(Der Rumpf von `_addEmptyPlan` bleibt exakt wie der heutige `_addPlan`-Rumpf.)

Darüber eine neue Methode einfügen, die das Auswahl-Sheet zeigt:

```dart
  Future<void> _addPlan(BuildContext context, int planCount) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('NEUER PLAN',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: Colors.white38)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined,
                  color: Colors.white54),
              title: const Text('Leer',
                  style: TextStyle(color: Colors.white70)),
              subtitle: const Text('Selbst aufbauen',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'empty'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.timer_outlined, color: AppTheme.accent),
              title: const Text('Klassisches EMOM',
                  style: TextStyle(color: Colors.white70)),
              subtitle: const Text('30 × 60s einer Übung',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'emom'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'empty') {
      await _addEmptyPlan(context, planCount);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmomWizardScreen(planCount: planCount),
        ),
      );
    }
  }
```

Der "Neuer Plan"-Button ruft weiterhin `_addPlan(context, library.plans.length)` auf — keine Änderung am Button selbst nötig.

- [ ] **Step 4: Test laufen lassen, Erfolg prüfen**

Run: `flutter test test/features/plans/plan_library_chooser_test.dart`
Expected: PASS.

- [ ] **Step 5: Volle Test-Suite + Analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: Alle Tests grün.

- [ ] **Step 6: Commit**

```bash
git add lib/features/plans/plan_library_screen.dart test/features/plans/plan_library_chooser_test.dart
git commit -m "feat: Auswahl-Sheet Leer vs. Klassisches EMOM beim Plan-Erstellen

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- Zusätzliche Option (nicht Ersatz) → Task 4 (Auswahl-Sheet, "Leer" behält heutigen Weg). ✓
- Vier Schemata Konstant/Aufsteigend/Absteigend/Pyramide → Task 1 (`EmomRepScheme`, `emomRepSequence`), Task 3 (`_schemePicker`). ✓
- Fest 30 × 60s → Task 2 (Default-Parameter `intervals = 30`, `durationSeconds = 60`). ✓
- von/bis-Modell mit Interpolation → Task 1 (`lerp`), Task 3 (`_repsInputs`, Konstant = 1 Feld, sonst 2). ✓
- Volle Übungsauswahl (Gerät/Variante/Übung/Seite) → Task 3 (`_equipmentPicker`, `_exercisePicker`; Seite automatisch über `hasSide` in Task 2). ✓
- Zeit-Übung: Schema weg, 30×60s, reps 0 → Task 2 (`isTimed`-Zweig), Task 3 (`isTimed`-UI-Zweig). ✓
- Seiten-Auto-Wechsel bei einarmigen Übungen → Task 2 (`i % 2`), getestet. ✓
- Nach Erstellen Editor öffnen, nicht auto-aktiv → Task 3 (`pushReplacement` auf `PlanEditorScreen`; `addPlan` setzt `activePlanId` nicht). ✓
- Defaults Konstant 10 / Aufsteigend 5→15 / Absteigend 15→5 / Pyramide 5→15 → Task 3 (`_applySchemeDefaults`, `_from/_to`-Init). ✓

**2. Placeholder-Scan:** Keine TBD/TODO; jeder Code-Schritt zeigt vollständigen Code. ✓

**3. Type-Konsistenz:** `EmomRepScheme` (Task 1) identisch in Task 2/3 verwendet; `emomRepSequence(scheme, {from, to, count})` und `TrainingPlan.emom({...})`-Signaturen stimmen zwischen Definition (Task 1/2) und Aufruf (Task 3) überein; `EmomWizardScreen(planCount:)` in Task 3 definiert, in Task 4 so aufgerufen. ✓
