import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';
import '../../../core/models/training_plan.dart';

class NextMinutePreview extends StatelessWidget {
  final IntervalConfig interval;

  const NextMinutePreview({super.key, required this.interval});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1);

    if (interval.isPause) {
      return Text('Nächste: PAUSE · ${interval.durationSeconds}s', style: style);
    }

    final parts = <String>[
      interval.equipment.label,
      interval.side != null
          ? '${interval.exercise.label} ${interval.side!.shortLabel}'
          : interval.exercise.label,
      '${interval.reps}W',
      '${interval.durationSeconds}s',
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(interval.equipment.iconPath,
            width: 12, height: 12, color: Colors.white38),
        const SizedBox(width: 5),
        Text(parts.join(' · '), style: style),
      ],
    );
  }
}
