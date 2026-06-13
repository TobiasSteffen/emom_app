import 'calendar_entry.dart';
import 'training_series.dart';

/// Aufgelöstes Tagesergebnis: welches Training ist an einem Tag geplant.
class PlannedDay {
  final String planId;
  final String note;
  final bool fromSeries;
  final String? seriesId;

  const PlannedDay({
    required this.planId,
    this.note = '',
    this.fromSeries = false,
    this.seriesId,
  });
}

/// Löst auf, welches Training an [date] geplant ist.
/// Vorrang: Einzeleintrag > jüngste passende Serie > nichts (max. ein
/// Training pro Tag). Serien gelten an ihren Wochentagen ab startDate,
/// außer das Datum ist ausgenommen.
PlannedDay? resolveDay(
  DateTime date,
  List<CalendarEntry> entries,
  List<TrainingSeries> series,
) {
  for (final e in entries) {
    if (e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day) {
      return PlannedDay(planId: e.planId, note: e.note);
    }
  }
  // Listen sind in Anlege-Reihenfolge — rückwärts = jüngste Serie zuerst.
  for (final s in series.reversed) {
    if (s.occursOn(date)) {
      return PlannedDay(planId: s.planId, fromSeries: true, seriesId: s.id);
    }
  }
  return null;
}
