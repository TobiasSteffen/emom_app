import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emom_app/core/services/garmin_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.emom_app/garmin');
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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
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
}
