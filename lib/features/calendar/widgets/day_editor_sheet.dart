// lib/features/calendar/widgets/day_editor_sheet.dart
import 'package:flutter/material.dart';
import '../../../core/models/calendar_entry.dart';
import '../../../core/models/training_plan.dart';

class DayEditorSheet extends StatefulWidget {
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
  State<DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<DayEditorSheet> {
  String? _selectedPlanId;
  late TextEditingController _preController;
  late TextEditingController _postController;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.existing?.planId;
    _preController =
        TextEditingController(text: widget.existing?.preNutrition ?? '');
    _postController =
        TextEditingController(text: widget.existing?.postNutrition ?? '');
  }

  @override
  void dispose() {
    _preController.dispose();
    _postController.dispose();
    super.dispose();
  }

  Widget _planChip(TrainingPlan plan) {
    final selected = _selectedPlanId == plan.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = plan.id),
      child: Container(
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B00) : const Color(0xFF222222),
          borderRadius: BorderRadius.circular(6),
          border: selected ? null : Border.all(color: Colors.white12),
        ),
        child: Text(
          plan.name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.black : Colors.white54,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const weekdays = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const months = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return '${weekdays[d.weekday]}, ${d.day}. ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedPlanId != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Date header
          Text(
            _formatDate(widget.date),
            style: const TextStyle(
                fontSize: 14, color: Colors.white54, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          // Plan selector
          const Text('Trainingsplan',
              style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(
            children: widget.plans.map(_planChip).toList(),
          ),
          const SizedBox(height: 16),
          // Pre-nutrition
          const Text('Ernährung Vortag',
              style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 6),
          TextField(
            controller: _preController,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'z.B. Kohlenhydrate erhöhen, wenig Fett',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Color(0xFF111111),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Color(0xFFFF6B00)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          // Post-nutrition
          const Text('Ernährung Nachtag',
              style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 6),
          TextField(
            controller: _postController,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'z.B. Protein erhöhen, Regeneration',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Color(0xFF111111),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Color(0xFFFF6B00)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 20),
          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: GestureDetector(
              onTap: canSave
                  ? () => widget.onSave(CalendarEntry(
                        date: widget.date,
                        planId: _selectedPlanId!,
                        preNutrition: _preController.text.trim(),
                        postNutrition: _postController.text.trim(),
                      ))
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: canSave
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Speichern',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canSave ? Colors.black : Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Delete button (only if entry exists)
          if (widget.onDelete != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onDelete,
                child: const Text(
                  'Eintrag entfernen',
                  style: TextStyle(fontSize: 13, color: Colors.white24),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
