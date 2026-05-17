import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/calendar_entry.dart';

void main() {
  group('CalendarEntry', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 5, 17),
        planId: 'plan-abc',
        preNutrition: 'Haferflocken',
        postNutrition: 'Proteinshake',
      );
      final restored = CalendarEntry.fromJson(entry.toJson());
      expect(restored.date, DateTime(2026, 5, 17));
      expect(restored.planId, 'plan-abc');
      expect(restored.preNutrition, 'Haferflocken');
      expect(restored.postNutrition, 'Proteinshake');
    });

    test('toJson omits empty nutrition fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 1, 1),
        planId: 'p1',
      );
      final json = entry.toJson();
      expect(json.containsKey('pre'), isFalse);
      expect(json.containsKey('post'), isFalse);
    });

    test('fromJson with missing nutrition fields defaults to empty string', () {
      final entry = CalendarEntry.fromJson({'d': '2026-03-15', 'p': 'plan-x'});
      expect(entry.preNutrition, '');
      expect(entry.postNutrition, '');
    });

    test('copyWith overrides only specified fields', () {
      final entry = CalendarEntry(
        date: DateTime(2026, 6, 10),
        planId: 'old-plan',
        preNutrition: 'Müsli',
        postNutrition: '',
      );
      final copy = entry.copyWith(planId: 'new-plan');
      expect(copy.planId, 'new-plan');
      expect(copy.date, DateTime(2026, 6, 10));
      expect(copy.preNutrition, 'Müsli');
    });
  });
}
