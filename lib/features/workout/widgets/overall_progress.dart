import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class OverallProgress extends StatelessWidget {
  final int currentMinute;
  final int totalMinutes;
  final bool isPause;

  const OverallProgress({
    super.key,
    required this.currentMinute,
    required this.totalMinutes,
    this.isPause = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentMinute / totalMinutes;
    final phaseColor = isPause ? Colors.white24 : phaseColorForMinute(currentMinute);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Minute ${currentMinute + 1} / $totalMinutes',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
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
