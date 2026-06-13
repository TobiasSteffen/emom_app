import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/calendar_entry.dart';

void main() {
  group('CalendarEntry', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 5, 17),
        planId: 'plan-abc',
        note: 'Abends Kohlenhydrate auffüllen',
      );
      final restored = CalendarEntry.fromJson(entry.toJson());
      expect(restored.date, DateTime(2026, 5, 17));
      expect(restored.planId, 'plan-abc');
      expect(restored.note, 'Abends Kohlenhydrate auffüllen');
    });

    test('toJson omits empty note', () {
      final entry = CalendarEntry(date: DateTime(2026, 1, 1), planId: 'p1');
      expect(entry.toJson().containsKey('n'), isFalse);
    });

    test('fromJson without note defaults to empty string', () {
      final entry = CalendarEntry.fromJson({'d': '2026-03-15', 'p': 'plan-x'});
      expect(entry.note, '');
    });

    test('fromJson migrates legacy pre/post fields into note', () {
      final entry = CalendarEntry.fromJson({
        'd': '2026-03-15',
        'p': 'plan-x',
        'pre': 'Haferflocken',
        'post': 'Proteinshake',
      });
      expect(entry.note, 'Haferflocken\nProteinshake');
    });

    test('fromJson migrates single legacy field without newline', () {
      final entry = CalendarEntry.fromJson({
        'd': '2026-03-15',
        'p': 'plan-x',
        'post': 'Proteinshake',
      });
      expect(entry.note, 'Proteinshake');
    });

    test('fromJson treats empty legacy fields as no note', () {
      final entry = CalendarEntry.fromJson(
          {'d': '2026-03-15', 'p': 'plan-x', 'pre': '', 'post': ''});
      expect(entry.note, '');
    });

    test('copyWith overrides only specified fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 6, 10),
        planId: 'old-plan',
        note: 'Müsli',
      );
      final copy = entry.copyWith(planId: 'new-plan');
      expect(copy.planId, 'new-plan');
      expect(copy.date, DateTime(2026, 6, 10));
      expect(copy.note, 'Müsli');
    });
  });
}
