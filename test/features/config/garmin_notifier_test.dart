import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emom_app/features/config/garmin_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.example.emom_app/garmin');
  const eventChannel = EventChannel('com.example.emom_app/garmin_events');
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  late StreamController<String> watchEvents;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    watchEvents = StreamController<String>.broadcast();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'isWatchConnected':
          return true;
        case 'openWatchApp':
          return 'launched';
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
      if (call.method == 'requestPermissions') {
        final requested = List<int>.from(call.arguments as List);
        return {for (final code in requested) code: 1};
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink events) {
          watchEvents.stream.listen(events.success);
        },
      ),
    );
  });

  tearDown(() async {
    await watchEvents.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  test('watchAppStatus wird durch "opened"/"closed"-Events live aktualisiert',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(garminProvider, (_, _) {});
    addTearDown(sub.close);

    final initial = await container.read(garminProvider.future);
    expect(initial.watchAppStatus, WatchAppStatus.unknown);

    watchEvents.add('opened');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.watchAppStatus, WatchAppStatus.running);

    watchEvents.add('closed');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.watchAppStatus, WatchAppStatus.notRunning);
  });

  test('openWatchApp() ueberschreibt den laufenden watchAppStatus-Wert nicht',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(garminProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(garminProvider.future);
    watchEvents.add('opened');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.watchAppStatus, WatchAppStatus.running);

    await container.read(garminProvider.notifier).openWatchApp();

    expect(container.read(garminProvider).value?.watchAppStatus, WatchAppStatus.running);
  });

  test('refreshConnection() fragt Bluetooth erneut ab, ohne watchAppStatus zurueckzusetzen',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(garminProvider, (_, _) {});
    addTearDown(sub.close);

    var isWatchConnectedCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'isWatchConnected':
          isWatchConnectedCalls++;
          return true;
        case 'openWatchApp':
          return 'launched';
      }
      return null;
    });

    await container.read(garminProvider.future);
    expect(isWatchConnectedCalls, 1);

    // watchAppStatus auf "running" bringen, wie es ein echtes "opened"-Event
    // von der Uhr taete.
    watchEvents.add('opened');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.watchAppStatus, WatchAppStatus.running);

    await container.read(garminProvider.notifier).refreshConnection();

    expect(isWatchConnectedCalls, 2);
    expect(container.read(garminProvider).value?.watchAppStatus, WatchAppStatus.running);
  });
}
