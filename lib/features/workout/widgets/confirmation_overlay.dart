import 'package:flutter/material.dart';

class ConfirmationOverlay extends StatelessWidget {
  final int nextReps;
  final Color nextColor;
  final String nextLabel;
  final int nextMinuteNumber;
  final VoidCallback onConfirm;
  final bool nextIsPause;

  const ConfirmationOverlay({
    super.key,
    required this.nextReps,
    required this.nextColor,
    required this.nextLabel,
    required this.nextMinuteNumber,
    required this.onConfirm,
    this.nextIsPause = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onConfirm,
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('INTERVALL BEENDET',
                  style: TextStyle(
                      color: Colors.white24, fontSize: 11, letterSpacing: 4)),
              const SizedBox(height: 32),
              if (nextIsPause)
                Text(
                  'PAUSE',
                  style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: nextColor,
                      height: 1,
                      letterSpacing: 4),
                )
              else
                Text(
                  '$nextReps',
                  style: TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      color: nextColor,
                      height: 1),
                ),
              Text(nextLabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 16)),
              Text('Minute $nextMinuteNumber',
                  style: const TextStyle(color: Colors.white24, fontSize: 13)),
              const SizedBox(height: 48),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: nextColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: nextColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: const Text('WEITER',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Colors.white)),
              ),
              const SizedBox(height: 16),
              const Text('oder irgendwo tippen',
                  style: TextStyle(color: Colors.white12, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
