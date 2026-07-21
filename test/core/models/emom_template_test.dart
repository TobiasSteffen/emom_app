import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/training_plan.dart';

void main() {
  group('emomRepSequence', () {
    test('konstant liefert überall denselben Wert', () {
      final seq = emomRepSequence(EmomRepScheme.konstant,
          from: 10, to: 10, count: 30);
      expect(seq.length, 30);
      expect(seq.every((r) => r == 10), isTrue);
    });

    test('aufsteigend interpoliert von Start bis Ziel (nicht fallend)', () {
      final seq = emomRepSequence(EmomRepScheme.aufsteigend,
          from: 5, to: 15, count: 30);
      expect(seq.length, 30);
      expect(seq.first, 5);
      expect(seq.last, 15);
      for (var i = 0; i < seq.length - 1; i++) {
        expect(seq[i] <= seq[i + 1], isTrue);
      }
    });

    test('absteigend interpoliert von Start bis Ziel (nicht steigend)', () {
      final seq = emomRepSequence(EmomRepScheme.absteigend,
          from: 15, to: 5, count: 30);
      expect(seq.first, 15);
      expect(seq.last, 5);
      for (var i = 0; i < seq.length - 1; i++) {
        expect(seq[i] >= seq[i + 1], isTrue);
      }
    });

    test('pyramide steigt zum Peak und fällt zurück', () {
      final seq = emomRepSequence(EmomRepScheme.pyramide,
          from: 5, to: 15, count: 30);
      expect(seq.length, 30);
      expect(seq.first, 5);
      expect(seq.last, 5);
      expect(seq.reduce((a, b) => a > b ? a : b), 15);
    });

    test('rundet nie unter 1', () {
      final seq = emomRepSequence(EmomRepScheme.absteigend,
          from: 2, to: 1, count: 30);
      expect(seq.every((r) => r >= 1), isTrue);
    });
  });
}
