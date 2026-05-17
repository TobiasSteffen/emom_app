import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarEntry {
  final DateTime date;
  final String planId;
  final String preNutrition;
  final String postNutrition;

  const CalendarEntry({
    required this.date,
    required this.planId,
    this.preNutrition = '',
    this.postNutrition = '',
  });

  Map<String, dynamic> toJson() => {
    'd': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'p': planId,
    if (preNutrition.isNotEmpty) 'pre': preNutrition,
    if (postNutrition.isNotEmpty) 'post': postNutrition,
  };

  factory CalendarEntry.fromJson(Map<String, dynamic> j) {
    final parts = (j['d'] as String).split('-');
    return CalendarEntry(
      date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      planId: j['p'] as String,
      preNutrition: j['pre'] as String? ?? '',
      postNutrition: j['post'] as String? ?? '',
    );
  }

  CalendarEntry copyWith({
    DateTime? date,
    String? planId,
    String? preNutrition,
    String? postNutrition,
  }) => CalendarEntry(
    date: date ?? this.date,
    planId: planId ?? this.planId,
    preNutrition: preNutrition ?? this.preNutrition,
    postNutrition: postNutrition ?? this.postNutrition,
  );
}

class CalendarStorage {
  static const _key = 'calendarEntries';

  static Future<List<CalendarEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((j) => CalendarEntry.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<CalendarEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
