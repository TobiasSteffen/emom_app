import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/settings.dart';
import '../../core/providers/settings_provider.dart';
import 'widgets/feedback_tab.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  final int visitCount;
  const ConfigScreen({super.key, this.visitCount = 0});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  late AppSettings _s;

  @override
  void initState() {
    super.initState();
    _s = ref.read(settingsNotifierProvider).requireValue;
  }

  @override
  void didUpdateWidget(ConfigScreen old) {
    super.didUpdateWidget(old);
    if (old.visitCount != widget.visitCount) {
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          FeedbackTab(
            settings: _s,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}
