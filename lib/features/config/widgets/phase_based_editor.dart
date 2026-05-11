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

class PhaseBasedEditor extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onChanged;

  const PhaseBasedEditor({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<PhaseBasedEditor> createState() => _PhaseBasedEditorState();
}

class _PhaseBasedEditorState extends State<PhaseBasedEditor> {
  static const _phaseNames = [
    'Warm Up',
    'Aufbau',
    'Peak',
    'Abbau',
    'Cool Down',
  ];
  static const _phaseColors = [
    Color(0xFF4CAF50),
    Color(0xFFFF6B00),
    Color(0xFFFF0000),
    Color(0xFFFF6B00),
    Color(0xFF4CAF50),
  ];

  void _set(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  int _phaseReps(int i) {
    final s = widget.settings;
    if (i == 0) return s.warmUpReps;
    if (i == 2) return s.peakReps;
    return s.coolDownReps;
  }

  Widget _inlineStepRow(
    int value, {
    required int min,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 88,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepButton(
              Icons.remove,
              value > min
                  ? () => onChanged((value - step).clamp(min, 9999))
                  : null),
          SizedBox(
            width: 36,
            child: Center(
              child: Text('$value',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54)),
            ),
          ),
          _stepButton(Icons.add, () => onChanged(value + step)),
        ],
      ),
    );
  }

  Widget _phaseTableRow(int i) {
    final s = widget.settings;
    final color = _phaseColors[i];
    final name = _phaseNames[i];
    final hasReps = i == 0 || i == 2 || i == 4;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF111111))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(name,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.75), fontSize: 12)),
              ],
            ),
          ),
          _inlineStepRow(
            s.phaseDurations[i],
            min: 30,
            step: 5,
            onChanged: (v) => _set(() => s.phaseDurations[i] = v),
          ),
          const SizedBox(width: 8),
          if (hasReps)
            _inlineStepRow(
              _phaseReps(i),
              min: 1,
              onChanged: (v) => _set(() {
                if (i == 0) s.warmUpReps = v;
                if (i == 2) s.peakReps = v;
                if (i == 4) s.coolDownReps = v;
              }),
            )
          else
            const SizedBox(
              width: 88,
              child: Center(
                child: Text('auto',
                    style: TextStyle(fontSize: 10, color: Colors.white12)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 88,
                child: Center(
                  child: Text('Dauer (s)',
                      style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: Colors.white12)),
                ),
              ),
              SizedBox(
                width: 88,
                child: Center(
                  child: Text('Reps',
                      style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: Colors.white12)),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1A1A1A), height: 1),
        for (int i = 0; i < 5; i++) _phaseTableRow(i),
        const SizedBox(height: 14),
        const Text(
          'Aufbau & Abbau Reps werden automatisch interpoliert',
          style: TextStyle(
              fontSize: 11, color: Colors.white12, letterSpacing: 0.5),
        ),
      ],
    );
  }
}
