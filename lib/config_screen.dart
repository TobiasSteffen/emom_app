import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models/settings.dart';
import 'core/providers/settings_provider.dart';
import 'features/config/widgets/plan_mode_selector.dart';
import 'features/config/widgets/equipment_selector.dart';
import 'features/config/widgets/phase_based_editor.dart';
import 'features/config/widgets/minute_exact_editor.dart';
import 'features/config/widgets/feedback_tab.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  final int visitCount;
  const ConfigScreen({super.key, this.visitCount = 0});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen>
    with SingleTickerProviderStateMixin {
  late AppSettings _s;
  late TabController _tabController;
  int? _selectedMinuteRow;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _s = ref.read(settingsNotifierProvider).requireValue;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ConfigScreen old) {
    super.didUpdateWidget(old);
    if (old.visitCount != widget.visitCount) {
      _tabController.animateTo(0);
      _selectedMinuteRow = null;
      _s = ref.read(settingsNotifierProvider).requireValue;
    }
  }

  void _save() {
    ref.read(settingsNotifierProvider.notifier).replace(_s);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    if (settingsAsync.valueOrNull == null) return const SizedBox();
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: _save,
        ),
        title: const Text(
          'EINSTELLUNGEN',
          style: TextStyle(fontSize: 15, letterSpacing: 4, color: Colors.white38),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B00),
          indicatorWeight: 2,
          labelColor: Colors.white54,
          unselectedLabelColor: Colors.white24,
          labelStyle: const TextStyle(fontSize: 11, letterSpacing: 3),
          unselectedLabelStyle: const TextStyle(fontSize: 11, letterSpacing: 3),
          tabs: const [
            Tab(text: 'WORKOUT-PLAN'),
            Tab(text: 'FEEDBACK'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Workout-Plan ───────────────────────────────────────────
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              PlanModeSelector(
                planMode: _s.planMode,
                onChanged: (mode) => setState(() => _s.planMode = mode),
              ),
              if (_s.planMode == PlanMode.phaseBased) ...[
                EquipmentSelector(
                  equipment: _s.equipment,
                  onChanged: (eq) => setState(() => _s.equipment = eq),
                ),
                PhaseBasedEditor(
                  settings: _s,
                  onChanged: () => setState(() {}),
                ),
              ] else
                MinuteExactEditor(
                  settings: _s,
                  selectedRow: _selectedMinuteRow,
                  onRowSelected: (i) => setState(() => _selectedMinuteRow = i),
                  onChanged: () => setState(() {}),
                ),
            ],
          ),
          // ── Tab 2: Feedback & Sound ───────────────────────────────────────
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              FeedbackTab(
                settings: _s,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
