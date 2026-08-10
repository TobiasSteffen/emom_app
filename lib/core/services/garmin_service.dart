import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GarminService {
  static const _channel = MethodChannel('com.example.emom_app/garmin');
  static const _everConnectedKey = 'garminHasEverConnected';
  static const _eventChannel = EventChannel('com.example.emom_app/garmin_events');

  /// Bluetooth-Laufzeitberechtigungen (Android 12+/API 31+): im Manifest
  /// deklariert reicht nicht, sie muessen zusaetzlich zur Laufzeit angefragt
  /// werden, sonst laeuft die Connect-IQ-SDK ins Leere (kein Fehler, einfach
  /// keine Geraete gefunden).
  Future<bool> _ensureBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<bool> isWatchConnected() async {
    if (!await _ensureBluetoothPermissions()) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isWatchConnected');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('GarminService.isWatchConnected failed: ${e.code} ${e.message}');
      return false;
    }
  }

  Future<String> openWatchApp() async {
    if (!await _ensureBluetoothPermissions()) return 'permission_denied';
    try {
      final result = await _channel.invokeMethod<String>('openWatchApp');
      return result ?? 'error';
    } on PlatformException catch (e) {
      debugPrint('GarminService.openWatchApp failed: ${e.code} ${e.message}');
      return 'error';
    }
  }

  Future<bool> hasEverConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_everConnectedKey) ?? false;
  }

  Future<void> markEverConnected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_everConnectedKey, true);
  }

  /// Live-Ereignisse der Watch-App: `true` bei "opened", `false` bei
  /// "closed". Unbekannte Payloads werden verworfen statt einen Fehler
  /// zu werfen (best-effort BLE-Zustellung, siehe Design-Spec).
  Stream<bool> watchAppRunningEvents() {
    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event == 'opened' || event == 'closed')
        .map((event) => event == 'opened');
  }
}
