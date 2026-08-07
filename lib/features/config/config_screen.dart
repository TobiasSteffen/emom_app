import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/settings.dart';
import '../../core/providers/settings_provider.dart';
import 'widgets/feedback_tab.dart';
import 'equipment_catalog_screen.dart';
import 'garmin_notifier.dart';

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
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
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
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fitness_center, color: AppTheme.ok, size: 18),
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
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              'GARMIN-UHR',
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white24),
            ),
          ),
          Builder(builder: (context) {
            final connectionAsync = ref.watch(garminProvider);
            final connected = connectionAsync.value?.connected ?? false;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        connected ? Icons.watch : Icons.watch_off,
                        color: connected ? AppTheme.ok : AppTheme.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          connected ? 'Uhr verbunden' : 'Uhr nicht verbunden',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final status = await ref.read(garminProvider.notifier).openWatchApp();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Status: $status')),
                          );
                        }
                      },
                      child: const Text('Watch-App öffnen'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'In der Hauptansicht anzeigen',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      Switch(
                        value: _s.garminHeaderIconVisible,
                        onChanged: (v) {
                          setState(() => _s.garminHeaderIconVisible = v);
                          _save();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
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
