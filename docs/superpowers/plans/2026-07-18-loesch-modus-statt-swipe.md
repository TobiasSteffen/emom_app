# Lösch-Modus statt Wischgeste Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Swipe-to-Delete komplett entfernen; stattdessen ein Lösch-Modus-Toggle im Header von Plan-Editor und Plan-Bibliothek, der pro Zeile einen roten Lösch-Button einblendet.

**Context:** Die Links-Swipe-Geste zum Löschen kollidiert unlösbar mit Long-Press-Verschieben (Editor) bzw. der horizontalen PageView-Navigation (Bibliothek) — vier Fix-Versuche in der Git-Historie, weiterhin nur mit schnellem aggressivem Wischen nutzbar. Entscheidung von Tobias: Wischgeste komplett raus, Löschen über expliziten Modus (Button oben → rote Buttons je Zeile → Button oben erneut = Modus aus). `SwipeToRevealRow` wird nur in `minute_exact_editor.dart` und `plan_library_screen.dart` verwendet (Equipment-Katalog nutzt es nicht) und fliegt ersatzlos raus.

**Architecture:** Neues Shared-Widget `DeleteModeRow` (Zeileninhalt + bei aktivem Modus rechts ein roter Lösch-Button, animiert ein-/ausblendend, mit Doppel-Tap-Schutz). `PlanEditorScreen` und `PlanLibraryScreen` halten je ein `_deleteMode`-Flag mit Toggle-IconButton im AppBar. Reorder per Long-Press und Rechts-Fling-Back bleiben unverändert und sind nun konfliktfrei.

**Tech Stack:** Flutter, bestehende Widget-Test-Infrastruktur (`flutter_test`). Kein Riverpod-Codegen betroffen.

## Global Constraints

- UI deutsch. Tooltip des Toggles: `'Löschen'`. Kein Bestätigungsdialog außer dem bestehenden „aktiver Plan"-Dialog im Editor.
- Toggle-Button: `Icons.delete_outline`, inaktiv `Colors.white38`, aktiv `Color(0xFFFF4444)`; im Editor mit `key: ValueKey('delete_mode_toggle')`, in der Bibliothek `key: ValueKey('library_delete_mode_toggle')`.
- Zeilen-Lösch-Button behält die bestehenden Keys (`ValueKey('delete_$i')` im Editor; Bibliothek: `ValueKey('delete_plan_${plan.id}')`).
- `SwipeToRevealRow` (Datei + Test) wird ersatzlos gelöscht; keine Referenzen dürfen übrig bleiben (`grep -rn "SwipeToRevealRow" lib test` leer).
- Nach jedem Task: `flutter analyze` sauber, `flutter test` grün, Commit (Message endet mit `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`).

---

### Task 1: Shared-Widget `DeleteModeRow`

**Files:**
- Create: `lib/features/shared/widgets/delete_mode_row.dart`
- Test: `test/features/shared/delete_mode_row_test.dart`

**Interfaces:**
- Produces: `DeleteModeRow({Key? key, required bool deleteMode, required bool canDelete, required Future<void> Function() onDeleteTap, required Widget child, Key? deleteKey})` — zeigt `child`; wenn `deleteMode && canDelete`, erscheint rechts daneben ein roter runder Lösch-Button (`Icons.delete_outline`), animiert über `AnimatedSize`.

- [ ] **Step 1: Failing Test schreiben**

```dart
// test/features/shared/delete_mode_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/features/shared/widgets/delete_mode_row.dart';

Future<void> _pump(WidgetTester tester,
    {required bool deleteMode,
    bool canDelete = true,
    Future<void> Function()? onDeleteTap}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeleteModeRow(
          deleteMode: deleteMode,
          canDelete: canDelete,
          deleteKey: const ValueKey('delete_x'),
          onDeleteTap: onDeleteTap ?? () async {},
          child: const SizedBox(height: 48, width: 200),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kein Lösch-Button wenn Modus aus', (tester) async {
    await _pump(tester, deleteMode: false);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('Lösch-Button sichtbar im Lösch-Modus', (tester) async {
    await _pump(tester, deleteMode: true);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('kein Button wenn canDelete false', (tester) async {
    await _pump(tester, deleteMode: true, canDelete: false);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('Tap ruft onDeleteTap genau einmal (Doppel-Tap-Schutz)',
      (tester) async {
    var calls = 0;
    final completer = Completer<void>();
    await _pump(tester, deleteMode: true, onDeleteTap: () async {
      calls++;
      await completer.future;
    });
    await tester.tap(find.byKey(const ValueKey('delete_x')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete_x')));
    completer.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
```

(`import 'dart:async';` für den Completer ergänzen.)

- [ ] **Step 2: Test laufen lassen — erwartet FAIL** (`flutter test test/features/shared/delete_mode_row_test.dart`, Datei existiert nicht)

- [ ] **Step 3: Widget implementieren**

```dart
// lib/features/shared/widgets/delete_mode_row.dart
import 'package:flutter/material.dart';

/// Zeileninhalt mit einblendbarem Lösch-Button rechts. Ersetzt die frühere
/// Swipe-to-Reveal-Geste: Löschen ist ein expliziter Modus, keine Geste.
class DeleteModeRow extends StatefulWidget {
  final bool deleteMode;
  final bool canDelete;
  final Future<void> Function() onDeleteTap;
  final Widget child;
  final Key? deleteKey;

  const DeleteModeRow({
    super.key,
    required this.deleteMode,
    required this.canDelete,
    required this.onDeleteTap,
    required this.child,
    this.deleteKey,
  });

  @override
  State<DeleteModeRow> createState() => _DeleteModeRowState();
}

class _DeleteModeRowState extends State<DeleteModeRow> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return;
    _busy = true;
    try {
      await widget.onDeleteTap();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.deleteMode && widget.canDelete;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: widget.child),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: show
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    key: widget.deleteKey,
                    onTap: _handleTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 20),
                    ),
                  ),
                )
              : const SizedBox(height: 36),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Test laufen lassen — PASS**, `flutter analyze` sauber.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: DeleteModeRow als Ersatz fuer Swipe-to-Reveal"`

---

### Task 2: Plan-Editor auf Lösch-Modus umstellen

**Files:**
- Modify: `lib/features/plans/plan_editor_screen.dart`
- Modify: `lib/features/plans/widgets/minute_exact_editor.dart`
- Modify: `test/features/plans/plan_editor_delete_confirmation_test.dart`
- Modify: `test/features/plans/plan_editor_swipe_back_test.dart`

**Interfaces:**
- Consumes: `DeleteModeRow` (Task 1).
- Produces: `PlanMinuteExactEditor` bekommt neuen Pflicht-Parameter `required bool deleteMode`.

- [ ] **Step 1: Tests zuerst umschreiben**

`plan_editor_delete_confirmation_test.dart`: Import von `swipe_to_reveal_row.dart` entfernen. Helper ersetzen:

```dart
/// Lösch-Modus über den AppBar-Toggle aktivieren.
Future<void> _enterDeleteMode(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('delete_mode_toggle')));
  await tester.pumpAndSettle();
}
```

Alle `_swipeOpen(tester, i)`-Aufrufe durch ein einmaliges `_enterDeleteMode(tester)` pro Test ersetzen (`_tapTrash` bleibt unverändert — Keys `delete_$i` bleiben). Assertions `find.byType(SwipeToRevealRow)` ersetzen durch `find.byType(PlanMinuteRow)` (Import `package:emom_app/features/plans/widgets/minute_row.dart`). Der letzte Test („Swipe gesperrt wenn nur noch minIntervals Zeilen") wird zu: Lösch-Modus aktivieren → `expect(find.byKey(const ValueKey('delete_0')), findsNothing)` (canDelete false bei minIntervals).

`plan_editor_swipe_back_test.dart`: Import von `swipe_to_reveal_row.dart` entfernen. Test 1 („Rechts-Fling im Editor navigiert zurück") bleibt unverändert. Tests 2 und 3 (Swipe-Gesten) ersetzen durch einen neuen Test:

```dart
  testWidgets('Lösch-Modus-Toggle blendet Lösch-Buttons ein und aus',
      (tester) async {
    await _pumpPushedEditor(tester);

    expect(find.byKey(const ValueKey('delete_0')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('delete_mode_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete_0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete_mode_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete_0')), findsNothing);
  });
```

- [ ] **Step 2: Tests laufen lassen — erwartet FAIL** (Toggle existiert noch nicht)

- [ ] **Step 3: `PlanEditorScreen` anpassen**

State-Feld `bool _deleteMode = false;` ergänzen. In den AppBar-`actions` **vor** dem Undo-Button:

```dart
            IconButton(
              key: const ValueKey('delete_mode_toggle'),
              tooltip: 'Löschen',
              icon: Icon(
                Icons.delete_outline,
                color: _deleteMode ? const Color(0xFFFF4444) : Colors.white38,
              ),
              onPressed: () => setState(() => _deleteMode = !_deleteMode),
            ),
```

`PlanMinuteExactEditor`-Aufruf ergänzen um `deleteMode: _deleteMode,`.

- [ ] **Step 4: `PlanMinuteExactEditor` anpassen**

Import `swipe_to_reveal_row.dart` → `delete_mode_row.dart`. Neues Feld `final bool deleteMode;` (Pflicht-Parameter). `SwipeToRevealRow(...)` ersetzen durch:

```dart
        child: DeleteModeRow(
          key: ValueKey(identityHashCode(plan.intervals[i])),
          deleteKey: ValueKey('delete_$i'),
          deleteMode: deleteMode,
          canDelete: plan.intervals.length > TrainingPlan.minIntervals,
          onDeleteTap: () async {
            if (onConfirmDelete != null) {
              final confirmed = await onConfirmDelete!(i);
              if (!confirmed) return;
            }
            onDelete(i);
          },
          child: PlanMinuteRow(
            // ... unverändert ...
          ),
        ),
```

Außerdem in `plan_editor_screen.dart` den veralteten Kommentar über dem Body-`GestureDetector` (Zeile 185–187, „interval rows reject rightward drags…") kürzen auf: `// Right-fling = app-wide back gesture (matches PageView navigation).`

- [ ] **Step 5: Tests laufen lassen — PASS**, `flutter analyze` sauber (Hinweis: `swipe_to_reveal_row.dart` selbst bleibt bis Task 4 bestehen, damit der Zwischenstand kompiliert — die Bibliothek referenziert es noch).

- [ ] **Step 6: Commit** — `git commit -am "feat: Loesch-Modus statt Swipe im Plan-Editor"`

---

### Task 3: Plan-Bibliothek auf Lösch-Modus umstellen

**Files:**
- Modify: `lib/features/plans/plan_library_screen.dart`

**Interfaces:**
- Consumes: `DeleteModeRow` (Task 1).

- [ ] **Step 1: Screen stateful machen**

`PlanLibraryScreen` von `ConsumerWidget` zu `ConsumerStatefulWidget`/`ConsumerState` umbauen (`_deleteMode = false` als State; die bestehenden Methoden `_formatDuration`, `_addPlan`, `_renamePlan` wandern in den State, `ref` ist dort Feld statt Parameter — `WidgetRef ref`-Parameter aus den Signaturen entfernen).

- [ ] **Step 2: Toggle in AppBar-`actions` vor dem `fitness_center`-Button**

```dart
          IconButton(
            key: const ValueKey('library_delete_mode_toggle'),
            tooltip: 'Löschen',
            icon: Icon(
              Icons.delete_outline,
              color: _deleteMode ? const Color(0xFFFF4444) : Colors.white38,
            ),
            onPressed: () => setState(() => _deleteMode = !_deleteMode),
          ),
```

- [ ] **Step 3: Zeile umbauen**

Import `swipe_to_reveal_row.dart` → `delete_mode_row.dart`. `SwipeToRevealRow(...)` ersetzen durch:

```dart
                    child: DeleteModeRow(
                      key: ValueKey(plan.id),
                      deleteKey: ValueKey('delete_plan_${plan.id}'),
                      deleteMode: _deleteMode,
                      canDelete: library.plans.length > 1,
                      onDeleteTap: () async {
                        await ref
                            .read(planLibraryProvider.notifier)
                            .deletePlan(plan.id);
                      },
                      child: Container(
                        // ... bestehender Zeileninhalt unverändert ...
                      ),
                    ),
```

Hinweis: Der Zeilen-Container hat `margin: EdgeInsets.only(bottom: 12)` — der Lösch-Button der `DeleteModeRow` sitzt vertikal mittig zur Gesamthöhe inkl. Margin; falls das optisch stört, das Margin vom Container auf ein `Padding` um die ganze `DeleteModeRow` verschieben.

- [ ] **Step 4: Verifizieren** — `flutter analyze` sauber, `flutter test` grün.

- [ ] **Step 5: Commit** — `git commit -am "feat: Loesch-Modus statt Swipe in der Plan-Bibliothek"`

---

### Task 4: SwipeToRevealRow entfernen

**Files:**
- Delete: `lib/features/shared/widgets/swipe_to_reveal_row.dart`
- Delete: `test/features/shared/swipe_to_reveal_row_test.dart`

**Interfaces:** keine.

- [ ] **Step 1: Dateien löschen** (`git rm lib/features/shared/widgets/swipe_to_reveal_row.dart test/features/shared/swipe_to_reveal_row_test.dart`)

- [ ] **Step 2: Referenz-Check** — `grep -rn "SwipeToRevealRow" lib test` muss leer sein.

- [ ] **Step 3: Verifizieren** — `flutter analyze` sauber, `flutter test` komplett grün.

- [ ] **Step 4: Commit** — `git commit -am "refactor: SwipeToRevealRow ersatzlos entfernt"`

---

## Verifikation (manuell, am Gerät)

1. Editor: Toggle oben → rote Buttons erscheinen an jeder Zeile; Tap löscht (beim aktiven Plan mit Dialog); Toggle erneut → Buttons weg.
2. Editor: Long-Press-Verschieben funktioniert jetzt zuverlässig (keine Gesten-Konkurrenz mehr), auch im Lösch-Modus.
3. Editor: Rechts-Fling navigiert zurück; Tap auf Zeile klappt Formular auf.
4. Bibliothek: Toggle → Buttons je Plan (außer wenn nur 1 Plan); Löschen des aktiven Plans bleibt durch Notifier blockiert; Tap/Long-Press (öffnen/umbenennen) unverändert.
5. Bei nur `minIntervals` Zeilen im Editor: keine Lösch-Buttons trotz Modus.
