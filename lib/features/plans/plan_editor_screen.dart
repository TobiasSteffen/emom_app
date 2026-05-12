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
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            PlanMinuteExactEditor(
              plan: _plan,
              selectedRow: _selectedRow,
              onRowSelected: (i) => setState(() => _selectedRow = i),
              onChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
