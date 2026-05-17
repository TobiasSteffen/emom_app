import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/training_plan.dart';
import '../../core/providers/plan_library_notifier.dart';
import 'plan_editor_screen.dart';

class PlanLibraryScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  const PlanLibraryScreen({super.key, this.onBack});

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Future<void> _addPlan(BuildContext context, WidgetRef ref, int planCount) async {
    final controller = TextEditingController(text: 'Plan ${planCount + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Neuer Plan',
              style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white70),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF6B00))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen',
                  style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Erstellen',
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final plan = TrainingPlan.pyramid(name);
    await ref.read(planLibraryNotifierProvider.notifier).addPlan(plan);
    if (!context.mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => PlanEditorScreen(plan: plan)));
  }

  Future<void> _renamePlan(
      BuildContext context, WidgetRef ref, TrainingPlan plan) async {
    final controller = TextEditingController(text: plan.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Plan umbenennen',
              style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white70),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF6B00))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen',
                  style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Speichern',
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await ref.read(planLibraryNotifierProvider.notifier).renamePlan(plan.id, name);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TrainingPlan plan,
      {required bool isActive, required bool isLast}) async {
    if (isActive || isLast) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Nicht möglich',
              style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
          content: Text(
            isActive
                ? 'Der aktive Plan kann nicht gelöscht werden.'
                : 'Der letzte Plan kann nicht gelöscht werden.',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Plan löschen?',
            style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
        content: Text('„${plan.name}" wird permanent gelöscht.',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    if (confirm) {
      await ref.read(planLibraryNotifierProvider.notifier).deletePlan(plan.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(planLibraryNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
        title: const Text('TRAININGSPLÄNE',
            style: TextStyle(fontSize: 15, letterSpacing: 4, color: Colors.white38)),
      ),
      body: libraryAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: Colors.white38))),
        data: (library) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: GestureDetector(
                onTap: () => _addPlan(context, ref, library.plans.length),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Color(0xFFFF6B00), size: 18),
                      SizedBox(width: 8),
                      Text('Neuer Plan',
                          style: TextStyle(
                              color: Color(0xFFFF6B00),
                              fontSize: 14,
                              letterSpacing: 2)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                itemCount: library.plans.length,
                itemBuilder: (_, i) {
                  final plan = library.plans[i];
                  final isActive = plan.id == library.activePlanId;
                  return GestureDetector(
                    onLongPress: () => _renamePlan(context, ref, plan),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PlanEditorScreen(plan: plan)),
                    ),
                    child: Dismissible(
                      key: ValueKey(plan.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _confirmDelete(context, ref, plan,
                            isActive: isActive,
                            isLast: library.plans.length == 1);
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => ref
                                  .read(planLibraryNotifierProvider.notifier)
                                  .setActivePlan(plan.id),
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xFFFF6B00)
                                          : Colors.white24,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isActive
                                          ? Colors.white70
                                          : Colors.white38,
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${plan.intervals.length} Intervalle · ${_formatDuration(plan.totalDurationSeconds)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white24),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.white24, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
