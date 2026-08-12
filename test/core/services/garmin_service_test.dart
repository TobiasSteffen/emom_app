import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emom_app/core/services/garmin_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.emom_app/garmin');
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'isWatchConnected':
          return true;
        case 'openWatchApp':
          return 'launched';
      }
      return null;
    });
    // Simuliert erteilte Bluetooth-Laufzeitberechtigungen, damit
    // GarminService._ensureBluetoothPermissions() nicht auf die echte
    // (in Tests nicht gemockte) Plattform-Implementierung trifft.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
      if (call.method == 'requestPermissions') {
        final requested = List<int>.from(call.arguments as List);
        // 1 = PermissionStatus.granted in permission_handler's internal wire
        // codec (permission_handler_platform_interface/src/permission_status.dart);
        // not exported publicly, hardcoded here since it's a fixed protocol constant.
        return {for (final code in requested) code: 1};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  test('isWatchConnected ruft den MethodChannel auf und gibt das Ergebnis zurueck', () async {
    final service = GarminService();
    final result = await service.isWatchConnected();
    expect(result, true);
    expect(calls.single.method, 'isWatchConnected');
  });

  test('openWatchApp gibt den nativen Status-String zurueck', () async {
    final service = GarminService();
    final result = await service.openWatchApp();
    expect(result, 'launched');
  });

  test('hasEverConnected ist zunaechst false', () async {
    final service = GarminService();
    expect(await service.hasEverConnected(), false);
  });

  test('markEverConnected setzt das Flag dauerhaft auf true', () async {
    final service = GarminService();
    await service.markEverConnected();
    expect(await service.hasEverConnected(), true);

    // Neue Service-Instanz simuliert App-Neustart — Flag muss ueberleben.
    final serviceAfterRestart = GarminService();
    expect(await serviceAfterRestart.hasEverConnected(), true);
  });

  group('watchAppRunningEvents', () {
    const eventChannel = EventChannel('com.example.emom_app/garmin_events');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('mappt "opened" auf true und "closed" auf false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            events.success('opened');
            events.success('closed');
          },
        ),
      );

      final service = GarminService();
      final results = await service.watchAppRunningEvents().take(2).toList();
      expect(results, [true, false]);
    });

    test('ignoriert unbekannte Payloads', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            events.success('garbage');
            events.success('opened');
          },
        ),
      );

      final service = GarminService();
      final result = await service.watchAppRunningEvents().first;
      expect(result, true);
    });
  });

  group('watchCommands', () {
    const eventChannel = EventChannel('com.example.emom_app/garmin_events');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('liefert nur cmd_*-Payloads, ignoriert opened/closed', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            events.success('opened');
            events.success('cmd_pause');
            events.success('cmd_skip');
          },
        ),
      );

      final service = GarminService();
      final results = await service.watchCommands().take(2).toList();
      expect(results, ['cmd_pause', 'cmd_skip']);
    });

    test('watchAppRunningEvents und watchCommands teilen sich einen Listener, auch ueber zwei GarminService-Instanzen', () async {
      // Absichtlich ZWEI separate Instanzen, wie es in der echten App
      // passiert (garmin_notifier.dart und garmin_workout_sync_notifier.dart
      // legen je eine eigene GarminService()-Instanz an) -- eine einzelne
      // gemeinsame Instanz wuerde den Bug nicht aufdecken, den dieser Test
      // eigentlich verhindern soll (der Cache muss static sein).
      var listenCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            listenCount++;
            events.success('opened');
            events.success('cmd_pause');
          },
        ),
      );

      final serviceA = GarminService();
      final serviceB = GarminService();
      final runningSub = serviceA.watchAppRunningEvents().listen((_) {});
      final commandsSub = serviceB.watchCommands().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(listenCount, 1);
      await runningSub.cancel();
      await commandsSub.cancel();
    });
  });
}
