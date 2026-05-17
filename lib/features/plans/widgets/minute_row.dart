import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';

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

class PlanMinuteRow extends StatefulWidget {
  final int index;
  final TrainingPlan plan;
  final VoidCallback onChanged;
  final bool isSelected;
  final VoidCallback onSelect;

  const PlanMinuteRow({
    super.key,
    required this.index,
    required this.plan,
    required this.onChanged,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<PlanMinuteRow> createState() => _PlanMinuteRowState();
}

class _PlanMinuteRowState extends State<PlanMinuteRow> {
  String? _openPicker;

  @override
  void didUpdateWidget(PlanMinuteRow old) {
    super.didUpdateWidget(old);
    if (!widget.isSelected) _openPicker = null;
  }

  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  void _togglePicker(String picker) {
    setState(() {
      _openPicker = _openPicker == picker ? null : picker;
    });
  }

  Widget _pickerChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFF6B00)
                : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(6),
            border: selected ? null : Border.all(color: Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.black : Colors.white54,
            ),
          ),
        ),
      );

  Widget _formSectionHeader(String label, String value, String picker) =>
      GestureDetector(
        onTap: () => _togglePicker(picker),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white38)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
              ),
              Icon(
                _openPicker == picker
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 16,
                color: Colors.white24,
              ),
            ],
          ),
        ),
      );

  Widget _formRow(String label, Widget content) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white38)),
            ),
            content,
          ],
        ),
      );

  Widget _stepper({
    required int value,
    required String display,
    required VoidCallback onInc,
    VoidCallback? onDec,
  }) =>
      Row(
        children: [
          _stepButton(Icons.remove, onDec),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(display,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
            ),
          ),
          _stepButton(Icons.add, onInc),
        ],
      );

  Widget _equipmentGroup(
    String iconPath,
    List<Equipment> items,
    Equipment current,
    void Function(Equipment) onSelect,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Image.asset(iconPath, width: 14, height: 14, color: Colors.white38),
            const SizedBox(width: 8),
            for (final eq in items) ...[
              _pickerChip(eq.shortLabel, current == eq, () => onSelect(eq)),
              const SizedBox(width: 6),
            ],
          ],
        ),
      );

  Widget _expandedForm(IntervalConfig iv) {
    void selectEquipment(Equipment eq) => _update(() {
          iv.equipment = eq;
          if (!eq.validExercises.contains(iv.exercise)) {
            iv.exercise = eq.defaultExercise;
          }
        });

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white12, height: 1),
          _formSectionHeader('Gerät', iv.equipment.label, 'equipment'),
          if (_openPicker == 'equipment') ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _equipmentGroup(
                    'assets/icon/kettlebell.png',
                    Equipment.values.where((e) => e.isKettlebell).toList(),
                    iv.equipment,
                    selectEquipment,
                  ),
                  _equipmentGroup(
                    'assets/icon/steelmace.png',
                    Equipment.values.where((e) => e.isSteelMace).toList(),
                    iv.equipment,
                    selectEquipment,
                  ),
                ],
              ),
            ),
          ],
          const Divider(color: Colors.white12, height: 1),
          _formSectionHeader('Übung', iv.exercise.label, 'exercise'),
          if (_openPicker == 'exercise') ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                children: [
                  for (final ex in iv.equipment.validExercises)
                    _pickerChip(ex.label, iv.exercise == ex,
                        () => _update(() => iv.exercise = ex)),
                ],
              ),
            ),
          ],
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Repetitionen',
            _stepper(
              value: iv.reps,
              display: '${iv.reps}',
              onDec: iv.reps > 1 ? () => _update(() => iv.reps--) : null,
              onInc: () => _update(() => iv.reps++),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Sekunden',
            _stepper(
              value: iv.durationSeconds,
              display: '${iv.durationSeconds}',
              onDec: iv.durationSeconds > 30
                  ? () => _update(() => iv.durationSeconds =
                      (iv.durationSeconds - 5).clamp(30, 9999))
                  : null,
              onInc: () => _update(() => iv.durationSeconds += 5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iv = widget.plan.intervals[widget.index];
    final i = widget.index;
    final color = phaseColorForMinute(i);

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
                Image.asset(iv.equipment.iconPath,
                    width: 14, height: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text(iv.equipment.label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38)),
                const SizedBox(width: 6),
                Text(iv.exercise.label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38)),
                const SizedBox(width: 6),
                Text('${iv.reps}R',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white38)),
                const SizedBox(width: 6),
                Text('${iv.durationSeconds}s',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white38)),
              ],
            ),
          ),
          if (widget.isSelected) _expandedForm(iv),
        ],
      ),
    );
  }
}
