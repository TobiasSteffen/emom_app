import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/plan_library_notifier.dart';
import '../../core/providers/settings_provider.dart';
import '../history/history_sheet.dart';
import '../config/config_screen.dart';
import '../config/garmin_notifier.dart';
import '../plans/plan_library_screen.dart';
import '../../core/models/app_page.dart';
import '../calendar/calendar_screen.dart';
import 'workout_notifier.dart';
import '../../core/models/planned_day.dart';
import '../../core/providers/calendar_notifier.dart';
import '../../core/providers/series_notifier.dart';
import 'widgets/plan_indicator.dart';
import 'widgets/planned_today_chip.dart';
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
  bool _wasRunningBeforeCalendar = false;
  String _planKeySnapshot = '';
  int _currentPage = AppPage.workout.index;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pageController = PageController(initialPage: AppPage.workout.index);
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
        builder: (_) => ConfigScreen(onBack: () => Navigator.pop(context)),
      ),
    );
    if (!mounted) return;
    // Erzwingt einen frischen Bluetooth-Check beim Verlassen der Settings
    // (garminProvider prueft sonst nur beim allerersten Build, s. Design-
    // Spec "Cold-Start-Icon-Refresh"). refreshConnection() statt
    // ref.invalidate(garminProvider) -- Invalidieren wuerde watchAppStatus
    // auf unknown zuruecksetzen und die laufende Snapshot-Zustellung zur
    // Uhr stoppen (s. GarminWorkoutSyncNotifier._send()).
    await ref.read(garminProvider.notifier).refreshConnection();
    if (!mounted) return;
    ref
        .read(workoutProvider.notifier)
        .updateSettings(ref.read(settingsProvider).requireValue);
  }

  void _startStop(WorkoutState state) {
    final notifier = ref.read(workoutProvider.notifier);
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
    final doReset =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(
              'Training zurücksetzen?',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),
            content: const Text(
              'Die Einstellungen wurden geändert. Das laufende Training zurücksetzen?',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Weiter',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Zurücksetzen',
                  style: TextStyle(color: AppTheme.accent),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (doReset) ref.read(workoutProvider.notifier).reset();
  }

  Future<void> _activatePlannedPlan(String planId, WorkoutState state) async {
    final active = state.isRunning ||
        state.waitingForConfirmation ||
        state.currentMinute > 0;
    if (active) {
      final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text(
                'Plan wechseln?',
                style: TextStyle(
                    color: Colors.white54, fontSize: 15, letterSpacing: 1),
              ),
              content: const Text(
                'Das laufende Training wird zurückgesetzt.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen',
                      style: TextStyle(color: Colors.white38)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Wechseln',
                      style: TextStyle(color: AppTheme.accent)),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
      if (!mounted) return;
    }
    await ref.read(planLibraryProvider.notifier).setActivePlan(planId);
    if (!mounted) return;
    await ref.read(workoutProvider.notifier).reset();
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const HistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only watch load/error state here: the timer tick (every second) must
    // not rebuild the PageView with all three pages — the workout page
    // watches the full state itself via a nested Consumer.
    final isLoading = ref.watch(workoutProvider.select((a) => a.isLoading));
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }
    final error =
        ref.watch(workoutProvider.select((a) => a.hasError ? a.error : null));
    if (error != null) {
      return Scaffold(body: Center(child: Text('$error')));
    }

    return _buildPageView();
  }

  Widget _buildPageView() {
    final notifier = ref.read(workoutProvider.notifier);

    // PageView pages are not Navigator routes — intercept system back to
    // navigate to the workout page instead of exiting the app.
    return PopScope(
      canPop: _currentPage == AppPage.workout.index,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _pageController.animateToPage(
          AppPage.workout.index,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
        );
      },
      child: PageView(
        controller: _pageController,
        onPageChanged: (page) {
          // Read fresh state at event time, not a build-time snapshot.
          final state = ref.read(workoutProvider).requireValue;
          // Snapshot pre-setState values used in side-effects below.
          final prevPlanLibOpened = _planLibWasOpened;
          final prevRunningBeforeCalendar = _wasRunningBeforeCalendar;
          final prevRunningBeforePlanLib = _wasRunningBeforePlanLib;
          final prevPlanKeySnapshot = _planKeySnapshot;
          final lib = page == AppPage.plans.index
              ? ref.read(planLibraryProvider).requireValue
              : null;
          setState(() {
            _currentPage = page;
            if (page == AppPage.calendar.index) {
              _wasRunningBeforeCalendar =
                  state.isRunning || state.waitingForConfirmation;
            }
            if (page == AppPage.plans.index) {
              _planLibWasOpened = true;
              _wasRunningBeforePlanLib =
                  state.isRunning || state.waitingForConfirmation;
              _planKeySnapshot = lib!.activePlan.planKey;
            }
            if (page == AppPage.workout.index) {
              _planLibWasOpened = false;
              _wasRunningBeforeCalendar = false;
            }
          });
          if (page == AppPage.calendar.index && state.isRunning) {
            notifier.pause();
          }
          if (page == AppPage.plans.index && state.isRunning) {
            notifier.pause();
          }
          if (page == AppPage.workout.index && prevPlanLibOpened) {
            final newLib = ref.read(planLibraryProvider).requireValue;
            final planChanged =
                newLib.activePlan.planKey != prevPlanKeySnapshot;
            if (planChanged) {
              final wasActive =
                  prevRunningBeforePlanLib || state.currentMinute > 0;
              if (wasActive) {
                _showResetConfirmDialog();
              } else {
                ref.read(workoutProvider.notifier).reset();
              }
            } else if (prevRunningBeforePlanLib && !state.isFinished) {
              notifier.start();
            }
          }
          if (page == AppPage.workout.index && prevRunningBeforeCalendar) {
            if (!state.isFinished) notifier.start();
          }
        },
        children: [
          CalendarScreen(
            onBack: () => _pageController.animateToPage(
              AppPage.workout.index,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
            ),
          ),
          Scaffold(
            body: SafeArea(
              child: Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(workoutProvider).requireValue;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      state.isFinished
                          ? _buildFinishedScreen(state)
                          : _buildWorkoutScreen(state, ref),
                      if (state.waitingForConfirmation)
                        _buildConfirmationOverlay(state),
                    ],
                  );
                },
              ),
            ),
          ),
          PlanLibraryScreen(
            onBack: () => _pageController.animateToPage(
              AppPage.workout.index,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  // `ref` is the nested Consumer's ref: ref.watch is only legal during the
  // build of the consumer it belongs to, and these watches must rebuild
  // only the workout page, not the whole PageView.
  Widget _buildWorkoutScreen(WorkoutState state, WidgetRef ref) {
    final notifier = ref.read(workoutProvider.notifier);
    final isPauseInterval = state.intervals[state.currentMinute].isPause;
    final phaseColor = isPauseInterval
        ? Colors.white24
        : phaseColorForMinute(state.currentMinute);
    final workoutLabel = notifier.workoutLabelForMinute(state.currentMinute);
    final iconPath = notifier.iconAssetForMinute(state.currentMinute);

    final entries = ref.watch(calendarProvider).value ?? const [];
    final seriesList = ref.watch(seriesProvider).value ?? const [];
    final lib = ref.watch(planLibraryProvider).value;
    final planned = resolveDay(DateTime.now(), entries, seriesList);
    String? plannedPlanName;
    if (planned != null && lib != null && planned.planId != lib.activePlanId) {
      for (final p in lib.plans) {
        if (p.id == planned.planId) {
          plannedPlanName = p.name;
          break;
        }
      }
    }

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
            isPause: isPauseInterval,
          ),
          const SizedBox(height: 8),
          PlanIndicator(
            planName:
                ref.watch(planLibraryProvider).value?.activePlan.name ?? '',
            onTap: () => _pageController.animateToPage(
              AppPage.plans.index,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
            ),
          ),
          if (plannedPlanName != null) ...[
            const SizedBox(height: 8),
            PlannedTodayChip(
              planName: plannedPlanName,
              onTap: () => _activatePlannedPlan(planned!.planId, state),
            ),
          ],
          const SizedBox(height: 40),
          RepsCard(
            currentMinute: state.currentMinute,
            currentReps: state.currentReps,
            workoutLabel: workoutLabel,
            iconPath: iconPath,
            pulseAnimation: _pulseAnimation,
            isPause: isPauseInterval,
            isTimed: state.currentIsTimed,
            timedSeconds: state.intervals[state.currentMinute].durationSeconds,
          ),
          const SizedBox(height: 32),
          TimerDisplay(
            secondsLeft: state.secondsLeft,
            currentDuration: state.currentDuration,
            isRunning: state.isRunning,
          ),
          if (state.currentMinute < state.totalMinutes - 1) ...[
            const SizedBox(height: 16),
            NextMinutePreview(
              interval: state.intervals[state.currentMinute + 1],
            ),
          ],
          const Spacer(),
          Row(
            children: [
              IconButton(
                onPressed: () => notifier.reset(),
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white38,
                  size: 28,
                ),
              ),
              IconButton(
                onPressed: () => notifier.skip(),
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white38,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                // Zeit-Übung: START/FERTIG ersetzt den Play/Pause-Button —
                // Play wäre im Warte-Zustand funktionslos (start() bricht
                // bei holdWaiting ab).
                child: state.currentIsTimed
                    ? GestureDetector(
                        onTap: () => state.holdWaiting
                            ? notifier.startHold()
                            : notifier.finishHold(),
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: state.holdWaiting
                                ? AppTheme.ok
                                : AppTheme.danger,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              state.holdWaiting ? 'START' : 'FERTIG',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3),
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
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
    final notifier = ref.read(workoutProvider.notifier);
    final nextMinute = state.currentMinute + 1;
    final nextInterval = state.intervals[nextMinute];
    final nextColor = nextInterval.isPause
        ? const Color(0xFF555555)
        : phaseColorForMinute(nextMinute);
    return ConfirmationOverlay(
      nextReps: (nextInterval.isPause || state.timedFlags[nextMinute])
          ? 0
          : nextInterval.reps,
      nextColor: nextColor,
      nextLabel: notifier.workoutLabelForMinute(nextMinute),
      nextMinuteNumber: nextMinute + 1,
      nextIsPause: nextInterval.isPause,
      onConfirm: () {
        _pulseController.forward().then((_) => _pulseController.reverse());
        notifier.confirmInterval();
      },
    );
  }

  Widget _buildFinishedScreen(WorkoutState state) {
    final notifier = ref.read(workoutProvider.notifier);
    return FinishedScreen(
      totalReps: state.totalReps,
      workoutLabel: _lastNonPauseLabel(state, notifier),
      onReset: () => notifier.reset(),
    );
  }

  String _lastNonPauseLabel(WorkoutState state, WorkoutNotifier notifier) {
    for (int i = state.currentMinute; i >= 0; i--) {
      if (!state.intervals[i].isPause) {
        return notifier.workoutLabelForMinute(i);
      }
    }
    return '';
  }
}
