import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/training_plan.dart';
import '../../core/providers/plan_library_notifier.dart';
import 'widgets/minute_exact_editor.dart';

class PlanEditorScreen extends ConsumerStatefulWidget {
  final TrainingPlan plan;
  const PlanEditorScreen({super.key, required this.plan});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  late TrainingPlan _plan;
  int? _selectedRow;

  @override
  void initState() {
    super.initState();
    _plan = TrainingPlan(
      id: widget.plan.id,
      name: widget.plan.name,
      intervals: widget.plan.intervals.map((iv) => iv.copyWith()).toList(),
    );
  }

  Future<void> _save() async {
    await ref.read(planLibraryNotifierProvider.notifier).updatePlan(_plan);
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _plan.intervals.removeAt(oldIndex);
      _plan.intervals.insert(newIndex, item);
      if (_selectedRow != null) {
        final s = _selectedRow!;
        if (s == oldIndex) {
          _selectedRow = newIndex;
        } else if (oldIndex < newIndex && s > oldIndex && s <= newIndex) {
          _selectedRow = s - 1;
        } else if (oldIndex > newIndex && s >= newIndex && s < oldIndex) {
          _selectedRow = s + 1;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _save();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white38),
            onPressed: () async {
              await _save();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Text(
            _plan.name.toUpperCase(),
            style: const TextStyle(
                fontSize: 15, letterSpacing: 4, color: Colors.white38),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: PlanMinuteExactEditor(
                plan: _plan,
                selectedRow: _selectedRow,
                onRowSelected: (i) => setState(() => _selectedRow = i),
                onChanged: () => setState(() {}),
                onReorder: _onReorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Container(
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
                            fontSize: 10, letterSpacing: 3, color: Colors.white24)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${_plan.totalReps} Wdh.',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white38)),
                        Text(_formatDuration(_plan.totalDurationSeconds),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white24)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
