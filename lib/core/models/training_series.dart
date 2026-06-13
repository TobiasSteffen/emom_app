import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Wiederkehrende Trainings-Serie: Plan + Wochentage, gilt unendlich ab
/// [startDate]. Einzelne Tage können über [exceptions] ausgenommen werden.
class TrainingSeries {
  final String id;
  final String planId;
  final Set<int> weekdays; // 1=Mo … 7=So (DateTime.weekday)
  final DateTime startDate; // nur Datum, keine Uhrzeit
  final Set<String> exceptions; // ISO-Daten 'yyyy-MM-dd'

  const TrainingSeries({
    required this.id,
    required this.planId,
    required this.weekdays,
    required this.startDate,
    this.exceptions = const {},
  });

  static String newId() {
    final r = Random();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Trifft die Serie auf [date] zu? (Wochentag passt, startDate erreicht,
  /// Datum nicht ausgenommen.)
  bool occursOn(DateTime date) {
    if (!weekdays.contains(date.weekday)) return false;
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (day.isBefore(start)) return false;
    return !exceptions.contains(dateKey(date));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'p': planId,
    'wd': (weekdays.toList()..sort()),
    's': dateKey(startDate),
    if (exceptions.isNotEmpty) 'ex': (exceptions.toList()..sort()),
  };

  factory TrainingSeries.fromJson(Map<String, dynamic> j) {
    final parts = (j['s'] as String).split('-');
    return TrainingSeries(
      id: j['id'] as String,
      planId: j['p'] as String,
      weekdays: (j['wd'] as List).cast<int>().toSet(),
      startDate: DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      exceptions: ((j['ex'] as List?) ?? const []).cast<String>().toSet(),
    );
  }

  TrainingSeries copyWith({Set<String>? exceptions}) => TrainingSeries(
    id: id,
    planId: planId,
    weekdays: weekdays,
    startDate: startDate,
    exceptions: exceptions ?? this.exceptions,
  );
}

class SeriesStorage {
  static const _key = 'trainingSeries';

  static Future<List<TrainingSeries>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => TrainingSeries.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<TrainingSeries> series) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(series.map((s) => s.toJson()).toList()),
    );
  }
}
