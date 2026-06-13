import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/calendar_entry.dart';
import '../models/reminder_planner.dart';
import '../models/settings.dart';
import '../models/training_plan.dart';
import '../models/training_series.dart';
import '../providers/calendar_notifier.dart';
import '../providers/plan_library_notifier.dart';
import '../providers/series_notifier.dart';
import '../providers/settings_provider.dart';

/// Plant lokale Erinnerungen für geplante Trainingstage. Rollierendes
/// 30-Tage-Fenster, weil Serien unendlich sind: bei jedem App-Start und
/// nach jeder Änderung wird alles storniert und neu geplant.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: android),
      );
      _initialized = true;
    } catch (_) {
      // Plattform ohne Notification-Support (Tests, Desktop) — still bleiben.
    }
    return _initialized;
  }

  /// Fragt die Android-13+-Notification-Permission an. true, wenn erteilt
  /// oder die Plattform keine Anfrage kennt.
  Future<bool> requestPermission() async {
    if (!await _ensureInitialized()) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? true;
  }

  Future<void> rescheduleAll({
    required AppSettings settings,
    required List<CalendarEntry> entries,
    required List<TrainingSeries> series,
    required List<TrainingPlan> plans,
  }) async {
    if (!await _ensureInitialized()) return;
    await _plugin.cancelAll();
    if (!settings.trainingReminderEnabled) return;

    final occurrences = upcomingReminders(
      now: DateTime.now(),
      reminderMinutes: settings.trainingReminderMinutes,
      entries: entries,
      series: series,
    );
    var id = 0;
    for (final occ in occurrences) {
      var planName = 'Training';
      for (final p in plans) {
        if (p.id == occ.planId) {
          planName = p.name;
          break;
        }
      }
      await _plugin.zonedSchedule(
        id: id++,
        title: 'Training geplant',
        body: 'Heute geplant: $planName',
        scheduledDate: tz.TZDateTime.from(occ.dateTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'training_reminder',
            'Trainings-Erinnerung',
            channelDescription: 'Erinnert an geplante Trainings',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

/// Plant alle Erinnerungen anhand der aktuellen Provider-Zustände neu.
/// Wird aus den Notifiern mit deren `ref` aufgerufen. Das App-Widget hält nur
/// einen `WidgetRef` und ruft daher `NotificationService.rescheduleAll` direkt.
Future<void> rescheduleReminders(Ref ref) async {
  final settings = ref.read(settingsProvider).value;
  if (settings == null) return;
  final entries =
      ref.read(calendarProvider).value ?? const <CalendarEntry>[];
  final series = ref.read(seriesProvider).value ?? const <TrainingSeries>[];
  final plans =
      ref.read(planLibraryProvider).value?.plans ?? const <TrainingPlan>[];
  await NotificationService.instance.rescheduleAll(
    settings: settings,
    entries: entries,
    series: series,
    plans: plans,
  );
}

/// Variante für Widgets, die nur einen [WidgetRef] halten (Riverpod trennt
/// `Ref` und `WidgetRef` ohne gemeinsamen Obertyp).
Future<void> rescheduleRemindersWidget(WidgetRef ref) async {
  final settings = ref.read(settingsProvider).value;
  if (settings == null) return;
  final entries =
      ref.read(calendarProvider).value ?? const <CalendarEntry>[];
  final series = ref.read(seriesProvider).value ?? const <TrainingSeries>[];
  final plans =
      ref.read(planLibraryProvider).value?.plans ?? const <TrainingPlan>[];
  await NotificationService.instance.rescheduleAll(
    settings: settings,
    entries: entries,
    series: series,
    plans: plans,
  );
}
