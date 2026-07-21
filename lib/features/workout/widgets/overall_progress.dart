import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_theme.dart';

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
        Text('MINUTE ${currentMinute + 1} / $totalMinutes',
            style: AppTheme.eyebrow.copyWith(fontSize: 11)),
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
