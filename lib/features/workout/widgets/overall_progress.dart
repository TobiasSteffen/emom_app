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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MINUTE ${currentMinute + 1} / $totalMinutes',
            style: AppTheme.eyebrow.copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        // Minuten-Leiste: ein Segment pro Minute in seiner Phasenfarbe —
        // die Phasenstruktur des Trainings ist direkt ablesbar, kommende
        // Minuten sind abgedunkelt.
        Row(
          children: [
            for (var i = 0; i < totalMinutes; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: phaseColorForMinute(i).withValues(
                        alpha: i <= currentMinute ? 1.0 : 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
