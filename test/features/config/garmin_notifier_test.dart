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

  test('appRunning wird durch "opened"/"closed"-Events live aktualisiert',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(garminProvider, (_, _) {});
    addTearDown(sub.close);

    final initial = await container.read(garminProvider.future);
    expect(initial.appRunning, false);

    watchEvents.add('opened');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.appRunning, true);

    watchEvents.add('closed');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.appRunning, false);
  });

  test('openWatchApp() ueberschreibt den laufenden appRunning-Wert nicht',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(garminProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(garminProvider.future);
    watchEvents.add('opened');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.appRunning, true);

    await container.read(garminProvider.notifier).openWatchApp();

    expect(container.read(garminProvider).value?.appRunning, true);
  });
}
