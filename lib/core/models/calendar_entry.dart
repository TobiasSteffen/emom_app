import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarEntry {
  final DateTime date;
  final String planId;
  final String note;

  const CalendarEntry({
    required this.date,
    required this.planId,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'd': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'p': planId,
    if (note.isNotEmpty) 'n': note,
  };

  factory CalendarEntry.fromJson(Map<String, dynamic> j) {
    final parts = (j['d'] as String).split('-');
    // Migration altes Format: 'pre'/'post' (Ernährung Vor-/Nachtag) → eine Notiz
    final legacy = [j['pre'] as String? ?? '', j['post'] as String? ?? '']
        .where((s) => s.isNotEmpty)
        .join('\n');
    return CalendarEntry(
      date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      planId: j['p'] as String,
      note: j['n'] as String? ?? legacy,
    );
  }

  CalendarEntry copyWith({
    DateTime? date,
    String? planId,
    String? note,
  }) => CalendarEntry(
    date: date ?? this.date,
    planId: planId ?? this.planId,
    note: note ?? this.note,
  );
}

class CalendarStorage {
  static const _key = 'calendarEntries';

  static Future<List<CalendarEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => CalendarEntry.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<CalendarEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
