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
  int _step = 1;
  bool _isNewSelected = false;
  EquipmentType? _selectedType;
  String _name = '';
  String _iconAsset = _kIconAssets.first;
  List<_EditableVariant> _variants = [];
  List<_EditableExercise> _exercises = [];

  final _newVariantCtrl = TextEditingController();
  final _newExerciseCtrl = TextEditingController();
  bool _addingVariant = false;
  bool _addingExercise = false;

  // ── Computed properties ───────────────────────────────────────────────────

  bool get _hasSelection => _isNewSelected || _selectedType != null;

  int get _displayStep {
    if (_isNewSelected) return _step;
    if (_step == 1) return 1;
    return _step - 1; // Step 3→2, 4→3, 5→4 when editing existing
  }

  int get _totalSteps => _isNewSelected ? 5 : 4;

  @override
  void initState() {
    super.initState();
    if (widget.editType != null) {
      _selectedType = widget.editType;
    }
  }

  @override
  void dispose() {
    _newVariantCtrl.dispose();
    _newExerciseCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goForward() {
    if (_step == 1) {
      if (_isNewSelected) {
        setState(() {
          _name = '';
          _iconAsset = _kIconAssets.first;
          _variants = [];
          _exercises = [];
          _step = 2;
        });
      } else {
        final t = _selectedType!;
        setState(() {
          _variants = t.variants
              .map((v) => _EditableVariant(id: v.id, label: v.label, shortLabel: v.shortLabel))
              .toList();
          _exercises = t.exercises
              .map((e) => _EditableExercise(id: e.id, name: e.name, hasSide: e.hasSide))
              .toList();
          _step = 3;
        });
      }
    } else if (_step < 5) {
      setState(() => _step++);
    }
  }

  void _goBack() {
    if (_step == 3 && !_isNewSelected) {
      setState(() => _step = 1);
    } else if (_step > 1) {
      setState(() => _step--);
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final isEdit = _selectedType != null && !_isNewSelected;
    final newType = EquipmentType(
      id: isEdit ? _selectedType!.id : EquipmentCatalog.newId(),
      name: isEdit ? _selectedType!.name : _name.trim(),
      iconAsset: isEdit ? _selectedType!.iconAsset : _iconAsset,
      variants: _variants
          .map((v) => EquipmentVariant(id: v.id, label: v.label, shortLabel: v.shortLabel))
          .toList(),
      exercises: _exercises
          .map((e) => ExerciseType(id: e.id, name: e.name, hasSide: e.hasSide))
          .toList(),
    );
    if (isEdit) {
      await ref.read(equipmentCatalogProvider.notifier).updateEquipmentType(newType);
    } else {
      await ref.read(equipmentCatalogProvider.notifier).addEquipmentType(newType);
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ── Delete checks ─────────────────────────────────────────────────────────

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

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _stepHeader() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Schritt $_displayStep von $_totalSteps',
          style: const TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white24),
        ),
      );

  Widget _summaryPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      );

  String _catalogSubtitle(EquipmentType t) {
    final variantPart = t.variants.isEmpty
        ? 'kein Gewicht'
        : t.variants.map((v) => v.label).join(' · ');
    final exercisePart = t.exercises.length == 1 ? '1 Übung' : '${t.exercises.length} Übungen';
    return '$variantPart · $exercisePart';
  }

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

  // Step 1 needs its own Scaffold with Expanded ListView — called via catalogAsync.when(data: _buildStep1)
  Widget _buildStep1(EquipmentCatalog catalog) => Column(
        children: [
          _stepHeader(),
          Expanded(
            child: ListView.separated(
              itemCount: catalog.types.length,
              separatorBuilder: (context, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = catalog.types[i];
                return _SelectionCard(
                  title: t.name,
                  subtitle: _catalogSubtitle(t),
                  selected: _selectedType?.id == t.id,
                  onTap: () => setState(() {
                    _selectedType = t;
                    _isNewSelected = false;
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          _SelectionCard(
            title: '＋ Neues Gerät erstellen',
            subtitle: 'eigener Name & Icon',
            selected: _isNewSelected,
            onTap: () => setState(() {
              _isNewSelected = true;
              _selectedType = null;
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _orangeButton('Weiter →', _hasSelection ? _goForward : null),
              ],
            ),
          ),
        ],
      );

  Widget _buildStep2() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(),
          _sectionLabel('NAME'),
          _nameField(autofocus: true),
          _sectionLabel('ICON WÄHLEN'),
          _iconGrid(),
          _stepNav(
            canGoForward: _name.trim().isNotEmpty,
            onForward: _goForward,
            forwardLabel: 'Weiter →',
          ),
        ],
      );

  Widget _buildStep3() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(),
          _sectionLabel('VARIANTEN'),
          ..._variants.asMap().entries.map(
                (entry) => _variantRow(entry.value, () => _tryDeleteVariant(entry.key)),
              ),
          if (_addingVariant)
            _inlineAddVariant()
          else
            _addButton('+ Variante hinzufügen', () => setState(() => _addingVariant = true)),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: const Text(
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

  Widget _buildStep4() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(),
          _sectionLabel('ÜBUNGEN (mind. 1)'),
          ..._exercises.asMap().entries.map((entry) => _exerciseRow(
                entry.value,
                _exercises.length > 1 ? () => _tryDeleteExercise(entry.key) : null,
              )),
          if (_addingExercise)
            _inlineAddExercise()
          else
            _addButton('+ Übung hinzufügen', () => setState(() => _addingExercise = true)),
          _stepNav(
            canGoForward: _exercises.isNotEmpty,
            onForward: _goForward,
            forwardLabel: 'Weiter →',
          ),
        ],
      );

  Widget _buildStep5() {
    final isEdit = _selectedType != null && !_isNewSelected;
    final iconAsset = isEdit ? _selectedType!.iconAsset : _iconAsset;
    final name = isEdit ? _selectedType!.name : _name.trim();

    return Column(
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
              Image.asset(iconAsset, width: 22, height: 22, color: const Color(0xFFFF6B00)),
              const SizedBox(width: 12),
              Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (_variants.isNotEmpty) ...[
          _sectionLabel('GEWICHTE'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _variants.map((v) => _summaryPill(v.label)).toList(),
          ),
        ],
        _sectionLabel('ÜBUNGEN'),
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
                  color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
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
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(equipmentCatalogProvider);

    final title = switch (_step) {
      1 => 'GERÄT WÄHLEN',
      2 => 'NAME & ICON',
      3 => 'GEWICHTE',
      4 => 'ÜBUNGEN',
      _ => 'ZUSAMMENFASSUNG',
    };

    // Step 1 needs Expanded ListView — own layout without SingleChildScrollView
    if (_step == 1) {
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
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: catalogAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Fehler: $e', style: const TextStyle(color: Colors.white38))),
            data: _buildStep1,
          ),
        ),
      );
    }

    final body = switch (_step) {
      2 => _buildStep2(),
      3 => _buildStep3(),
      4 => _buildStep4(),
      _ => _buildStep5(),
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
