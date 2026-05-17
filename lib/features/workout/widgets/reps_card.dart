import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class RepsCard extends StatelessWidget {
  final int currentMinute;
  final int currentReps;
  final String workoutLabel;
  final String iconPath;
  final Animation<double> pulseAnimation;
  final bool isPause;

  const RepsCard({
    super.key,
    required this.currentMinute,
    required this.currentReps,
    required this.workoutLabel,
    required this.iconPath,
    required this.pulseAnimation,
    this.isPause = false,
  });

  @override
  Widget build(BuildContext context) {
    final phaseColor =
        isPause ? Colors.white24 : phaseColorForMinute(currentMinute);
    return ScaleTransition(
      scale: pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: phaseColor.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            if (!isPause) ...[
              Image.asset(iconPath, width: 48, height: 48, color: phaseColor),
              const SizedBox(height: 4),
              Text(
                'REPS',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              Text(
                '$currentReps',
                style: TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: phaseColor,
                    height: 1),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'PAUSE',
                style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: phaseColor,
                    height: 1,
                    letterSpacing: 4),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            Text(
              workoutLabel,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
