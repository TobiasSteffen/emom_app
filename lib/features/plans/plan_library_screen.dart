import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/training_plan.dart';
import '../../core/providers/plan_library_notifier.dart';
import '../shared/widgets/delete_mode_row.dart';
import 'plan_editor_screen.dart';
import '../config/equipment_catalog_screen.dart';
import 'emom_wizard_screen.dart';

class PlanLibraryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const PlanLibraryScreen({super.key, this.onBack});

  @override
  ConsumerState<PlanLibraryScreen> createState() => _PlanLibraryScreenState();
}

class _PlanLibraryScreenState extends ConsumerState<PlanLibraryScreen> {
  bool _deleteMode = false;

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Future<void> _addPlan(BuildContext context, int planCount) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('NEUER PLAN',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: Colors.white38)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined,
                  color: Colors.white54),
              title: const Text('Leer',
                  style: TextStyle(color: Colors.white70)),
              subtitle: const Text('Selbst aufbauen',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'empty'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.timer_outlined, color: AppTheme.accent),
              title: const Text('Klassisches EMOM',
                  style: TextStyle(color: Colors.white70)),
              subtitle: const Text('30 × 60s einer Übung',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'emom'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'empty') {
      await _addEmptyPlan(context, planCount);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmomWizardScreen(planCount: planCount),
        ),
      );
    }
  }

  Future<void> _addEmptyPlan(BuildContext context, int planCount) async {
    final controller = TextEditingController(text: 'Plan ${planCount + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
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
                  borderSide: BorderSide(color: AppTheme.accent)),
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
                  style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final plan = TrainingPlan.fresh(name);
    await ref.read(planLibraryProvider.notifier).addPlan(plan);
    if (!context.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => PlanEditorScreen(plan: plan)));
      }
    });
  }

  Future<void> _renamePlan(BuildContext context, TrainingPlan plan) async {
    final controller = TextEditingController(text: plan.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
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
                  borderSide: BorderSide(color: AppTheme.accent)),
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
                  style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    await ref.read(planLibraryProvider.notifier).renamePlan(plan.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(planLibraryProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
        ),
        title: const Text('TRAININGSPLÄNE',
            style: TextStyle(fontSize: 15, letterSpacing: 4, color: Colors.white38)),
        actions: [
          IconButton(
            key: const ValueKey('library_delete_mode_toggle'),
            tooltip: 'Löschen',
            icon: Icon(
              Icons.delete_outline,
              color: _deleteMode ? AppTheme.danger : Colors.white38,
            ),
            onPressed: () => setState(() => _deleteMode = !_deleteMode),
          ),
          IconButton(
            icon: const Icon(Icons.fitness_center, color: AppTheme.accent),
            tooltip: 'Geräte & Übungen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EquipmentCatalogScreen(),
              ),
            ),
          ),
        ],
      ),
      body: libraryAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: Colors.white38))),
        data: (library) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: GestureDetector(
                onTap: () => _addPlan(context, library.plans.length),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: AppTheme.accent, size: 18),
                      SizedBox(width: 8),
                      Text('Neuer Plan',
                          style: TextStyle(
                              color: AppTheme.accent,
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PlanEditorScreen(plan: plan)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DeleteModeRow(
                        key: ValueKey(plan.id),
                        deleteKey: ValueKey('delete_plan_${plan.id}'),
                        deleteMode: _deleteMode,
                        canDelete: library.plans.length > 1,
                        onDeleteTap: () async {
                          await ref
                              .read(planLibraryProvider.notifier)
                              .deletePlan(plan.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => ref
                                    .read(planLibraryProvider.notifier)
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
                                            ? AppTheme.accent
                                            : Colors.white24,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: GestureDetector(
                                  onLongPress: () => _renamePlan(context, plan),
                                  behavior: HitTestBehavior.opaque,
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
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white24, size: 20),
                            ],
                          ),
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
