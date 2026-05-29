import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/features/plans/undo_manager.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/models/settings.dart';

IntervalConfig _iv({int reps = 10}) => IntervalConfig(
      reps: reps,
      durationSeconds: 60,
      equipment: Equipment.kb16,
      exercise: Exercise.swingBeidarmig,
    );

void main() {
  group('UndoManager', () {
    test('canUndo is false initially', () {
      final um = UndoManager();
      expect(um.canUndo, isFalse);
    });

    test('canUndo is true after push', () {
      final um = UndoManager();
      um.push([_iv()]);
      expect(um.canUndo, isTrue);
    });

    test('undo returns deep copy — snapshot unaffected by later mutations', () {
      final um = UndoManager();
      final original = [_iv(reps: 5)];
      um.push(original);
      original[0] = original[0].copyWith(reps: 99);
      final restored = um.undo();
      expect(restored[0].reps, 5);
    });

    test('undo pops in LIFO order', () {
      final um = UndoManager();
      um.push([_iv(reps: 1)]);
      um.push([_iv(reps: 2)]);
      expect(um.undo()[0].reps, 2);
      expect(um.undo()[0].reps, 1);
    });

    test('canUndo is false after all steps undone', () {
      final um = UndoManager();
      um.push([_iv()]);
      um.undo();
      expect(um.canUndo, isFalse);
    });

    test('undo() on empty stack throws StateError', () {
      final um = UndoManager();
      expect(() => um.undo(), throwsStateError);
    });

    test('oldest entry discarded when maxSteps exceeded', () {
      final um = UndoManager(maxSteps: 3);
      um.push([_iv(reps: 1)]);
      um.push([_iv(reps: 2)]);
      um.push([_iv(reps: 3)]);
      um.push([_iv(reps: 4)]);
      expect(um.undo()[0].reps, 4);
      expect(um.undo()[0].reps, 3);
      expect(um.undo()[0].reps, 2);
      expect(um.canUndo, isFalse);
    });

    test('pushDebounced: first call pushes snapshot immediately', () {
      fakeAsync((async) {
        final um = UndoManager();
        final state = [_iv(reps: 10)];
        um.pushDebounced(state);
        state[0].reps = 20;
        expect(um.canUndo, isTrue);
        expect(um.undo()[0].reps, 10);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });

    test('pushDebounced: second call within 800ms does not push again', () {
      fakeAsync((async) {
        final um = UndoManager();
        um.pushDebounced([_iv(reps: 10)]);
        async.elapse(const Duration(milliseconds: 400));
        um.pushDebounced([_iv(reps: 11)]);
        um.undo();
        expect(um.canUndo, isFalse);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });

    test('pushDebounced: after cooldown, next call pushes again', () {
      fakeAsync((async) {
        final um = UndoManager();
        um.pushDebounced([_iv(reps: 10)]);
        async.elapse(const Duration(milliseconds: 900));
        um.pushDebounced([_iv(reps: 15)]);
        expect(um.undo()[0].reps, 15);
        expect(um.undo()[0].reps, 10);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });

    test('push() cancels active debounce and resets it', () {
      fakeAsync((async) {
        final um = UndoManager();
        um.pushDebounced([_iv(reps: 10)]);
        async.elapse(const Duration(milliseconds: 400));
        um.push([_iv(reps: 11)]);
        um.pushDebounced([_iv(reps: 12)]);
        expect(um.undo()[0].reps, 12);
        expect(um.undo()[0].reps, 11);
        expect(um.undo()[0].reps, 10);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });

    test('undo() resets debounce — next pushDebounced pushes immediately', () {
      fakeAsync((async) {
        final um = UndoManager();
        um.pushDebounced([_iv(reps: 10)]);
        um.undo();
        um.pushDebounced([_iv(reps: 20)]);
        expect(um.canUndo, isTrue);
        expect(um.undo()[0].reps, 20);
        async.elapse(const Duration(seconds: 2));
        um.dispose();
      });
    });
  });
}
