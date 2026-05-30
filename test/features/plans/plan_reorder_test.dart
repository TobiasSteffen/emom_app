import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';

List<IntervalConfig> _makeIntervals() => List.generate(30, (i) => IntervalConfig(
  reps: i + 1,
  durationSeconds: 60,
  equipmentTypeId: 'kettlebell',
  variantId: 'kb_24',
  exerciseTypeId: 'swing_beidarmig',
));

({List<IntervalConfig> intervals, int? selectedRow}) _applyReorder(
  List<IntervalConfig> intervals,
  int? selectedRow,
  int oldIndex,
  int newIndex,
) {
  if (newIndex > oldIndex) newIndex--;
  final item = intervals.removeAt(oldIndex);
  intervals.insert(newIndex, item);
  if (selectedRow != null) {
    final s = selectedRow;
    if (s == oldIndex) {
      selectedRow = newIndex;
    } else if (oldIndex < newIndex && s > oldIndex && s <= newIndex) {
      selectedRow = s - 1;
    } else if (oldIndex > newIndex && s >= newIndex && s < oldIndex) {
      selectedRow = s + 1;
    }
  }
  return (intervals: intervals, selectedRow: selectedRow);
}

void main() {
  group('plan reorder logic', () {
    test('item moves down: reps follow', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, null, 2, 5);
      expect(result.intervals[4].reps, 3);
      expect(result.intervals[2].reps, 4);
      expect(result.intervals.length, 30);
    });

    test('item moves up: reps follow', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, null, 4, 2);
      expect(result.intervals[2].reps, 5);
      expect(result.intervals[3].reps, 3);
      expect(result.intervals.length, 30);
    });

    test('selectedRow follows moved item down', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 2, 2, 5);
      expect(result.selectedRow, 4);
    });

    test('selectedRow follows moved item up', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 4, 4, 2);
      expect(result.selectedRow, 2);
    });

    test('selectedRow between old and new (move down) shifts up', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 3, 2, 5);
      expect(result.selectedRow, 2);
    });

    test('selectedRow between old and new (move up) shifts down', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 3, 5, 2);
      expect(result.selectedRow, 4);
    });

    test('selectedRow outside range stays unchanged', () {
      final intervals = _makeIntervals();
      final result = _applyReorder(intervals, 0, 2, 5);
      expect(result.selectedRow, 0);
    });
  });
}
