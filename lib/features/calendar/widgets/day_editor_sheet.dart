// lib/features/calendar/widgets/day_editor_sheet.dart
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../../core/models/calendar_entry.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/training_series.dart';

class DayEditorSheet extends StatefulWidget {
  final DateTime date;
  final List<TrainingPlan> plans;
  final CalendarEntry? existing;

  /// Serie, die diesen Tag trifft — nur gesetzt, wenn KEIN Einzeleintrag
  /// existiert (Override-Tage verhalten sich wie normale Einträge).
  final TrainingSeries? seriesForDay;
  final void Function(CalendarEntry entry) onSaveEntry;
  final void Function(TrainingSeries series, String note) onCreateSeries;
  final VoidCallback? onDeleteEntry;
  final VoidCallback? onExcludeDay;
  final VoidCallback? onDeleteSeries;

  const DayEditorSheet({
    super.key,
    required this.date,
    required this.plans,
    required this.existing,
    required this.onSaveEntry,
    required this.onCreateSeries,
    this.seriesForDay,
    this.onDeleteEntry,
    this.onExcludeDay,
    this.onDeleteSeries,
  });

  @override
  State<DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<DayEditorSheet> {
  static const _orange = AppTheme.accent;
  static const _weekdayLabels = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  String? _selectedPlanId;
  late TextEditingController _noteController;
  bool _repeatWeekly = false;
  late Set<int> _weekdays;

  bool get _isSeriesDay => widget.seriesForDay != null;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.existing?.planId ?? widget.seriesForDay?.planId;
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _weekdays = {widget.date.weekday};
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return '${_weekdayLabels[d.weekday]}, ${d.day}. ${months[d.month]} ${d.year}';
  }

  String _seriesBadgeText(TrainingSeries s) {
    final days = s.weekdays.toList()..sort();
    return 'SERIE · ${days.map((d) => _weekdayLabels[d].toUpperCase()).join('/')}';
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11, color: Colors.white38, letterSpacing: 2));

  Widget _planRow(TrainingPlan plan) {
    final selected = _selectedPlanId == plan.id;
    final minutes = (plan.totalDurationSeconds / 60).round();
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = plan.id),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A1505) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _orange.withValues(alpha: 0.6)
                : AppTheme.surfaceHigh,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$minutes min · ${plan.intervals.length} Intervalle',
                    style: const TextStyle(fontSize: 10, color: Colors.white30),
                  ),
                ],
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _orange : const Color(0xFF333333),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: _orange, shape: BoxShape.circle),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekdayCircle(int wd) {
    final on = _weekdays.contains(wd);
    return GestureDetector(
      onTap: () => setState(() {
        if (on) {
          if (_weekdays.length > 1) _weekdays.remove(wd); // min. ein Tag
        } else {
          _weekdays.add(wd);
        }
      }),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? _orange : AppTheme.surface,
          border: Border.all(color: on ? _orange : AppTheme.surfaceHigh),
        ),
        child: Center(
          child: Text(
            _weekdayLabels[wd],
            style: TextStyle(
              fontSize: 11,
              fontWeight: on ? FontWeight.bold : FontWeight.normal,
              color: on ? Colors.black : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSeries() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Serie löschen?',
          style: TextStyle(
              color: Colors.white54, fontSize: 15, letterSpacing: 1),
        ),
        content: const Text(
          'Alle zukünftigen Serientage werden entfernt. Einzelne Tages-Einträge bleiben erhalten.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Abbrechen', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDeleteSeries?.call();
  }

  void _save() {
    final planId = _selectedPlanId;
    if (planId == null) return;
    final note = _noteController.text.trim();
    if (_repeatWeekly && !_isSeriesDay) {
      widget.onCreateSeries(
        TrainingSeries(
          id: TrainingSeries.newId(),
          planId: planId,
          weekdays: {..._weekdays},
          startDate: widget.date,
        ),
        note,
      );
    } else {
      widget.onSaveEntry(
        CalendarEntry(date: widget.date, planId: planId, note: note),
      );
    }
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
      child: SingleChildScrollView(
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
            // Datum + Serien-Badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(widget.date),
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white54, letterSpacing: 1),
                  ),
                ),
                if (_isSeriesDay)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🔁 ${_seriesBadgeText(widget.seriesForDay!)}',
                      style: const TextStyle(fontSize: 9, color: _orange),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Plan-Auswahl: vertikale Liste mit Radio-Ringen
            _label('TRAININGSPLAN'),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: widget.plans.map(_planRow).toList(),
              ),
            ),
            if (_isSeriesDay) ...[
              const SizedBox(height: 6),
              const Text(
                'Änderungen gelten nur für diesen Tag.',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
            if (!_isSeriesDay) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🔁 Wöchentlich wiederholen',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  Switch(
                    value: _repeatWeekly,
                    onChanged: (v) => setState(() => _repeatWeekly = v),
                    activeThumbColor: _orange,
                  ),
                ],
              ),
              if (_repeatWeekly) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var wd = 1; wd <= 7; wd++) _weekdayCircle(wd),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            // Notiz
            _label('NOTIZ'),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'z.B. Ernährung: abends Kohlenhydrate auffüllen',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: AppTheme.surface,
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
                  borderSide: BorderSide(color: AppTheme.accent),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),
            // Speichern
            SizedBox(
              width: double.infinity,
              height: 48,
              child: GestureDetector(
                onTap: canSave ? _save : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: canSave ? _orange : AppTheme.surfaceHigh,
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
            // Einzeleintrag entfernen
            if (widget.onDeleteEntry != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onDeleteEntry,
                  child: const Text(
                    'Eintrag entfernen',
                    style: TextStyle(fontSize: 13, color: Colors.white24),
                  ),
                ),
              ),
            ],
            // Serientag-Aktionen
            if (_isSeriesDay) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton(
                  onPressed: widget.onExcludeDay,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.surfaceHigh),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Diesen Tag ausnehmen',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _confirmDeleteSeries,
                  child: const Text(
                    'Serie löschen',
                    style: TextStyle(
                        fontSize: 12, color: Color(0x99FF5050)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
