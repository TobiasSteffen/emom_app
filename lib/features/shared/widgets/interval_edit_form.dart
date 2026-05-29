import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';
import '../../../core/models/equipment_catalog.dart';
import '../../../core/providers/equipment_catalog_notifier.dart';

Widget _stepButton(IconData icon, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null ? Colors.white38 : Colors.white12),
      ),
    );

class IntervalEditForm extends ConsumerStatefulWidget {
  final IntervalConfig iv;
  final VoidCallback onChanged;
  final int? index;
  final VoidCallback? onCollapse;
  final VoidCallback? onBeforeChange;

  const IntervalEditForm({
    super.key,
    required this.iv,
    required this.onChanged,
    this.index,
    this.onCollapse,
    this.onBeforeChange,
  });

  @override
  ConsumerState<IntervalEditForm> createState() => _IntervalEditFormState();
}

class _IntervalEditFormState extends ConsumerState<IntervalEditForm> {
  String? _openPicker;

  void _update(VoidCallback fn) {
    widget.onBeforeChange?.call();
    setState(fn);
    widget.onChanged();
  }

  void _togglePicker(String picker) {
    setState(() => _openPicker = _openPicker == picker ? null : picker);
  }

  Widget _pickerChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF6B00) : const Color(0xFF222222),
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

  Widget _formSectionHeader(String label, String value, String picker) =>
      GestureDetector(
        onTap: () => _togglePicker(picker),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            SizedBox(
                width: 96,
                child: Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.white38))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontSize: 13, color: Colors.white70))),
            Icon(_openPicker == picker ? Icons.expand_less : Icons.expand_more,
                size: 16, color: Colors.white24),
          ]),
        ),
      );

  Widget _formRow(String label, Widget content) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.white38))),
          content,
        ]),
      );

  Widget _stepper({
    required String display,
    required VoidCallback onInc,
    VoidCallback? onDec,
  }) =>
      Row(children: [
        _stepButton(Icons.remove, onDec),
        SizedBox(
            width: 40,
            child: Center(
                child: Text(display,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)))),
        _stepButton(Icons.add, onInc),
      ]);

  void _selectEquipmentAndVariant(
      IntervalConfig iv, EquipmentType newType, String? newVariantId) {
    _update(() {
      final typeChanged = iv.equipmentTypeId != newType.id;
      iv.equipmentTypeId = newType.id;
      iv.variantId = newVariantId;
      if (typeChanged && !newType.exercises.any((e) => e.id == iv.exerciseTypeId)) {
        iv.exerciseTypeId = newType.exercises.first.id;
      }
      final exercise = newType.exercises
          .where((e) => e.id == iv.exerciseTypeId)
          .firstOrNull ?? newType.exercises.first;
      if (!exercise.hasSide) iv.side = null;
      if (exercise.hasSide && iv.side == null) {
        iv.side = (widget.index ?? 0) % 2 == 0
            ? ExerciseSide.links
            : ExerciseSide.rechts;
      }
    });
  }

  Widget _equipmentGroup(EquipmentType eqType, IntervalConfig iv) {
    final isCurrentType = iv.equipmentTypeId == eqType.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Image.asset(eqType.iconAsset,
                width: 14, height: 14, color: Colors.white38),
          ),
          Expanded(
            child: Wrap(children: [
              if (eqType.variants.isEmpty)
                _pickerChip(
                  eqType.name,
                  isCurrentType,
                  () => _selectEquipmentAndVariant(iv, eqType, null),
                )
              else
                for (final v in eqType.variants)
                  _pickerChip(
                    v.shortLabel,
                    isCurrentType && iv.variantId == v.id,
                    () => _selectEquipmentAndVariant(iv, eqType, v.id),
                  ),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(equipmentCatalogProvider);
    return catalogAsync.when(
      loading: () => const SizedBox(),
      error: (e, _) => const SizedBox(),
      data: (catalog) => _buildForm(catalog),
    );
  }

  Widget _buildForm(EquipmentCatalog catalog) {
    final iv = widget.iv;
    final eqType =
        catalog.findType(iv.equipmentTypeId) ?? catalog.types.first;
    final variant = iv.variantId != null
        ? eqType.variants.where((v) => v.id == iv.variantId).firstOrNull
        : null;
    final exercise = eqType.exercises
        .where((e) => e.id == iv.exerciseTypeId)
        .firstOrNull ?? eqType.exercises.first;

    final equipmentLabel = variant != null
        ? '${eqType.name} · ${variant.label}'
        : eqType.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pause toggle
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                if (iv.isPause) {
                  _update(() => iv.isPause = false);
                } else {
                  _update(() {
                    _openPicker = null;
                    iv.isPause = true;
                    iv.side = null;
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: iv.isPause
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(6),
                  border: iv.isPause ? null : Border.all(color: Colors.white12),
                ),
                child: Text('Pause',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: iv.isPause
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: iv.isPause ? Colors.white : Colors.white38)),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
            crossFadeState: iv.isPause
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white12, height: 1),
                _formSectionHeader('Gerät', equipmentLabel, 'equipment'),
                if (_openPicker == 'equipment')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final t in catalog.types) _equipmentGroup(t, iv),
                      ],
                    ),
                  ),
                const Divider(color: Colors.white12, height: 1),
                _formSectionHeader('Übung', exercise.name, 'exercise'),
                if (_openPicker == 'exercise')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      children: [
                        for (final ex in eqType.exercises)
                          _pickerChip(
                            ex.name,
                            iv.exerciseTypeId == ex.id,
                            () => _update(() {
                              iv.exerciseTypeId = ex.id;
                              if (!ex.hasSide) iv.side = null;
                              if (ex.hasSide && iv.side == null) {
                                iv.side = (widget.index ?? 0) % 2 == 0
                                    ? ExerciseSide.links
                                    : ExerciseSide.rechts;
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                if (exercise.hasSide) ...[
                  const Divider(color: Colors.white12, height: 1),
                  _formRow(
                    'Seite',
                    Row(children: [
                      _pickerChip('Links', iv.side == ExerciseSide.links,
                          () => _update(() => iv.side = ExerciseSide.links)),
                      const SizedBox(width: 6),
                      _pickerChip('Rechts', iv.side == ExerciseSide.rechts,
                          () => _update(() => iv.side = ExerciseSide.rechts)),
                    ]),
                  ),
                ],
                const Divider(color: Colors.white12, height: 1),
                _formRow(
                  'Wiederholungen',
                  _stepper(
                    display: '${iv.reps}',
                    onDec: iv.reps > 1 ? () => _update(() => iv.reps--) : null,
                    onInc: () => _update(() => iv.reps++),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Sekunden',
            _stepper(
              display: '${iv.durationSeconds}',
              onDec: iv.durationSeconds > 30
                  ? () => _update(() => iv.durationSeconds =
                      (iv.durationSeconds - 5).clamp(30, 9999))
                  : null,
              onInc: () => _update(() => iv.durationSeconds += 5),
            ),
          ),
          if (widget.onCollapse != null)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onCollapse,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: Icon(Icons.expand_less, size: 20, color: Colors.white24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
