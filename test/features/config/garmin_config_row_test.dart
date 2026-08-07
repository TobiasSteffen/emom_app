import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emom_app/features/config/config_screen.dart';
import 'package:emom_app/features/config/garmin_notifier.dart';
import 'package:emom_app/core/providers/settings_provider.dart';

// `ConfigScreen.initState` liest `settingsProvider` synchron per `requireValue`
// aus — im echten App-Flow ist der Provider zu diesem Zeitpunkt längst
// geladen (z.B. via WorkoutScreen), in einem isolierten Widget-Test aber noch
// nicht. Deshalb wird der Container hier vorab erzeugt und `settingsProvider`
// vor dem Mounten von ConfigScreen einmal ausgelesen/abgewartet.
Future<ProviderContainer> _pumpConfigScreen(
  WidgetTester tester, {
  required GarminNotifier Function() garmin,
}) async {
  final container = ProviderContainer(
    overrides: [garminProvider.overrideWith(garmin)],
  );
  addTearDown(container.dispose);
  await container.read(settingsProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ConfigScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('zeigt Garmin-Abschnitt mit Verbindungsstatus und Sichtbarkeits-Toggle', (tester) async {
    await _pumpConfigScreen(tester, garmin: () => _FakeGarminNotifier());

    expect(find.text('GARMIN-UHR'), findsOneWidget);
    expect(find.text('Watch-App öffnen'), findsOneWidget);
    expect(find.text('In der Hauptansicht anzeigen'), findsOneWidget);
  });

  testWidgets('Tap auf "Watch-App öffnen" ruft openWatchApp auf', (tester) async {
    final fake = _FakeGarminNotifier();
    await _pumpConfigScreen(tester, garmin: () => fake);

    await tester.tap(find.text('Watch-App öffnen'));
    await tester.pumpAndSettle();

    expect(fake.openWatchAppCalled, true);
  });

  testWidgets('Toggle schaltet garminHeaderIconVisible um', (tester) async {
    final container = await _pumpConfigScreen(
      tester,
      garmin: () => _FakeGarminNotifier(),
    );

    expect(container.read(settingsProvider).requireValue.garminHeaderIconVisible, false);

    final garminSwitch = find.descendant(
      of: find.ancestor(
        of: find.text('In der Hauptansicht anzeigen'),
        matching: find.byType(Row),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(garminSwitch);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).requireValue.garminHeaderIconVisible, true);
  });
}

class _FakeGarminNotifier extends GarminNotifier {
  bool openWatchAppCalled = false;

  @override
  Future<GarminConnectionStatus> build() async =>
      const GarminConnectionStatus(connected: true, everConnected: true);

  @override
  Future<String> openWatchApp() async {
    openWatchAppCalled = true;
    return 'launched';
  }
}
