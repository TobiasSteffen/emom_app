import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'core/providers/calendar_notifier.dart';
import 'core/providers/plan_library_notifier.dart';
import 'core/providers/series_notifier.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/workout/workout_screen.dart';

class KettlebellApp extends ConsumerStatefulWidget {
  const KettlebellApp({super.key});

  @override
  ConsumerState<KettlebellApp> createState() => _KettlebellAppState();
}

class _KettlebellAppState extends ConsumerState<KettlebellApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the screen awake while the app is in the foreground.
    WakelockPlus.enable();
    _initReminders();
  }

  Future<void> _initReminders() async {
    // Erst alle Provider laden — beim Kaltstart sind sie noch leer.
    await ref.read(settingsProvider.future);
    await ref.read(calendarProvider.future);
    await ref.read(seriesProvider.future);
    await ref.read(planLibraryProvider.future);
    // KettlebellApp hält einen WidgetRef, daher die Widget-Variante.
    await rescheduleRemindersWidget(ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hold the wakelock only while resumed; release it when backgrounded so
    // the screen can sleep normally when the app isn't visible.
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kettlebell EMOM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppTheme.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.accent,
          secondary: AppTheme.accent,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppTheme.surfaceHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppTheme.surfaceLow,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
          ),
        ),
      ),
      home: const WorkoutScreen(),
    );
  }
}
