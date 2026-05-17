import 'package:flutter/material.dart';

class FinishedScreen extends StatelessWidget {
  final int totalReps;
  final String workoutLabel;
  final VoidCallback onReset;

  const FinishedScreen({
    super.key,
    required this.totalReps,
    required this.workoutLabel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            const Text('WORKOUT DONE!',
                style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w900,
                    color: Color(0xFFFF6B00), letterSpacing: 4)),
            const SizedBox(height: 16),
            Text('$totalReps $workoutLabel',
                style: TextStyle(
                    fontSize: 20, color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    borderRadius: BorderRadius.circular(16)),
                child: const Text('Nochmal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
