import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Equipment { kb16, kb20, kb24, sm8, sm12 }

enum Exercise { swingBeidarmig, swingEinarmig, snatch, pushPress, mace360 }

extension EquipmentX on Equipment {
  bool get isKettlebell => index < 3;

  String get label {
    switch (this) {
      case Equipment.kb16: return 'KB 16kg';
      case Equipment.kb20: return 'KB 20kg';
      case Equipment.kb24: return 'KB 24kg';
      case Equipment.sm8:  return 'SM 8kg';
      case Equipment.sm12: return 'SM 12kg';
    }
  }

  String get iconPath =>
      isKettlebell ? 'assets/icon/kettlebell.png' : 'assets/icon/steelmace.png';

  Exercise get defaultExercise =>
      isKettlebell ? Exercise.swingBeidarmig : Exercise.mace360;

  List<Exercise> get validExercises => isKettlebell
      ? [Exercise.swingBeidarmig, Exercise.swingEinarmig, Exercise.snatch, Exercise.pushPress]
      : [Exercise.mace360];
}

extension ExerciseX on Exercise {
  String get label {
    switch (this) {
      case Exercise.swingBeidarmig: return 'Swing beidarmig';
      case Exercise.swingEinarmig:  return 'Swing einarmig';
      case Exercise.snatch:         return 'Snatch';
      case Exercise.pushPress:      return 'Push Press';
      case Exercise.mace360:        return '360s';
    }
  }
}

Color phaseColorForMinute(int minute) {
  if (minute < 5) return const Color(0xFF4CAF50);
  if (minute < 15) return const Color(0xFFFF6B00);
  if (minute < 20) return const Color(0xFFFF0000);
  if (minute < 25) return const Color(0xFFFF6B00);
  return const Color(0xFF4CAF50);
}

class AppSettings {
  bool vibrationEnabled;
  bool warningTonesEnabled;
  bool alarmEnabled;
  bool volumeBoostEnabled;
  double volumeBoostLevel;
  String countdownSoundFile;
  String alarmSoundFile;

  AppSettings({
    this.vibrationEnabled = true,
    this.warningTonesEnabled = true,
    this.alarmEnabled = true,
    this.volumeBoostEnabled = true,
    this.volumeBoostLevel = 1.0,
    this.countdownSoundFile = 'tick.wav',
    this.alarmSoundFile = 'alarm.wav',
  });

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      vibrationEnabled: prefs.getBool('vibrationEnabled') ?? true,
      warningTonesEnabled: prefs.getBool('warningTonesEnabled') ?? true,
      alarmEnabled: prefs.getBool('alarmEnabled') ?? true,
      volumeBoostEnabled: prefs.getBool('volumeBoostEnabled') ?? true,
      volumeBoostLevel: prefs.getDouble('volumeBoostLevel') ?? 1.0,
      countdownSoundFile: prefs.getString('countdownSoundFile') ?? 'tick.wav',
      alarmSoundFile: prefs.getString('alarmSoundFile') ?? 'alarm.wav',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrationEnabled', vibrationEnabled);
    await prefs.setBool('warningTonesEnabled', warningTonesEnabled);
    await prefs.setBool('alarmEnabled', alarmEnabled);
    await prefs.setBool('volumeBoostEnabled', volumeBoostEnabled);
    await prefs.setDouble('volumeBoostLevel', volumeBoostLevel);
    await prefs.setString('countdownSoundFile', countdownSoundFile);
    await prefs.setString('alarmSoundFile', alarmSoundFile);
  }
}
