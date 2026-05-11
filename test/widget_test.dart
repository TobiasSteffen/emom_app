import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/main.dart';
import 'package:emom_app/core/models/settings.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(KettlebellApp(settings: AppSettings()));
    await tester.pump();
    expect(find.text('EMOM 30'), findsOneWidget);
  });
}
