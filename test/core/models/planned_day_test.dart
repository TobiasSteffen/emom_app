import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/calendar_entry.dart';
import 'package:emom_app/core/models/planned_day.dart';
import 'package:emom_app/core/models/training_series.dart';

void main() {
  // Di 16.06.2026
  final date = DateTime(2026, 6, 16);

  TrainingSeries series({
    String id = 's1',
    String planId = 'series-plan',
    Set<String> exceptions = const {},
  }) => TrainingSeries(
    id: id,
    planId: planId,
    weekdays: {DateTime.tuesday},
    startDate: DateTime(2026, 6, 1),
    exceptions: exceptions,
  );

  group('resolveDay', () {
    test('returns null when nothing is planned', () {
      expect(resolveDay(date, [], []), isNull);
    });

    test('returns entry data for a single entry', () {
      final entry =
          CalendarEntry(date: date, planId: 'entry-plan', note: 'Notiz');
      final result = resolveDay(date, [entry], []);
      expect(result!.planId, 'entry-plan');
      expect(result.note, 'Notiz');
      expect(result.fromSeries, isFalse);
      expect(result.seriesId, isNull);
    });

    test('returns series occurrence when no entry exists', () {
      final result = resolveDay(date, [], [series()]);
      expect(result!.planId, 'series-plan');
      expect(result.fromSeries, isTrue);
      expect(result.seriesId, 's1');
      expect(result.note, '');
    });

    test('entry overrides series on the same day', () {
      final entry = CalendarEntry(date: date, planId: 'entry-plan');
      final result = resolveDay(date, [entry], [series()]);
      expect(result!.planId, 'entry-plan');
      expect(result.fromSeries, isFalse);
    });

    test('excepted series day resolves to null', () {
      final s = series(exceptions: {'2026-06-16'});
      expect(resolveDay(date, [], [s]), isNull);
    });

    test('newest series wins on collision', () {
      final older = series(id: 'old', planId: 'old-plan');
      final newer = series(id: 'new', planId: 'new-plan');
      final result = resolveDay(date, [], [older, newer]);
      expect(result!.planId, 'new-plan');
      expect(result.seriesId, 'new');
    });
  });
}
