# Riverpod Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `main.dart` und `config_screen.dart` (~1000 Zeilen je) in eine feature-basierte Struktur mit `@riverpod` code generation aufteilen — ohne UI-Änderungen.

**Architecture:** `WorkoutNotifier` (AsyncNotifier) übernimmt Timer/Audio/Wakelock-Logik. `SettingsNotifier` + `HistoryNotifier` als shared provider. WorkoutScreen und ConfigScreen werden zu `ConsumerStatefulWidget`s die nur noch Widgets komponieren.

**Tech Stack:** Flutter, flutter_riverpod ^2.6.1, riverpod_annotation ^2.3.5, riverpod_generator ^2.4.3, build_runner ^2.4.9

---

## Dateiübersicht (Zielzustand)

| Pfad | Verantwortung |
|------|---------------|
| `lib/main.dart` | `ProviderScope` + `runApp` + `initializeDateFormatting` |
| `lib/app.dart` | `KettlebellApp` Widget (MaterialApp + Theme) |
| `lib/core/models/settings.dart` | `AppSettings`, `PlanMode`, `Equipment`, `phaseColorForMinute()` |
| `lib/core/models/workout_history.dart` | `WorkoutRecord`, `IntervalRecord`, `WorkoutHistory` |
| `lib/core/providers/settings_provider.dart` | `@riverpod SettingsNotifier` |
| `lib/features/workout/workout_screen.dart` | `ConsumerStatefulWidget` — PageView + Komposition |
| `lib/features/workout/workout_notifier.dart` | `WorkoutState` + `@riverpod WorkoutNotifier` |
| `lib/features/workout/widgets/workout_header.dart` | Phasenlabel, History-Icon, Settings-Icon |
| `lib/features/workout/widgets/overall_progress.dart` | Fortschrittsbalken + Minute X/30 |
| `lib/features/workout/widgets/reps_card.dart` | Große Reps-Karte mit ScaleTransition |
| `lib/features/workout/widgets/timer_display.dart` | Countdown + sekündlicher Balken |
| `lib/features/workout/widgets/next_minute_preview.dart` | „Nächste Minute: X Reps" |
| `lib/features/workout/widgets/confirmation_overlay.dart` | Zwischen-Intervall-Overlay |
| `lib/features/workout/widgets/finished_screen.dart` | Abschlussscreen |
| `lib/features/config/config_screen.dart` | `ConsumerStatefulWidget` — TabBar + TabBarView |
| `lib/features/config/widgets/plan_mode_selector.dart` | Phasen-basiert / Minuten-genau |
| `lib/features/config/widgets/equipment_selector.dart` | Kettlebell / Steel Mace |
| `lib/features/config/widgets/phase_based_editor.dart` | Phasen-Tabelle + _inlineStepRow |
| `lib/features/config/widgets/minute_exact_editor.dart` | 30-Minuten-Liste + Gesamt-Footer |
| `lib/features/config/widgets/minute_row.dart` | Einzelne Zeile (war `_MinuteRow`) |
| `lib/features/config/widgets/feedback_tab.dart` | Lautstärke, Warntöne, Alarm, Vibration |
| `lib/features/config/widgets/sound_picker_dialog.dart` | Sound-Auswahl-Dialog |
| `lib/features/history/history_notifier.dart` | `@riverpod HistoryNotifier` |
| `lib/features/history/history_sheet.dart` | Bottom Sheet Liste |
| `lib/features/history/history_detail_sheet.dart` | Bottom Sheet Detail |

---

## Task 1: Riverpod Dependencies + ProviderScope

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

- [ ] **Schritt 1: Dependencies hinzufügen**

In `pubspec.yaml` unter `dependencies` ergänzen:
```yaml
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.3.5
```

Unter `dev_dependencies` ergänzen:
```yaml
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.9
```

- [ ] **Schritt 2: Packages installieren**

```bash
flutter pub get
```

Erwartete Ausgabe: `Got dependencies!`

- [ ] **Schritt 3: ProviderScope in main.dart einbauen**

`lib/main.dart` — nur die `main()`-Funktion und den `KettlebellApp`-Aufruf ändern. Die `KettlebellApp`-Klasse bleibt vorerst unverändert. Import `flutter_riverpod` hinzufügen:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

`main()` anpassen — Settings werden noch direkt geladen (wird in Task 3 entfernt):
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  final settings = await AppSettings.load();
  runApp(ProviderScope(child: KettlebellApp(settings: settings)));
}
```

- [ ] **Schritt 4: Analysieren**

```bash
flutter analyze
```

Erwartete Ausgabe: `No issues found!`

- [ ] **Schritt 5: Committen**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "chore: add riverpod dependencies, wrap app with ProviderScope"
```

---

## Task 2: Models nach core/models/ verschieben + planKey

**Files:**
- Create: `lib/core/models/settings.dart` (Inhalt von `lib/settings.dart`)
- Create: `lib/core/models/workout_history.dart` (Inhalt von `lib/workout_history.dart`)
- Delete: `lib/settings.dart`, `lib/workout_history.dart`
- Modify: `lib/main.dart` (Imports)
- Modify: `lib/config_screen.dart` (Imports)

- [ ] **Schritt 1: Verzeichnis erstellen**

```bash
New-Item -ItemType Directory -Force lib/core/models
```

- [ ] **Schritt 2: settings.dart nach core/models/ kopieren + planKey ergänzen**

Datei `lib/core/models/settings.dart` erstellen mit identischem Inhalt wie `lib/settings.dart`, plus folgenden Getter in der `AppSettings`-Klasse hinzufügen (nach `coolDownReps`):

```dart
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
```

- [ ] **Schritt 3: workout_history.dart nach core/models/ kopieren**

Datei `lib/core/models/workout_history.dart` erstellen — identischer Inhalt wie `lib/workout_history.dart`.

- [ ] **Schritt 4: Imports in main.dart aktualisieren**

```dart
// Alt:
import 'settings.dart';
import 'config_screen.dart';
import 'workout_history.dart';

// Neu:
import 'core/models/settings.dart';
import 'config_screen.dart';
import 'core/models/workout_history.dart';
```

- [ ] **Schritt 5: Imports in config_screen.dart aktualisieren**

```dart
// Alt:
import 'settings.dart';

// Neu:
import 'core/models/settings.dart';
```

- [ ] **Schritt 6: Alte Dateien löschen**

```bash
Remove-Item lib/settings.dart
Remove-Item lib/workout_history.dart
```

- [ ] **Schritt 7: Analysieren**

```bash
flutter analyze
```

Erwartete Ausgabe: `No issues found!`

- [ ] **Schritt 8: Committen**

```bash
git add lib/core/ lib/main.dart lib/config_screen.dart
git rm lib/settings.dart lib/workout_history.dart
git commit -m "refactor: move models to core/models/, add AppSettings.planKey"
```

---

## Task 3: SettingsNotifier + build_runner + WorkoutScreen/ConfigScreen auf Provider umstellen

**Files:**
- Create: `lib/core/providers/settings_provider.dart`
- Create: `lib/core/providers/settings_provider.g.dart` (generiert)
- Modify: `lib/main.dart`
- Modify: `lib/config_screen.dart`

- [ ] **Schritt 1: Verzeichnis erstellen**

```bash
New-Item -ItemType Directory -Force lib/core/providers
```

- [ ] **Schritt 2: SettingsNotifier erstellen**

`lib/core/providers/settings_provider.dart`:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/settings.dart';

part 'settings_provider.g.dart';

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<AppSettings> build() => AppSettings.load();

  void update(AppSettings settings) => state = AsyncData(settings);

  Future<void> save() async {
    final s = state.valueOrNull;
    if (s != null) await s.save();
  }
}
```

- [ ] **Schritt 3: build_runner ausführen**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Erwartete Ausgabe: Generiert `lib/core/providers/settings_provider.g.dart`.

- [ ] **Schritt 4: main.dart — Settings-Laden entfernen, KettlebellApp ohne Settings**

`lib/main.dart` — `main()` und `KettlebellApp` ersetzen:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/models/settings.dart';
import 'core/models/workout_history.dart';
import 'core/providers/settings_provider.dart';
import 'config_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  runApp(const ProviderScope(child: KettlebellApp()));
}

class KettlebellApp extends StatelessWidget {
  const KettlebellApp({super.key});

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
```

- [ ] **Schritt 5: WorkoutScreen zu ConsumerStatefulWidget machen**

`WorkoutScreen` und `_WorkoutScreenState` in `main.dart` anpassen:

```dart
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen>
    with TickerProviderStateMixin {
```

Alle `widget.settings` Zugriffe durch `ref.watch(settingsNotifierProvider).requireValue` ersetzen. Die `_settings`-Feld-Initialisierung in `initState` entfällt. Stattdessen `build()` wie folgt anpassen — oben in der `build()`-Methode settings lesen:

```dart
@override
Widget build(BuildContext context) {
  final settingsAsync = ref.watch(settingsNotifierProvider);
  return settingsAsync.when(
    loading: () => const Scaffold(
      backgroundColor: Color(0xFF000000),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
    ),
    error: (e, s) => Scaffold(body: Center(child: Text('$e'))),
    data: (settings) {
      // _plan und _durations müssen jetzt aus settings bezogen werden
      // Statt lokaler Felder wird _plan / _durations via settings gebaut
      // Vorübergehend: wenn settings sich ändert, reset auslösen
      return PageView(/* ... wie bisher ... */);
    },
  );
}
```

**Wichtig:** `_plan`, `_durations`, `_settings` als lokale Felder in `_WorkoutScreenState` bleiben vorerst bestehen — sie werden in Task 5/6 entfernt. Füge nur `late AppSettings _settings;` als Feld hinzu und weise es in `build()` zu: `_settings = settings;`. Dies ist ein Zwischenzustand.

- [ ] **Schritt 6: ConfigScreen zu ConsumerStatefulWidget machen**

In `lib/config_screen.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/settings_provider.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  final int visitCount;
  const ConfigScreen({super.key, this.visitCount = 0});
  // settings, onSave, onPlanChanged entfallen

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen>
    with SingleTickerProviderStateMixin {
  // _s wird jetzt aus dem Provider gelesen
```

In `initState()` — `_s = widget.settings` ersetzen durch settings aus Provider in build():

In `_ConfigScreenState.build()` oben:
```dart
@override
Widget build(BuildContext context) {
  final settingsAsync = ref.watch(settingsNotifierProvider);
  final s = settingsAsync.valueOrNull;
  if (s == null) return const SizedBox();
  // Überall wo vorher _s stand, nun direkt s verwenden
  // Für Mutationen: ref.read(settingsNotifierProvider.notifier).update(s.copyWith(...))
```

**Hinweis:** Da `AppSettings` mutable ist, kann `_s` als lokale Kopie beibehalten werden. Beim Verlassen der Config (Zurück-Button / Swipe) wird der aktuelle Stand via `update()` in den Provider geschrieben. Die `_save()`-Methode des ConfigScreen ruft jetzt `ref.read(settingsNotifierProvider.notifier).update(_s)` statt `widget.onSave(_s)`.

In WorkoutScreen — den ConfigScreen-Aufruf im PageView anpassen:
```dart
ConfigScreen(visitCount: _configVisitCount)
// statt:
// ConfigScreen(visitCount: _configVisitCount, settings: _settings, onSave: ..., onPlanChanged: ...)
```

Im `onPageChanged`-Handler von WorkoutScreen, wenn `page == 0`:
```dart
if (page == 0 && _configWasOpened) {
  _configWasOpened = false;
  await ref.read(settingsNotifierProvider.notifier).save();
  final newSettings = ref.read(settingsNotifierProvider).requireValue;
  final changed = newSettings.planKey != _planKeySnapshot;
  if (!changed) {
    if (_wasRunningBeforeConfig && !_isFinished) _start();
  } else {
    final wasActive = _wasRunningBeforeConfig || _currentMinute > 0;
    if (wasActive) {
      _showResetConfirmDialog();
    } else {
      _reset();
    }
  }
}
```

Im `onPageChanged`-Handler, wenn `page == 1`:
```dart
if (page == 1) {
  final settings = ref.read(settingsNotifierProvider).requireValue;
  setState(() {
    _configWasOpened = true;
    _wasRunningBeforeConfig = _isRunning || _waitingForConfirmation;
    _planKeySnapshot = settings.planKey;   // statt _planKey()
    _configVisitCount++;
  });
  if (_isRunning) _pause();
}
```

Die `_planKey()`-Methode und `_planKeySnapshot`-Felder in `_WorkoutScreenState` bleiben. `_planKey()` wird durch `settings.planKey` ersetzt — die Methode kann entfernt werden.

- [ ] **Schritt 7: Analysieren**

```bash
flutter analyze
```

Erwartete Ausgabe: `No issues found!`

- [ ] **Schritt 8: Committen**

```bash
git add lib/core/providers/ lib/main.dart lib/config_screen.dart
git commit -m "feat: add SettingsNotifier, convert WorkoutScreen + ConfigScreen to ConsumerStatefulWidget"
```

---

## Task 4: HistoryNotifier + History Sheets auslagern

**Files:**
- Create: `lib/features/history/history_notifier.dart`
- Create: `lib/features/history/history_notifier.g.dart` (generiert)
- Create: `lib/features/history/history_sheet.dart`
- Create: `lib/features/history/history_detail_sheet.dart`
- Modify: `lib/main.dart` (History-Methoden entfernen, Sheet importieren)

- [ ] **Schritt 1: Verzeichnis erstellen**

```bash
New-Item -ItemType Directory -Force lib/features/history
```

- [ ] **Schritt 2: HistoryNotifier erstellen**

`lib/features/history/history_notifier.dart`:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/models/workout_history.dart';

part 'history_notifier.g.dart';

@riverpod
class HistoryNotifier extends _$HistoryNotifier {
  @override
  Future<List<WorkoutRecord>> build() => WorkoutHistory.load();

  Future<void> addOrUpdate(WorkoutRecord record) async {
    await WorkoutHistory.addOrUpdateRecord(record);
    ref.invalidateSelf();
  }
}
```

- [ ] **Schritt 3: build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Schritt 4: HistorySheet erstellen**

`lib/features/history/history_sheet.dart` — extrahiert aus `_showHistory` + `_buildHistoryCard` in `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/workout_history.dart';
import '../../core/models/settings.dart';
import 'history_notifier.dart';
import 'history_detail_sheet.dart';

class HistorySheet extends ConsumerWidget {
  const HistorySheet({super.key});

  String _formatDateTime(DateTime dt) =>
      DateFormat("EE, d. MMMM yyyy  HH:mm", 'de').format(dt);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyNotifierProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'VERLAUF',
                style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 3),
              ),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => const SizedBox(),
              data: (records) => records.isEmpty
                  ? const Center(
                      child: Text(
                        'Noch keine Trainings gespeichert',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: records.length,
                      itemBuilder: (ctx, i) => GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(0xFF0D0D0D),
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => HistoryDetailSheet(record: records[i]),
                        ),
                        child: _buildCard(records[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(WorkoutRecord record) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final planModeStr = record.planMode == 0 ? 'Phasenbasiert' : 'Minuten-genau';
    final kbReps = record.kettlebellReps;
    final smReps = record.steelMaceReps;
    final equipStr = kbReps > 0 && smReps > 0
        ? 'Kettlebell + Steel Mace'
        : kbReps > 0 ? 'Kettlebell' : 'Steel Mace';
    final totalSecs = record.totalDurationSeconds;
    final durStr = '${totalSecs ~/ 60}m ${(totalSecs % 60).toString().padLeft(2, '0')}s';
    final repBreakdown = kbReps > 0 && smReps > 0 ? '  ·  $kbReps× KB  /  $smReps× SM' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatDateTime(dt),
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 6),
          Text('$equipStr · $planModeStr · ${record.intervals.length}/30 Intervalle',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${record.totalReps} Reps  ·  $durStr$repBreakdown',
              style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 13)),
        ],
      ),
    );
  }
}
```

- [ ] **Schritt 5: HistoryDetailSheet erstellen**

`lib/features/history/history_detail_sheet.dart` — extrahiert aus `_showHistoryDetail` in `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/workout_history.dart';
import '../../core/models/settings.dart';

class HistoryDetailSheet extends StatelessWidget {
  final WorkoutRecord record;
  const HistoryDetailSheet({super.key, required this.record});

  String _formatDateTime(DateTime dt) =>
      DateFormat("EE, d. MMMM yyyy  HH:mm", 'de').format(dt);

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final kbReps = record.kettlebellReps;
    final smReps = record.steelMaceReps;
    final totalSecs = record.totalDurationSeconds;
    final durStr = '${totalSecs ~/ 60}m ${(totalSecs % 60).toString().padLeft(2, '0')}s';
    final repBreakdown = kbReps > 0 && smReps > 0
        ? '${kbReps}× KB  /  ${smReps}× SM'
        : '${record.totalReps} Reps';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDateTime(dt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${record.intervals.length}/30 Intervalle',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('$repBreakdown  ·  $durStr',
                        style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: record.intervals.length,
              itemBuilder: (ctx, i) {
                final iv = record.intervals[i];
                final color = phaseColorForMinute(i);
                final isKb = iv.equipment == 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 52,
                        child: Text('Min ${i + 1}',
                            style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                      Image.asset(
                        isKb ? 'assets/icon/kettlebell.png' : 'assets/icon/steelmace.png',
                        width: 14, height: 14, color: Colors.white38,
                      ),
                      const SizedBox(width: 10),
                      Text('${iv.reps} Reps',
                          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${iv.durationSeconds}s',
                          style: const TextStyle(color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Schritt 6: _showHistory + History-Methoden in main.dart ersetzen**

In `lib/main.dart` folgende Imports ergänzen:
```dart
import 'features/history/history_sheet.dart';
```

Die Methoden `_showHistory`, `_showHistoryDetail`, `_buildHistoryCard` und `_formatDateTime` aus `_WorkoutScreenState` entfernen. `_showHistory`-Aufruf ersetzen durch:

```dart
void _showHistory() {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0D0D0D),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const HistorySheet(),
  );
}
```

Die `_saveHistoryIfEligible`-Methode in `_WorkoutScreenState` auf `HistoryNotifier` umstellen:

```dart
Future<void> _saveHistoryIfEligible() async {
  if (_completedIntervals.length < 2 || _workoutStartTime == null) return;
  final record = WorkoutRecord(
    timestamp: _workoutStartTime!.millisecondsSinceEpoch,
    planMode: _settings.planMode.index,
    intervals: List.from(_completedIntervals),
  );
  await ref.read(historyNotifierProvider.notifier).addOrUpdate(record);
}
```

Import für HistoryNotifier in main.dart:
```dart
import 'features/history/history_notifier.dart';
```

- [ ] **Schritt 7: Analysieren**

```bash
flutter analyze
```

Erwartete Ausgabe: `No issues found!`

- [ ] **Schritt 8: Committen**

```bash
git add lib/features/history/ lib/main.dart
git commit -m "feat: extract HistoryNotifier, HistorySheet, HistoryDetailSheet"
```

---

## Task 5: WorkoutState + WorkoutNotifier

**Files:**
- Create: `lib/features/workout/workout_notifier.dart`
- Create: `lib/features/workout/workout_notifier.g.dart` (generiert)

Dies ist der größte Einzelschritt: Die gesamte Timer-/Audio-/Wakelock-Logik aus `_WorkoutScreenState` wandert in den Notifier.

- [ ] **Schritt 1: Verzeichnis erstellen**

```bash
New-Item -ItemType Directory -Force lib/features/workout/widgets
```

- [ ] **Schritt 2: workout_notifier.dart erstellen**

`lib/features/workout/workout_notifier.dart` — komplette Datei:

```dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vibration/vibration.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/models/settings.dart';
import '../../core/models/workout_history.dart';
import '../../core/providers/settings_provider.dart';
import '../history/history_notifier.dart';

part 'workout_notifier.g.dart';

@immutable
class WorkoutState {
  final List<int> plan;
  final List<int> durations;
  final int currentMinute;
  final int secondsLeft;
  final bool isRunning;
  final bool isFinished;
  final bool waitingForConfirmation;
  final int totalRepsDone;
  final List<IntervalRecord> completedIntervals;
  final DateTime? workoutStartTime;

  const WorkoutState({
    required this.plan,
    required this.durations,
    required this.currentMinute,
    required this.secondsLeft,
    required this.isRunning,
    required this.isFinished,
    required this.waitingForConfirmation,
    required this.totalRepsDone,
    required this.completedIntervals,
    this.workoutStartTime,
  });

  int get totalMinutes => plan.length;
  int get currentReps => plan[currentMinute];
  int get currentDuration => durations[currentMinute];
  int get totalReps => plan.fold(0, (a, b) => a + b);

  WorkoutState copyWith({
    List<int>? plan,
    List<int>? durations,
    int? currentMinute,
    int? secondsLeft,
    bool? isRunning,
    bool? isFinished,
    bool? waitingForConfirmation,
    int? totalRepsDone,
    List<IntervalRecord>? completedIntervals,
    DateTime? workoutStartTime,
    bool clearWorkoutStartTime = false,
  }) =>
      WorkoutState(
        plan: plan ?? this.plan,
        durations: durations ?? this.durations,
        currentMinute: currentMinute ?? this.currentMinute,
        secondsLeft: secondsLeft ?? this.secondsLeft,
        isRunning: isRunning ?? this.isRunning,
        isFinished: isFinished ?? this.isFinished,
        waitingForConfirmation: waitingForConfirmation ?? this.waitingForConfirmation,
        totalRepsDone: totalRepsDone ?? this.totalRepsDone,
        completedIntervals: completedIntervals ?? this.completedIntervals,
        workoutStartTime: clearWorkoutStartTime ? null : (workoutStartTime ?? this.workoutStartTime),
      );
}

@riverpod
class WorkoutNotifier extends _$WorkoutNotifier {
  Timer? _timer;
  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  StreamSubscription? _alarmLoopSub;
  bool? _hasVibrator;
  late AppSettings _settings;

  @override
  Future<WorkoutState> build() async {
    _settings = await ref.read(settingsNotifierProvider.future);
    _hasVibrator = await Vibration.hasVibrator();

    ref.onDispose(() {
      _timer?.cancel();
      _alarmLoopSub?.cancel();
      _tickPlayer.dispose();
      _alarmPlayer.dispose();
      WakelockPlus.disable();
    });

    final plan = _settings.buildPlan();
    final durations = _settings.buildDurations();
    return WorkoutState(
      plan: plan,
      durations: durations,
      currentMinute: 0,
      secondsLeft: durations[0],
      isRunning: false,
      isFinished: false,
      waitingForConfirmation: false,
      totalRepsDone: 0,
      completedIntervals: const [],
    );
  }

  WorkoutState get _s => state.requireValue;

  void start() {
    final now = _s.workoutStartTime == null ? DateTime.now() : null;
    state = AsyncData(_s.copyWith(
      isRunning: true,
      workoutStartTime: now,
    ));
    WakelockPlus.enable();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void pause() {
    _timer?.cancel();
    WakelockPlus.disable();
    state = AsyncData(_s.copyWith(isRunning: false));
  }

  void reset([AppSettings? newSettings]) {
    _timer?.cancel();
    _alarmLoopSub?.cancel();
    _alarmLoopSub = null;
    _alarmPlayer.stop();
    WakelockPlus.disable();
    if (newSettings != null) _settings = newSettings;
    final plan = _settings.buildPlan();
    final durations = _settings.buildDurations();
    state = AsyncData(WorkoutState(
      plan: plan,
      durations: durations,
      currentMinute: 0,
      secondsLeft: durations[0],
      isRunning: false,
      isFinished: false,
      waitingForConfirmation: false,
      totalRepsDone: 0,
      completedIntervals: const [],
    ));
  }

  void confirmInterval() {
    _alarmLoopSub?.cancel();
    _alarmLoopSub = null;
    _alarmPlayer.stop();
    final nextMinute = _s.currentMinute + 1;
    state = AsyncData(_s.copyWith(
      waitingForConfirmation: false,
      currentMinute: nextMinute,
      secondsLeft: _s.durations[nextMinute],
    ));
    _vibrate(400);
    _saveHistory();
    start();
  }

  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    if (_s.isRunning || _s.waitingForConfirmation) return;
    final plan = newSettings.buildPlan();
    final durations = newSettings.buildDurations();
    state = AsyncData(_s.copyWith(
      plan: plan,
      durations: durations,
      secondsLeft: durations[_s.currentMinute],
    ));
  }

  Equipment equipmentForMinute(int minute) {
    if (_settings.planMode == PlanMode.minuteExact) {
      return Equipment.values[_settings.customEquipment[minute]];
    }
    return _settings.equipment;
  }

  String exerciseLabelForMinute(int minute) =>
      equipmentForMinute(minute) == Equipment.kettlebell ? 'Swings' : '360s';

  void _tick(Timer timer) {
    final newSeconds = _s.secondsLeft - 1;
    if (newSeconds <= 0) {
      state = AsyncData(_s.copyWith(secondsLeft: 0));
      _onMinuteComplete();
    } else {
      state = AsyncData(_s.copyWith(secondsLeft: newSeconds));
      if (newSeconds <= 5 && _settings.warningTonesEnabled) {
        if (newSeconds == 5) _raiseVolume();
        _playTickSound();
      }
    }
  }

  Future<void> _raiseVolume() async {
    if (!_settings.volumeBoostEnabled || _settings.volumeBoostLevel <= 0) return;
    try {
      final current = await VolumeController().getVolume();
      if (current < _settings.volumeBoostLevel) {
        VolumeController().setVolume(_settings.volumeBoostLevel, showSystemUI: false);
      }
    } catch (_) {}
  }

  void _onMinuteComplete() {
    _timer?.cancel();
    final s = _s;
    final newTotalReps = s.totalRepsDone + s.currentReps;
    final newIntervals = [
      ...s.completedIntervals,
      IntervalRecord(
        reps: s.currentReps,
        durationSeconds: s.currentDuration,
        equipment: equipmentForMinute(s.currentMinute).index,
      ),
    ];

    if (s.currentMinute >= s.totalMinutes - 1) {
      state = AsyncData(s.copyWith(
        isFinished: true,
        isRunning: false,
        totalRepsDone: newTotalReps,
        completedIntervals: newIntervals,
      ));
      WakelockPlus.disable();
      _vibrate(600);
      _saveHistory(intervals: newIntervals, startTime: s.workoutStartTime);
    } else {
      state = AsyncData(s.copyWith(
        isRunning: false,
        waitingForConfirmation: true,
        totalRepsDone: newTotalReps,
        completedIntervals: newIntervals,
      ));
      _playAlarm();
    }
  }

  Source _soundSource(String f) =>
      f.startsWith('/') ? DeviceFileSource(f) : AssetSource('sounds/$f');

  Future<void> _playTickSound() async {
    try {
      await _tickPlayer.play(_soundSource(_settings.countdownSoundFile));
    } catch (_) {}
  }

  Future<void> _playAlarm() async {
    if (_hasVibrator == true && _settings.vibrationEnabled) {
      Vibration.vibrate(duration: 800);
    }
    if (!_settings.alarmEnabled) return;

    Future<void> playOnce() async {
      try {
        await _alarmPlayer.setReleaseMode(ReleaseMode.release);
        await _alarmPlayer.play(_soundSource(_settings.alarmSoundFile));
      } catch (_) {
        SystemSound.play(SystemSoundType.click);
      }
    }

    await _alarmLoopSub?.cancel();
    _alarmLoopSub = _alarmPlayer.onPlayerComplete.listen((_) async {
      if (!_s.waitingForConfirmation) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (_s.waitingForConfirmation) await playOnce();
    });
    await playOnce();
  }

  void _vibrate(int durationMs) {
    if (!_settings.vibrationEnabled || _hasVibrator != true) return;
    Vibration.vibrate(duration: durationMs);
  }

  Future<void> _saveHistory({
    List<IntervalRecord>? intervals,
    DateTime? startTime,
  }) async {
    final ivs = intervals ?? _s.completedIntervals;
    final t = startTime ?? _s.workoutStartTime;
    if (ivs.length < 2 || t == null) return;
    final record = WorkoutRecord(
      timestamp: t.millisecondsSinceEpoch,
      planMode: _settings.planMode.index,
      intervals: List.from(ivs),
    );
    await ref.read(historyNotifierProvider.notifier).addOrUpdate(record);
  }
}
```

- [ ] **Schritt 3: build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Schritt 4: Analysieren**

```bash
flutter analyze lib/features/workout/workout_notifier.dart
```

Erwartete Ausgabe: `No issues found!` (oder nur Warnungen über ungenutzte Felder — akzeptabel in diesem Zwischenzustand)

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/workout/
git commit -m "feat: add WorkoutState + WorkoutNotifier with full timer/audio/wakelock logic"
```

---

## Task 6: WorkoutScreen auf WorkoutNotifier umstellen

**Files:**
- Modify: `lib/main.dart` — `_WorkoutScreenState` komplett umschreiben

In diesem Task wird `_WorkoutScreenState` von ~600 Zeilen eigener Logik auf ~150 Zeilen reinen UI-Code reduziert. Die gesamte Logik steckt jetzt im `WorkoutNotifier`.

- [ ] **Schritt 1: Import für WorkoutNotifier in main.dart ergänzen**

```dart
import 'features/workout/workout_notifier.dart';
```

- [ ] **Schritt 2: _WorkoutScreenState auf WorkoutNotifier umstellen**

`_WorkoutScreenState` neu schreiben. Alle privaten Felder außer den folgenden entfernen:

**Beibehaltene lokale Felder:**
```dart
late AnimationController _pulseController;
late Animation<double> _pulseAnimation;
late PageController _pageController;
bool _configWasOpened = false;
bool _wasRunningBeforeConfig = false;
String _planKeySnapshot = '';
int _configVisitCount = 0;
```

**initState** — nur noch Controller initialisieren:
```dart
@override
void initState() {
  super.initState();
  _pulseController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
    CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
  );
  _pageController = PageController();
}
```

**dispose** — nur noch Controller disposen (Audio/Timer-Dispose ist jetzt im Notifier):
```dart
@override
void dispose() {
  _pulseController.dispose();
  _pageController.dispose();
  super.dispose();
}
```

**build** — auf AsyncValue.when umstellen:
```dart
@override
Widget build(BuildContext context) {
  final workoutAsync = ref.watch(workoutNotifierProvider);
  final settings = ref.watch(settingsNotifierProvider).valueOrNull;

  if (workoutAsync.isLoading || settings == null) {
    return const Scaffold(
      backgroundColor: Color(0xFF000000),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
    );
  }
  if (workoutAsync.hasError) {
    return Scaffold(body: Center(child: Text('${workoutAsync.error}')));
  }

  return _buildPageView(workoutAsync.requireValue, settings);
}
```

**_buildPageView** — Notifier-Methoden aufrufen statt eigene:
```dart
Widget _buildPageView(WorkoutState state, AppSettings settings) {
  final notifier = ref.read(workoutNotifierProvider.notifier);

  return PageView(
    controller: _pageController,
    physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
    dragStartBehavior: DragStartBehavior.down,
    onPageChanged: (page) {
      if (page == 1) {
        setState(() {
          _configWasOpened = true;
          _wasRunningBeforeConfig = state.isRunning || state.waitingForConfirmation;
          _planKeySnapshot = settings.planKey;
          _configVisitCount++;
        });
        if (state.isRunning) notifier.pause();
      }
      if (page == 0 && _configWasOpened) {
        _configWasOpened = false;
        final newSettings = ref.read(settingsNotifierProvider).requireValue;
        ref.read(settingsNotifierProvider.notifier).save();
        final changed = newSettings.planKey != _planKeySnapshot;
        if (!changed) {
          notifier.updateSettings(newSettings);
          if (_wasRunningBeforeConfig && !state.isFinished) notifier.start();
        } else {
          final wasActive = _wasRunningBeforeConfig || state.currentMinute > 0;
          if (wasActive) {
            _showResetConfirmDialog(newSettings);
          } else {
            notifier.reset(newSettings);
          }
        }
      }
    },
    children: [
      Scaffold(
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              state.isFinished ? _buildFinishedScreen(state, settings) : _buildWorkoutScreen(state, settings),
              if (state.waitingForConfirmation) _buildConfirmationOverlay(state, settings),
            ],
          ),
        ),
      ),
      ConfigScreen(visitCount: _configVisitCount),
    ],
  );
}
```

**_startStop** — delegiert an Notifier:
```dart
void _startStop(WorkoutState state) {
  final notifier = ref.read(workoutNotifierProvider.notifier);
  if (state.isFinished) { notifier.reset(); return; }
  if (state.waitingForConfirmation) {
    _pulseController.forward().then((_) => _pulseController.reverse());
    notifier.confirmInterval();
    return;
  }
  state.isRunning ? notifier.pause() : notifier.start();
}
```

**_showResetConfirmDialog** — reset via Notifier:
```dart
Future<void> _showResetConfirmDialog(AppSettings newSettings) async {
  final doReset = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Training zurücksetzen?',
          style: TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
      content: const Text(
          'Die Einstellungen wurden geändert. Das laufende Training zurücksetzen?',
          style: TextStyle(color: Colors.white38, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Weiter', style: TextStyle(color: Colors.white38)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Zurücksetzen', style: TextStyle(color: Color(0xFFFF6B00))),
        ),
      ],
    ),
  ) ?? false;
  if (doReset) ref.read(workoutNotifierProvider.notifier).reset(newSettings);
}
```

**_buildWorkoutScreen** — erhält `WorkoutState` und `AppSettings` als Parameter, keine eigenen Felder mehr:
```dart
Widget _buildWorkoutScreen(WorkoutState state, AppSettings settings) {
  final progress = state.currentMinute / state.totalMinutes;
  final secondProgress = (state.currentDuration - state.secondsLeft) / state.currentDuration;
  final isWarning = state.secondsLeft <= 5 && state.secondsLeft > 0 && state.isRunning;
  final notifier = ref.read(workoutNotifierProvider.notifier);
  final phaseColor = phaseColorForMinute(state.currentMinute);
  final exerciseLabel = notifier.exerciseLabelForMinute(state.currentMinute);
  final iconPath = notifier.equipmentForMinute(state.currentMinute) == Equipment.kettlebell
      ? 'assets/icon/kettlebell.png'
      : 'assets/icon/steelmace.png';

  // Restlicher Aufbau identisch mit dem bisherigen _buildWorkoutScreen,
  // aber statt _isRunning → state.isRunning, _currentMinute → state.currentMinute, etc.
  // _startStop() → _startStop(state)
  // _reset() → ref.read(workoutNotifierProvider.notifier).reset()
  // ... (gleiche Widget-Struktur wie bisher)
```

**_buildConfirmationOverlay** — liest aus WorkoutState:
```dart
Widget _buildConfirmationOverlay(WorkoutState state, AppSettings settings) {
  final nextMinute = state.currentMinute + 1;
  final notifier = ref.read(workoutNotifierProvider.notifier);
  final nextReps = state.plan[nextMinute];
  final nextColor = phaseColorForMinute(nextMinute);
  final nextLabel = notifier.exerciseLabelForMinute(nextMinute);
  // Widget-Aufbau identisch, onTap:
  // () { _pulseController.forward().then((_) => _pulseController.reverse()); notifier.confirmInterval(); }
```

**_buildFinishedScreen** — liest aus WorkoutState:
```dart
Widget _buildFinishedScreen(WorkoutState state, AppSettings settings) {
  final notifier = ref.read(workoutNotifierProvider.notifier);
  // state.totalReps statt totalReps getter
  // notifier.exerciseLabelForMinute(state.currentMinute) statt exerciseLabel
  // notifier.reset() statt _reset()
```

- [ ] **Schritt 3: Entfernte Methoden aus main.dart bereinigen**

Folgende Methoden/Felder aus `_WorkoutScreenState` löschen (sind jetzt im Notifier):
- `_timer`, `_tickPlayer`, `_alarmPlayer`, `_alarmLoopSub`, `_hasVibrator`
- `_plan`, `_durations`, `_isRunning`, `_isFinished`, `_waitingForConfirmation`, `_totalRepsDone`
- `_completedIntervals`, `_workoutStartTime`
- `_start()`, `_pause()`, `_reset()`, `_tick()`, `_raiseVolume()`
- `_onMinuteComplete()`, `_confirmInterval()`, `_vibrate()`, `_playTickSound()`, `_playAlarm()`
- `_saveHistoryIfEligible()`, `_planKey()`, `_soundSource()`
- Alle Getter: `totalMinutes`, `currentReps`, `currentDuration`, `totalReps`, `phaseColor`, `exerciseLabel`, `iconPath`, `phaseLabel`

- [ ] **Schritt 4: Analysieren**

```bash
flutter analyze
```

Erwartete Ausgabe: `No issues found!`

- [ ] **Schritt 5: Committen**

```bash
git add lib/main.dart
git commit -m "refactor: WorkoutScreen delegates all logic to WorkoutNotifier"
```

---

## Task 7: Workout-Widgets extrahieren

**Files:**
- Create: `lib/features/workout/widgets/workout_header.dart`
- Create: `lib/features/workout/widgets/overall_progress.dart`
- Create: `lib/features/workout/widgets/reps_card.dart`
- Create: `lib/features/workout/widgets/timer_display.dart`
- Create: `lib/features/workout/widgets/next_minute_preview.dart`
- Create: `lib/features/workout/widgets/confirmation_overlay.dart`
- Create: `lib/features/workout/widgets/finished_screen.dart`
- Modify: `lib/main.dart`

Für jeden Widget: Klasse erstellen, aus `_buildWorkoutScreen` extrahieren, im WorkoutScreen importieren und verwenden.

- [ ] **Schritt 1: workout_header.dart**

```dart
// lib/features/workout/widgets/workout_header.dart
import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class WorkoutHeader extends StatelessWidget {
  final int currentMinute;
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  const WorkoutHeader({
    super.key,
    required this.currentMinute,
    required this.onHistory,
    required this.onSettings,
  });

  String get _phaseLabel {
    if (currentMinute < 5) return 'Warm Up';
    if (currentMinute < 15) return 'Aufbau ↑';
    if (currentMinute < 20) return 'Peak';
    if (currentMinute < 25) return 'Abbau ↓';
    return 'Cool Down';
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = phaseColorForMinute(currentMinute);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('EMOM 30',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.6), letterSpacing: 3,
            )),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: phaseColor.withValues(alpha: 0.5)),
              ),
              child: Text(_phaseLabel,
                  style: TextStyle(color: phaseColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onHistory,
              child: const Icon(Icons.history, color: Colors.white24, size: 22),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onSettings,
              child: const Icon(Icons.settings, color: Colors.white24, size: 22),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Schritt 2: overall_progress.dart**

```dart
// lib/features/workout/widgets/overall_progress.dart
import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class OverallProgress extends StatelessWidget {
  final int currentMinute;
  final int totalMinutes;
  final int totalRepsDone;
  final int totalReps;
  final String exerciseLabel;

  const OverallProgress({
    super.key,
    required this.currentMinute,
    required this.totalMinutes,
    required this.totalRepsDone,
    required this.totalReps,
    required this.exerciseLabel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentMinute / totalMinutes;
    final phaseColor = phaseColorForMinute(currentMinute);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Minute ${currentMinute + 1} / $totalMinutes',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            Text('$totalRepsDone / $totalReps $exerciseLabel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Schritt 3: reps_card.dart**

```dart
// lib/features/workout/widgets/reps_card.dart
import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class RepsCard extends StatelessWidget {
  final int currentMinute;
  final int currentReps;
  final String exerciseLabel;
  final String iconPath;
  final Animation<double> pulseAnimation;

  const RepsCard({
    super.key,
    required this.currentMinute,
    required this.currentReps,
    required this.exerciseLabel,
    required this.iconPath,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final phaseColor = phaseColorForMinute(currentMinute);
    return ScaleTransition(
      scale: pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: phaseColor.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            Image.asset(iconPath, width: 48, height: 48, color: phaseColor),
            const SizedBox(height: 4),
            Text('REPS',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 14, letterSpacing: 4)),
            const SizedBox(height: 8),
            Text('$currentReps',
                style: TextStyle(
                    fontSize: 120, fontWeight: FontWeight.w900, color: phaseColor, height: 1)),
            const SizedBox(height: 8),
            Text(exerciseLabel,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Schritt 4: timer_display.dart**

```dart
// lib/features/workout/widgets/timer_display.dart
import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final int secondsLeft;
  final int currentDuration;
  final bool isRunning;

  const TimerDisplay({
    super.key,
    required this.secondsLeft,
    required this.currentDuration,
    required this.isRunning,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = secondsLeft <= 5 && secondsLeft > 0 && isRunning;
    final secondProgress = (currentDuration - secondsLeft) / currentDuration;
    return Column(
      children: [
        Text(
          _formatTime(secondsLeft),
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w300,
            color: isWarning ? const Color(0xFFFF4444) : Colors.white,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: secondProgress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              isWarning ? const Color(0xFFFF4444) : Colors.white24,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Schritt 5: next_minute_preview.dart**

```dart
// lib/features/workout/widgets/next_minute_preview.dart
import 'package:flutter/material.dart';

class NextMinutePreview extends StatelessWidget {
  final int nextReps;

  const NextMinutePreview({super.key, required this.nextReps});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Nächste Minute: $nextReps Reps',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
    );
  }
}
```

- [ ] **Schritt 6: confirmation_overlay.dart**

```dart
// lib/features/workout/widgets/confirmation_overlay.dart
import 'package:flutter/material.dart';

class ConfirmationOverlay extends StatelessWidget {
  final int nextReps;
  final Color nextColor;
  final String nextLabel;
  final int nextMinuteNumber;
  final VoidCallback onConfirm;

  const ConfirmationOverlay({
    super.key,
    required this.nextReps,
    required this.nextColor,
    required this.nextLabel,
    required this.nextMinuteNumber,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onConfirm,
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('INTERVALL BEENDET',
                  style: TextStyle(color: Colors.white24, fontSize: 11, letterSpacing: 4)),
              const SizedBox(height: 32),
              Text('$nextReps',
                  style: TextStyle(
                      fontSize: 96, fontWeight: FontWeight.w900, color: nextColor, height: 1)),
              Text(nextLabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 16)),
              Text('Minute $nextMinuteNumber',
                  style: const TextStyle(color: Colors.white24, fontSize: 13)),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: nextColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: nextColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: const Text('WEITER',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        letterSpacing: 3, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              const Text('oder irgendwo tippen',
                  style: TextStyle(color: Colors.white12, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Schritt 7: finished_screen.dart**

```dart
// lib/features/workout/widgets/finished_screen.dart
import 'package:flutter/material.dart';

class FinishedScreen extends StatelessWidget {
  final int totalReps;
  final String exerciseLabel;
  final VoidCallback onReset;

  const FinishedScreen({
    super.key,
    required this.totalReps,
    required this.exerciseLabel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            const Text('WORKOUT DONE!',
                style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w900,
                    color: Color(0xFFFF6B00), letterSpacing: 4)),
            const SizedBox(height: 16),
            Text('$totalReps $exerciseLabel',
                style: TextStyle(
                    fontSize: 20, color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    borderRadius: BorderRadius.circular(16)),
                child: const Text('Nochmal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Schritt 8: main.dart — Widgets verwenden**

In `lib/main.dart` Imports für alle 7 Widgets ergänzen:
```dart
import 'features/workout/widgets/workout_header.dart';
import 'features/workout/widgets/overall_progress.dart';
import 'features/workout/widgets/reps_card.dart';
import 'features/workout/widgets/timer_display.dart';
import 'features/workout/widgets/next_minute_preview.dart';
import 'features/workout/widgets/confirmation_overlay.dart';
import 'features/workout/widgets/finished_screen.dart';
```

`_buildWorkoutScreen` in `_WorkoutScreenState` auf die neuen Widgets umstellen:

```dart
Widget _buildWorkoutScreen(WorkoutState state, AppSettings settings) {
  final notifier = ref.read(workoutNotifierProvider.notifier);
  final phaseColor = phaseColorForMinute(state.currentMinute);
  final exerciseLabel = notifier.exerciseLabelForMinute(state.currentMinute);
  final iconPath = notifier.equipmentForMinute(state.currentMinute) == Equipment.kettlebell
      ? 'assets/icon/kettlebell.png'
      : 'assets/icon/steelmace.png';

  return Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        WorkoutHeader(
          currentMinute: state.currentMinute,
          onHistory: () => _showHistory(),
          onSettings: () => _pageController.animateToPage(1,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic),
        ),
        const SizedBox(height: 32),
        OverallProgress(
          currentMinute: state.currentMinute,
          totalMinutes: state.totalMinutes,
          totalRepsDone: state.totalRepsDone,
          totalReps: state.totalReps,
          exerciseLabel: exerciseLabel,
        ),
        const SizedBox(height: 48),
        RepsCard(
          currentMinute: state.currentMinute,
          currentReps: state.currentReps,
          exerciseLabel: exerciseLabel,
          iconPath: iconPath,
          pulseAnimation: _pulseAnimation,
        ),
        const SizedBox(height: 32),
        TimerDisplay(
          secondsLeft: state.secondsLeft,
          currentDuration: state.currentDuration,
          isRunning: state.isRunning,
        ),
        if (state.currentMinute < state.totalMinutes - 1) ...[
          const SizedBox(height: 16),
          NextMinutePreview(nextReps: state.plan[state.currentMinute + 1]),
        ],
        const Spacer(),
        Row(
          children: [
            IconButton(
              onPressed: () => notifier.reset(),
              icon: const Icon(Icons.refresh, color: Colors.white38, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _startStop(state),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: phaseColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: phaseColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

`_buildConfirmationOverlay` und `_buildFinishedScreen` auf neue Widgets umstellen:

```dart
Widget _buildConfirmationOverlay(WorkoutState state, AppSettings settings) {
  final notifier = ref.read(workoutNotifierProvider.notifier);
  final nextMinute = state.currentMinute + 1;
  return ConfirmationOverlay(
    nextReps: state.plan[nextMinute],
    nextColor: phaseColorForMinute(nextMinute),
    nextLabel: notifier.exerciseLabelForMinute(nextMinute),
    nextMinuteNumber: nextMinute + 1,
    onConfirm: () {
      _pulseController.forward().then((_) => _pulseController.reverse());
      notifier.confirmInterval();
    },
  );
}

Widget _buildFinishedScreen(WorkoutState state, AppSettings settings) {
  final notifier = ref.read(workoutNotifierProvider.notifier);
  return FinishedScreen(
    totalReps: state.totalReps,
    exerciseLabel: notifier.exerciseLabelForMinute(state.currentMinute),
    onReset: () => notifier.reset(),
  );
}
```

- [ ] **Schritt 9: Analysieren**

```bash
flutter analyze
```

Erwartete Ausgabe: `No issues found!`

- [ ] **Schritt 10: Committen**

```bash
git add lib/features/workout/widgets/ lib/main.dart
git commit -m "refactor: extract workout widgets into individual files"
```

---

## Task 8: Config-Widgets extrahieren

**Files:**
- Create: `lib/features/config/widgets/plan_mode_selector.dart`
- Create: `lib/features/config/widgets/equipment_selector.dart`
- Create: `lib/features/config/widgets/phase_based_editor.dart`
- Create: `lib/features/config/widgets/minute_exact_editor.dart`
- Create: `lib/features/config/widgets/minute_row.dart`
- Create: `lib/features/config/widgets/feedback_tab.dart`
- Create: `lib/features/config/widgets/sound_picker_dialog.dart`
- Modify: `lib/config_screen.dart`

- [ ] **Schritt 1: Verzeichnis erstellen**

```bash
New-Item -ItemType Directory -Force lib/features/config/widgets
```

- [ ] **Schritt 2: plan_mode_selector.dart**

```dart
// lib/features/config/widgets/plan_mode_selector.dart
import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class PlanModeSelector extends StatelessWidget {
  final PlanMode planMode;
  final ValueChanged<PlanMode> onChanged;

  const PlanModeSelector({
    super.key,
    required this.planMode,
    required this.onChanged,
  });

  Widget _radioBtn(String label, PlanMode mode) {
    final active = planMode == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E1E1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? const Color(0xFF333333) : const Color(0xFF1A1A1A)),
        ),
        child: Center(
          child: Text('${active ? "●" : "○"} $label',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: active ? Colors.white54 : Colors.white12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: _radioBtn('Phasen-basiert', PlanMode.phaseBased)),
          const SizedBox(width: 8),
          Expanded(child: _radioBtn('Minuten-genau', PlanMode.minuteExact)),
        ],
      ),
    );
  }
}
```

- [ ] **Schritt 3: equipment_selector.dart**

```dart
// lib/features/config/widgets/equipment_selector.dart
import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class EquipmentSelector extends StatelessWidget {
  final Equipment equipment;
  final ValueChanged<Equipment> onChanged;

  const EquipmentSelector({
    super.key,
    required this.equipment,
    required this.onChanged,
  });

  Widget _btn(String label, Equipment eq, String iconPath) {
    final active = equipment == eq;
    return GestureDetector(
      onTap: () => onChanged(eq),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E1E1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? const Color(0xFF333333) : const Color(0xFF1A1A1A)),
        ),
        child: Column(
          children: [
            Image.asset(iconPath, width: 32, height: 32,
                color: active ? const Color(0xFFFF6B00) : Colors.white12),
            const SizedBox(height: 6),
            Text('${active ? "●" : "○"} $label',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: active ? Colors.white54 : Colors.white12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: _btn('Kettlebell', Equipment.kettlebell, 'assets/icon/kettlebell.png')),
          const SizedBox(width: 8),
          Expanded(child: _btn('Steel Mace', Equipment.steelmace, 'assets/icon/steelmace.png')),
        ],
      ),
    );
  }
}
```

- [ ] **Schritt 4: minute_row.dart**

Datei `lib/features/config/widgets/minute_row.dart` erstellen — vollständiger Inhalt der privaten `_MinuteRow`- und `_MinuteRowState`-Klassen aus `lib/config_screen.dart` kopieren. Aus `private` (Unterstrich-Prefix) `public` machen:

```dart
// lib/features/config/widgets/minute_row.dart
import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

// Widget _stepButton() aus config_screen.dart hier ebenfalls inkludieren
// (oder aus shared utils importieren — für jetzt duplizieren)
Widget _stepButton(IconData icon, VoidCallback? onTap, {double size = 26}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(size / 4),
        ),
        child: Icon(icon,
            size: size / 2,
            color: onTap != null ? Colors.white38 : Colors.white12),
      ),
    );

class MinuteRow extends StatefulWidget {
  final int index;
  final AppSettings settings;
  final VoidCallback onChanged;
  final bool isSelected;
  final VoidCallback onSelect;

  const MinuteRow({
    super.key,
    required this.index,
    required this.settings,
    required this.onChanged,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<MinuteRow> createState() => _MinuteRowState();
}

class _MinuteRowState extends State<MinuteRow> {
  // Identischer Inhalt wie der bisherige _MinuteRowState,
  // außer dass _phaseColor() durch phaseColorForMinute() ersetzt wird
  // und _smallStepBtn() durch _stepButton() (top-level, weiter oben definiert)
  
  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final i = widget.index;
    final eq = Equipment.values[s.customEquipment[i]];
    final iconPath = eq == Equipment.kettlebell
        ? 'assets/icon/kettlebell.png'
        : 'assets/icon/steelmace.png';
    final color = phaseColorForMinute(i);

    return GestureDetector(
      onTap: widget.onSelect,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 6, height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(
              width: 42,
              child: Text('Min ${i + 1}',
                  style: TextStyle(
                      fontSize: 11,
                      color: widget.isSelected ? Colors.white38 : Colors.white24,
                      letterSpacing: 1)),
            ),
            const Spacer(),
            if (widget.isSelected) ...[
              SizedBox(
                width: 26, height: 26,
                child: PopupMenuButton<int>(
                  initialValue: s.customEquipment[i],
                  onSelected: (v) => _update(() => s.customEquipment[i] = v),
                  color: const Color(0xFF1E1E1E),
                  padding: EdgeInsets.zero,
                  tooltip: '',
                  child: Center(
                      child: Image.asset(iconPath,
                          width: 16, height: 16, color: Colors.white54)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: Equipment.kettlebell.index,
                      child: Row(children: [
                        Image.asset('assets/icon/kettlebell.png',
                            width: 18, height: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        const Text('Kettlebell',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: Equipment.steelmace.index,
                      child: Row(children: [
                        Image.asset('assets/icon/steelmace.png',
                            width: 18, height: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        const Text('Steel Mace',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('R', style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _stepButton(Icons.remove,
                  s.customPlan[i] > 1 ? () => _update(() => s.customPlan[i]--) : null,
                  size: 32),
              SizedBox(
                width: 30,
                child: Center(
                    child: Text('${s.customPlan[i]}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white54))),
              ),
              _stepButton(Icons.add, () => _update(() => s.customPlan[i]++), size: 32),
              const SizedBox(width: 8),
              const Text('s', style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(width: 3),
              _stepButton(Icons.remove,
                  s.customDurations[i] > 30
                      ? () => _update(() =>
                          s.customDurations[i] = (s.customDurations[i] - 5).clamp(30, 9999))
                      : null,
                  size: 32),
              SizedBox(
                width: 34,
                child: Center(
                    child: Text('${s.customDurations[i]}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white54))),
              ),
              _stepButton(Icons.add,
                  () => _update(() => s.customDurations[i] += 5), size: 32),
            ] else ...[
              Image.asset(iconPath, width: 14, height: 14, color: Colors.white24),
              const SizedBox(width: 8),
              Text('${s.customPlan[i]}R',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
              const SizedBox(width: 6),
              Text('${s.customDurations[i]}s',
                  style: const TextStyle(fontSize: 12, color: Colors.white24)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Schritt 5: sound_picker_dialog.dart**

```dart
// lib/features/config/widgets/sound_picker_dialog.dart
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// Identischer Inhalt der bisherigen _SoundPickerDialog und _SoundPickerDialogState
// aus lib/config_screen.dart — aus private in public umbenennen:
// _SoundPickerDialog → SoundPickerDialog
// _SoundPickerDialogState → _SoundPickerDialogState (bleibt private)

class SoundPickerDialog extends StatefulWidget {
  final String title;
  final String currentFile;
  final List<String> builtinSounds;
  final List<String> importedSounds;

  const SoundPickerDialog({
    super.key,
    required this.title,
    required this.currentFile,
    required this.builtinSounds,
    required this.importedSounds,
  });

  @override
  State<SoundPickerDialog> createState() => _SoundPickerDialogState();
}

class _SoundPickerDialogState extends State<SoundPickerDialog> {
  late String _selected;
  late List<String> _imported;
  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _selected = widget.currentFile;
    _imported = List.from(widget.importedSounds);
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Source _soundSource(String f) =>
      f.startsWith('/') ? DeviceFileSource(f) : AssetSource('sounds/$f');

  Future<void> _preview(String file) async {
    await _previewPlayer.stop();
    try { await _previewPlayer.play(_soundSource(file)); } catch (_) {}
  }

  Future<void> _importFromFilesystem() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final sourcePath = result.files.first.path;
    if (sourcePath == null) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${docsDir.path}/sounds');
    await soundsDir.create(recursive: true);
    final filename = result.files.first.name;
    var destPath = '${soundsDir.path}/$filename';
    if (File(destPath).existsSync()) {
      final lastDot = filename.lastIndexOf('.');
      final name = lastDot >= 0 ? filename.substring(0, lastDot) : filename;
      final ext = lastDot >= 0 ? filename.substring(lastDot) : '';
      int counter = 1;
      while (File('${soundsDir.path}/${name}_$counter$ext').existsSync()) counter++;
      destPath = '${soundsDir.path}/${name}_$counter$ext';
    }
    await File(sourcePath).copy(destPath);
    setState(() { _imported.add(destPath); _selected = destPath; });
  }

  String _displayName(String file) =>
      file.startsWith('/') ? file.split('/').last : file;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(widget.title,
          style: const TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 1)),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.builtinSounds.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: const Text('Integriert',
                    style: TextStyle(fontSize: 9, letterSpacing: 3, color: Colors.white24)),
              ),
              ...widget.builtinSounds.map((f) => _soundTile(f, isAsset: true)),
            ],
            if (_imported.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: const Text('Importiert',
                    style: TextStyle(fontSize: 9, letterSpacing: 3, color: Colors.white24)),
              ),
              ..._imported.map((f) => _soundTile(f, isAsset: false)),
            ],
            const Divider(color: Color(0xFF222222), height: 1),
            TextButton.icon(
              onPressed: _importFromFilesystem,
              icon: const Icon(Icons.folder_open, color: Colors.white38, size: 18),
              label: const Text('Aus Dateisystem wählen',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen', style: TextStyle(color: Colors.white24)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Übernehmen', style: TextStyle(color: Color(0xFFFF6B00))),
        ),
      ],
    );
  }

  Widget _soundTile(String file, {required bool isAsset}) {
    final isSelected = _selected == file;
    return InkWell(
      onTap: () => setState(() => _selected = file),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFFFF6B00) : Colors.white12,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_displayName(file),
                  style: TextStyle(
                      color: isSelected ? Colors.white54 : Colors.white24, fontSize: 13)),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white24, size: 20),
              onPressed: () => _preview(file),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Schritt 6: phase_based_editor.dart, minute_exact_editor.dart, feedback_tab.dart**

Diese drei Widgets direkt aus den entsprechenden Methoden in `_ConfigScreenState` extrahieren. Jede Methode wird eine eigene `StatelessWidget`-Klasse. Sie erhalten die benötigten Werte als Constructor-Parameter und geben Änderungen via Callbacks zurück.

**phase_based_editor.dart** — wraps `_phaseBasedEditor()`:
```dart
// lib/features/config/widgets/phase_based_editor.dart
import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class PhaseBasedEditor extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onChanged;

  const PhaseBasedEditor({
    super.key,
    required this.settings,
    required this.onChanged,
  });
  // Inhalt von _phaseBasedEditor() + _phaseTableRow() + _inlineStepRow() + _phaseReps()
  // Als lokale Methoden der Widget-Klasse übernehmen
  // _setPlan(() => ...) wird ersetzt durch: setState(fn); onChanged();
  // Da StatelessWidget kein setState hat: PhaseBasedEditor zu StatefulWidget machen
```

**Hinweis:** `PhaseBasedEditor` muss ein `StatefulWidget` sein, da es `_setPlan()` calls enthält die `setState` brauchen. Alternativ: alle Änderungen sofort via `onChanged` nach oben reichen.

Einfachste Implementierung — `PhaseBasedEditor` als `StatefulWidget`:
```dart
class PhaseBasedEditor extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onChanged;
  const PhaseBasedEditor({super.key, required this.settings, required this.onChanged});
  @override
  State<PhaseBasedEditor> createState() => _PhaseBasedEditorState();
}

class _PhaseBasedEditorState extends State<PhaseBasedEditor> {
  void _set(VoidCallback fn) { setState(fn); widget.onChanged(); }
  // ... _phaseBasedEditor, _phaseTableRow, _inlineStepRow, _phaseReps Inhalt
}
```

**minute_exact_editor.dart** — wraps `_minuteExactEditor()`:
```dart
class MinuteExactEditor extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onChanged;
  const MinuteExactEditor({super.key, required this.settings, required this.onChanged});
  // MinuteRow-Widget importieren
  // _minuteExactEditor() Inhalt übernehmen
}
```

**feedback_tab.dart** — wraps den Feedback-Tab ListView:
```dart
class FeedbackTab extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onChanged;
  const FeedbackTab({super.key, required this.settings, required this.onChanged});
  // _toggleRow, _volumeSliderRow, _soundPickerRow, _indentedGroup übernehmen
  // _openSoundPicker als Methode der Klasse
}
```

- [ ] **Schritt 7: ConfigScreen auf neue Widgets umstellen**

In `lib/config_screen.dart` Imports ergänzen:
```dart
import 'features/config/widgets/plan_mode_selector.dart';
import 'features/config/widgets/equipment_selector.dart';
import 'features/config/widgets/phase_based_editor.dart';
import 'features/config/widgets/minute_exact_editor.dart';
import 'features/config/widgets/feedback_tab.dart';
import 'features/config/widgets/sound_picker_dialog.dart';
// MinuteRow wird nur intern von MinuteExactEditor genutzt, kein direkter Import nötig
```

Die privaten Klassen `_MinuteRow`, `_MinuteRowState`, `_SoundPickerDialog`, `_SoundPickerDialogState` sowie alle extrahierten Build-Methoden aus `_ConfigScreenState` entfernen. `_ConfigScreenState.build()` verwendet jetzt die importierten Widgets.

- [ ] **Schritt 8: Analysieren**

```bash
flutter analyze
```

Erwartete Ausgabe: `No issues found!`

- [ ] **Schritt 9: Committen**

```bash
git add lib/features/config/ lib/config_screen.dart
git commit -m "refactor: extract all config widgets into features/config/widgets/"
```

---

## Task 9: Dateien in finale Positionen verschieben + app.dart + Aufräumen

**Files:**
- Create: `lib/app.dart`
- Create: `lib/features/workout/workout_screen.dart` (Inhalt aus main.dart)
- Create: `lib/features/config/config_screen.dart` (Inhalt aus lib/config_screen.dart)
- Modify: `lib/main.dart` (auf ~10 Zeilen reduzieren)
- Delete: `lib/config_screen.dart`

- [ ] **Schritt 1: app.dart erstellen**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'features/workout/workout_screen.dart';

class KettlebellApp extends StatelessWidget {
  const KettlebellApp({super.key});

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
```

- [ ] **Schritt 2: WorkoutScreen nach features/workout/ verschieben**

Inhalt der `WorkoutScreen`- und `_WorkoutScreenState`-Klassen aus `lib/main.dart` nach `lib/features/workout/workout_screen.dart` verschieben. Imports entsprechend anpassen (relative Pfade von `features/workout/` aus).

- [ ] **Schritt 3: ConfigScreen nach features/config/ verschieben**

`lib/config_screen.dart` → `lib/features/config/config_screen.dart`. Imports anpassen.

- [ ] **Schritt 4: main.dart auf Minimalversion reduzieren**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  runApp(const ProviderScope(child: KettlebellApp()));
}
```

- [ ] **Schritt 5: Alte Dateien löschen**

```bash
git rm lib/config_screen.dart
```

- [ ] **Schritt 6: Finalen build_runner run ausführen**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Schritt 7: Analysieren**

```bash
flutter analyze
```

Erwartete Ausgabe: `No issues found!`

- [ ] **Schritt 8: App bauen (vollständiger Compile-Check)**

```bash
flutter build apk --debug
```

Erwartete Ausgabe: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Schritt 9: Finalen Commit erstellen**

```bash
git add lib/ && git commit -m "refactor: complete Riverpod feature-based restructure

- WorkoutNotifier owns all timer/audio/wakelock logic
- SettingsNotifier + HistoryNotifier as shared providers
- Feature folders: workout/, config/, history/
- main.dart reduced to 8 lines
- 24 focused files instead of 4 large ones"
```

---

## Verifikations-Checkliste (nach allen Tasks)

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter build apk --debug` → erfolgreich
- [ ] App startet, Workout-Timer läuft korrekt
- [ ] Config-Einstellungen werden gespeichert und beim Zurückwischen erkannt
- [ ] History wird nach Intervall-Bestätigung geschrieben
- [ ] Reset-Dialog erscheint wenn Plan-Änderung während laufendem Training
