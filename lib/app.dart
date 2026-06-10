import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'features/workout/workout_screen.dart';

class KettlebellApp extends StatefulWidget {
  const KettlebellApp({super.key});

  @override
  State<KettlebellApp> createState() => _KettlebellAppState();
}

class _KettlebellAppState extends State<KettlebellApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the screen awake while the app is in the foreground.
    WakelockPlus.enable();
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
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B00),
          secondary: Color(0xFFFF6B00),
        ),
      ),
      home: const WorkoutScreen(),
    );
  }
}
