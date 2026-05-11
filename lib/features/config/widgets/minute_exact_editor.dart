import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';
import 'minute_row.dart';

class MinuteExactEditor extends StatelessWidget {
  final AppSettings settings;
  final int? selectedRow;
  final ValueChanged<int?> onRowSelected;
  final VoidCallback onChanged;

  const MinuteExactEditor({
    super.key,
    required this.settings,
    required this.selectedRow,
    required this.onRowSelected,
    required this.onChanged,
  });

  int get _minuteTotal => settings.customPlan.fold(0, (sum, v) => sum + v);
  int get _totalDurationSeconds =>
      settings.customDurations.fold(0, (sum, v) => sum + v);

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
          key: const PageStorageKey<String>('minuteExactList'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemExtent: 42,
          itemCount: 30,
          itemBuilder: (_, i) => MinuteRow(
            key: ValueKey(i),
            index: i,
            settings: settings,
            isSelected: selectedRow == i,
            onSelect: () =>
                onRowSelected(selectedRow == i ? null : i),
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
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 3,
                      color: Colors.white24)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$_minuteTotal Reps',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38)),
                  Text(_formatDuration(_totalDurationSeconds),
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white24)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
