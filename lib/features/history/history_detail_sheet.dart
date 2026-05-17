import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/workout_history.dart';
import '../../core/models/settings.dart';

class HistoryDetailSheet extends StatelessWidget {
  final WorkoutRecord record;
  const HistoryDetailSheet({super.key, required this.record});

  String _formatDateTime(DateTime dt) =>
      DateFormat("EE, d. MMMM yyyy  HH:mm", 'de').format(dt);

  String _repBreakdown() {
    final Map<Equipment, int> byEquipment = {};
    for (final iv in record.intervals) {
      byEquipment[iv.equipment] = (byEquipment[iv.equipment] ?? 0) + iv.reps;
    }
    if (byEquipment.length == 1) return '${record.totalReps} Reps';
    return (byEquipment.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index)))
        .map((e) {
          final label = e.key.label;
          return '${e.value}× $label';
        })
        .join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final totalSecs = record.totalDurationSeconds;
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
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${record.intervals.length}/30 Intervalle',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text('$repBreakdown  ·  $durStr',
                        style: const TextStyle(
                            color: Color(0xFFFF6B00), fontSize: 13)),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: record.intervals.length,
              itemBuilder: (ctx, i) {
                final iv = record.intervals[i];
                final color = phaseColorForMinute(i);
                final eq = iv.equipment;
                final ex = iv.exercise;
                final eqLabel = eq.label;
                final exLabel = ex.label;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
                                color: Colors.white38, fontSize: 12)),
                      ),
                      Image.asset(
                        iv.equipment.iconPath,
                        width: 14,
                        height: 14,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Text(eqLabel,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      const SizedBox(width: 4),
                      Text('· $exLabel',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('${iv.reps} Reps',
                          style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${iv.durationSeconds}s',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
