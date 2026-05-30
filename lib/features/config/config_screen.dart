import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/settings.dart';
import '../../core/providers/settings_provider.dart';
import 'widgets/feedback_tab.dart';
import 'equipment_catalog_screen.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  final int visitCount;
  final VoidCallback? onBack;
  const ConfigScreen({super.key, this.visitCount = 0, this.onBack});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  late AppSettings _s;

  @override
  void initState() {
    super.initState();
    _s = ref.read(settingsProvider).requireValue;
  }

  @override
  void didUpdateWidget(ConfigScreen old) {
    super.didUpdateWidget(old);
    if (old.visitCount != widget.visitCount) {
      _s = ref.read(settingsProvider).requireValue;
    }
  }

  void _save() {
    ref.read(settingsProvider.notifier).replace(_s);
    ref.read(settingsProvider.notifier).save();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    if (settingsAsync.value == null) return const SizedBox();
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: () {
            _save();
            widget.onBack?.call();
          },
        ),
        title: const Text(
          'EINSTELLUNGEN',
          style: TextStyle(fontSize: 15, letterSpacing: 4, color: Colors.white38),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              'GERÄTE & ÜBUNGEN',
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white24),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EquipmentCatalogScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fitness_center, color: Color(0xFFFF6B00), size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Geräte & Übungen verwalten',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FeedbackTab(
            settings: _s,
            onChanged: () => setState(() {}),
            onSaved: _save,
          ),
        ],
      ),
    );
  }
}
