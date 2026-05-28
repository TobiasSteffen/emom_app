import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import 'minute_row.dart';

class PlanMinuteExactEditor extends StatelessWidget {
  final TrainingPlan plan;
  final int? selectedRow;
  final ValueChanged<int?> onRowSelected;
  final VoidCallback onChanged;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onDelete;
  final Future<bool> Function(int index)? onConfirmDelete;

  const PlanMinuteExactEditor({
    super.key,
    required this.plan,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
    required this.onReorder,
    required this.onDelete,
    this.onConfirmDelete,
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
      itemCount: plan.intervals.length,
      itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(i),
        index: i,
        child: Dismissible(
          key: ValueKey(identityHashCode(plan.intervals[i])),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (_) async {
            if (plan.intervals.length <= TrainingPlan.minIntervals) return false;
            if (onConfirmDelete != null) return await onConfirmDelete!(i);
            return true;
          },
          onDismissed: (_) => onDelete(i),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          ),
          child: PlanMinuteRow(
            index: i,
            plan: plan,
            isSelected: selectedRow == i,
            onSelect: () => onRowSelected(selectedRow == i ? null : i),
            onChanged: onChanged,
          ),
        ),
      ),
      onReorder: onReorder,
    );
  }
}
