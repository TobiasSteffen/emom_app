import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/calendar_entry.dart';
import 'package:emom_app/core/models/reminder_planner.dart';
import 'package:emom_app/core/models/training_series.dart';

void main() {
  // Sa 13.06.2026, 10:00 Uhr
  final now = DateTime(2026, 6, 13, 10, 0);
  const eightAm = 8 * 60;
  const sixPm = 18 * 60;

  group('upcomingReminders', () {
    test('empty when nothing is planned', () {
      expect(
        upcomingReminders(
            now: now, reminderMinutes: eightAm, entries: [], series: []),
        isEmpty,
      );
    });

    test('skips today when reminder time already passed', () {
      final entry =
          CalendarEntry(date: DateTime(2026, 6, 13), planId: 'p1');
      final result = upcomingReminders(
          now: now, reminderMinutes: eightAm, entries: [entry], series: []);
      expect(result, isEmpty);
    });

    test('includes today when reminder time is still ahead', () {
      final entry =
          CalendarEntry(date: DateTime(2026, 6, 13), planId: 'p1');
      final result = upcomingReminders(
          now: now, reminderMinutes: sixPm, entries: [entry], series: []);
      expect(result, hasLength(1));
      expect(result.first.dateTime, DateTime(2026, 6, 13, 18, 0));
      expect(result.first.planId, 'p1');
    });

    test('expands series within the window', () {
      final series = TrainingSeries(
        id: 's1',
        planId: 'sp',
        weekdays: {DateTime.tuesday, DateTime.thursday},
        startDate: DateTime(2026, 6, 13),
      );
      final result = upcomingReminders(
          now: now,
          reminderMinutes: eightAm,
          entries: [],
          series: [series],
          windowDays: 14);
      // Di 16., Do 18., Di 23., Do 25. — 4 Termine in 14 Tagen
      expect(result, hasLength(4));
      expect(result.first.dateTime, DateTime(2026, 6, 16, 8, 0));
      expect(result.last.dateTime, DateTime(2026, 6, 25, 8, 0));
    });

    test('respects window limit', () {
      final entry =
          CalendarEntry(date: DateTime(2026, 7, 20), planId: 'p1');
      final result = upcomingReminders(
          now: now,
          reminderMinutes: eightAm,
          entries: [entry],
          series: [],
          windowDays: 30);
      expect(result, isEmpty); // 20.07. liegt außerhalb von 30 Tagen
    });
  });
}
