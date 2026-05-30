import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/equipment_catalog.dart';
import '../../core/providers/equipment_catalog_notifier.dart';
import '../../core/providers/plan_library_notifier.dart';

const _kIconAssets = [
  'assets/icon/kettlebell.png',
  'assets/icon/steelmace.png',
  'assets/icon/pezziball.png',
  'assets/icon/liegestuetz.png',
];

// ── Local mutable state classes ───────────────────────────────────────────

class _EditableVariant {
  final String id;
  String label;
  String shortLabel;
  _EditableVariant({required this.id, required this.label, required this.shortLabel});
}

class _EditableExercise {
  final String id;
  String name;
  bool hasSide;
  _EditableExercise({required this.id, required this.name, required this.hasSide});
}

// ── Main screen ───────────────────────────────────────────────────────────

class EquipmentWizardScreen extends ConsumerStatefulWidget {
  final EquipmentType? editType;

  const EquipmentWizardScreen({super.key, this.editType});

  @override
  ConsumerState<EquipmentWizardScreen> createState() => _EquipmentWizardScreenState();
}

class _EquipmentWizardScreenState extends ConsumerState<EquipmentWizardScreen> {
  late String _name;
  late String _iconAsset;
  late bool _hasVariants;
  late List<_EditableVariant> _variants;
  late List<_EditableExercise> _exercises;

  int _step = 1;

  final _newVariantCtrl = TextEditingController();
  final _newExerciseCtrl = TextEditingController();
  bool _addingVariant = false;
  bool _addingExercise = false;

  bool get _isEdit => widget.editType != null;

  @override
  void initState() {
    super.initState();
    final t = widget.editType;
    if (t != null) {
      _name = t.name;
      _iconAsset = t.iconAsset;
      _hasVariants = t.variants.isNotEmpty;
      _variants = t.variants
          .map((v) => _EditableVariant(id: v.id, label: v.label, shortLabel: v.shortLabel))
          .toList();
      _exercises = t.exercises
          .map((e) => _EditableExercise(id: e.id, name: e.name, hasSide: e.hasSide))
          .toList();
    } else {
      _name = '';
      _iconAsset = _kIconAssets.first;
      _hasVariants = true;
      _variants = [];
      _exercises = [];
    }
  }

  @override
  void dispose() {
    _newVariantCtrl.dispose();
    _newExerciseCtrl.dispose();
    super.dispose();
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final t = widget.editType;
    final newType = EquipmentType(
      id: t?.id ?? EquipmentCatalog.newId(),
      name: _name.trim(),
      iconAsset: _iconAsset,
      variants: _hasVariants
          ? _variants
              .map((v) => EquipmentVariant(id: v.id, label: v.label, shortLabel: v.shortLabel))
              .toList()
          : [],
      exercises: _exercises
          .map((e) => ExerciseType(id: e.id, name: e.name, hasSide: e.hasSide))
          .toList(),
    );
    if (t != null) {
      await ref.read(equipmentCatalogProvider.notifier).updateEquipmentType(newType);
    } else {
      await ref.read(equipmentCatalogProvider.notifier).addEquipmentType(newType);
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ── Delete checks (edit mode only) ───────────────────────────────────────

  bool _variantUsed(String variantId) {
    final library = ref.read(planLibraryProvider).value;
    return library?.plans.any((p) => p.intervals.any((iv) => iv.variantId == variantId)) ?? false;
  }

  bool _exerciseUsed(String exerciseId) {
    final library = ref.read(planLibraryProvider).value;
    return library?.plans.any((p) => p.intervals.any((iv) => iv.exerciseTypeId == exerciseId)) ?? false;
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

  // ── Validation ────────────────────────────────────────────────────────────

  bool get _step1Valid => _name.trim().isNotEmpty;
  bool get _step4Valid => _exercises.isNotEmpty;
  bool get _editValid => _name.trim().isNotEmpty && _exercises.isNotEmpty;

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, letterSpacing: 1.5, color: Colors.white38)),
      );

  Widget _iconGrid() => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: _kIconAssets.map((asset) {
          final selected = asset == _iconAsset;
          return GestureDetector(
            onTap: () => setState(() => _iconAsset = asset),
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

  Widget _nameField({bool autofocus = false}) {
    final ctrl = TextEditingController(text: _name)
      ..selection = TextSelection.collapsed(offset: _name.length);
    return TextField(
      autofocus: autofocus,
      controller: ctrl,
      onChanged: (v) => setState(() => _name = v),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'z.B. Resistance Band',
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

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
          child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );

  Widget _addButton(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label,
              style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 12)),
        ),
      );

  Widget _stepNav({
    required bool canGoForward,
    required VoidCallback onForward,
    required String forwardLabel,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_step > 1)
              _ghostButton('← Zurück', () => setState(() => _step--))
            else
              const SizedBox(),
            _orangeButton(forwardLabel, canGoForward ? onForward : null),
          ],
        ),
      );

  // ── Inline add rows ───────────────────────────────────────────────────────

  Widget _inlineAddVariant() => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newVariantCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'z.B. 16 kg',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final text = _newVariantCtrl.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _variants.add(_EditableVariant(
                        id: EquipmentCatalog.newId(), label: text, shortLabel: text));
                    _newVariantCtrl.clear();
                    _addingVariant = false;
                  });
                }
              },
              child: const Text('OK', style: TextStyle(color: Color(0xFFFF6B00))),
            ),
            TextButton(
              onPressed: () => setState(() {
                _addingVariant = false;
                _newVariantCtrl.clear();
              }),
              child: const Text('✕', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      );

  Widget _inlineAddExercise() => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newExerciseCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'z.B. Clean and Press',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final text = _newExerciseCtrl.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _exercises.add(_EditableExercise(
                        id: EquipmentCatalog.newId(), name: text, hasSide: false));
                    _newExerciseCtrl.clear();
                    _addingExercise = false;
                  });
                }
              },
              child: const Text('OK', style: TextStyle(color: Color(0xFFFF6B00))),
            ),
            TextButton(
              onPressed: () => setState(() {
                _addingExercise = false;
                _newExerciseCtrl.clear();
              }),
              child: const Text('✕', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      );

  // ── Item rows ─────────────────────────────────────────────────────────────

  Widget _variantRow(_EditableVariant v, VoidCallback onDelete) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(v.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 13))),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close, size: 16, color: Colors.white38),
            ),
          ],
        ),
      );

  Widget _exerciseRow(_EditableExercise e, VoidCallback? onDelete) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(e.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 13))),
            GestureDetector(
              onTap: () => setState(() => e.hasSide = !e.hasSide),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: e.hasSide ? const Color(0xFFFF6B00) : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('L/R',
                    style: TextStyle(
                        fontSize: 11,
                        color: e.hasSide ? Colors.black : Colors.white38,
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

  // ── Wizard steps ──────────────────────────────────────────────────────────

  Widget _buildStep1() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('NAME'),
          _nameField(autofocus: true),
          _sectionLabel('ICON WÄHLEN'),
          _iconGrid(),
          _stepNav(
            canGoForward: _step1Valid,
            onForward: () => setState(() => _step = 2),
            forwardLabel: 'Weiter →',
          ),
        ],
      );

  Widget _buildStep2() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Hat dieses Gerät Gewichtsvarianten?',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          _SelectionCard(
            title: 'Ja, mit Gewichten',
            subtitle: 'z.B. 16 kg, 20 kg …',
            selected: _hasVariants,
            onTap: () => setState(() => _hasVariants = true),
          ),
          const SizedBox(height: 8),
          _SelectionCard(
            title: 'Nein, Körpergewicht',
            subtitle: 'keine Varianten',
            selected: !_hasVariants,
            onTap: () => setState(() => _hasVariants = false),
          ),
          _stepNav(
            canGoForward: true,
            onForward: () => setState(() => _step = _hasVariants ? 3 : 4),
            forwardLabel: 'Weiter →',
          ),
        ],
      );

  Widget _buildStep3() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('VARIANTEN'),
          ..._variants.asMap().entries.map((entry) =>
              _variantRow(entry.value, () => setState(() => _variants.removeAt(entry.key)))),
          if (_addingVariant)
            _inlineAddVariant()
          else
            _addButton('+ Variante hinzufügen', () => setState(() => _addingVariant = true)),
          _stepNav(
            canGoForward: true,
            onForward: () => setState(() => _step = 4),
            forwardLabel: 'Weiter →',
          ),
        ],
      );

  Widget _buildStep4() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ÜBUNGEN (mind. 1)'),
          ..._exercises.asMap().entries.map((entry) => _exerciseRow(
                entry.value,
                _exercises.length > 1
                    ? () => setState(() => _exercises.removeAt(entry.key))
                    : null,
              )),
          if (_addingExercise)
            _inlineAddExercise()
          else
            _addButton('+ Übung hinzufügen', () => setState(() => _addingExercise = true)),
          _stepNav(
            canGoForward: _step4Valid,
            onForward: _save,
            forwardLabel: 'Fertig ✓',
          ),
        ],
      );

  // ── Edit mode flat form ───────────────────────────────────────────────────

  Widget _buildEditMode() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('NAME'),
          _nameField(),
          _sectionLabel('ICON'),
          _iconGrid(),
          if (_hasVariants) ...[
            _sectionLabel('VARIANTEN'),
            ..._variants.asMap().entries.map((entry) =>
                _variantRow(entry.value, () => _tryDeleteVariant(entry.key))),
            if (_addingVariant)
              _inlineAddVariant()
            else
              _addButton('+ Variante hinzufügen', () => setState(() => _addingVariant = true)),
          ],
          _sectionLabel('ÜBUNGEN'),
          ..._exercises.asMap().entries.map((entry) => _exerciseRow(
                entry.value,
                _exercises.length > 1 ? () => _tryDeleteExercise(entry.key) : null,
              )),
          if (_addingExercise)
            _inlineAddExercise()
          else
            _addButton('+ Übung hinzufügen', () => setState(() => _addingExercise = true)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: _orangeButton('Speichern', _editValid ? _save : null),
          ),
          const SizedBox(height: 40),
        ],
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _isEdit
        ? 'GERÄT BEARBEITEN'
        : ['NAME & ICON', 'VARIANTEN?', 'VARIANTEN', 'ÜBUNGEN'][_step - 1];

    final body = _isEdit
        ? _buildEditMode()
        : switch (_step) {
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

// ── Shared sub-widget ─────────────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFFF6B00) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: selected
                                ? const Color(0xFFFF6B00)
                                : Colors.white70,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    color: Color(0xFFFF6B00), size: 18),
            ],
          ),
        ),
      );
}
