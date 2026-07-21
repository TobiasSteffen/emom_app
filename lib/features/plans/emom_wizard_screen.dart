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
            // Schemawechsel lässt die eingestellten von/bis-Werte unangetastet.
            setState(() => _scheme = s);
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
