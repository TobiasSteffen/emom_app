// lib/features/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/calendar_entry.dart';
import '../../core/models/planned_day.dart';
import '../../core/models/settings.dart';
import '../../core/models/training_plan.dart';
import '../../core/models/training_series.dart';
import '../../core/providers/calendar_notifier.dart';
import '../../core/providers/plan_library_notifier.dart';
import '../../core/providers/series_notifier.dart';
import '../../core/providers/settings_provider.dart';
import '../workout/workout_notifier.dart';
import 'widgets/day_editor_sheet.dart';

const _orange = Color(0xFFFF6B00);
const _monthNames = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];
const _weekdayShort = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

class CalendarScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const CalendarScreen({super.key, this.onBack});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() => setState(() {
        _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
      });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  TrainingSeries? _seriesFor(DateTime date, List<TrainingSeries> seriesList) {
    for (final s in seriesList.reversed) {
      if (s.occursOn(date)) return s;
    }
    return null;
  }

  String _planName(PlanLibrary? lib, String planId) {
    if (lib == null) return '';
    for (final p in lib.plans) {
      if (p.id == planId) return p.name;
    }
    return 'Unbekannter Plan';
  }

  String _dateLabel(DateTime d) =>
      '${_weekdayShort[d.weekday].toUpperCase()} ${d.day}. ${_monthNames[d.month].toUpperCase()}';

  // ───────────────────────── Tag-Editor ─────────────────────────

  void _openDay(DateTime date) {
    final libAsync = ref.read(planLibraryProvider);
    if (!libAsync.hasValue) return;
    final plans = libAsync.requireValue.plans;
    final existing = ref.read(calendarProvider.notifier).entryFor(date);
    final seriesList =
        ref.read(seriesProvider).value ?? const <TrainingSeries>[];
    final seriesForDay = existing == null ? _seriesFor(date, seriesList) : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DayEditorSheet(
        date: date,
        plans: plans,
        existing: existing,
        seriesForDay: seriesForDay,
        onSaveEntry: (entry) {
          ref.read(calendarProvider.notifier).setEntry(entry);
          Navigator.pop(context);
        },
        onCreateSeries: (series, note) async {
          await ref.read(seriesProvider.notifier).addSeries(series);
          final cal = ref.read(calendarProvider.notifier);
          // Bestehender Einzeleintrag wird durch die Serie ersetzt;
          // eine Notiz bleibt als Tages-Override erhalten.
          if (existing != null) await cal.removeEntry(date);
          if (note.isNotEmpty) {
            await cal.setEntry(
                CalendarEntry(date: date, planId: series.planId, note: note));
          }
          if (mounted) Navigator.pop(context);
        },
        onDeleteEntry: existing == null
            ? null
            : () {
                ref.read(calendarProvider.notifier).removeEntry(date);
                Navigator.pop(context);
              },
        onExcludeDay: seriesForDay == null
            ? null
            : () {
                ref
                    .read(seriesProvider.notifier)
                    .addException(seriesForDay.id, date);
                Navigator.pop(context);
              },
        onDeleteSeries: seriesForDay == null
            ? null
            : () {
                ref.read(seriesProvider.notifier).removeSeries(seriesForDay.id);
                Navigator.pop(context);
              },
      ),
    );
  }

  // ─────────────────────── Training starten ───────────────────────

  Future<void> _startToday(PlannedDay planned) async {
    final lib = ref.read(planLibraryProvider).value;
    if (lib == null) return;
    if (lib.activePlanId != planned.planId) {
      final workout = ref.read(workoutProvider).value;
      final workoutActive = workout != null &&
          (workout.isRunning ||
              workout.waitingForConfirmation ||
              workout.currentMinute > 0);
      if (workoutActive) {
        final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
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
                        style: TextStyle(color: _orange)),
                  ),
                ],
              ),
            ) ??
            false;
        if (!ok) return;
      }
      await ref.read(planLibraryProvider.notifier).setActivePlan(planned.planId);
      await ref.read(workoutProvider.notifier).reset();
    }
    widget.onBack?.call();
  }

  // ───────────────────────── UI-Bausteine ─────────────────────────

  Widget _header() => Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                text: _monthNames[_displayMonth.month],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                children: [
                  TextSpan(
                    text: ' ${_displayMonth.year}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w300, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white38, size: 22),
            onPressed: _prevMonth,
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right, color: Colors.white38, size: 22),
            onPressed: _nextMonth,
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: Colors.white12,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white38, size: 20),
            tooltip: 'Zum Training',
            onPressed: widget.onBack,
          ),
        ],
      );

  Widget _todayCard(
    DateTime day,
    PlannedDay planned,
    String planName,
    List<TrainingSeries> seriesList,
    AppSettings? settings,
  ) {
    final metaParts = <String>[];
    if (planned.fromSeries) {
      for (final s in seriesList) {
        if (s.id == planned.seriesId) {
          final days = s.weekdays.toList()..sort();
          metaParts.add(
              '🔁 Serie · ${days.map((d) => _weekdayShort[d]).join(' / ')}');
          break;
        }
      }
    }
    if (settings != null && settings.trainingReminderEnabled) {
      final h = (settings.trainingReminderMinutes ~/ 60).toString().padLeft(2, '0');
      final m = (settings.trainingReminderMinutes % 60).toString().padLeft(2, '0');
      metaParts.add('🔔 $h:$m');
    }

    return GestureDetector(
      onTap: () => _openDay(day),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1505), Color(0xFF1A0D02)],
          ),
          border: Border.all(color: _orange.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HEUTE · ${_dateLabel(day)}',
              style: const TextStyle(
                  fontSize: 9, letterSpacing: 2, color: _orange),
            ),
            const SizedBox(height: 4),
            Text(
              planName,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            if (metaParts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                metaParts.join('  ·  '),
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
            if (planned.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📝 ${planned.note}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _startToday(planned),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.black, size: 20),
                      SizedBox(width: 4),
                      Text(
                        'Training starten',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upcomingCard(DateTime day, PlannedDay planned, String planName) {
    final suffix = planned.fromSeries ? ' 🔁' : '';
    final noteSuffix =
        planned.note.isNotEmpty ? '  ·  📝 ${planned.note}' : '';
    return GestureDetector(
      onTap: () => _openDay(day),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(color: const Color(0xFF222222)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateLabel(day),
              style: const TextStyle(
                  fontSize: 9, letterSpacing: 2, color: Colors.white24),
            ),
            const SizedBox(height: 2),
            Text(
              '$planName$suffix$noteSuffix',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _agendaCards(
    DateTime now,
    List<CalendarEntry> entries,
    List<TrainingSeries> seriesList,
    PlanLibrary? lib,
    AppSettings? settings,
  ) {
    final cards = <Widget>[];
    for (var i = 0; i < 14; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final planned = resolveDay(day, entries, seriesList);
      if (planned == null) continue;
      final planName = _planName(lib, planned.planId);
      cards.add(i == 0
          ? _todayCard(day, planned, planName, seriesList, settings)
          : _upcomingCard(day, planned, planName));
    }
    if (cards.isEmpty) {
      cards.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Tippe auf einen Tag, um ein Training zu planen.',
            style: TextStyle(fontSize: 12, color: Colors.white24),
          ),
        ),
      ));
    }
    return cards;
  }

  // ───────────────────────────── Build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final entries =
        ref.watch(calendarProvider).value ?? const <CalendarEntry>[];
    final seriesList =
        ref.watch(seriesProvider).value ?? const <TrainingSeries>[];
    final lib = ref.watch(planLibraryProvider).value;
    final settings = ref.watch(settingsProvider).value;

    final today = DateTime.now();
    final firstDay = _displayMonth;
    final daysInMonth = DateTime(firstDay.year, firstDay.month + 1, 0).day;
    // weekday: 1=Mon..7=Sun, we want Mon=0
    final startOffset = firstDay.weekday - 1;
    final totalCells = ((startOffset + daysInMonth) / 7).ceil() * 7;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _header(),
            const SizedBox(height: 10),
            // Weekday header
            Row(
              children: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white24,
                                letterSpacing: 1),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            // Day grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.9,
              ),
              itemCount: totalCells,
              itemBuilder: (_, i) {
                final dayNumber = i - startOffset + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox();
                }
                final date =
                    DateTime(firstDay.year, firstDay.month, dayNumber);
                final isToday = _sameDay(date, today);
                final isPast = date.isBefore(
                    DateTime(today.year, today.month, today.day));
                final planned = resolveDay(date, entries, seriesList);

                final dot = planned == null
                    ? const SizedBox(height: 7)
                    : Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.black
                              : planned.fromSeries
                                  ? _orange.withValues(alpha: 0.45)
                                  : _orange,
                          shape: BoxShape.circle,
                        ),
                      );

                final content = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 13,
                        color: isToday
                            ? Colors.black
                            : isPast
                                ? Colors.white24
                                : Colors.white70,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    dot,
                  ],
                );

                return GestureDetector(
                  onTap: () => _openDay(date),
                  behavior: HitTestBehavior.opaque,
                  child: isToday
                      ? Center(
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                                color: _orange, shape: BoxShape.circle),
                            child: content,
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.all(3), child: content),
                );
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'ANSTEHEND',
              style: TextStyle(
                  fontSize: 10, letterSpacing: 2, color: Colors.white38),
            ),
            const SizedBox(height: 8),
            ..._agendaCards(today, entries, seriesList, lib, settings),
          ],
        ),
      ),
    );
  }
}
