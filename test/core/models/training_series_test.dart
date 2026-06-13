import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_series.dart';

void main() {
  group('TrainingSeries', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final series = TrainingSeries(
        id: 'abc',
        planId: 'plan-1',
        weekdays: {DateTime.tuesday, DateTime.thursday, DateTime.saturday},
        startDate: DateTime(2026, 6, 13),
        exceptions: {'2026-06-16'},
      );
      final restored = TrainingSeries.fromJson(series.toJson());
      expect(restored.id, 'abc');
      expect(restored.planId, 'plan-1');
      expect(restored.weekdays, {2, 4, 6});
      expect(restored.startDate, DateTime(2026, 6, 13));
      expect(restored.exceptions, {'2026-06-16'});
    });

    test('toJson omits empty exceptions', () {
      final series = TrainingSeries(
        id: 'a',
        planId: 'p',
        weekdays: {1},
        startDate: DateTime(2026, 1, 1),
      );
      expect(series.toJson().containsKey('ex'), isFalse);
    });

    group('occursOn', () {
      final series = TrainingSeries(
        id: 'a',
        planId: 'p',
        weekdays: {DateTime.tuesday, DateTime.thursday},
        startDate: DateTime(2026, 6, 13), // Samstag
        exceptions: {'2026-06-18'},
      );

      test('matches weekday on/after startDate', () {
        // Di 16.06.2026
        expect(series.occursOn(DateTime(2026, 6, 16)), isTrue);
      });

      test('does not match other weekdays', () {
        // Mo 15.06.2026
        expect(series.occursOn(DateTime(2026, 6, 15)), isFalse);
      });

      test('does not match before startDate', () {
        // Di 09.06.2026 — vor dem 13.06.
        expect(series.occursOn(DateTime(2026, 6, 9)), isFalse);
      });

      test('does not match excepted dates', () {
        // Do 18.06.2026 steht in exceptions
        expect(series.occursOn(DateTime(2026, 6, 18)), isFalse);
      });
    });

    test('dateKey formats with zero padding', () {
      expect(TrainingSeries.dateKey(DateTime(2026, 3, 5)), '2026-03-05');
    });
  });
}
