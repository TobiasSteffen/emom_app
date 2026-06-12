import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/equipment_catalog.dart';
import '../../core/providers/equipment_catalog_notifier.dart';
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
  final _editCtrl = TextEditingController();
  int? _editingVariantIndex;
  int? _editingExerciseIndex;

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
    _editCtrl.dispose();
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

  void _tryDeleteVariant(int i) {
    final v = _variants[i];
    if (ref.read(equipmentCatalogProvider.notifier).variantUsedInPlans(v.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Variante "${v.label}" wird in einem Plan verwendet.'),
        backgroundColor: Colors.red[900],
      ));
      return;
    }
    setState(() {
      _variants.removeAt(i);
      // Löschen bricht eine laufende Inline-Bearbeitung ab (Indizes verschieben sich).
      _editingVariantIndex = null;
      _editingExerciseIndex = null;
    });
  }

  void _tryDeleteExercise(int i) {
    final e = _exercises[i];
    if (ref.read(equipmentCatalogProvider.notifier).exerciseUsedInPlans(e.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Übung "${e.name}" wird in einem Plan verwendet.'),
        backgroundColor: Colors.red[900],
      ));
      return;
    }
    setState(() {
      _exercises.removeAt(i);
      _editingVariantIndex = null;
      _editingExerciseIndex = null;
    });
  }

  // ── Inline-Edit (nur eine Edit-/Add-Zeile gleichzeitig) ─────────────────

  void _startEditVariant(int i) {
    setState(() {
      _addingVariant = false;
      _addingExercise = false;
      _editingExerciseIndex = null;
      _editingVariantIndex = i;
      _editCtrl.text = _variants[i].label;
    });
  }

  void _startEditExercise(int i) {
    setState(() {
      _addingVariant = false;
      _addingExercise = false;
      _editingVariantIndex = null;
      _editingExerciseIndex = i;
      _editCtrl.text = _exercises[i].name;
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final liveName = _nameCtrl.text.trim();
    final title = (liveName.isEmpty ? widget.type.name : liveName).toUpperCase();
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
          title: Text(title,
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
                onChanged: (_) => setState(() {}),
              ),
              const SectionLabel('ICON'),
              EquipmentIconGrid(
                selectedAsset: _iconAsset,
                onSelect: (asset) => setState(() => _iconAsset = asset),
              ),
              const SectionLabel('GEWICHTE'),
              ..._variants.asMap().entries.map(
                    (entry) => entry.key == _editingVariantIndex
                        ? InlineAddRow(
                            controller: _editCtrl,
                            hintText: 'z.B. 16 kg',
                            onSubmit: () {
                              final text = _editCtrl.text.trim();
                              if (text.isEmpty) return;
                              setState(() {
                                entry.value.label = text;
                                entry.value.shortLabel = text;
                                _editingVariantIndex = null;
                              });
                            },
                            onCancel: () =>
                                setState(() => _editingVariantIndex = null),
                          )
                        : VariantRow(
                            variant: entry.value,
                            onTap: () => _startEditVariant(entry.key),
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
                  onTap: () => setState(() {
                    _addingVariant = true;
                    _editingVariantIndex = null;
                    _editingExerciseIndex = null;
                  }),
                ),
              const SectionLabel('ÜBUNGEN'),
              ..._exercises.asMap().entries.map(
                    (entry) => entry.key == _editingExerciseIndex
                        ? InlineAddRow(
                            controller: _editCtrl,
                            hintText: 'z.B. Clean and Press',
                            onSubmit: () {
                              final text = _editCtrl.text.trim();
                              if (text.isEmpty) return;
                              setState(() {
                                entry.value.name = text;
                                _editingExerciseIndex = null;
                              });
                            },
                            onCancel: () =>
                                setState(() => _editingExerciseIndex = null),
                          )
                        : ExerciseRow(
                            exercise: entry.value,
                            onTap: () => _startEditExercise(entry.key),
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
                  onTap: () => setState(() {
                    _addingExercise = true;
                    _editingVariantIndex = null;
                    _editingExerciseIndex = null;
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
