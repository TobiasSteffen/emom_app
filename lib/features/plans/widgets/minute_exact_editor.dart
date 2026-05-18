import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import 'minute_row.dart';

class PlanMinuteExactEditor extends StatelessWidget {
  final TrainingPlan plan;
  final int? selectedRow;
  final ValueChanged<int?> onRowSelected;
  final VoidCallback onChanged;
  final void Function(int oldIndex, int newIndex) onReorder;

  const PlanMinuteExactEditor({
    super.key,
    required this.plan,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => Material(
        elevation: 4,
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
      itemCount: 30,
      itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(i),
        index: i,
        child: PlanMinuteRow(
          index: i,
          plan: plan,
          isSelected: selectedRow == i,
          onSelect: () => onRowSelected(selectedRow == i ? null : i),
          onChanged: onChanged,
        ),
      ),
      onReorder: onReorder,
    );
  }
}
