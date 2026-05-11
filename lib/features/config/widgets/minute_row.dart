import 'package:flutter/material.dart';
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

class MinuteRow extends StatefulWidget {
  final int index;
  final AppSettings settings;
  final VoidCallback onChanged;
  final bool isSelected;
  final VoidCallback onSelect;

  const MinuteRow({
    super.key,
    required this.index,
    required this.settings,
    required this.onChanged,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<MinuteRow> createState() => _MinuteRowState();
}

class _MinuteRowState extends State<MinuteRow> {
  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  Widget _smallStepBtn(IconData icon, VoidCallback? onTap) =>
      _stepButton(icon, onTap, size: 32);

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final i = widget.index;
    final eq = Equipment.values[s.customEquipment[i]];
    final iconPath = eq == Equipment.kettlebell
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
                  initialValue: s.customEquipment[i],
                  onSelected: (v) => _update(() => s.customEquipment[i] = v),
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
              const Text('R',
                  style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _smallStepBtn(Icons.remove,
                  s.customPlan[i] > 1 ? () => _update(() => s.customPlan[i]--) : null),
              SizedBox(
                width: 30,
                child: Center(
                  child: Text('${s.customPlan[i]}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54)),
                ),
              ),
              _smallStepBtn(Icons.add, () => _update(() => s.customPlan[i]++)),
              const SizedBox(width: 8),
              const Text('s',
                  style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _smallStepBtn(
                  Icons.remove,
                  s.customDurations[i] > 30
                      ? () => _update(() =>
                          s.customDurations[i] =
                              (s.customDurations[i] - 5).clamp(30, 9999))
                      : null),
              SizedBox(
                width: 34,
                child: Center(
                  child: Text('${s.customDurations[i]}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54)),
                ),
              ),
              _smallStepBtn(
                  Icons.add, () => _update(() => s.customDurations[i] += 5)),
            ] else ...[
              Image.asset(iconPath, width: 14, height: 14, color: Colors.white24),
              const SizedBox(width: 8),
              Text('${s.customPlan[i]}R',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
              const SizedBox(width: 6),
              Text('${s.customDurations[i]}s',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
            ],
          ],
        ),
      ),
    );
  }
}
