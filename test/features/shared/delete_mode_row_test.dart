import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/features/shared/widgets/delete_mode_row.dart';

Future<void> _pump(WidgetTester tester,
    {required bool deleteMode,
    bool canDelete = true,
    Future<void> Function()? onDeleteTap}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeleteModeRow(
          deleteMode: deleteMode,
          canDelete: canDelete,
          deleteKey: const ValueKey('delete_x'),
          onDeleteTap: onDeleteTap ?? () async {},
          child: const SizedBox(height: 48, width: 200),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kein Lösch-Button wenn Modus aus', (tester) async {
    await _pump(tester, deleteMode: false);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('Lösch-Button sichtbar im Lösch-Modus', (tester) async {
    await _pump(tester, deleteMode: true);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('kein Button wenn canDelete false', (tester) async {
    await _pump(tester, deleteMode: true, canDelete: false);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('Tap ruft onDeleteTap genau einmal (Doppel-Tap-Schutz)',
      (tester) async {
    var calls = 0;
    final completer = Completer<void>();
    await _pump(tester, deleteMode: true, onDeleteTap: () async {
      calls++;
      await completer.future;
    });
    await tester.tap(find.byKey(const ValueKey('delete_x')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete_x')));
    completer.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
