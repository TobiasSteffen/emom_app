import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import '../../shared/widgets/delete_mode_row.dart';
import 'minute_row.dart';

class PlanMinuteExactEditor extends StatelessWidget {
  final TrainingPlan plan;
  final bool deleteMode;
  final int? selectedRow;
  final ValueChanged<int?> onRowSelected;
  final VoidCallback onChanged;
  final VoidCallback onBeforeFieldChange;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onDelete;
  final Future<bool> Function(int index)? onConfirmDelete;

  const PlanMinuteExactEditor({
    super.key,
    required this.plan,
    required this.deleteMode,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
    required this.onBeforeFieldChange,
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
      itemCount: plan.intervals.length,
      itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(identityHashCode(plan.intervals[i])),
        index: i,
        child: DeleteModeRow(
          key: ValueKey(identityHashCode(plan.intervals[i])),
          deleteKey: ValueKey('delete_$i'),
          deleteMode: deleteMode,
          canDelete: plan.intervals.length > TrainingPlan.minIntervals,
          onDeleteTap: () async {
            if (onConfirmDelete != null) {
              final confirmed = await onConfirmDelete!(i);
              if (!confirmed) return;
            }
            onDelete(i);
          },
          child: PlanMinuteRow(
            index: i,
            plan: plan,
            isSelected: selectedRow == i,
            onSelect: () => onRowSelected(selectedRow == i ? null : i),
            onChanged: onChanged,
            onBeforeFieldChange: onBeforeFieldChange,
          ),
        ),
      ),
      onReorderItem: onReorder,
    );
  }
}
