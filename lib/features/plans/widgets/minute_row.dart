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
  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  Widget _smallStepBtn(IconData icon, VoidCallback? onTap) =>
      _stepButton(icon, onTap, size: 32);

  @override
  Widget build(BuildContext context) {
    final iv = widget.plan.intervals[widget.index];
    final i = widget.index;
    final iconPath = iv.equipment == Equipment.kettlebell
        ? 'assets/icon/kettlebell.png'
        : 'assets/icon/steelmace.png';
    final color = phaseColorForMinute(i);

    return GestureDetector(
      onTap: widget.onSelect,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(
              width: 42,
              child: Text(
                'Min ${i + 1}',
                style: TextStyle(
                    fontSize: 11,
                    color: widget.isSelected ? Colors.white38 : Colors.white24,
                    letterSpacing: 1),
              ),
            ),
            const Spacer(),
            if (widget.isSelected) ...[
              SizedBox(
                width: 26,
                height: 26,
                child: PopupMenuButton<int>(
                  initialValue: iv.equipment.index,
                  onSelected: (v) => _update(() => iv.equipment = Equipment.values[v]),
                  color: const Color(0xFF1E1E1E),
                  padding: EdgeInsets.zero,
                  tooltip: '',
                  child: Center(
                      child: Image.asset(iconPath,
                          width: 16, height: 16, color: Colors.white54)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 0,
                      child: Row(children: [
                        Image.asset('assets/icon/kettlebell.png',
                            width: 18, height: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        const Text('Kettlebell',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: Row(children: [
                        Image.asset('assets/icon/steelmace.png',
                            width: 18, height: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        const Text('Steel Mace',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('R', style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _smallStepBtn(Icons.remove,
                  iv.reps > 1 ? () => _update(() => iv.reps--) : null),
              SizedBox(
                width: 30,
                child: Center(
                  child: Text('${iv.reps}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white54)),
                ),
              ),
              _smallStepBtn(Icons.add, () => _update(() => iv.reps++)),
              const SizedBox(width: 8),
              const Text('s', style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _smallStepBtn(
                  Icons.remove,
                  iv.durationSeconds > 30
                      ? () => _update(() =>
                          iv.durationSeconds = (iv.durationSeconds - 5).clamp(30, 9999))
                      : null),
              SizedBox(
                width: 34,
                child: Center(
                  child: Text('${iv.durationSeconds}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white54)),
                ),
              ),
              _smallStepBtn(Icons.add, () => _update(() => iv.durationSeconds += 5)),
            ] else ...[
              Image.asset(iconPath, width: 14, height: 14, color: Colors.white24),
              const SizedBox(width: 8),
              Text('${iv.reps}R',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
              const SizedBox(width: 6),
              Text('${iv.durationSeconds}s',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
            ],
          ],
        ),
      ),
    );
  }
}
