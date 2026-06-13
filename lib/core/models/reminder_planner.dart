import 'calendar_entry.dart';
import 'planned_day.dart';
import 'training_series.dart';

class ReminderOccurrence {
  final DateTime dateTime;
  final String planId;

  const ReminderOccurrence({required this.dateTime, required this.planId});
}

/// Berechnet die anstehenden Erinnerungstermine: für jeden geplanten
/// Trainingstag im Fenster von [windowDays] Tagen ab heute ein Termin zur
/// Uhrzeit [reminderMinutes] (Minuten seit Mitternacht). Termine, die vor
/// [now] liegen, entfallen.
List<ReminderOccurrence> upcomingReminders({
  required DateTime now,
  required int reminderMinutes,
  required List<CalendarEntry> entries,
  required List<TrainingSeries> series,
  int windowDays = 30,
}) {
  final result = <ReminderOccurrence>[];
  for (var i = 0; i < windowDays; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    final planned = resolveDay(day, entries, series);
    if (planned == null) continue;
    final at = DateTime(
        day.year, day.month, day.day, reminderMinutes ~/ 60, reminderMinutes % 60);
    if (!at.isAfter(now)) continue;
    result.add(ReminderOccurrence(dateTime: at, planId: planned.planId));
  }
  return result;
}
