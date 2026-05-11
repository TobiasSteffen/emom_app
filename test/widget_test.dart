import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/app.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KettlebellApp()));
    await tester.pump();
    // Loading state shown while settings load asynchronously
    expect(find.byType(KettlebellApp), findsOneWidget);
  });
}
