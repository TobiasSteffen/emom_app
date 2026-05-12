import 'package:flutter/material.dart';

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
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 11, color: Colors.white24),
            const SizedBox(width: 5),
            Text(planName,
                style: const TextStyle(
                    fontSize: 11, color: Colors.white24, letterSpacing: 1)),
            const SizedBox(width: 3),
            const Icon(Icons.chevron_right, size: 13, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
