# Equipment Detail-Editor + Creation-only Wizard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Geräte & Übungen umbauen: der Wizard dient nur noch der Neuanlage (4 Schritte), Bearbeiten geschieht über einen neuen Detail-Editor mit direkt editierbaren Sektionen (inkl. Name & Icon), und die Geräte-Liste wird zusätzlich aus der Plan-Bibliothek erreichbar.

**Architecture:** Geteilte UI-Bausteine (Zeilen, Inline-Add, Icon-Grid, Namensfeld) wandern in `widgets/equipment_edit_widgets.dart`. `EquipmentWizardScreen` wird auf Creation-only reduziert (kein `editType`, kein "Gerät wählen"-Schritt). Neuer `EquipmentDetailScreen` speichert automatisch beim Verlassen via `PopScope` (Muster aus `plan_editor_screen.dart`). `EquipmentCatalogScreen` routet Tap → Detail-Editor, "+" → Wizard.

**Tech Stack:** Flutter, Riverpod codegen (`equipmentCatalogProvider` / `planLibraryProvider` — beide bereits generiert, kein build_runner nötig, da keine Provider geändert werden).

**Spec:** `docs/superpowers/specs/2026-06-12-equipment-detail-editor-design.md`

**Hinweis zu Tests:** Das Datenmodell ändert sich nicht; die bestehenden Tests (`test/core/models/equipment_catalog_test.dart`) bleiben unberührt. Das Projekt hat keine Widget-Test-Infrastruktur (keine Provider-Override-Fakes, Storage hängt an `path_provider`) — Verifikation läuft pro Task über `flutter analyze`, am Ende `flutter test` + manuelle Checkliste (Task 6).

---

### Task 1: Geteilte Edit-Widgets extrahieren

**Files:**
- Create: `lib/features/config/widgets/equipment_edit_widgets.dart`

- [ ] **Step 1: Datei mit allen geteilten Bausteinen anlegen**

Vollständiger Inhalt:

```dart
import 'package:flutter/material.dart';
import '../../../core/models/equipment_catalog.dart';

const kEquipmentIconAssets = [
  'assets/icon/kettlebell.png',
  'assets/icon/steelmace.png',
  'assets/icon/pezziball.png',
  'assets/icon/liegestuetz.png',
];

// ── Mutable Arbeitskopien für die Editier-Screens ─────────────────────────

class EditableVariant {
  final String id;
  String label;
  String shortLabel;
  EditableVariant({required this.id, required this.label, required this.shortLabel});

  factory EditableVariant.from(EquipmentVariant v) =>
      EditableVariant(id: v.id, label: v.label, shortLabel: v.shortLabel);

  EquipmentVariant toVariant() =>
      EquipmentVariant(id: id, label: label, shortLabel: shortLabel);
}

class EditableExercise {
  final String id;
  String name;
  bool hasSide;
  EditableExercise({required this.id, required this.name, required this.hasSide});

  factory EditableExercise.from(ExerciseType e) =>
      EditableExercise(id: e.id, name: e.name, hasSide: e.hasSide);

  ExerciseType toType() => ExerciseType(id: id, name: name, hasSide: hasSide);
}

// ── Bausteine ─────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, letterSpacing: 1.5, color: Colors.white38)),
      );
}

class EquipmentIconGrid extends StatelessWidget {
  final String selectedAsset;
  final ValueChanged<String> onSelect;
  const EquipmentIconGrid(
      {super.key, required this.selectedAsset, required this.onSelect});

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: kEquipmentIconAssets.map((asset) {
          final selected = asset == selectedAsset;
          return GestureDetector(
            onTap: () => onSelect(asset),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? const Color(0xFFFF6B00) : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(asset, color: const Color(0xFFFF6B00)),
            ),
          );
        }).toList(),
      );
}

class EquipmentNameField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  const EquipmentNameField(
      {super.key,
      required this.controller,
      required this.onChanged,
      this.autofocus = false});

  @override
  Widget build(BuildContext context) => TextField(
        autofocus: autofocus,
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'z.B. Resistance Band',
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

class VariantRow extends StatelessWidget {
  final EditableVariant variant;
  final VoidCallback onDelete;
  const VariantRow({super.key, required this.variant, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(variant.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 13))),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close, size: 16, color: Colors.white38),
            ),
          ],
        ),
      );
}

class ExerciseRow extends StatelessWidget {
  final EditableExercise exercise;
  final VoidCallback onToggleSide;
  final VoidCallback? onDelete;
  const ExerciseRow(
      {super.key,
      required this.exercise,
      required this.onToggleSide,
      required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(exercise.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 13))),
            GestureDetector(
              onTap: onToggleSide,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: exercise.hasSide
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('L/R',
                    style: TextStyle(
                        fontSize: 11,
                        color: exercise.hasSide ? Colors.black : Colors.white38,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close,
                  size: 16,
                  color: onDelete != null ? Colors.white38 : Colors.white12),
            ),
          ],
        ),
      );
}

class InlineAddRow extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  const InlineAddRow(
      {super.key,
      required this.controller,
      required this.hintText,
      required this.onSubmit,
      required this.onCancel});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onSubmit,
              child: const Text('OK', style: TextStyle(color: Color(0xFFFF6B00))),
            ),
            TextButton(
              onPressed: onCancel,
              child: const Text('✕', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      );
}

class AddEntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AddEntryButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label,
              style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 12)),
        ),
      );
}
```

- [ ] **Step 2: Analyse laufen lassen**

Run: `flutter analyze`
Expected: `No issues found!` (die neue Datei wird noch nirgends importiert — unbenutzte Klassen sind kein Analyzer-Fehler)

- [ ] **Step 3: Commit**

```bash
git add lib/features/config/widgets/equipment_edit_widgets.dart
git commit -m "refactor: extract shared equipment edit widgets"
```

---

### Task 2: Wizard auf Creation-only reduzieren (4 Schritte)

**Files:**
- Modify: `lib/features/config/equipment_wizard_screen.dart` (kompletter Ersatz des Dateiinhalts)

- [ ] **Step 1: Datei vollständig ersetzen**

Entfernt werden: `editType`-Parameter, Schritt "Gerät wählen" inkl. `_SelectionCard`, `_selectedType`/`_isNewSelected`/`_displayStep`/`_totalSteps`, Edit-Zweig in `_save()`, Usage-Checks (`_variantUsed`/`_exerciseUsed`, `_tryDelete*` — bei Neuanlage sind alle IDs frisch), `_catalogSubtitle`, lokale `_kIconAssets`/`_EditableVariant`/`_EditableExercise` (kommen jetzt aus `equipment_edit_widgets.dart`). Der `planLibraryProvider`-Import entfällt ebenso wie das `catalogAsync.when(...)` im Build.

Vollständiger neuer Inhalt:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/equipment_catalog.dart';
import '../../core/providers/equipment_catalog_notifier.dart';
import 'widgets/equipment_edit_widgets.dart';

/// Wizard zum Anlegen eines neuen Geräts (4 Schritte).
/// Bearbeiten bestehender Geräte läuft über [EquipmentDetailScreen].
class EquipmentWizardScreen extends ConsumerStatefulWidget {
  const EquipmentWizardScreen({super.key});

  @override
  ConsumerState<EquipmentWizardScreen> createState() =>
      _EquipmentWizardScreenState();
}

class _EquipmentWizardScreenState extends ConsumerState<EquipmentWizardScreen> {
  int _step = 1;
  String _name = '';
  String _iconAsset = kEquipmentIconAssets.first;
  final List<EditableVariant> _variants = [];
  final List<EditableExercise> _exercises = [];

  final _nameCtrl = TextEditingController();
  final _newVariantCtrl = TextEditingController();
  final _newExerciseCtrl = TextEditingController();
  bool _addingVariant = false;
  bool _addingExercise = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _newVariantCtrl.dispose();
    _newExerciseCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _goForward() {
    if (_step < 4) {
      setState(() {
        _addingVariant = false;
        _addingExercise = false;
        _step++;
      });
    }
  }

  void _goBack() {
    if (_step > 1) {
      setState(() {
        _addingVariant = false;
        _addingExercise = false;
        _step--;
      });
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final newType = EquipmentType(
      id: EquipmentCatalog.newId(),
      name: _name.trim(),
      iconAsset: _iconAsset,
      variants: _variants.map((v) => v.toVariant()).toList(),
      exercises: _exercises.map((e) => e.toType()).toList(),
    );
    await ref.read(equipmentCatalogProvider.notifier).addEquipmentType(newType);
    if (mounted) Navigator.of(context).pop();
  }

  // ── UI helpers ──────────────────────────────────────────────────────────

  Widget _stepHeader() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Schritt $_step von 4',
          style: const TextStyle(
              fontSize: 11, letterSpacing: 2, color: Colors.white24),
        ),
      );

  Widget _summaryPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      );

  Widget _orangeButton(String label, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: onTap != null ? const Color(0xFFFF6B00) : Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: onTap != null ? Colors.black : Colors.white24,
                  fontSize: 13)),
        ),
      );

  Widget _ghostButton(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );

  Widget _stepNav({
    required bool canGoForward,
    required VoidCallback? onForward,
    required String forwardLabel,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_step > 1)
              _ghostButton('← Zurück', _goBack)
            else
              const SizedBox(),
            if (forwardLabel.isNotEmpty)
              _orangeButton(forwardLabel, canGoForward ? onForward : null),
          ],
        ),
      );

  // ── Wizard steps ────────────────────────────────────────────────────────

  Widget _buildStep1() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(),
          const SectionLabel('NAME'),
          EquipmentNameField(
            controller: _nameCtrl,
            autofocus: true,
            onChanged: (v) => setState(() => _name = v),
          ),
          const SectionLabel('ICON WÄHLEN'),
          EquipmentIconGrid(
            selectedAsset: _iconAsset,
            onSelect: (asset) => setState(() => _iconAsset = asset),
          ),
          _stepNav(
            canGoForward: _name.trim().isNotEmpty,
            onForward: _goForward,
            forwardLabel: 'Weiter →',
          ),
        ],
      );

  Widget _buildStep2() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(),
          const SectionLabel('VARIANTEN'),
          ..._variants.asMap().entries.map(
                (entry) => VariantRow(
                  variant: entry.value,
                  onDelete: () =>
                      setState(() => _variants.removeAt(entry.key)),
                ),
              ),
          if (_addingVariant)
            InlineAddRow(
              controller: _newVariantCtrl,
              hintText: 'z.B. 16 kg',
              onSubmit: () {
                final text = _newVariantCtrl.text.trim();
                if (text.isEmpty) return;
                setState(() {
                  _variants.add(EditableVariant(
                      id: EquipmentCatalog.newId(),
                      label: text,
                      shortLabel: text));
                  _newVariantCtrl.clear();
                  _addingVariant = false;
                });
              },
              onCancel: () => setState(() {
                _addingVariant = false;
                _newVariantCtrl.clear();
              }),
            )
          else
            AddEntryButton(
              label: '+ Variante hinzufügen',
              onTap: () => setState(() => _addingVariant = true),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Leer lassen für kein Gewicht',
              style: TextStyle(fontSize: 10, color: Colors.white24),
            ),
          ),
          _stepNav(
            canGoForward: true,
            onForward: _goForward,
            forwardLabel: 'Weiter →',
          ),
        ],
      );

  Widget _buildStep3() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(),
          const SectionLabel('ÜBUNGEN (mind. 1)'),
          ..._exercises.asMap().entries.map(
                (entry) => ExerciseRow(
                  exercise: entry.value,
                  onToggleSide: () => setState(
                      () => entry.value.hasSide = !entry.value.hasSide),
                  onDelete: () =>
                      setState(() => _exercises.removeAt(entry.key)),
                ),
              ),
          if (_addingExercise)
            InlineAddRow(
              controller: _newExerciseCtrl,
              hintText: 'z.B. Clean and Press',
              onSubmit: () {
                final text = _newExerciseCtrl.text.trim();
                if (text.isEmpty) return;
                setState(() {
                  _exercises.add(EditableExercise(
                      id: EquipmentCatalog.newId(),
                      name: text,
                      hasSide: false));
                  _newExerciseCtrl.clear();
                  _addingExercise = false;
                });
              },
              onCancel: () => setState(() {
                _addingExercise = false;
                _newExerciseCtrl.clear();
              }),
            )
          else
            AddEntryButton(
              label: '+ Übung hinzufügen',
              onTap: () => setState(() => _addingExercise = true),
            ),
          _stepNav(
            canGoForward: _exercises.isNotEmpty,
            onForward: _goForward,
            forwardLabel: 'Weiter →',
          ),
        ],
      );

  Widget _buildStep4() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Image.asset(_iconAsset,
                    width: 22, height: 22, color: const Color(0xFFFF6B00)),
                const SizedBox(width: 12),
                Text(_name.trim(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_variants.isNotEmpty) ...[
            const SectionLabel('GEWICHTE'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _variants.map((v) => _summaryPill(v.label)).toList(),
            ),
          ],
          const SectionLabel('ÜBUNGEN'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _exercises.map((e) => _summaryPill(e.name)).toList(),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '✓ Speichern',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
          _stepNav(
            canGoForward: false,
            onForward: null,
            forwardLabel: '',
          ),
        ],
      );

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      1 => 'NAME & ICON',
      2 => 'GEWICHTE',
      3 => 'ÜBUNGEN',
      _ => 'ZUSAMMENFASSUNG',
    };

    final body = switch (_step) {
      1 => _buildStep1(),
      2 => _buildStep2(),
      3 => _buildStep3(),
      _ => _buildStep4(),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 15, letterSpacing: 4, color: Colors.white38)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: body,
      ),
    );
  }
}
```

- [ ] **Step 2: Analyse laufen lassen**

Run: `flutter analyze`
Expected: ein Fehler in `equipment_catalog_screen.dart` (Zeile ~61: `EquipmentWizardScreen(editType: t)` — Parameter existiert nicht mehr). Das ist erwartet und wird in Task 4 behoben. Keine weiteren Fehler.

> Hinweis: Wer Task 4 vorziehen will, um den Build grün zu halten, kann Task 2 + Task 4 zusammen committen. Standard-Reihenfolge: erst Task 3 (Detail-Screen), dann Task 4 (Routing), dann committen beider Routing-Änderungen — siehe Commit-Steps der jeweiligen Tasks. Der Commit in diesem Task ist deshalb bewusst **nur** der Wizard, der Analyzer-Fehler wird im selben Arbeitsgang durch Task 3+4 geschlossen, bevor gepusht wird.

- [ ] **Step 3: Commit**

```bash
git add lib/features/config/equipment_wizard_screen.dart
git commit -m "refactor: reduce equipment wizard to creation-only 4-step flow"
```

---

### Task 3: Detail-Editor anlegen

**Files:**
- Create: `lib/features/config/equipment_detail_screen.dart`

- [ ] **Step 1: Screen anlegen**

Vollständiger Inhalt:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/equipment_catalog.dart';
import '../../core/providers/equipment_catalog_notifier.dart';
import '../../core/providers/plan_library_notifier.dart';
import 'widgets/equipment_edit_widgets.dart';

/// Detail-Editor für ein bestehendes Gerät. Alle Sektionen (Name & Icon,
/// Gewichte, Übungen) sind direkt editierbar; gespeichert wird automatisch
/// beim Verlassen (PopScope) — gleiches Muster wie der Plan-Editor.
class EquipmentDetailScreen extends ConsumerStatefulWidget {
  final EquipmentType type;

  const EquipmentDetailScreen({super.key, required this.type});

  @override
  ConsumerState<EquipmentDetailScreen> createState() =>
      _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends ConsumerState<EquipmentDetailScreen> {
  late final TextEditingController _nameCtrl;
  final _newVariantCtrl = TextEditingController();
  final _newExerciseCtrl = TextEditingController();

  late String _iconAsset;
  late List<EditableVariant> _variants;
  late List<EditableExercise> _exercises;
  bool _addingVariant = false;
  bool _addingExercise = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.type.name);
    _iconAsset = widget.type.iconAsset;
    _variants = widget.type.variants.map(EditableVariant.from).toList();
    _exercises = widget.type.exercises.map(EditableExercise.from).toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _newVariantCtrl.dispose();
    _newExerciseCtrl.dispose();
    super.dispose();
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final updated = EquipmentType(
      id: widget.type.id,
      // Leeres Namensfeld beim Verlassen: alten Namen behalten.
      name: name.isEmpty ? widget.type.name : name,
      iconAsset: _iconAsset,
      variants: _variants.map((v) => v.toVariant()).toList(),
      exercises: _exercises.map((e) => e.toType()).toList(),
    );
    await ref
        .read(equipmentCatalogProvider.notifier)
        .updateEquipmentType(updated);
  }

  // ── Delete checks (Verwendung in Plänen blockiert Löschen) ──────────────

  bool _variantUsed(String variantId) {
    final library = ref.read(planLibraryProvider).value;
    return library?.plans
            .any((p) => p.intervals.any((iv) => iv.variantId == variantId)) ??
        false;
  }

  bool _exerciseUsed(String exerciseId) {
    final library = ref.read(planLibraryProvider).value;
    return library?.plans.any(
            (p) => p.intervals.any((iv) => iv.exerciseTypeId == exerciseId)) ??
        false;
  }

  void _tryDeleteVariant(int i) {
    final v = _variants[i];
    if (_variantUsed(v.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Variante "${v.label}" wird in einem Plan verwendet.'),
        backgroundColor: Colors.red[900],
      ));
      return;
    }
    setState(() => _variants.removeAt(i));
  }

  void _tryDeleteExercise(int i) {
    final e = _exercises[i];
    if (_exerciseUsed(e.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Übung "${e.name}" wird in einem Plan verwendet.'),
        backgroundColor: Colors.red[900],
      ));
      return;
    }
    setState(() => _exercises.removeAt(i));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _save().ignore();
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
          title: Text(widget.type.name.toUpperCase(),
              style: const TextStyle(
                  fontSize: 15, letterSpacing: 4, color: Colors.white38)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('NAME'),
              EquipmentNameField(
                controller: _nameCtrl,
                onChanged: (_) {},
              ),
              const SectionLabel('ICON'),
              EquipmentIconGrid(
                selectedAsset: _iconAsset,
                onSelect: (asset) => setState(() => _iconAsset = asset),
              ),
              const SectionLabel('GEWICHTE'),
              ..._variants.asMap().entries.map(
                    (entry) => VariantRow(
                      variant: entry.value,
                      onDelete: () => _tryDeleteVariant(entry.key),
                    ),
                  ),
              if (_addingVariant)
                InlineAddRow(
                  controller: _newVariantCtrl,
                  hintText: 'z.B. 16 kg',
                  onSubmit: () {
                    final text = _newVariantCtrl.text.trim();
                    if (text.isEmpty) return;
                    setState(() {
                      _variants.add(EditableVariant(
                          id: EquipmentCatalog.newId(),
                          label: text,
                          shortLabel: text));
                      _newVariantCtrl.clear();
                      _addingVariant = false;
                    });
                  },
                  onCancel: () => setState(() {
                    _addingVariant = false;
                    _newVariantCtrl.clear();
                  }),
                )
              else
                AddEntryButton(
                  label: '+ Gewicht hinzufügen',
                  onTap: () => setState(() => _addingVariant = true),
                ),
              const SectionLabel('ÜBUNGEN'),
              ..._exercises.asMap().entries.map(
                    (entry) => ExerciseRow(
                      exercise: entry.value,
                      onToggleSide: () => setState(
                          () => entry.value.hasSide = !entry.value.hasSide),
                      onDelete: _exercises.length > 1
                          ? () => _tryDeleteExercise(entry.key)
                          : null,
                    ),
                  ),
              if (_addingExercise)
                InlineAddRow(
                  controller: _newExerciseCtrl,
                  hintText: 'z.B. Clean and Press',
                  onSubmit: () {
                    final text = _newExerciseCtrl.text.trim();
                    if (text.isEmpty) return;
                    setState(() {
                      _exercises.add(EditableExercise(
                          id: EquipmentCatalog.newId(),
                          name: text,
                          hasSide: false));
                      _newExerciseCtrl.clear();
                      _addingExercise = false;
                    });
                  },
                  onCancel: () => setState(() {
                    _addingExercise = false;
                    _newExerciseCtrl.clear();
                  }),
                )
              else
                AddEntryButton(
                  label: '+ Übung hinzufügen',
                  onTap: () => setState(() => _addingExercise = true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyse laufen lassen**

Run: `flutter analyze`
Expected: weiterhin nur der bekannte `editType`-Fehler aus Task 2 in `equipment_catalog_screen.dart`; die neue Datei selbst fehlerfrei.

- [ ] **Step 3: Commit**

```bash
git add lib/features/config/equipment_detail_screen.dart
git commit -m "feat: add equipment detail editor with save-on-leave"
```

---

### Task 4: Katalog-Routing umstellen (Tap → Detail-Editor)

**Files:**
- Modify: `lib/features/config/equipment_catalog_screen.dart:59-63`

- [ ] **Step 1: Import ergänzen und onTap-Routing ändern**

Import hinzufügen (nach Zeile 5, `import 'equipment_wizard_screen.dart';` bleibt für den "+"-Button):

```dart
import 'equipment_detail_screen.dart';
```

Im `itemBuilder` das `onTap` der `_EquipmentRow` ändern — alt:

```dart
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EquipmentWizardScreen(editType: t),
                ),
              ),
```

neu:

```dart
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EquipmentDetailScreen(type: t),
                ),
              ),
```

Der "+"-Button in der AppBar (`const EquipmentWizardScreen()`) bleibt unverändert.

- [ ] **Step 2: Analyse laufen lassen**

Run: `flutter analyze`
Expected: `No issues found!` (der `editType`-Fehler aus Task 2 ist damit behoben)

- [ ] **Step 3: Commit**

```bash
git add lib/features/config/equipment_catalog_screen.dart
git commit -m "feat: route equipment tap to detail editor instead of wizard"
```

---

### Task 5: Einstieg aus der Plan-Bibliothek

**Files:**
- Modify: `lib/features/plans/plan_library_screen.dart:111-120`

- [ ] **Step 1: Import ergänzen und AppBar-Action hinzufügen**

Import hinzufügen (bei den bestehenden Feature-Imports, nach `import 'plan_editor_screen.dart';`):

```dart
import '../config/equipment_catalog_screen.dart';
```

Die AppBar (Zeilen 111–120) bekommt `actions` — alt:

```dart
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
        title: const Text('TRAININGSPLÄNE',
            style: TextStyle(fontSize: 15, letterSpacing: 4, color: Colors.white38)),
      ),
```

neu:

```dart
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
        title: const Text('TRAININGSPLÄNE',
            style: TextStyle(fontSize: 15, letterSpacing: 4, color: Colors.white38)),
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center, color: Color(0xFFFF6B00)),
            tooltip: 'Geräte & Übungen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EquipmentCatalogScreen(),
              ),
            ),
          ),
        ],
      ),
```

- [ ] **Step 2: Analyse laufen lassen**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/plans/plan_library_screen.dart
git commit -m "feat: open equipment catalog from plan library app bar"
```

---

### Task 6: Endverifikation

- [ ] **Step 1: Tests laufen lassen**

Run: `flutter test`
Expected: alle Tests grün (es wurden keine Modelle/Provider geändert).

- [ ] **Step 2: Analyse final**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Manuelle Verifikation auf Gerät/Emulator** (`flutter run`)

Checkliste:
1. Einstellungen → "Geräte & Übungen verwalten" → Liste erscheint wie bisher.
2. **"+"** → Wizard startet direkt bei "NAME & ICON" (Schritt 1 von 4); Name eingeben, Icon wählen, Gewicht `5 kg` anlegen, Übung anlegen, Zusammenfassung prüfen, "✓ Speichern" → neues Gerät erscheint in der Liste.
3. **Tap auf "Kettlebell"** → Detail-Editor öffnet sich direkt (keine Geräteauswahl-Liste); Name ändern, Icon wechseln, Übung hinzufügen → Zurück-Pfeil → Liste zeigt den neuen Namen; erneut öffnen → alle Änderungen sind da.
4. Im Detail-Editor versuchen, eine in einem Plan verwendete Variante zu löschen → rote Snackbar, Eintrag bleibt.
5. Letzte verbleibende Übung eines Geräts: ✕ ist ausgegraut und ohne Funktion.
6. Namensfeld komplett leeren, zurück navigieren, erneut öffnen → alter Name ist erhalten.
7. Plan-Bibliothek (TRAININGSPLÄNE): Hantel-Icon oben rechts → öffnet Geräte & Übungen; Zurück führt zur Plan-Bibliothek.
8. Im Wizard auf Schritt 1 den AppBar-Back drücken → zurück zur Liste, nichts wurde angelegt.
