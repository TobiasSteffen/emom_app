import 'package:flutter/material.dart';

class NextMinutePreview extends StatelessWidget {
  final int nextReps;

  const NextMinutePreview({super.key, required this.nextReps});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Nächste Minute: $nextReps Reps',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
    );
  }
}
