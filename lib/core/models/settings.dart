import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Equipment { kb16, kb20, kb24, sm8, sm12, pb0, pb2_5, pb5, pb7_5, pb10 }

enum Exercise { swingBeidarmig, swingEinarmig, snatch, pushPress, mace360, myotatischerCrunch }

extension EquipmentX on Equipment {
  bool get isKettlebell =>
      this == Equipment.kb16 || this == Equipment.kb20 || this == Equipment.kb24;

  bool get isSteelMace =>
      this == Equipment.sm8 || this == Equipment.sm12;

  bool get isPezziball =>
      this == Equipment.pb0   || this == Equipment.pb2_5 ||
      this == Equipment.pb5   || this == Equipment.pb7_5 ||
      this == Equipment.pb10;

  String get label {
    switch (this) {
      case Equipment.kb16:  return 'Kettlebell 16kg';
      case Equipment.kb20:  return 'Kettlebell 20kg';
      case Equipment.kb24:  return 'Kettlebell 24kg';
      case Equipment.sm8:   return 'Steel Mace 8kg';
      case Equipment.sm12:  return 'Steel Mace 12kg';
      case Equipment.pb0:   return 'Pezziball';
      case Equipment.pb2_5: return 'Pezziball + 2,5kg';
      case Equipment.pb5:   return 'Pezziball + 5kg';
      case Equipment.pb7_5: return 'Pezziball + 7,5kg';
      case Equipment.pb10:  return 'Pezziball + 10kg';
    }
  }

  String get shortLabel {
    switch (this) {
      case Equipment.kb16:  return '16 kg';
      case Equipment.kb20:  return '20 kg';
      case Equipment.kb24:  return '24 kg';
      case Equipment.sm8:   return '8 kg';
      case Equipment.sm12:  return '12 kg';
      case Equipment.pb0:   return 'ohne';
      case Equipment.pb2_5: return '2,5 kg';
      case Equipment.pb5:   return '5 kg';
      case Equipment.pb7_5: return '7,5 kg';
      case Equipment.pb10:  return '10 kg';
    }
  }

  String get iconPath => switch (this) {
    Equipment.kb16 || Equipment.kb20 || Equipment.kb24 => 'assets/icon/kettlebell.png',
    Equipment.sm8  || Equipment.sm12                   => 'assets/icon/steelmace.png',
    Equipment.pb0  || Equipment.pb2_5 || Equipment.pb5 ||
    Equipment.pb7_5 || Equipment.pb10                  => 'assets/icon/pezziball.png',
  };

  Exercise get defaultExercise => switch (this) {
    Equipment.kb16 || Equipment.kb20 || Equipment.kb24 => Exercise.swingBeidarmig,
    Equipment.sm8  || Equipment.sm12                   => Exercise.mace360,
    Equipment.pb0  || Equipment.pb2_5 || Equipment.pb5 ||
    Equipment.pb7_5 || Equipment.pb10                  => Exercise.myotatischerCrunch,
  };

  List<Exercise> get validExercises => switch (this) {
    Equipment.kb16 || Equipment.kb20 || Equipment.kb24 =>
        [Exercise.swingBeidarmig, Exercise.swingEinarmig, Exercise.snatch, Exercise.pushPress],
    Equipment.sm8  || Equipment.sm12 => [Exercise.mace360],
    Equipment.pb0  || Equipment.pb2_5 || Equipment.pb5 ||
    Equipment.pb7_5 || Equipment.pb10 => [Exercise.myotatischerCrunch],
  };
}

extension ExerciseX on Exercise {
  bool get isOneArm =>
      this == Exercise.swingEinarmig ||
      this == Exercise.snatch ||
      this == Exercise.pushPress;

  String get label {
    switch (this) {
      case Exercise.swingBeidarmig:     return 'Swing beidarmig';
      case Exercise.swingEinarmig:      return 'Swing einarmig';
      case Exercise.snatch:             return 'Snatch';
      case Exercise.pushPress:          return 'Push Press';
      case Exercise.mace360:            return '360s';
      case Exercise.myotatischerCrunch: return 'Myotatischer Crunch';
    }
  }
}

enum ExerciseSide { links, rechts }

extension ExerciseSideX on ExerciseSide {
  String get label => this == ExerciseSide.links ? 'Links' : 'Rechts';
  String get shortLabel => this == ExerciseSide.links ? 'L' : 'R';
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
