import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/calendar_entry.dart';

part 'calendar_notifier.g.dart';

@Riverpod(keepAlive: true)
class CalendarNotifier extends _$CalendarNotifier {
  @override
  Future<List<CalendarEntry>> build() => CalendarStorage.load();

  Future<void> setEntry(CalendarEntry entry) async {
    final entries = [...state.requireValue];
    final idx = entries.indexWhere((e) => _sameDay(e.date, entry.date));
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    await CalendarStorage.save(entries);
    state = AsyncData(entries);
  }

  Future<void> removeEntry(DateTime date) async {
    final entries =
        state.requireValue.where((e) => !_sameDay(e.date, date)).toList();
    await CalendarStorage.save(entries);
    state = AsyncData(entries);
  }

  CalendarEntry? entryFor(DateTime date) {
    final entries = state.value ?? [];
    for (final e in entries) {
      if (_sameDay(e.date, date)) return e;
    }
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
