import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'settings.dart';

class ConfigScreen extends StatefulWidget {
  final AppSettings settings;
  final void Function(AppSettings) onSave;
  final VoidCallback? onPlanChanged;
  final int visitCount;
  const ConfigScreen({super.key, required this.settings, required this.onSave, this.onPlanChanged, this.visitCount = 0});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen>
    with SingleTickerProviderStateMixin {
  late AppSettings _s;
  late TabController _tabController;
  int? _selectedMinuteRow;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
    _tabController = TabController(length: 2, vsync: this);
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
    }
  }

  void _save() {
    widget.onSave(_s);
  }

  void _setPlan(VoidCallback fn) {
    setState(fn);
    widget.onPlanChanged?.call();
  }

  int get _minuteTotal => _s.customPlan.fold(0, (sum, v) => sum + v);
  int get _totalDurationSeconds =>
      _s.customDurations.fold(0, (sum, v) => sum + v);

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  // ── Sound-Auswahl ────────────────────────────────────────────────────────────

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
    String label,
    String currentFile,
    ValueChanged<String> onSelected,
  ) async {
    final imported = await _getImportedSounds();
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SoundPickerDialog(
        title: label,
        currentFile: currentFile,
        builtinSounds: const ['bell.wav', 'tick.wav', 'alarm.wav', 'alarm_low.wav'],
        importedSounds: imported,
      ),
    );

    if (result != null) {
      setState(() => onSelected(result));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
              _planModeSelector(),
              if (_s.planMode == PlanMode.phaseBased) ...[
                _equipmentSelector(),
                _phaseBasedEditor(),
              ] else
                _minuteExactEditor(),
            ],
          ),
          // ── Tab 2: Feedback & Sound ───────────────────────────────────────
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              _toggleRow('Lautstärke erhöhen', _s.volumeBoostEnabled,
                  (v) => setState(() => _s.volumeBoostEnabled = v)),
              if (_s.volumeBoostEnabled) _volumeSliderRow(),
              _toggleRow('Warntöne (letzte 5s)', _s.warningTonesEnabled,
                  (v) => setState(() => _s.warningTonesEnabled = v)),
              if (_s.warningTonesEnabled)
                _indentedGroup([
                  _soundPickerRow('Countdown-Sound', _s.countdownSoundFile,
                      () => _openSoundPicker('Countdown-Sound',
                          _s.countdownSoundFile,
                          (v) => _s.countdownSoundFile = v)),
                ]),
              _toggleRow('Wecker-Signal', _s.alarmEnabled,
                  (v) => setState(() => _s.alarmEnabled = v)),
              if (_s.alarmEnabled)
                _indentedGroup([
                  _soundPickerRow('Sound', _s.alarmSoundFile,
                      () => _openSoundPicker('Wecker-Signal', _s.alarmSoundFile,
                          (v) => _s.alarmSoundFile = v)),
                ]),
              _toggleRow('Vibration', _s.vibrationEnabled,
                  (v) => setState(() => _s.vibrationEnabled = v)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _toggleRow(
          String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 15)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF4CAF50),
            ),
          ],
        ),
      );

  Widget _volumeSliderRow() => Padding(
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
                  value: _s.volumeBoostLevel,
                  min: 0,
                  max: 1,
                  onChanged: (v) => setState(() {
                    _s.volumeBoostLevel = v;
                    if (v <= 0) _s.volumeBoostEnabled = false;
                  }),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${(_s.volumeBoostLevel * 100).round()}%',
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
                margin: const EdgeInsets.only(left: 6, right: 14, top: 2, bottom: 2),
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

  Widget _soundPickerRow(
          String label, String file, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 15)),
              Row(
                children: [
                  Text(
                    file.startsWith('/')
                        ? file.split('/').last
                        : file,
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right,
                      color: Colors.white12, size: 18),
                ],
              ),
            ],
          ),
        ),
      );

  // ── Sportgerät-Auswahl ───────────────────────────────────────────────────────

  Widget _equipmentSelector() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
                child: _equipmentBtn('Kettlebell', Equipment.kettlebell,
                    'assets/icon/kettlebell.png')),
            const SizedBox(width: 8),
            Expanded(
                child: _equipmentBtn('Steel Mace', Equipment.steelmace,
                    'assets/icon/steelmace.png')),
          ],
        ),
      );

  Widget _equipmentBtn(String label, Equipment eq, String iconPath) {
    final active = _s.equipment == eq;
    return GestureDetector(
      onTap: () => _setPlan(() => _s.equipment = eq),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E1E1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF333333)
                : const Color(0xFF1A1A1A),
          ),
        ),
        child: Column(
          children: [
            Image.asset(
              iconPath,
              width: 32,
              height: 32,
              color: active ? const Color(0xFFFF6B00) : Colors.white12,
            ),
            const SizedBox(height: 6),
            Text(
              '${active ? "●" : "○"} $label',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.5,
                color: active ? Colors.white54 : Colors.white12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Plan-Modus ───────────────────────────────────────────────────────────────

  Widget _planModeSelector() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Expanded(
                child:
                    _radioBtn('Phasen-basiert', PlanMode.phaseBased)),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _radioBtn('Minuten-genau', PlanMode.minuteExact)),
          ],
        ),
      );

  Widget _radioBtn(String label, PlanMode mode) {
    final active = _s.planMode == mode;
    return GestureDetector(
      onTap: () => _setPlan(() => _s.planMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E1E1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF333333)
                : const Color(0xFF1A1A1A),
          ),
        ),
        child: Center(
          child: Text(
            '${active ? "●" : "○"} $label',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              color: active ? Colors.white54 : Colors.white12,
            ),
          ),
        ),
      ),
    );
  }

  // ── Phasen-basiert ───────────────────────────────────────────────────────────

  static const _phaseNames = [
    'Warm Up',
    'Aufbau',
    'Peak',
    'Abbau',
    'Cool Down'
  ];
  static const _phaseColors = [
    Color(0xFF4CAF50),
    Color(0xFFFF6B00),
    Color(0xFFFF0000),
    Color(0xFFFF6B00),
    Color(0xFF4CAF50),
  ];

  int _phaseReps(int i) {
    if (i == 0) return _s.warmUpReps;
    if (i == 2) return _s.peakReps;
    return _s.coolDownReps;
  }

  Widget _phaseBasedEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 88,
                child: Center(
                  child: Text('Dauer (s)',
                      style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: Colors.white12)),
                ),
              ),
              SizedBox(
                width: 88,
                child: Center(
                  child: Text('Reps',
                      style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: Colors.white12)),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1A1A1A), height: 1),
        for (int i = 0; i < 5; i++) _phaseTableRow(i),
        const SizedBox(height: 14),
        const Text(
          'Aufbau & Abbau Reps werden automatisch interpoliert',
          style: TextStyle(
              fontSize: 11, color: Colors.white12, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _phaseTableRow(int i) {
    final color = _phaseColors[i];
    final name = _phaseNames[i];
    final hasReps = i == 0 || i == 2 || i == 4;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF111111))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(name,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.75),
                        fontSize: 12)),
              ],
            ),
          ),
          _inlineStepRow(
            _s.phaseDurations[i],
            min: 30,
            step: 5,
            onChanged: (v) => _setPlan(() => _s.phaseDurations[i] = v),
          ),
          const SizedBox(width: 8),
          if (hasReps)
            _inlineStepRow(
              _phaseReps(i),
              min: 1,
              onChanged: (v) => _setPlan(() {
                if (i == 0) _s.warmUpReps = v;
                if (i == 2) _s.peakReps = v;
                if (i == 4) _s.coolDownReps = v;
              }),
            )
          else
            const SizedBox(
              width: 88,
              child: Center(
                child: Text('auto',
                    style:
                        TextStyle(fontSize: 10, color: Colors.white12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inlineStepRow(
    int value, {
    required int min,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 88,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _smallStepBtn(Icons.remove,
              value > min
                  ? () => onChanged((value - step).clamp(min, 9999))
                  : null),
          SizedBox(
            width: 36,
            child: Center(
              child: Text('$value',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54)),
            ),
          ),
          _smallStepBtn(Icons.add, () => onChanged(value + step)),
        ],
      ),
    );
  }

  Widget _smallStepBtn(IconData icon, VoidCallback? onTap) =>
      _stepButton(icon, onTap);

  // ── Minuten-genau ────────────────────────────────────────────────────────────

  Widget _minuteExactEditor() => Column(
        children: [
          ListView.builder(
            key: const PageStorageKey<String>('minuteExactList'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemExtent: 42,
            itemCount: 30,
            itemBuilder: (_, i) => _MinuteRow(
              key: ValueKey(i),
              index: i,
              settings: _s,
              isSelected: _selectedMinuteRow == i,
              onSelect: () => setState(() {
                _selectedMinuteRow = _selectedMinuteRow == i ? null : i;
              }),
              onChanged: () {
                setState(() {});
                widget.onPlanChanged?.call();
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GESAMT',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 3,
                        color: Colors.white24)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$_minuteTotal Reps',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white38)),
                    Text(_formatDuration(_totalDurationSeconds),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white24)),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

}

Widget _stepButton(IconData icon, VoidCallback? onTap, {double size = 26}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(size / 4),
        ),
        child: Icon(icon,
            size: size / 2,
            color: onTap != null ? Colors.white38 : Colors.white12),
      ),
    );

// ── Minuten-genau Zeile ──────────────────────────────────────────────────────

class _MinuteRow extends StatefulWidget {
  final int index;
  final AppSettings settings;
  final VoidCallback onChanged;
  final bool isSelected;
  final VoidCallback onSelect;

  const _MinuteRow({
    super.key,
    required this.index,
    required this.settings,
    required this.onChanged,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<_MinuteRow> createState() => _MinuteRowState();
}

class _MinuteRowState extends State<_MinuteRow> {
  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  Widget _smallStepBtn(IconData icon, VoidCallback? onTap) =>
      _stepButton(icon, onTap, size: 32);

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final i = widget.index;
    final eq = Equipment.values[s.customEquipment[i]];
    final iconPath = eq == Equipment.kettlebell
        ? 'assets/icon/kettlebell.png'
        : 'assets/icon/steelmace.png';
    final color = phaseColorForMinute(i);

    return GestureDetector(
      onTap: widget.onSelect,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(
              width: 42,
              child: Text(
                'Min ${i + 1}',
                style: TextStyle(
                    fontSize: 11,
                    color: widget.isSelected ? Colors.white38 : Colors.white24,
                    letterSpacing: 1),
              ),
            ),
            const Spacer(),
            if (widget.isSelected) ...[
              SizedBox(
                width: 26,
                height: 26,
                child: PopupMenuButton<int>(
                  initialValue: s.customEquipment[i],
                  onSelected: (v) => _update(() => s.customEquipment[i] = v),
                  color: const Color(0xFF1E1E1E),
                  padding: EdgeInsets.zero,
                  tooltip: '',
                  child: Center(
                      child: Image.asset(iconPath,
                          width: 16, height: 16, color: Colors.white54)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 0,
                      child: Row(children: [
                        Image.asset('assets/icon/kettlebell.png',
                            width: 18, height: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        const Text('Kettlebell',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: Row(children: [
                        Image.asset('assets/icon/steelmace.png',
                            width: 18, height: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        const Text('Steel Mace',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('R',
                  style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _smallStepBtn(Icons.remove,
                  s.customPlan[i] > 1 ? () => _update(() => s.customPlan[i]--) : null),
              SizedBox(
                width: 30,
                child: Center(
                  child: Text('${s.customPlan[i]}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54)),
                ),
              ),
              _smallStepBtn(Icons.add, () => _update(() => s.customPlan[i]++)),
              const SizedBox(width: 8),
              const Text('s',
                  style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _smallStepBtn(Icons.remove,
                  s.customDurations[i] > 30
                      ? () => _update(() =>
                          s.customDurations[i] = (s.customDurations[i] - 5).clamp(30, 9999))
                      : null),
              SizedBox(
                width: 34,
                child: Center(
                  child: Text('${s.customDurations[i]}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54)),
                ),
              ),
              _smallStepBtn(
                  Icons.add, () => _update(() => s.customDurations[i] += 5)),
            ] else ...[
              Image.asset(iconPath, width: 14, height: 14, color: Colors.white24),
              const SizedBox(width: 8),
              Text('${s.customPlan[i]}R',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
              const SizedBox(width: 6),
              Text('${s.customDurations[i]}s',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sound-Auswahl-Dialog ─────────────────────────────────────────────────────

class _SoundPickerDialog extends StatefulWidget {
  final String title;
  final String currentFile;
  final List<String> builtinSounds;
  final List<String> importedSounds;

  const _SoundPickerDialog({
    required this.title,
    required this.currentFile,
    required this.builtinSounds,
    required this.importedSounds,
  });

  @override
  State<_SoundPickerDialog> createState() => _SoundPickerDialogState();
}

class _SoundPickerDialogState extends State<_SoundPickerDialog> {
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
      final name =
          lastDot >= 0 ? filename.substring(0, lastDot) : filename;
      final ext = lastDot >= 0 ? filename.substring(lastDot) : '';
      int counter = 1;
      while (File('${soundsDir.path}/${name}_$counter$ext')
          .existsSync()) {
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
                        fontSize: 9,
                        letterSpacing: 3,
                        color: Colors.white24)),
              ),
              ...widget.builtinSounds
                  .map((f) => _soundTile(f, isAsset: true)),
            ],
            if (_imported.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('Importiert',
                    style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 3,
                        color: Colors.white24)),
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
              color: isSelected
                  ? const Color(0xFFFF6B00)
                  : Colors.white12,
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
