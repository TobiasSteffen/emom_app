import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class OverallProgress extends StatelessWidget {
  final int currentMinute;
  final int totalMinutes;
  final int totalRepsDone;
  final int totalReps;
  final String workoutLabel;

  const OverallProgress({
    super.key,
    required this.currentMinute,
    required this.totalMinutes,
    required this.totalRepsDone,
    required this.totalReps,
    required this.workoutLabel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentMinute / totalMinutes;
    final phaseColor = phaseColorForMinute(currentMinute);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Minute ${currentMinute + 1} / $totalMinutes',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            Text('$totalRepsDone / $totalReps $workoutLabel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
