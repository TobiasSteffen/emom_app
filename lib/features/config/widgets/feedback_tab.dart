import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/models/settings.dart';
import 'sound_picker_dialog.dart';

class FeedbackTab extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onChanged;

  const FeedbackTab({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  Future<List<String>> _getImportedSounds() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${docsDir.path}/sounds');
    if (!await soundsDir.exists()) return [];
    return soundsDir
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .toList();
  }

  Future<void> _openSoundPicker(
    BuildContext context,
    String label,
    String currentFile,
    ValueChanged<String> onSelected,
  ) async {
    final imported = await _getImportedSounds();
    if (!context.mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => SoundPickerDialog(
        title: label,
        currentFile: currentFile,
        builtinSounds: const ['bell.wav', 'tick.wav', 'alarm.wav', 'alarm_low.wav'],
        importedSounds: imported,
      ),
    );

    if (result != null) {
      onSelected(result);
      onChanged();
    }
  }

  Widget _toggleRow(
    String label,
    bool value,
    ValueChanged<bool> onToggled,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 15)),
            Switch(
              value: value,
              onChanged: onToggled,
              activeThumbColor: const Color(0xFF4CAF50),
            ),
          ],
        ),
      );

  Widget _volumeSliderRow(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            const Text('Ziellautstärke',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF4CAF50),
                  inactiveTrackColor: const Color(0xFF1A1A1A),
                  thumbColor: const Color(0xFF4CAF50),
                  overlayColor: const Color(0x224CAF50),
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: settings.volumeBoostLevel,
                  min: 0,
                  max: 1,
                  onChanged: (v) {
                    settings.volumeBoostLevel = v;
                    if (v <= 0) settings.volumeBoostEnabled = false;
                    onChanged();
                  },
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${(settings.volumeBoostLevel * 100).round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ],
        ),
      );

  Widget _indentedGroup(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 2,
                margin:
                    const EdgeInsets.only(left: 6, right: 14, top: 2, bottom: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(child: Column(children: children)),
            ],
          ),
        ),
      );

  Widget _soundPickerRow(String label, String file, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 15)),
              Row(
                children: [
                  Text(
                    file.startsWith('/') ? file.split('/').last : file,
                    style: const TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Colors.white12, size: 18),
                ],
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return Column(
      children: [
        _toggleRow('Lautstärke erhöhen', s.volumeBoostEnabled, (v) {
          s.volumeBoostEnabled = v;
          onChanged();
        }),
        if (s.volumeBoostEnabled) _volumeSliderRow(context),
        _toggleRow('Warntöne (letzte 5s)', s.warningTonesEnabled, (v) {
          s.warningTonesEnabled = v;
          onChanged();
        }),
        if (s.warningTonesEnabled)
          _indentedGroup([
            _soundPickerRow(
              'Countdown-Sound',
              s.countdownSoundFile,
              () => _openSoundPicker(
                context,
                'Countdown-Sound',
                s.countdownSoundFile,
                (v) => s.countdownSoundFile = v,
              ),
            ),
          ]),
        _toggleRow('Wecker-Signal', s.alarmEnabled, (v) {
          s.alarmEnabled = v;
          onChanged();
        }),
        if (s.alarmEnabled)
          _indentedGroup([
            _soundPickerRow(
              'Sound',
              s.alarmSoundFile,
              () => _openSoundPicker(
                context,
                'Wecker-Signal',
                s.alarmSoundFile,
                (v) => s.alarmSoundFile = v,
              ),
            ),
          ]),
        _toggleRow('Vibration', s.vibrationEnabled, (v) {
          s.vibrationEnabled = v;
          onChanged();
        }),
      ],
    );
  }
}
