import 'package:flutter/material.dart';

class NextMinutePreview extends StatelessWidget {
  final int nextReps;
  final bool nextIsPause;

  const NextMinutePreview({
    super.key,
    required this.nextReps,
    this.nextIsPause = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = nextIsPause ? 'Pause' : '$nextReps Reps';
    return Text(
      'Nächste Minute: $label',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
    );
  }
}
