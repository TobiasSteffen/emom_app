import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/workout_history.dart';
import 'history_notifier.dart';
import 'history_detail_sheet.dart';

class HistorySheet extends ConsumerWidget {
  const HistorySheet({super.key});

  String _formatDateTime(DateTime dt) =>
      DateFormat("EE, d. MMMM yyyy  HH:mm", 'de').format(dt);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.3,
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'VERLAUF',
                style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 3),
              ),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => const SizedBox(),
              data: (records) => records.isEmpty
                  ? const Center(
                      child: Text(
                        'Noch keine Trainings gespeichert',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: records.length,
                      itemBuilder: (ctx, i) => GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(0xFF0D0D0D),
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => HistoryDetailSheet(record: records[i]),
                        ),
                        child: _buildCard(records[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(WorkoutRecord record) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final planModeStr = record.planMode == 0 ? 'Phasenbasiert' : 'Minuten-genau';
    final kbReps = record.kettlebellReps;
    final smReps = record.steelMaceReps;
    final equipStr = kbReps > 0 && smReps > 0
        ? 'Kettlebell + Steel Mace'
        : kbReps > 0 ? 'Kettlebell' : 'Steel Mace';
    final totalSecs = record.totalDurationSeconds;
    final durStr = '${totalSecs ~/ 60}m ${(totalSecs % 60).toString().padLeft(2, '0')}s';
    final repBreakdown = kbReps > 0 && smReps > 0 ? '  ·  $kbReps× KB  /  $smReps× SM' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatDateTime(dt),
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 6),
          Text('$equipStr · $planModeStr · ${record.intervals.length}/30 Intervalle',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${record.totalReps} Reps  ·  $durStr$repBreakdown',
              style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 13)),
        ],
      ),
    );
  }
}
