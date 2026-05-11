import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/models/settings.dart';
import 'core/providers/settings_provider.dart';
import 'config_screen.dart';
import 'features/history/history_sheet.dart';
import 'features/workout/workout_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  runApp(const ProviderScope(child: KettlebellApp()));
}

class KettlebellApp extends StatelessWidget {
  const KettlebellApp({super.key});

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
      home: const WorkoutScreen(),
    );
  }
}

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late PageController _pageController;
  bool _configWasOpened = false;
  bool _wasRunningBeforeConfig = false;
  String _planKeySnapshot = '';
  int _configVisitCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _openConfig() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  void _startStop(WorkoutState state) {
    final notifier = ref.read(workoutNotifierProvider.notifier);
    if (state.isFinished) {
      notifier.reset();
      return;
    }
    if (state.waitingForConfirmation) {
      _pulseController.forward().then((_) => _pulseController.reverse());
      notifier.confirmInterval();
      return;
    }
    state.isRunning ? notifier.pause() : notifier.start();
  }

  Future<void> _showResetConfirmDialog(AppSettings newSettings) async {
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
    if (doReset) ref.read(workoutNotifierProvider.notifier).reset(newSettings);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const HistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutAsync = ref.watch(workoutNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;

    if (workoutAsync.isLoading || settings == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
      );
    }
    if (workoutAsync.hasError) {
      return Scaffold(body: Center(child: Text('${workoutAsync.error}')));
    }

    return _buildPageView(workoutAsync.requireValue, settings);
  }

  Widget _buildPageView(WorkoutState state, AppSettings settings) {
    final notifier = ref.read(workoutNotifierProvider.notifier);

    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
      dragStartBehavior: DragStartBehavior.down,
      onPageChanged: (page) {
        if (page == 1) {
          setState(() {
            _configWasOpened = true;
            _wasRunningBeforeConfig = state.isRunning || state.waitingForConfirmation;
            _planKeySnapshot = ref.read(settingsNotifierProvider).requireValue.planKey;
            _configVisitCount++;
          });
          if (state.isRunning) notifier.pause();
        }
        if (page == 0 && _configWasOpened) {
          _configWasOpened = false;
          final newSettings = ref.read(settingsNotifierProvider).requireValue;
          ref.read(settingsNotifierProvider.notifier).save();
          final changed = newSettings.planKey != _planKeySnapshot;
          if (!changed) {
            notifier.updateSettings(newSettings);
            if (_wasRunningBeforeConfig && !state.isFinished) notifier.start();
          } else {
            final wasActive = _wasRunningBeforeConfig || state.currentMinute > 0;
            if (wasActive) {
              _showResetConfirmDialog(newSettings);
            } else {
              notifier.reset(newSettings);
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
                state.isFinished
                    ? _buildFinishedScreen(state)
                    : _buildWorkoutScreen(state, settings),
                if (state.waitingForConfirmation) _buildConfirmationOverlay(state),
              ],
            ),
          ),
        ),
        ConfigScreen(visitCount: _configVisitCount),
      ],
    );
  }

  Widget _buildWorkoutScreen(WorkoutState state, AppSettings settings) {
    final phaseColor = phaseColorForMinute(state.currentMinute);
    final notifier = ref.read(workoutNotifierProvider.notifier);
    final exerciseLabel = notifier.exerciseLabelForMinute(state.currentMinute);
    final iconPath = notifier.equipmentForMinute(state.currentMinute) == Equipment.kettlebell
        ? 'assets/icon/kettlebell.png'
        : 'assets/icon/steelmace.png';
    final isWarning = state.secondsLeft <= 5 && state.secondsLeft > 0 && state.isRunning;
    final progress = state.currentMinute / state.totalMinutes;
    final secondProgress = (state.currentDuration - state.secondsLeft) / state.currentDuration;

    String phaseLabel;
    if (state.currentMinute < 5) {
      phaseLabel = 'Warm Up';
    } else if (state.currentMinute < 15) {
      phaseLabel = 'Aufbau ↑';
    } else if (state.currentMinute < 20) {
      phaseLabel = 'Peak';
    } else if (state.currentMinute < 25) {
      phaseLabel = 'Abbau ↓';
    } else {
      phaseLabel = 'Cool Down';
    }

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
                    'Minute ${state.currentMinute + 1} / ${state.totalMinutes}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13),
                  ),
                  Text(
                    '${state.totalRepsDone} / ${state.totalReps} $exerciseLabel',
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
                    '${state.currentReps}',
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
                _formatTime(state.secondsLeft),
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

          if (state.currentMinute < state.totalMinutes - 1) ...[
            const SizedBox(height: 16),
            Text(
              'Nächste Minute: ${state.plan[state.currentMinute + 1]} Reps',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
            ),
          ],

          const Spacer(),

          Row(
            children: [
              IconButton(
                onPressed: () => ref.read(workoutNotifierProvider.notifier).reset(),
                icon: const Icon(Icons.refresh,
                    color: Colors.white38, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _startStop(state),
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
                        state.isRunning
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

  Widget _buildConfirmationOverlay(WorkoutState state) {
    final notifier = ref.read(workoutNotifierProvider.notifier);
    final nextMinute = state.currentMinute + 1;
    final nextReps = state.plan[nextMinute];
    final nextColor = phaseColorForMinute(nextMinute);
    final nextLabel = notifier.exerciseLabelForMinute(nextMinute);

    return GestureDetector(
      onTap: () {
        _pulseController.forward().then((_) => _pulseController.reverse());
        notifier.confirmInterval();
      },
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

  Widget _buildFinishedScreen(WorkoutState state) {
    final notifier = ref.read(workoutNotifierProvider.notifier);
    final exerciseLabel = notifier.exerciseLabelForMinute(state.currentMinute);

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
              '${state.totalReps} $exerciseLabel',
              style: TextStyle(
                  fontSize: 20, color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: () => notifier.reset(),
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
