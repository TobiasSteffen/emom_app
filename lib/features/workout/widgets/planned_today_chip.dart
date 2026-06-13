import 'package:flutter/material.dart';

/// Dezenter Hinweis auf dem Workout-Screen: heute ist ein anderer Plan
/// geplant als der aktive. Tap aktiviert den geplanten Plan.
class PlannedTodayChip extends StatelessWidget {
  static const _orange = Color(0xFFFF6B00);

  final String planName;
  final VoidCallback onTap;

  const PlannedTodayChip({
    super.key,
    required this.planName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _orange.withValues(alpha: 0.12),
          border: Border.all(color: _orange.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available, size: 14, color: _orange),
            const SizedBox(width: 6),
            Text(
              'Heute geplant: $planName',
              style: const TextStyle(fontSize: 12, color: _orange),
            ),
          ],
        ),
      ),
    );
  }
}
