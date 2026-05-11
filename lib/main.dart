import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/models/settings.dart';
import 'core/providers/settings_provider.dart';
import 'config_screen.dart';
import 'features/history/history_sheet.dart';
import 'features/workout/workout_notifier.dart';
import 'features/workout/widgets/workout_header.dart';
import 'features/workout/widgets/overall_progress.dart';
import 'features/workout/widgets/reps_card.dart';
import 'features/workout/widgets/timer_display.dart';
import 'features/workout/widgets/next_minute_preview.dart';
import 'features/workout/widgets/confirmation_overlay.dart';
import 'features/workout/widgets/finished_screen.dart';

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
    final notifier = ref.read(workoutNotifierProvider.notifier);
    final phaseColor = phaseColorForMinute(state.currentMinute);
    final exerciseLabel = notifier.exerciseLabelForMinute(state.currentMinute);
    final iconPath = notifier.equipmentForMinute(state.currentMinute) == Equipment.kettlebell
        ? 'assets/icon/kettlebell.png'
        : 'assets/icon/steelmace.png';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          WorkoutHeader(
            currentMinute: state.currentMinute,
            onHistory: _showHistory,
            onSettings: _openConfig,
          ),
          const SizedBox(height: 32),
          OverallProgress(
            currentMinute: state.currentMinute,
            totalMinutes: state.totalMinutes,
            totalRepsDone: state.totalRepsDone,
            totalReps: state.totalReps,
            exerciseLabel: exerciseLabel,
          ),
          const SizedBox(height: 48),
          RepsCard(
            currentMinute: state.currentMinute,
            currentReps: state.currentReps,
            exerciseLabel: exerciseLabel,
            iconPath: iconPath,
            pulseAnimation: _pulseAnimation,
          ),
          const SizedBox(height: 32),
          TimerDisplay(
            secondsLeft: state.secondsLeft,
            currentDuration: state.currentDuration,
            isRunning: state.isRunning,
          ),
          if (state.currentMinute < state.totalMinutes - 1) ...[
            const SizedBox(height: 16),
            NextMinutePreview(nextReps: state.plan[state.currentMinute + 1]),
          ],
          const Spacer(),
          Row(
            children: [
              IconButton(
                onPressed: () => notifier.reset(),
                icon: const Icon(Icons.refresh, color: Colors.white38, size: 28),
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
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
    return ConfirmationOverlay(
      nextReps: state.plan[nextMinute],
      nextColor: phaseColorForMinute(nextMinute),
      nextLabel: notifier.exerciseLabelForMinute(nextMinute),
      nextMinuteNumber: nextMinute + 1,
      onConfirm: () {
        _pulseController.forward().then((_) => _pulseController.reverse());
        notifier.confirmInterval();
      },
    );
  }

  Widget _buildFinishedScreen(WorkoutState state) {
    final notifier = ref.read(workoutNotifierProvider.notifier);
    return FinishedScreen(
      totalReps: state.totalReps,
      exerciseLabel: notifier.exerciseLabelForMinute(state.currentMinute),
      onReset: () => notifier.reset(),
    );
  }
}
