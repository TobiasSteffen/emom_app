// lib/features/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/calendar_notifier.dart';
import '../../core/providers/plan_library_notifier.dart';
import 'widgets/day_editor_sheet.dart';

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
        _displayMonth =
            DateTime(_displayMonth.year, _displayMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _displayMonth =
            DateTime(_displayMonth.year, _displayMonth.month + 1);
      });

  void _openDay(DateTime date) {
    final calendarAsync = ref.read(calendarProvider);
    final libAsync = ref.read(planLibraryProvider);
    if (!calendarAsync.hasValue || !libAsync.hasValue) return;
    final plans = libAsync.requireValue.plans;
    if (plans.isEmpty) return;
    final existing = ref.read(calendarProvider.notifier).entryFor(date);
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
        onSave: (entry) {
          ref.read(calendarProvider.notifier).setEntry(entry);
          Navigator.pop(context);
        },
        onDelete: existing == null
            ? null
            : () {
                ref
                    .read(calendarProvider.notifier)
                    .removeEntry(date);
                Navigator.pop(context);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(calendarProvider);
    final entries = entriesAsync.value ?? [];

    final monthNames = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];

    final today = DateTime.now();
    final firstDay = _displayMonth;
    final daysInMonth =
        DateTime(firstDay.year, firstDay.month + 1, 0).day;
    // weekday: 1=Mon..7=Sun, we want Mon=0
    final startOffset = firstDay.weekday - 1;
    final totalCells =
        ((startOffset + daysInMonth) / 7).ceil() * 7;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        leading: IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white38),
          onPressed: widget.onBack,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white38, size: 20),
              onPressed: _prevMonth,
            ),
            Text(
              '${monthNames[_displayMonth.month]} ${_displayMonth.year}',
              style: const TextStyle(
                  fontSize: 14, letterSpacing: 1, color: Colors.white54),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
              onPressed: _nextMonth,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Weekday header
            Row(
              children: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white24,
                                  letterSpacing: 1)),
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
                final date = DateTime(
                    firstDay.year, firstDay.month, dayNumber);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isPast = date.isBefore(
                    DateTime(today.year, today.month, today.day));
                final hasEntry = entries
                    .any((e) => _sameDay(e.date, date));

                return GestureDetector(
                  onTap: () => _openDay(date),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      border: isToday
                          ? Border.all(
                              color: const Color(0xFFFF6B00), width: 1)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13,
                            color: isPast
                                ? Colors.white24
                                : Colors.white70,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (hasEntry)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B00),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
