import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class WorkoutHeader extends StatelessWidget {
  final int currentMinute;
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  const WorkoutHeader({
    super.key,
    required this.currentMinute,
    required this.onHistory,
    required this.onSettings,
  });

  String get _phaseLabel {
    if (currentMinute < 5) return 'Warm Up';
    if (currentMinute < 15) return 'Aufbau ↑';
    if (currentMinute < 20) return 'Peak';
    if (currentMinute < 25) return 'Abbau ↓';
    return 'Cool Down';
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = phaseColorForMinute(currentMinute);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('EMOM 30',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.6), letterSpacing: 3,
            )),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: phaseColor.withValues(alpha: 0.5)),
              ),
              child: Text(_phaseLabel,
                  style: TextStyle(color: phaseColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onHistory,
              child: const Icon(Icons.history, color: Colors.white24, size: 22),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onSettings,
              child: const Icon(Icons.settings, color: Colors.white24, size: 22),
            ),
          ],
        ),
      ],
    );
  }
}
