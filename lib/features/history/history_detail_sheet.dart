import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/workout_history.dart';
import '../../core/models/settings.dart';
import '../../core/models/training_plan.dart';
import '../shared/widgets/interval_edit_form.dart';
import 'history_notifier.dart';

IntervalConfig _toConfig(IntervalRecord r) => IntervalConfig(
      equipment: r.equipment,
      exercise: r.exercise,
      reps: r.reps,
      durationSeconds: r.durationSeconds,
      side: r.side,
      isPause: r.isPause,
    );

IntervalRecord _toRecord(IntervalConfig c) => IntervalRecord(
      equipment: c.equipment,
      exercise: c.exercise,
      reps: c.reps,
      durationSeconds: c.durationSeconds,
      side: c.side,
      isPause: c.isPause,
    );

class HistoryDetailSheet extends ConsumerStatefulWidget {
  final WorkoutRecord record;
  const HistoryDetailSheet({super.key, required this.record});

  @override
  ConsumerState<HistoryDetailSheet> createState() =>
      _HistoryDetailSheetState();
}

class _HistoryDetailSheetState extends ConsumerState<HistoryDetailSheet> {
  late List<IntervalConfig> _editIntervals;
  late List<IntervalRecord> _savedIntervals;
  int? _selectedRow;
  bool _isDirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _editIntervals = widget.record.intervals.map(_toConfig).toList();
    _savedIntervals = List.from(widget.record.intervals);
  }

  String _formatDateTime(DateTime dt) =>
      DateFormat("EE, d. MMMM yyyy  HH:mm", 'de').format(dt);

  String _repBreakdown() {
    final Map<Equipment, int> byEquipment = {};
    for (final iv in _editIntervals) {
      if (!iv.isPause) {
        byEquipment[iv.equipment] =
            (byEquipment[iv.equipment] ?? 0) + iv.reps;
      }
    }
    final totalReps = byEquipment.values.fold(0, (a, b) => a + b);
    if (byEquipment.length <= 1) return '$totalReps Reps';
    return (byEquipment.entries.toList()
          ..sort((a, b) => a.key.index.compareTo(b.key.index)))
        .map((e) => '${e.value}× ${e.key.label}')
        .join(' / ');
  }

  void _revertRow(int i) {
    _editIntervals[i] = _toConfig(_savedIntervals[i]);
  }

  bool _computeIsDirty() {
    for (int i = 0; i < _editIntervals.length; i++) {
      final orig = _savedIntervals[i];
      final edit = _editIntervals[i];
      if (orig.reps != edit.reps ||
          orig.durationSeconds != edit.durationSeconds ||
          orig.equipment != edit.equipment ||
          orig.exercise != edit.exercise ||
          orig.side != edit.side ||
          orig.isPause != edit.isPause) {
        return true;
      }
    }
    return false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = WorkoutRecord(
      timestamp: widget.record.timestamp,
      planMode: widget.record.planMode,
      intervals: _editIntervals.map(_toRecord).toList(),
    );
    await ref.read(historyProvider.notifier).updateRecord(updated);
    if (mounted) {
      setState(() {
        _savedIntervals = _editIntervals.map(_toRecord).toList();
        _isDirty = false;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt =
        DateTime.fromMillisecondsSinceEpoch(widget.record.timestamp);
    final totalSecs =
        _editIntervals.fold(0, (a, b) => a + b.durationSeconds);
    final durStr =
        '${totalSecs ~/ 60}m ${(totalSecs % 60).toString().padLeft(2, '0')}s';
    final repBreakdown = _repBreakdown();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDateTime(dt),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_editIntervals.length}/30 Intervalle',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    Flexible(
                      child: Text(
                        '$repBreakdown  ·  $durStr',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFFF6B00), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(16, 8, 16, _isDirty ? 80 : 32),
              itemCount: _editIntervals.length,
              itemBuilder: (ctx, i) {
                final iv = _editIntervals[i];
                final isSelected = _selectedRow == i;
                final color =
                    iv.isPause ? Colors.white24 : phaseColorForMinute(i);

                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _revertRow(i);
                      _isDirty = _computeIsDirty();
                      _selectedRow = null;
                    } else {
                      _selectedRow = i;
                    }
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 52,
                              child: Text('Min ${i + 1}',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12)),
                            ),
                            if (iv.isPause) ...[
                              const Text('PAUSE',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white38,
                                      letterSpacing: 1)),
                              const Spacer(),
                              Text('${iv.durationSeconds}s',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12)),
                            ] else ...[
                              Image.asset(
                                iv.equipment.iconPath,
                                width: 14,
                                height: 14,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 6),
                              Text(iv.equipment.label,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                iv.side != null
                                    ? '· ${iv.exercise.label} ${iv.side!.shortLabel}'
                                    : '· ${iv.exercise.label}',
                                style: const TextStyle(
                                    color: Colors.white24, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Text('${iv.reps} Reps',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('${iv.durationSeconds}s',
                                  style: const TextStyle(
                                      color: Colors.white24,
                                      fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        sizeCurve: Curves.easeInOut,
                        crossFadeState: isSelected
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: GestureDetector(
                          onTap: () {},
                          behavior: HitTestBehavior.opaque,
                          child: IntervalEditForm(
                            key: ValueKey(i),
                            iv: iv,
                            onChanged: () =>
                                setState(() => _isDirty = true),
                            index: i,
                            onCollapse: () => setState(() {
                              _revertRow(i);
                              _isDirty = _computeIsDirty();
                              _selectedRow = null;
                            }),
                          ),
                        ),
                        secondChild: const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isDirty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Speichern',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
