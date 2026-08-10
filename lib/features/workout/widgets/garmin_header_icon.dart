import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../config/garmin_notifier.dart';

class GarminHeaderIcon extends ConsumerWidget {
  final VoidCallback onSettings;

  const GarminHeaderIcon({super.key, required this.onSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final visible = settingsAsync.value?.garminHeaderIconVisible ?? false;
    if (!visible) return const SizedBox.shrink();

    final status = ref.watch(garminProvider).value;
    final everConnected = status?.everConnected ?? false;
    final appRunning = status?.appRunning ?? false;

    final Color color = appRunning
        ? AppTheme.ok
        : (everConnected ? AppTheme.danger : AppTheme.textMuted);

    return GestureDetector(
      onTap: () async {
        if (!everConnected) {
          onSettings();
          return;
        }
        final result = await ref.read(garminProvider.notifier).openWatchApp();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status: $result')),
          );
        }
      },
      child: Icon(Icons.watch, key: const Key('garminHeaderIcon'), color: color, size: 22),
    );
  }
}
