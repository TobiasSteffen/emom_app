import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';

Widget _stepButton(IconData icon, VoidCallback? onTap, {double size = 26}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(size / 4),
        ),
        child: Icon(icon,
            size: size / 2,
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
  // null | 'equipment' | 'exercise'
  String? _openPicker;

  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  void _togglePicker(String picker) {
    setState(() {
      _openPicker = _openPicker == picker ? null : picker;
    });
  }

  Widget _smallStepBtn(IconData icon, VoidCallback? onTap) =>
      _stepButton(icon, onTap, size: 32);

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF6B00) : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(4),
            border: active ? null : Border.all(color: Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? Colors.black : Colors.white54,
            ),
          ),
        ),
      );

  Widget _pickerBtn({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF6B00) : const Color(0xFF1A1A1A),
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

  Widget _equipmentPicker(IntervalConfig iv) {
    void selectEquipment(Equipment eq) => _update(() {
      final wasKb = iv.equipment.isKettlebell;
      iv.equipment = eq;
      if (wasKb != eq.isKettlebell) {
        iv.exercise = eq.defaultExercise;
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Image.asset('assets/icon/kettlebell.png',
                width: 14, height: 14, color: Colors.white38),
            const SizedBox(width: 8),
            _pickerBtn(label: '16 kg', selected: iv.equipment == Equipment.kb16,
                onTap: () => selectEquipment(Equipment.kb16)),
            const SizedBox(width: 6),
            _pickerBtn(label: '20 kg', selected: iv.equipment == Equipment.kb20,
                onTap: () => selectEquipment(Equipment.kb20)),
            const SizedBox(width: 6),
            _pickerBtn(label: '24 kg', selected: iv.equipment == Equipment.kb24,
                onTap: () => selectEquipment(Equipment.kb24)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Image.asset('assets/icon/steelmace.png',
                width: 14, height: 14, color: Colors.white38),
            const SizedBox(width: 8),
            _pickerBtn(label: '8 kg', selected: iv.equipment == Equipment.sm8,
                onTap: () => selectEquipment(Equipment.sm8)),
            const SizedBox(width: 6),
            _pickerBtn(label: '12 kg', selected: iv.equipment == Equipment.sm12,
                onTap: () => selectEquipment(Equipment.sm12)),
          ]),
        ],
      ),
    );
  }

  Widget _exercisePicker(IntervalConfig iv) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: iv.equipment.validExercises.map((ex) {
            return _pickerBtn(
              label: ex.label,
              selected: iv.exercise == ex,
              onTap: () => _update(() => iv.exercise = ex),
            );
          }).toList(),
        ),
      );

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
            padding: const EdgeInsets.symmetric(vertical: 4),
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
                            ? Colors.white54
                            : Colors.white38,
                        letterSpacing: 1),
                  ),
                ),
                const Spacer(),
                if (widget.isSelected) ...[
                  _chip(
                    label: iv.equipment.label,
                    active: _openPicker == 'equipment',
                    onTap: () => _togglePicker('equipment'),
                  ),
                  const SizedBox(width: 6),
                  _chip(
                    label: iv.exercise.label,
                    active: _openPicker == 'exercise',
                    onTap: () => _togglePicker('exercise'),
                  ),
                  const SizedBox(width: 8),
                  const Text('R',
                      style: TextStyle(fontSize: 13, color: Colors.white38)),
                  const SizedBox(width: 3),
                  _smallStepBtn(Icons.remove,
                      iv.reps > 1 ? () => _update(() => iv.reps--) : null),
                  SizedBox(
                    width: 30,
                    child: Center(
                      child: Text('${iv.reps}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54)),
                    ),
                  ),
                  _smallStepBtn(Icons.add, () => _update(() => iv.reps++)),
                  const SizedBox(width: 8),
                  const Text('s',
                      style: TextStyle(fontSize: 13, color: Colors.white38)),
                  const SizedBox(width: 3),
                  _smallStepBtn(
                      Icons.remove,
                      iv.durationSeconds > 30
                          ? () => _update(() => iv.durationSeconds =
                              (iv.durationSeconds - 5).clamp(30, 9999))
                          : null),
                  SizedBox(
                    width: 34,
                    child: Center(
                      child: Text('${iv.durationSeconds}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54)),
                    ),
                  ),
                  _smallStepBtn(
                      Icons.add, () => _update(() => iv.durationSeconds += 5)),
                ] else ...[
                  Image.asset(iv.equipment.iconPath,
                      width: 14, height: 14, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(iv.equipment.label,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white38)),
                  const SizedBox(width: 6),
                  Text(iv.exercise.label,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white38)),
                  const SizedBox(width: 6),
                  Text('${iv.reps}R',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white38)),
                  const SizedBox(width: 6),
                  Text('${iv.durationSeconds}s',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white38)),
                ],
              ],
            ),
          ),
          if (widget.isSelected && _openPicker == 'equipment')
            _equipmentPicker(iv),
          if (widget.isSelected && _openPicker == 'exercise')
            _exercisePicker(iv),
        ],
      ),
    );
  }
}
