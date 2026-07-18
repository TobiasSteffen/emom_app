import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/equipment_catalog.dart';
import '../../core/providers/equipment_catalog_notifier.dart';
import 'widgets/equipment_edit_widgets.dart';

/// Wizard zum Anlegen eines neuen Geräts (4 Schritte).
/// Bearbeiten bestehender Geräte läuft über EquipmentDetailScreen.
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
  final _editCtrl = TextEditingController();
  bool _addingVariant = false;
  bool _addingExercise = false;
  int? _editingVariantIndex;
  int? _editingExerciseIndex;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _newVariantCtrl.dispose();
    _newExerciseCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _goForward() {
    if (_step < 4) {
      setState(() {
        _addingVariant = false;
        _addingExercise = false;
        _editingVariantIndex = null;
        _editingExerciseIndex = null;
        _step++;
      });
    }
  }

  void _goBack() {
    if (_step > 1) {
      setState(() {
        _addingVariant = false;
        _addingExercise = false;
        _editingVariantIndex = null;
        _editingExerciseIndex = null;
        _step--;
      });
    }
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
          color: AppTheme.surface,
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
            color: onTap != null ? AppTheme.accent : Colors.white12,
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
                        onDelete: () => setState(() {
                          _variants.removeAt(entry.key);
                          // Löschen bricht eine laufende Inline-Bearbeitung ab
                          // (Indizes verschieben sich).
                          _editingVariantIndex = null;
                          _editingExerciseIndex = null;
                        }),
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
              onTap: () => setState(() {
                _addingVariant = true;
                _editingVariantIndex = null;
                _editingExerciseIndex = null;
              }),
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
                        onToggleTimed: () => setState(
                            () => entry.value.isTimed = !entry.value.isTimed),
                        onDelete: () => setState(() {
                          _exercises.removeAt(entry.key);
                          _editingVariantIndex = null;
                          _editingExerciseIndex = null;
                        }),
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
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Image.asset(_iconAsset,
                    width: 22, height: 22, color: AppTheme.accent),
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
                color: AppTheme.ok,
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
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
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
