import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PlanIndicator extends StatelessWidget {
  final String planName;
  final VoidCallback onTap;

  const PlanIndicator({super.key, required this.planName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 11, color: AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(planName,
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    letterSpacing: 1)),
            const SizedBox(width: 3),
            Icon(Icons.chevron_right, size: 13, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
