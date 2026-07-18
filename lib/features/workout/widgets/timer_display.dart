import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TimerDisplay extends StatelessWidget {
  final int secondsLeft;
  final int currentDuration;
  final bool isRunning;

  const TimerDisplay({
    super.key,
    required this.secondsLeft,
    required this.currentDuration,
    required this.isRunning,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final overtime = secondsLeft < 0;
    final isWarning = !overtime && secondsLeft <= 5 && secondsLeft > 0 && isRunning;
    final secondProgress = overtime
        ? 1.0
        : ((currentDuration - secondsLeft) / currentDuration).clamp(0.0, 1.0);
    final display = overtime ? '+${_formatTime(-secondsLeft)}' : _formatTime(secondsLeft);
    final color =
        (overtime || isWarning) ? AppTheme.danger : AppTheme.textPrimary;
    return Column(
      children: [
        Text(
          display,
          style: AppTheme.display.copyWith(
            fontSize: 68,
            color: color,
            letterSpacing: 3,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: secondProgress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              (overtime || isWarning) ? AppTheme.danger : Colors.white24,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
