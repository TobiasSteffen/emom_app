import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/features/shared/widgets/swipe_to_reveal_row.dart';

Future<void> _pumpRow(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SwipeToRevealRow(
            canDelete: true,
            onDeleteTap: () async {},
            child: const SizedBox(
              height: 48,
              width: 300,
              child: ColoredBox(color: Colors.grey),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Kontrolle: perfekt gerader Links-Drag öffnet die Row',
      (tester) async {
    await _pumpRow(tester);

    final center = tester.getCenter(find.byType(SwipeToRevealRow));
    final g = await tester.startGesture(center);
    for (int i = 0; i < 5; i++) {
      await g.moveBy(const Offset(-16, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets(
      'Realistischer Finger: 2px Rechts-Jitter beim Aufsetzen, dann Links-Swipe',
      (tester) async {
    await _pumpRow(tester);

    final center = tester.getCenter(find.byType(SwipeToRevealRow));
    final g = await tester.startGesture(center);
    // Finger setzt auf und rollt minimal nach rechts (typisch beim Touch-Down)
    await g.moveBy(const Offset(2, 0));
    await tester.pump(const Duration(milliseconds: 16));
    // Danach klarer Links-Swipe über 80px
    for (int i = 0; i < 5; i++) {
      await g.moveBy(const Offset(-16, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget,
        reason: 'Row sollte trotz minimalem Anfangs-Jitter öffnen');
  });

  testWidgets(
      'Realistischer Finger: leicht diagonaler Links-Swipe mit Y-Anteil',
      (tester) async {
    await _pumpRow(tester);

    final center = tester.getCenter(find.byType(SwipeToRevealRow));
    final g = await tester.startGesture(center);
    // Bogenförmige Bewegung: ein einzelnes Event driftet +1.5px nach rechts
    await g.moveBy(const Offset(-3, 2));
    await tester.pump(const Duration(milliseconds: 16));
    await g.moveBy(const Offset(1.5, 1));
    await tester.pump(const Duration(milliseconds: 16));
    for (int i = 0; i < 5; i++) {
      await g.moveBy(const Offset(-16, 2));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget,
        reason: 'Ein einzelnes 1.5px-Rechts-Event mitten im Links-Swipe '
            'darf die Geste nicht komplett verwerfen');
  });
}
