import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/features/config/equipment_wizard_screen.dart';

// Bild-Asset-Fehler unterdrücken (Icon-Grid in Schritt 1, Header in Schritt 4
// laden Assets, die im Widget-Test nicht gebündelt sind).
void Function(FlutterErrorDetails)? _originalError;

void _suppressImageErrors() {
  _originalError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('Unable to load asset') ||
        msg.contains('HttpException') ||
        msg.contains('ImageCodecException')) {
      return;
    }
    _originalError?.call(details);
  };
}

void _restoreErrorHandler() {
  FlutterError.onError = _originalError;
}

Future<void> _pumpWizard(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: EquipmentWizardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(_suppressImageErrors);
  tearDown(_restoreErrorHandler);

  testWidgets('Im Wizard hinzugefügte Variante ist per Tap editierbar',
      (tester) async {
    await _pumpWizard(tester);

    // Schritt 1: Name eingeben → Weiter
    await tester.enterText(find.byType(TextField).first, 'Testgerät');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Weiter →'));
    await tester.tap(find.text('Weiter →'));
    await tester.pumpAndSettle();

    // Schritt 2: Variante hinzufügen
    await tester.tap(find.text('+ Variante hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '10 kg');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Variante per Tap editieren
    await tester.tap(find.text('10 kg'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '10 kg'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '12 kg');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('12 kg'), findsOneWidget);
    expect(find.text('10 kg'), findsNothing);

    await tester.tap(find.text('Weiter →'));
    await tester.pumpAndSettle();

    // Schritt 3: Übung hinzufügen → Weiter
    await tester.tap(find.text('+ Übung hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Schwingen');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter →'));
    await tester.pumpAndSettle();

    // Schritt 4: Zusammenfassung zeigt den editierten Wert
    expect(find.text('ZUSAMMENFASSUNG'), findsOneWidget);
    expect(find.text('12 kg'), findsOneWidget);
  });
}
