// lib/features/calendar/widgets/day_editor_sheet.dart
import 'package:flutter/material.dart';
import '../../../core/models/calendar_entry.dart';
import '../../../core/models/training_plan.dart';

class DayEditorSheet extends StatelessWidget {
  final DateTime date;
  final List<TrainingPlan> plans;
  final CalendarEntry? existing;
  final void Function(CalendarEntry) onSave;
  final VoidCallback? onDelete;

  const DayEditorSheet({
    super.key,
    required this.date,
    required this.plans,
    required this.existing,
    required this.onSave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) => const SizedBox();
}
