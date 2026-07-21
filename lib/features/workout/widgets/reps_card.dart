import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_theme.dart';

class RepsCard extends StatelessWidget {
  final int currentMinute;
  final int currentReps;
  final String workoutLabel;
  final String iconPath;
  final Animation<double> pulseAnimation;
  final bool isPause;
  final bool isTimed;
  final int timedSeconds;

  const RepsCard({
    super.key,
    required this.currentMinute,
    required this.currentReps,
    required this.workoutLabel,
    required this.iconPath,
    required this.pulseAnimation,
    this.isPause = false,
    this.isTimed = false,
    this.timedSeconds = 0,
  });

  @override
  Widget build(BuildContext context) {
    final phaseColor =
        isPause ? Colors.white24 : phaseColorForMinute(currentMinute);
    return ScaleTransition(
      scale: pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          // Phasenfarbe als kaum sichtbarer Verlauf statt flacher Fläche —
          // die Karte "leuchtet" von oben in der aktuellen Phase.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                  phaseColor.withValues(alpha: 0.10), AppTheme.surface),
              AppTheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: phaseColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            if (!isPause) ...[
              Image.asset(iconPath, width: 44, height: 44, color: phaseColor),
              const SizedBox(height: 6),
              Text(isTimed ? 'ZEIT' : 'REPS', style: AppTheme.eyebrow),
              const SizedBox(height: 4),
              Text(
                isTimed ? '${timedSeconds}s' : '$currentReps',
                style: AppTheme.display.copyWith(
                  fontSize: 128,
                  color: phaseColor,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'PAUSE',
                style: AppTheme.display.copyWith(
                  fontSize: 72,
                  color: phaseColor,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 10),
            Text(
              workoutLabel,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
