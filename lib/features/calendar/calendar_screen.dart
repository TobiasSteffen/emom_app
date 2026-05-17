import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const CalendarScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        leading: IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white38),
          onPressed: onBack,
        ),
        title: const Text('Kalender',
            style: TextStyle(fontSize: 14, letterSpacing: 1, color: Colors.white54)),
      ),
      body: const Center(
        child: Text('Kalender — coming soon',
            style: TextStyle(color: Colors.white24)),
      ),
    );
  }
}
