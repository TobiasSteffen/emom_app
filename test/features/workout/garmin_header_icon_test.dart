import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emom_app/features/workout/widgets/garmin_header_icon.dart';
import 'package:emom_app/features/config/garmin_notifier.dart';
import 'package:emom_app/core/theme/app_theme.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    GarminNotifier fakeNotifier,
    VoidCallback onSettings,
  ) async {
    SharedPreferences.setMockInitialValues({'garminHeaderIconVisible': true});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [garminProvider.overrideWith(() => fakeNotifier)],
        child: MaterialApp(
          home: Scaffold(body: GarminHeaderIcon(onSettings: onSettings)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unsichtbar wenn garminHeaderIconVisible false ist', (tester) async {
    SharedPreferences.setMockInitialValues({'garminHeaderIconVisible': false});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garminProvider.overrideWith(
            () => _FakeGarminNotifier(everConnected: true, watchAppStatus: WatchAppStatus.running),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: GarminHeaderIcon(onSettings: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('garminHeaderIcon')), findsNothing);
  });

  testWidgets('gruen wenn watchAppStatus running ist', (tester) async {
    await pump(
      tester,
      _FakeGarminNotifier(everConnected: true, watchAppStatus: WatchAppStatus.running),
      () {},
    );
    final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.ok);
  });

  testWidgets('rot wenn everConnected aber watchAppStatus nicht running ist', (tester) async {
    await pump(
      tester,
      _FakeGarminNotifier(everConnected: true, watchAppStatus: WatchAppStatus.notRunning),
      () {},
    );
    final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.danger);
  });

  testWidgets('rot wenn everConnected und watchAppStatus unknown', (tester) async {
    await pump(
      tester,
      _FakeGarminNotifier(everConnected: true, watchAppStatus: WatchAppStatus.unknown),
      () {},
    );
    final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.danger);
  });

  testWidgets('grau wenn noch nie verbunden', (tester) async {
    await pump(
      tester,
      _FakeGarminNotifier(everConnected: false, watchAppStatus: WatchAppStatus.notRunning),
      () {},
    );
    final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.textMuted);
  });

  testWidgets('watchAppStatus-Wechsel aktualisiert die Icon-Farbe live', (tester) async {
    final fake = _FakeGarminNotifier(everConnected: true, watchAppStatus: WatchAppStatus.notRunning);
    await pump(tester, fake, () {});

    var icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.danger);

    fake.setWatchAppStatus(WatchAppStatus.running);
    await tester.pump();

    icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.ok);
  });

  testWidgets('Tap bei Grau ruft onSettings auf, nicht openWatchApp', (tester) async {
    var settingsCalled = false;
    final fake = _FakeGarminNotifier(everConnected: false, watchAppStatus: WatchAppStatus.notRunning);
    await pump(tester, fake, () => settingsCalled = true);

    await tester.tap(find.byKey(const Key('garminHeaderIcon')));
    await tester.pumpAndSettle();

    expect(settingsCalled, true);
    expect(fake.openWatchAppCalled, false);
  });

  testWidgets('Tap bei Rot ruft openWatchApp auf, nicht onSettings', (tester) async {
    var settingsCalled = false;
    final fake = _FakeGarminNotifier(everConnected: true, watchAppStatus: WatchAppStatus.notRunning);
    await pump(tester, fake, () => settingsCalled = true);

    await tester.tap(find.byKey(const Key('garminHeaderIcon')));
    await tester.pumpAndSettle();

    expect(settingsCalled, false);
    expect(fake.openWatchAppCalled, true);
  });
}

class _FakeGarminNotifier extends GarminNotifier {
  final bool everConnected;
  final WatchAppStatus watchAppStatus;
  bool openWatchAppCalled = false;

  _FakeGarminNotifier({required this.everConnected, required this.watchAppStatus});

  @override
  Future<GarminConnectionStatus> build() async => GarminConnectionStatus(
        connected: everConnected,
        everConnected: everConnected,
        watchAppStatus: watchAppStatus,
      );

  @override
  Future<String> openWatchApp() async {
    openWatchAppCalled = true;
    return 'launched';
  }

  /// Simuliert ein eingehendes "opened"/"closed"-Event fuer Widget-Tests,
  /// ohne echte Plattform-Kanaele zu mocken.
  void setWatchAppStatus(WatchAppStatus value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(GarminConnectionStatus(
      connected: current.connected,
      everConnected: current.everConnected,
      watchAppStatus: value,
    ));
  }
}
