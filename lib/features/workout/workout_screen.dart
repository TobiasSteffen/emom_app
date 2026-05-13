import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/settings.dart';
import '../../core/providers/plan_library_notifier.dart';
import '../../core/providers/settings_provider.dart';
import '../history/history_sheet.dart';
import '../config/config_screen.dart';
import '../plans/plan_library_screen.dart';
import 'workout_notifier.dart';
import 'widgets/plan_indicator.dart';
import 'widgets/workout_header.dart';
import 'widgets/overall_progress.dart';
import 'widgets/reps_card.dart';
import 'widgets/timer_display.dart';
import 'widgets/next_minute_preview.dart';
import 'widgets/confirmation_overlay.dart';
import 'widgets/finished_screen.dart';

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
  bool _planLibWasOpened = false;
  bool _wasRunningBeforePlanLib = false;
  String _planKeySnapshot = '';

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

  Future<void> _openConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigScreen(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
    if (!mounted) return;
    ref.read(workoutNotifierProvider.notifier).updateSettings(
      ref.read(settingsNotifierProvider).requireValue,
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
    if (doReset) ref.read(workoutNotifierProvider.notifier).reset();
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

    if (workoutAsync.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
      );
    }
    if (workoutAsync.hasError) {
      return Scaffold(body: Center(child: Text('${workoutAsync.error}')));
    }

    return _buildPageView(workoutAsync.requireValue);
  }

  Widget _buildPageView(WorkoutState state) {
    final notifier = ref.read(workoutNotifierProvider.notifier);

    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
      dragStartBehavior: DragStartBehavior.down,
      onPageChanged: (page) {
        if (page == 1) {
          final lib = ref.read(planLibraryNotifierProvider).requireValue;
          setState(() {
            _planLibWasOpened = true;
            _wasRunningBeforePlanLib = state.isRunning || state.waitingForConfirmation;
            _planKeySnapshot = lib.activePlan.planKey;
          });
          if (state.isRunning) notifier.pause();
        }
        if (page == 0 && _planLibWasOpened) {
          setState(() => _planLibWasOpened = false);
          final newLib = ref.read(planLibraryNotifierProvider).requireValue;
          final planChanged = newLib.activePlan.planKey != _planKeySnapshot;
          if (planChanged) {
            final wasActive = _wasRunningBeforePlanLib || state.currentMinute > 0;
            if (wasActive) {
              _showResetConfirmDialog();
            } else {
              ref.read(workoutNotifierProvider.notifier).reset();
            }
          } else if (_wasRunningBeforePlanLib && !state.isFinished) {
            notifier.start();
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
                    : _buildWorkoutScreen(state),
                if (state.waitingForConfirmation) _buildConfirmationOverlay(state),
              ],
            ),
          ),
        ),
        PlanLibraryScreen(
          onBack: () => _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutScreen(WorkoutState state) {
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
          const SizedBox(height: 8),
          PlanIndicator(
            planName: ref.watch(planLibraryNotifierProvider).valueOrNull?.activePlan.name ?? '',
            onTap: () => _pageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
            ),
          ),
          const SizedBox(height: 40),
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
            NextMinutePreview(nextReps: state.intervals[state.currentMinute + 1].reps),
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
      nextReps: state.intervals[nextMinute].reps,
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
