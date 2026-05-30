import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';
import '../../../core/providers/equipment_catalog_notifier.dart';
import '../../shared/widgets/interval_edit_form.dart';

class PlanMinuteRow extends ConsumerStatefulWidget {
  final int index;
  final TrainingPlan plan;
  final VoidCallback onChanged;
  final VoidCallback onBeforeFieldChange;
  final bool isSelected;
  final VoidCallback onSelect;

  const PlanMinuteRow({
    super.key,
    required this.index,
    required this.plan,
    required this.onChanged,
    required this.onBeforeFieldChange,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  ConsumerState<PlanMinuteRow> createState() => _PlanMinuteRowState();
}

class _PlanMinuteRowState extends ConsumerState<PlanMinuteRow> {
  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final iv = widget.plan.intervals[widget.index];
    final i = widget.index;
    final color = iv.isPause ? Colors.white24 : phaseColorForMinute(i);

    final catalogAsync = ref.watch(equipmentCatalogProvider);
    final catalog = catalogAsync.value;
    final eqType = catalog?.findType(iv.equipmentTypeId);
    final exerciseType = eqType?.exercises
        .where((e) => e.id == iv.exerciseTypeId)
        .firstOrNull;

    final iconAsset = eqType?.iconAsset ?? 'assets/icon/kettlebell.png';
    final equipmentLabel = eqType?.name ?? iv.equipmentTypeId;
    final exerciseLabel = exerciseType?.name ?? iv.exerciseTypeId;

    return GestureDetector(
      onTap: widget.onSelect,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    'Min ${i + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        color: widget.isSelected
                            ? Colors.white70
                            : Colors.white38,
                        letterSpacing: 1),
                  ),
                ),
                const Spacer(),
                if (iv.isPause) ...[
                  const Text('PAUSE',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                          letterSpacing: 1)),
                  const SizedBox(width: 6),
                  Text('${iv.durationSeconds}s',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white38)),
                ] else ...[
                  Image.asset(iconAsset,
                      width: 14, height: 14, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(equipmentLabel,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38)),
                  const SizedBox(width: 6),
                  Text(
                    iv.side != null
                        ? '$exerciseLabel ${iv.side!.shortLabel}'
                        : exerciseLabel,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38)),
                  const SizedBox(width: 6),
                  Text('${iv.reps}W',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white38)),
                  const SizedBox(width: 6),
                  Text('${iv.durationSeconds}s',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white38)),
                ],
              ],
            ),
          ),
          if (widget.isSelected)
            GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: IntervalEditForm(
                iv: iv,
                onBeforeChange: widget.onBeforeFieldChange,
                onChanged: () => _update(() {}),
                index: widget.index,
                onCollapse: widget.onSelect,
              ),
            ),
        ],
      ),
    );
  }
}
