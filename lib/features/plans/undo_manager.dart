import 'dart:async';
import 'dart:collection';
import '../../core/models/training_plan.dart';

class UndoManager {
  UndoManager({this.maxSteps = 90});

  final int maxSteps;
  final _stack = ListQueue<List<IntervalConfig>>();
  Timer? _debounceTimer;
  bool _debounceActive = false;

  bool get canUndo => _stack.isNotEmpty;

  void push(List<IntervalConfig> intervals) {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _debounceActive = false;
    _pushSnapshot(intervals);
  }

  void pushDebounced(List<IntervalConfig> intervals) {
    if (!_debounceActive) {
      _pushSnapshot(intervals);
      _debounceActive = true;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _debounceActive = false;
      _debounceTimer = null;
    });
  }

  List<IntervalConfig> undo() {
    if (_stack.isEmpty) throw StateError('Nothing to undo');
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _debounceActive = false;
    return _stack.removeLast();
  }

  void dispose() {
    _debounceTimer?.cancel();
  }

  void _pushSnapshot(List<IntervalConfig> intervals) {
    if (_stack.length >= maxSteps) {
      _stack.removeFirst();
    }
    _stack.addLast(intervals.map((iv) => iv.copyWith()).toList());
  }
}
