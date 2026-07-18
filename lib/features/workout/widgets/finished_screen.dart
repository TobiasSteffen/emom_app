import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

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
            const Text('🏆', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            Text('WORKOUT DONE',
                style: AppTheme.display.copyWith(
                    fontSize: 48,
                    color: AppTheme.accent,
                    letterSpacing: 5)),
            const SizedBox(height: 8),
            Text('$totalReps',
                style: AppTheme.display.copyWith(
                    fontSize: 96, color: AppTheme.textPrimary)),
            Text(workoutLabel,
                style:
                    TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                child: const Text('Nochmal',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
