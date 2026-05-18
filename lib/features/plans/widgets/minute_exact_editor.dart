import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import 'minute_row.dart';

class PlanMinuteExactEditor extends StatelessWidget {
  final TrainingPlan plan;
  final int? selectedRow;
  final ValueChanged<int?> onRowSelected;
  final VoidCallback onChanged;

  const PlanMinuteExactEditor({
    super.key,
    required this.plan,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
  });

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder(
          key: const PageStorageKey<String>('planMinuteExactList'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 30,
          itemBuilder: (_, i) => PlanMinuteRow(
            key: ValueKey(i),
            index: i,
            plan: plan,
            isSelected: selectedRow == i,
            onSelect: () => onRowSelected(selectedRow == i ? null : i),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GESAMT',
                  style: TextStyle(fontSize: 10, letterSpacing: 3, color: Colors.white24)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${plan.totalReps} Wdh.',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white38)),
                  Text(_formatDuration(plan.totalDurationSeconds),
                      style: const TextStyle(fontSize: 13, color: Colors.white24)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
