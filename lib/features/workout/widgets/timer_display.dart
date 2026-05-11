import 'package:flutter/material.dart';

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
    final isWarning = secondsLeft <= 5 && secondsLeft > 0 && isRunning;
    final secondProgress = (currentDuration - secondsLeft) / currentDuration;
    return Column(
      children: [
        Text(
          _formatTime(secondsLeft),
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w300,
            color: isWarning ? const Color(0xFFFF4444) : Colors.white,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: secondProgress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              isWarning ? const Color(0xFFFF4444) : Colors.white24,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
