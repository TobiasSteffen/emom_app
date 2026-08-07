import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../../core/models/equipment_catalog.dart';

const kEquipmentIconAssets = [
  'assets/icon/kettlebell.png',
  'assets/icon/steelmace.png',
  'assets/icon/pezziball.png',
  'assets/icon/liegestuetz.png',
  'assets/icon/kniebeuge.png',
  'assets/icon/plank.png',
  'assets/icon/dehnen.png',
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
  bool isTimed;
  EditableExercise(
      {required this.id, required this.name, required this.hasSide, this.isTimed = false});

  factory EditableExercise.from(ExerciseType e) =>
      EditableExercise(id: e.id, name: e.name, hasSide: e.hasSide, isTimed: e.isTimed);

  ExerciseType toType() =>
      ExerciseType(id: id, name: name, hasSide: hasSide, isTimed: isTimed);
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
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppTheme.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(asset, color: AppTheme.accent),
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
          fillColor: AppTheme.surface,
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
  final VoidCallback? onTap;
  const VariantRow(
      {super.key, required this.variant, required this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Text(variant.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
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
  final VoidCallback onToggleTimed;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  const ExerciseRow(
      {super.key,
      required this.exercise,
      required this.onToggleSide,
      required this.onToggleTimed,
      required this.onDelete,
      this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Text(exercise.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
            GestureDetector(
              onTap: onToggleSide,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: exercise.hasSide
                      ? AppTheme.accent
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
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onToggleTimed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: exercise.isTimed
                      ? AppTheme.accent
                      : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Zeit',
                    style: TextStyle(
                        fontSize: 11,
                        color: exercise.isTimed ? Colors.black : Colors.white38,
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

/// Eingabezeile mit OK/✕ — dient sowohl dem Hinzufügen (leerer Controller)
/// als auch dem Inline-Editieren (vorbefüllter Controller).
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
                  fillColor: AppTheme.surface,
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
              child: const Text('OK', style: TextStyle(color: AppTheme.accent)),
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
              style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
        ),
      );
}
