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

  test('refreshConnection() wirft nicht, wenn niemand mehr zuhoert (Provider zwischendurch disposed)',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Verzoegerung im gemockten MethodChannel-Handler: container.read()
    // unten hoert kurz zu und schliesst synchron wieder (genau wie
    // ProviderContainer.read() intern tut), was fuer diesen autoDispose-
    // Provider einen Dispose ueber einen Timer(Duration.zero, ...)
    // einplant (riverpod 3.3.2 core/element.dart mayNeedDispose() ->
    // core/scheduler.dart scheduleProviderDispose()). Dieser Timer wird
    // VOR dem Aufruf von refreshConnection() eingereiht. Ohne eine echte
    // Verzoegerung hier loesen sich alle awaits in build()/
    // refreshConnection() rein ueber Microtasks auf und laufen dem
    // Dispose-Timer davon -- das war genau der Grund, warum die erste
    // Fassung dieses Tests (kein Handler-Delay) nicht rot wurde, obwohl
    // der Guard fehlte. Future.delayed(Duration.zero, ...) benutzt selbst
    // einen Timer, der NACH dem Dispose-Timer eingereiht wird -> der
    // Dispose feuert zuverlaessig zuerst, bevor refreshConnection() seinen
    // state-Schreibzugriff erreicht.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      await Future<void>.delayed(Duration.zero);
      switch (call.method) {
        case 'isWatchConnected':
          return true;
        case 'openWatchApp':
          return 'launched';
      }
      return null;
    });

    // Kein container.listen() hier -- garminProvider ist autoDispose und
    // hat direkt nach dem ersten Read keinen Watcher mehr, genau wie bei
    // _openConfig() im echten Fall (Header-Icon aus, noch nie verbunden).
    final notifier = container.read(garminProvider.notifier);
    await expectLater(notifier.refreshConnection(), completes);
  });
}
