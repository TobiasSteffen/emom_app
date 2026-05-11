import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models/settings.dart';
import 'config_screen.dart';
import 'core/models/workout_history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  final settings = await AppSettings.load();
  runApp(ProviderScope(child: KettlebellApp(settings: settings)));
}

class KettlebellApp extends StatelessWidget {
  final AppSettings settings;
  const KettlebellApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kettlebell EMOM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B00),
          secondary: Color(0xFFFF6B00),
        ),
      ),
      home: WorkoutScreen(settings: settings),
    );
  }
}

class WorkoutScreen extends StatefulWidget {
  final AppSettings settings;
  const WorkoutScreen({super.key, required this.settings});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with TickerProviderStateMixin {
  late AppSettings _settings;
  late List<int> _plan;
  late List<int> _durations;

  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  StreamSubscription? _alarmLoopSub;
  bool? _hasVibrator;

  Timer? _timer;
  int _currentMinute = 0;
  int _secondsLeft = 60;
  bool _isRunning = false;
  bool _isFinished = false;
  bool _waitingForConfirmation = false;
  int _totalRepsDone = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late PageController _pageController;
  bool _configWasOpened = false;
  bool _wasRunningBeforeConfig = false;
  String _planKeySnapshot = '';
  int _configVisitCount = 0;

  final List<IntervalRecord> _completedIntervals = [];
  DateTime? _workoutStartTime;

  int get totalMinutes => _plan.length;
  int get currentReps => _plan[_currentMinute];
  int get currentDuration => _durations[_currentMinute];
  int get totalReps => _plan.fold(0, (a, b) => a + b);

  Color get phaseColor => phaseColorForMinute(_currentMinute);

  Equipment _equipmentForMinute(int minute) {
    if (_settings.planMode == PlanMode.minuteExact) {
      return Equipment.values[_settings.customEquipment[minute]];
    }
    return _settings.equipment;
  }

  String _exerciseLabelForMinute(int minute) =>
      _equipmentForMinute(minute) == Equipment.kettlebell ? 'Swings' : '360s';

  String get exerciseLabel => _exerciseLabelForMinute(_currentMinute);

  String get iconPath =>
      _equipmentForMinute(_currentMinute) == Equipment.kettlebell
          ? 'assets/icon/kettlebell.png'
          : 'assets/icon/steelmace.png';

  String get phaseLabel {
    if (_currentMinute < 5) return 'Warm Up';
    if (_currentMinute < 15) return 'Aufbau ↑';
    if (_currentMinute < 20) return 'Peak';
    if (_currentMinute < 25) return 'Abbau ↓';
    return 'Cool Down';
  }

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _plan = _settings.buildPlan();
    _durations = _settings.buildDurations();
    _secondsLeft = _durations[0];
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pageController = PageController();
    Vibration.hasVibrator().then((v) => _hasVibrator = v);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alarmLoopSub?.cancel();
    _pulseController.dispose();
    _pageController.dispose();
    _tickPlayer.dispose();
    _alarmPlayer.dispose();
    super.dispose();
  }

  void _openConfig() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  void _startStop() {
    if (_isFinished) {
      _reset();
      return;
    }
    if (_waitingForConfirmation) {
      _confirmInterval();
      return;
    }
    _isRunning ? _pause() : _start();
  }

  void _start() {
    _workoutStartTime ??= DateTime.now();
    setState(() => _isRunning = true);
    WakelockPlus.enable();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _pause() {
    _timer?.cancel();
    WakelockPlus.disable();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    _alarmLoopSub?.cancel();
    _alarmLoopSub = null;
    _alarmPlayer.stop();
    final newPlan = _settings.buildPlan();
    final newDurations = _settings.buildDurations();
    _completedIntervals.clear();
    _workoutStartTime = null;
    setState(() {
      _plan = newPlan;
      _durations = newDurations;
      _currentMinute = 0;
      _secondsLeft = newDurations[0];
      _isRunning = false;
      _isFinished = false;
      _waitingForConfirmation = false;
      _totalRepsDone = 0;
    });
  }

  void _tick(Timer timer) {
    setState(() {
      _secondsLeft--;
      if (_secondsLeft <= 0) {
        _onMinuteComplete();
      } else if (_secondsLeft <= 5 && _settings.warningTonesEnabled) {
        if (_secondsLeft == 5) _raiseVolume();
        _playTickSound();
      }
    });
  }

  Future<void> _raiseVolume() async {
    if (!_settings.volumeBoostEnabled || _settings.volumeBoostLevel <= 0) return;
    try {
      final current = await VolumeController().getVolume();
      if (current < _settings.volumeBoostLevel) {
        VolumeController().setVolume(_settings.volumeBoostLevel, showSystemUI: false);
      }
    } catch (_) {}
  }

  void _onMinuteComplete() {
    _timer?.cancel();
    _totalRepsDone += currentReps;

    _completedIntervals.add(IntervalRecord(
      reps: currentReps,
      durationSeconds: currentDuration,
      equipment: _equipmentForMinute(_currentMinute).index,
    ));

    if (_currentMinute >= totalMinutes - 1) {
      _isFinished = true;
      _isRunning = false;
      WakelockPlus.disable();
      _vibrate(600);
      _saveHistoryIfEligible();
      return;
    }

    _isRunning = false;
    _waitingForConfirmation = true;
    _playAlarm();
  }

  Future<void> _saveHistoryIfEligible() async {
    if (_completedIntervals.length < 2 || _workoutStartTime == null) return;
    final record = WorkoutRecord(
      timestamp: _workoutStartTime!.millisecondsSinceEpoch,
      planMode: _settings.planMode.index,
      intervals: List.from(_completedIntervals),
    );
    await WorkoutHistory.addOrUpdateRecord(record);
  }

  void _confirmInterval() {
    _alarmLoopSub?.cancel();
    _alarmLoopSub = null;
    _alarmPlayer.stop();
    setState(() {
      _waitingForConfirmation = false;
      _currentMinute++;
      _secondsLeft = _durations[_currentMinute];
    });
    _pulseController.forward().then((_) => _pulseController.reverse());
    _vibrate(400);
    _saveHistoryIfEligible();
    _start();
  }

  Source _soundSource(String f) =>
      f.startsWith('/') ? DeviceFileSource(f) : AssetSource('sounds/$f');

  Future<void> _vibrate(int durationMs) async {
    if (!_settings.vibrationEnabled || _hasVibrator != true) return;
    Vibration.vibrate(duration: durationMs);
  }

  Future<void> _playTickSound() async {
    try {
      await _tickPlayer.play(_soundSource(_settings.countdownSoundFile));
    } catch (_) {}
  }

  Future<void> _playAlarm() async {
    if (_settings.vibrationEnabled && _hasVibrator == true) {
      Vibration.vibrate(duration: 800);
    }

    if (!_settings.alarmEnabled) return;

    Future<void> playOnce() async {
      try {
        final f = _settings.alarmSoundFile;
        await _alarmPlayer.setReleaseMode(ReleaseMode.release);
        await _alarmPlayer.play(_soundSource(f));
      } catch (_) {
        SystemSound.play(SystemSoundType.click);
      }
    }

    await _alarmLoopSub?.cancel();
    _alarmLoopSub = _alarmPlayer.onPlayerComplete.listen((_) async {
      if (!_waitingForConfirmation || !mounted) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (_waitingForConfirmation && mounted) await playOnce();
    });

    await playOnce();
  }

  String _planKey() => [
        _settings.planMode.index,
        _settings.equipment.index,
        _settings.warmUpReps,
        _settings.peakReps,
        _settings.coolDownReps,
        ..._settings.phaseDurations,
        ..._settings.customPlan,
        ..._settings.customDurations,
        ..._settings.customEquipment,
      ].join(',');

  Future<void> _showResetConfirmDialog() async {
    final doReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Training zurücksetzen?',
          style: TextStyle(
              color: Colors.white54, fontSize: 15, letterSpacing: 1),
        ),
        content: const Text(
          'Die Einstellungen wurden geändert. Das laufende Training zurücksetzen?',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Weiter',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zurücksetzen',
                style: TextStyle(color: Color(0xFFFF6B00))),
          ),
        ],
      ),
    ) ?? false;

    if (doReset) {
      _reset();
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat("EE, d. MMMM yyyy  HH:mm", 'de').format(dt);
  }

Future<void> _showHistory() async {
    final records = await WorkoutHistory.load();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'VERLAUF',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text(
                        'Noch keine Trainings gespeichert',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: records.length,
                      itemBuilder: (ctx, i) => GestureDetector(
                        onTap: () => _showHistoryDetail(ctx, records[i]),
                        child: _buildHistoryCard(records[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDetail(BuildContext sheetCtx, WorkoutRecord record) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final kbReps = record.kettlebellReps;
    final smReps = record.steelMaceReps;
    final totalSecs = record.totalDurationSeconds;
    final durStr =
        '${totalSecs ~/ 60}m ${(totalSecs % 60).toString().padLeft(2, '0')}s';
    final repBreakdown = kbReps > 0 && smReps > 0
        ? '$kbReps× KB  /  $smReps× SM'
        : '${record.totalReps} Reps';

    showModalBottomSheet(
      context: sheetCtx,
      backgroundColor: const Color(0xFF0D0D0D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateTime(dt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${record.intervals.length}/30 Intervalle',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$repBreakdown  ·  $durStr',
                        style: const TextStyle(
                            color: Color(0xFFFF6B00), fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: record.intervals.length,
                itemBuilder: (ctx, i) {
                  final iv = record.intervals[i];
                  final color = phaseColorForMinute(i);
                  final isKb = iv.equipment == 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 52,
                          child: Text(
                            'Min ${i + 1}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ),
                        Image.asset(
                          isKb
                              ? 'assets/icon/kettlebell.png'
                              : 'assets/icon/steelmace.png',
                          width: 14,
                          height: 14,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${iv.reps} Reps',
                          style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          '${iv.durationSeconds}s',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 12),
                        ),
                      ],
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

  Widget _buildHistoryCard(WorkoutRecord record) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final dateStr = _formatDateTime(dt);
    final planModeStr =
        record.planMode == 0 ? 'Phasenbasiert' : 'Minuten-genau';
    final completed = record.intervals.length;
    final kbReps = record.kettlebellReps;
    final smReps = record.steelMaceReps;
    final equipStr = kbReps > 0 && smReps > 0
        ? 'Kettlebell + Steel Mace'
        : kbReps > 0
            ? 'Kettlebell'
            : 'Steel Mace';
    final totalSecs = record.totalDurationSeconds;
    final durStr =
        '${totalSecs ~/ 60}m ${(totalSecs % 60).toString().padLeft(2, '0')}s';
    final repBreakdown =
        kbReps > 0 && smReps > 0 ? '  ·  $kbReps× KB  /  $smReps× SM' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            '$equipStr · $planModeStr · $completed/30 Intervalle',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${record.totalReps} Reps  ·  $durStr$repBreakdown',
            style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
      dragStartBehavior: DragStartBehavior.down,
      onPageChanged: (page) {
        if (page == 1) {
          setState(() {
            _configWasOpened = true;
            _wasRunningBeforeConfig = _isRunning || _waitingForConfirmation;
            _planKeySnapshot = _planKey();
            _configVisitCount++;
          });
          if (_isRunning) _pause();
        }
        if (page == 0 && _configWasOpened) {
          _configWasOpened = false;
          _settings.save();
          final changed = _planKey() != _planKeySnapshot;
          if (!changed) {
            if (_wasRunningBeforeConfig && !_isFinished) _start();
          } else {
            final wasActive = _wasRunningBeforeConfig || _currentMinute > 0;
            if (wasActive) {
              _showResetConfirmDialog();
            } else {
              _reset();
            }
          }
        }
      },
      children: [
        Scaffold(
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _isFinished ? _buildFinishedScreen() : _buildWorkoutScreen(),
                if (_waitingForConfirmation) _buildConfirmationOverlay(),
              ],
            ),
          ),
        ),
        ConfigScreen(
          visitCount: _configVisitCount,
          settings: _settings,
          onSave: (settings) {
            setState(() => _settings = settings);
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          onPlanChanged: () {
            if (!_isRunning && !_waitingForConfirmation) {
              final newPlan = _settings.buildPlan();
              final newDurations = _settings.buildDurations();
              setState(() {
                _plan = newPlan;
                _durations = newDurations;
                _secondsLeft = newDurations[_currentMinute];
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildWorkoutScreen() {
    final progress = _currentMinute / totalMinutes;
    final secondProgress = (currentDuration - _secondsLeft) / currentDuration;
    final isWarning = _secondsLeft <= 5 && _secondsLeft > 0 && _isRunning;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EMOM 30',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 3,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: phaseColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      phaseLabel,
                      style: TextStyle(
                          color: phaseColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _showHistory,
                    child: const Icon(Icons.history,
                        color: Colors.white24, size: 22),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _openConfig,
                    child: const Icon(Icons.settings,
                        color: Colors.white24, size: 22),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Minute ${_currentMinute + 1} / $totalMinutes',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13),
                  ),
                  Text(
                    '$_totalRepsDone / $totalReps $exerciseLabel',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),

          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                    color: phaseColor.withValues(alpha: 0.3), width: 2),
              ),
              child: Column(
                children: [
                  Image.asset(
                    iconPath,
                    width: 48,
                    height: 48,
                    color: phaseColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'REPS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentReps',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: phaseColor,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    exerciseLabel,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          Column(
            children: [
              Text(
                _formatTime(_secondsLeft),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w300,
                  color: isWarning ? const Color(0xFFFF4444) : Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: secondProgress,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isWarning ? const Color(0xFFFF4444) : Colors.white24,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),

          if (_currentMinute < totalMinutes - 1) ...[
            const SizedBox(height: 16),
            Text(
              'Nächste Minute: ${_plan[_currentMinute + 1]} Reps',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
            ),
          ],

          const Spacer(),

          Row(
            children: [
              IconButton(
                onPressed: _reset,
                icon: const Icon(Icons.refresh,
                    color: Colors.white38, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: _startStop,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: phaseColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: phaseColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationOverlay() {
    final nextMinute = _currentMinute + 1;
    final nextReps = _plan[nextMinute];
    final nextColor = phaseColorForMinute(nextMinute);
    final nextLabel = _exerciseLabelForMinute(nextMinute);

    return GestureDetector(
      onTap: _confirmInterval,
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'INTERVALL BEENDET',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 11,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '$nextReps',
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  color: nextColor,
                  height: 1,
                ),
              ),
              Text(
                nextLabel,
                style: const TextStyle(color: Colors.white38, fontSize: 16),
              ),
              Text(
                'Minute ${nextMinute + 1}',
                style: const TextStyle(color: Colors.white24, fontSize: 13),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: nextColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: nextColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'WEITER',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'oder irgendwo tippen',
                style: TextStyle(color: Colors.white12, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            const Text(
              'WORKOUT DONE!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF6B00),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$totalReps $exerciseLabel',
              style: TextStyle(
                  fontSize: 20, color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: _reset,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Nochmal',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
