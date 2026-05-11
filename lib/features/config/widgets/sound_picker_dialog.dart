import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SoundPickerDialog extends StatefulWidget {
  final String title;
  final String currentFile;
  final List<String> builtinSounds;
  final List<String> importedSounds;

  const SoundPickerDialog({
    super.key,
    required this.title,
    required this.currentFile,
    required this.builtinSounds,
    required this.importedSounds,
  });

  @override
  State<SoundPickerDialog> createState() => _SoundPickerDialogState();
}

class _SoundPickerDialogState extends State<SoundPickerDialog> {
  late String _selected;
  late List<String> _imported;
  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _selected = widget.currentFile;
    _imported = List.from(widget.importedSounds);
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Source _soundSource(String f) =>
      f.startsWith('/') ? DeviceFileSource(f) : AssetSource('sounds/$f');

  Future<void> _preview(String file) async {
    await _previewPlayer.stop();
    try {
      await _previewPlayer.play(_soundSource(file));
    } catch (_) {}
  }

  Future<void> _importFromFilesystem() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final sourcePath = result.files.first.path;
    if (sourcePath == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${docsDir.path}/sounds');
    await soundsDir.create(recursive: true);

    final filename = result.files.first.name;
    var destPath = '${soundsDir.path}/$filename';

    if (File(destPath).existsSync()) {
      final lastDot = filename.lastIndexOf('.');
      final name = lastDot >= 0 ? filename.substring(0, lastDot) : filename;
      final ext = lastDot >= 0 ? filename.substring(lastDot) : '';
      int counter = 1;
      while (File('${soundsDir.path}/${name}_$counter$ext').existsSync()) {
        counter++;
      }
      destPath = '${soundsDir.path}/${name}_$counter$ext';
    }

    await File(sourcePath).copy(destPath);

    setState(() {
      _imported.add(destPath);
      _selected = destPath;
    });
  }

  String _displayName(String file) =>
      file.startsWith('/') ? file.split('/').last : file;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(
        widget.title,
        style: const TextStyle(
            color: Colors.white54, fontSize: 15, letterSpacing: 1),
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.builtinSounds.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text('Integriert',
                    style: const TextStyle(
                        fontSize: 9, letterSpacing: 3, color: Colors.white24)),
              ),
              ...widget.builtinSounds.map((f) => _soundTile(f, isAsset: true)),
            ],
            if (_imported.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('Importiert',
                    style: const TextStyle(
                        fontSize: 9, letterSpacing: 3, color: Colors.white24)),
              ),
              ..._imported.map((f) => _soundTile(f, isAsset: false)),
            ],
            const Divider(color: Color(0xFF222222), height: 1),
            TextButton.icon(
              onPressed: _importFromFilesystem,
              icon: const Icon(Icons.folder_open,
                  color: Colors.white38, size: 18),
              label: const Text(
                'Aus Dateisystem wählen',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen',
              style: TextStyle(color: Colors.white24)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Übernehmen',
              style: TextStyle(color: Color(0xFFFF6B00))),
        ),
      ],
    );
  }

  Widget _soundTile(String file, {required bool isAsset}) {
    final isSelected = _selected == file;
    return InkWell(
      onTap: () => setState(() => _selected = file),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFFFF6B00) : Colors.white12,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _displayName(file),
                style: TextStyle(
                  color: isSelected ? Colors.white54 : Colors.white24,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white24, size: 20),
              onPressed: () => _preview(file),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}
