import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlanMode { phaseBased, minuteExact }
enum Equipment { kettlebell, steelmace }

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
  double volumeBoostLevel; // 0.0 – 1.0
  String countdownSoundFile;
  String alarmSoundFile;
  PlanMode planMode;
  Equipment equipment;
  int warmUpReps;
  int peakReps;
  int coolDownReps;
  List<int> customPlan;       // 30 Reps-Werte
  List<int> customDurations;  // 30 Dauern in Sekunden, min. 30 (minuteExact)
  List<int> customEquipment;  // 30 Equipment-Werte (minuteExact, 0=kettlebell, 1=steelmace)
  List<int> phaseDurations;   // 5 Dauern in Sekunden, eine pro Phase (phaseBased)

  AppSettings({
    this.vibrationEnabled = true,
    this.warningTonesEnabled = true,
    this.alarmEnabled = true,
    this.volumeBoostEnabled = true,
    this.volumeBoostLevel = 1.0,
    this.countdownSoundFile = 'tick.wav',
    this.alarmSoundFile = 'alarm.wav',
    this.planMode = PlanMode.phaseBased,
    this.equipment = Equipment.kettlebell,
    this.warmUpReps = 5,
    this.peakReps = 15,
    this.coolDownReps = 10,
    List<int>? customPlan,
    List<int>? customDurations,
    List<int>? customEquipment,
    List<int>? phaseDurations,
  })  : customPlan = customPlan ?? _defaultPlan(),
        customDurations = customDurations ?? List.filled(30, 60),
        customEquipment = customEquipment ?? List.filled(30, 0),
        phaseDurations = phaseDurations ?? List.filled(5, 60);

  static List<int> _defaultPlan() => [
        5, 5, 5, 5, 5,
        6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        15, 15, 15, 15, 15,
        14, 13, 12, 11, 10,
        10, 10, 10, 10, 10,
      ];

  String get planKey => [
    planMode.index,
    equipment.index,
    warmUpReps,
    peakReps,
    coolDownReps,
    ...phaseDurations,
    ...customPlan,
    ...customDurations,
    ...customEquipment,
  ].join(',');

  List<int> buildPlan() {
    if (planMode == PlanMode.minuteExact) return List<int>.from(customPlan);
    return _buildPhasePlan();
  }

  List<int> buildDurations() {
    if (planMode == PlanMode.minuteExact) return List<int>.from(customDurations);
    return _buildPhaseDurations();
  }

  List<int> _buildPhasePlan() {
    final plan = <int>[];
    for (int i = 0; i < 5; i++) { plan.add(warmUpReps); }
    for (int i = 1; i <= 10; i++) {
      plan.add(warmUpReps + ((peakReps - warmUpReps) * i / 10).round());
    }
    for (int i = 0; i < 5; i++) { plan.add(peakReps); }
    for (int i = 1; i <= 5; i++) {
      plan.add(peakReps - ((peakReps - coolDownReps) * i / 5).round());
    }
    for (int i = 0; i < 5; i++) { plan.add(coolDownReps); }
    return plan;
  }

  List<int> _buildPhaseDurations() {
    const counts = [5, 10, 5, 5, 5];
    final result = <int>[];
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < counts[i]; j++) {
        result.add(phaseDurations[i]);
      }
    }
    return result;
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    List<int>? customPlan;
    final cpJson = prefs.getString('customPlan');
    if (cpJson != null) customPlan = List<int>.from(jsonDecode(cpJson));

    List<int>? customDurations;
    final cdJson = prefs.getString('customDurations');
    if (cdJson != null) customDurations = List<int>.from(jsonDecode(cdJson));

    List<int>? customEquipment;
    final ceJson = prefs.getString('customEquipment');
    if (ceJson != null) customEquipment = List<int>.from(jsonDecode(ceJson));

    List<int>? phaseDurations;
    final pdJson = prefs.getString('phaseDurations');
    if (pdJson != null) phaseDurations = List<int>.from(jsonDecode(pdJson));

    return AppSettings(
      vibrationEnabled: prefs.getBool('vibrationEnabled') ?? true,
      warningTonesEnabled: prefs.getBool('warningTonesEnabled') ?? true,
      alarmEnabled: prefs.getBool('alarmEnabled') ?? true,
      volumeBoostEnabled: prefs.getBool('volumeBoostEnabled') ?? true,
      volumeBoostLevel: prefs.getDouble('volumeBoostLevel') ?? 1.0,
      countdownSoundFile: prefs.getString('countdownSoundFile') ?? 'tick.wav',
      alarmSoundFile: prefs.getString('alarmSoundFile') ?? 'alarm.wav',
      planMode: PlanMode.values[prefs.getInt('planMode') ?? 0],
      equipment: Equipment.values[prefs.getInt('equipment') ?? 0],
      warmUpReps: prefs.getInt('warmUpReps') ?? 5,
      peakReps: prefs.getInt('peakReps') ?? 15,
      coolDownReps: prefs.getInt('coolDownReps') ?? 10,
      phaseDurations: phaseDurations,
      customPlan: customPlan,
      customDurations: customDurations,
      customEquipment: customEquipment,
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
    await prefs.setInt('planMode', planMode.index);
    await prefs.setInt('equipment', equipment.index);
    await prefs.setInt('warmUpReps', warmUpReps);
    await prefs.setInt('peakReps', peakReps);
    await prefs.setInt('coolDownReps', coolDownReps);
    await prefs.setString('phaseDurations', jsonEncode(phaseDurations));
    await prefs.setString('customPlan', jsonEncode(customPlan));
    await prefs.setString('customDurations', jsonEncode(customDurations));
    await prefs.setString('customEquipment', jsonEncode(customEquipment));
  }
}
