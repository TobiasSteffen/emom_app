import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GarminService {
  static const _channel = MethodChannel('com.example.emom_app/garmin');
  static const _everConnectedKey = 'garminHasEverConnected';

  Future<bool> isWatchConnected() async {
    final result = await _channel.invokeMethod<bool>('isWatchConnected');
    return result ?? false;
  }

  Future<String> openWatchApp() async {
    final result = await _channel.invokeMethod<String>('openWatchApp');
    return result ?? 'error';
  }

  Future<bool> hasEverConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_everConnectedKey) ?? false;
  }

  Future<void> markEverConnected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_everConnectedKey, true);
  }
}
