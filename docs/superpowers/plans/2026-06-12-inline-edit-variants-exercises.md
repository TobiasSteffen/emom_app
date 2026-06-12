# Inline-Editieren von Gewichten und Übungen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bestehende Varianten (Gewichte) und Übungen sind per Tap auf den Zeilentext inline editierbar — im Detail-Editor und im Wizard.

**Architecture:** `VariantRow`/`ExerciseRow` bekommen einen optionalen `onTap`-Callback (Tap-Ziel = Textbereich). Die Screens halten `int? _editingVariantIndex` / `int? _editingExerciseIndex` + einen gemeinsamen `_editCtrl`; die Zeile in Bearbeitung wird durch das bestehende `InlineAddRow` (vorbefüllter Controller) ersetzt. Nur eine Edit-/Add-Zeile gleichzeitig; Öffnen einer anderen verwirft die vorige. IDs bleiben stabil, kein Usage-Guard beim Umbenennen.

**Tech Stack:** Flutter, Riverpod codegen. Keine Provider-Änderungen, kein build_runner.

**Spec:** `docs/superpowers/specs/2026-06-12-inline-edit-variants-exercises-design.md`

---

### Task 1: Zeilen tappbar machen (`VariantRow`/`ExerciseRow`)

**Files:**
- Modify: `lib/features/config/widgets/equipment_edit_widgets.dart`

- [ ] **Step 1: `VariantRow` ersetzen**

Die bestehende Klasse `VariantRow` komplett durch diese Version ersetzen (neu: optionales `onTap`, Textbereich in `GestureDetector` mit `HitTestBehavior.opaque`):

```dart
class VariantRow extends StatelessWidget {
  final EditableVariant variant;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  const VariantRow(
      {super.key, required this.variant, required this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Text(variant.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close, size: 16, color: Colors.white38),
            ),
          ],
        ),
      );
}
```

- [ ] **Step 2: `ExerciseRow` ersetzen**

Die bestehende Klasse `ExerciseRow` komplett durch diese Version ersetzen (gleiche Änderung; L/R-Toggle und ✕ bleiben unverändert):

```dart
class ExerciseRow extends StatelessWidget {
  final EditableExercise exercise;
  final VoidCallback onToggleSide;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  const ExerciseRow(
      {super.key,
      required this.exercise,
      required this.onToggleSide,
      required this.onDelete,
      this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Text(exercise.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
            GestureDetector(
              onTap: onToggleSide,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: exercise.hasSide
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('L/R',
                    style: TextStyle(
                        fontSize: 11,
                        color: exercise.hasSide ? Colors.black : Colors.white38,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close,
                  size: 16,
                  color: onDelete != null ? Colors.white38 : Colors.white12),
            ),
          ],
        ),
      );
}
```

Außerdem den Doc-Kommentar über `InlineAddRow` ergänzen (das Widget dient jetzt auch dem Editieren):

```dart
/// Eingabezeile mit OK/✕ — dient sowohl dem Hinzufügen (leerer Controller)
/// als auch dem Inline-Editieren (vorbefüllter Controller).
class InlineAddRow extends StatelessWidget {
```

- [ ] **Step 3: Analyse**

Run: `flutter analyze`
Expected: `No issues found!` (`onTap` ist optional — bestehende Call-Sites kompilieren unverändert)

- [ ] **Step 4: Commit**

```bash
git add lib/features/config/widgets/equipment_edit_widgets.dart
git commit -m "feat: tappable text area on variant/exercise rows"
```

---

### Task 2: Detail-Editor — Inline-Edit (TDD)

**Files:**
- Test: `test/features/config/equipment_detail_screen_test.dart` (4 Tests anhängen)
- Modify: `lib/features/config/equipment_detail_screen.dart`

- [ ] **Step 1: Fehlschlagende Tests anhängen**

In `test/features/config/equipment_detail_screen_test.dart` VOR der schließenden Klammer von `main()` anhängen (nutzt die vorhandenen Helfer `_testType`, `_pumpScreen`):

```dart
  // ── Inline-Editieren ──────────────────────────────────────────────────────

  testWidgets('Tap auf Variante editiert Label und shortLabel, id bleibt',
      (tester) async {
    final type = _testType();
    final container = await _pumpScreen(tester, type: type);

    await tester.tap(find.text('10 kg'));
    await tester.pumpAndSettle();

    // Edit-Zeile ist mit dem aktuellen Label vorbefüllt
    expect(find.widgetWithText(TextField, '10 kg'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '12 kg');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('12 kg'), findsOneWidget);
    expect(find.text('10 kg'), findsNothing);

    // Pop → Save-on-Leave persistiert
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    final saved = container
        .read(equipmentCatalogProvider)
        .value!
        .types
        .firstWhere((t) => t.id == type.id);
    final v = saved.variants.firstWhere((v) => v.id == 'var_a');
    expect(v.label, '12 kg');
    expect(v.shortLabel, '12 kg');
  });

  testWidgets('✕ verwirft die Inline-Bearbeitung', (tester) async {
    final type = _testType();
    await _pumpScreen(tester, type: type);

    await tester.tap(find.text('10 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'XYZ');
    await tester.tap(find.text('✕'));
    await tester.pumpAndSettle();

    expect(find.text('10 kg'), findsOneWidget);
    expect(find.text('XYZ'), findsNothing);
  });

  testWidgets('OK mit leerem Text übernimmt nichts', (tester) async {
    final type = _testType();
    await _pumpScreen(tester, type: type);

    await tester.tap(find.text('10 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Edit-Zeile bleibt offen (OK weiterhin sichtbar), nichts übernommen
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('✕'));
    await tester.pumpAndSettle();
    expect(find.text('10 kg'), findsOneWidget);
  });

  testWidgets('Übung umbenennen behält hasSide', (tester) async {
    final type = _testType();
    final container = await _pumpScreen(tester, type: type);

    await tester.tap(find.text('Übung B'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Übung B2');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    final saved = container
        .read(equipmentCatalogProvider)
        .value!
        .types
        .firstWhere((t) => t.id == type.id);
    final e = saved.exercises.firstWhere((e) => e.id == 'ex_b');
    expect(e.name, 'Übung B2');
    expect(e.hasSide, isTrue);
  });
```

- [ ] **Step 2: Tests laufen lassen — Fehlschlag verifizieren**

Run: `flutter test test/features/config/equipment_detail_screen_test.dart`
Expected: Die 4 neuen Tests schlagen fehl (Tap auf den Zeilentext hat noch keinen Handler — z.B. `find.widgetWithText(TextField, '10 kg')` findet nichts). Die 4 bestehenden Tests bleiben grün.

- [ ] **Step 3: Detail-Editor implementieren**

In `lib/features/config/equipment_detail_screen.dart`:

**(a)** State-Felder ergänzen — nach `bool _addingExercise = false;`:

```dart
  final _editCtrl = TextEditingController();
  int? _editingVariantIndex;
  int? _editingExerciseIndex;
```

**(b)** In `dispose()` vor `super.dispose();` ergänzen:

```dart
    _editCtrl.dispose();
```

**(c)** Edit-Start-Helfer ergänzen — nach `_tryDeleteExercise` einfügen:

```dart
  // ── Inline-Edit (nur eine Edit-/Add-Zeile gleichzeitig) ─────────────────

  void _startEditVariant(int i) {
    setState(() {
      _addingVariant = false;
      _addingExercise = false;
      _editingExerciseIndex = null;
      _editingVariantIndex = i;
      _editCtrl.text = _variants[i].label;
    });
  }

  void _startEditExercise(int i) {
    setState(() {
      _addingVariant = false;
      _addingExercise = false;
      _editingVariantIndex = null;
      _editingExerciseIndex = i;
      _editCtrl.text = _exercises[i].name;
    });
  }
```

**(d)** GEWICHTE-Sektion: den bestehenden `..._variants.asMap().entries.map(...)`-Block ersetzen durch:

```dart
              ..._variants.asMap().entries.map(
                    (entry) => entry.key == _editingVariantIndex
                        ? InlineAddRow(
                            controller: _editCtrl,
                            hintText: 'z.B. 16 kg',
                            onSubmit: () {
                              final text = _editCtrl.text.trim();
                              if (text.isEmpty) return;
                              setState(() {
                                entry.value.label = text;
                                entry.value.shortLabel = text;
                                _editingVariantIndex = null;
                              });
                            },
                            onCancel: () =>
                                setState(() => _editingVariantIndex = null),
                          )
                        : VariantRow(
                            variant: entry.value,
                            onTap: () => _startEditVariant(entry.key),
                            onDelete: () => _tryDeleteVariant(entry.key),
                          ),
                  ),
```

**(e)** Gewicht-AddEntryButton: `onTap` ersetzen durch:

```dart
                AddEntryButton(
                  label: '+ Gewicht hinzufügen',
                  onTap: () => setState(() {
                    _addingVariant = true;
                    _editingVariantIndex = null;
                    _editingExerciseIndex = null;
                  }),
                ),
```

**(f)** ÜBUNGEN-Sektion: den bestehenden `..._exercises.asMap().entries.map(...)`-Block ersetzen durch:

```dart
              ..._exercises.asMap().entries.map(
                    (entry) => entry.key == _editingExerciseIndex
                        ? InlineAddRow(
                            controller: _editCtrl,
                            hintText: 'z.B. Clean and Press',
                            onSubmit: () {
                              final text = _editCtrl.text.trim();
                              if (text.isEmpty) return;
                              setState(() {
                                entry.value.name = text;
                                _editingExerciseIndex = null;
                              });
                            },
                            onCancel: () =>
                                setState(() => _editingExerciseIndex = null),
                          )
                        : ExerciseRow(
                            exercise: entry.value,
                            onTap: () => _startEditExercise(entry.key),
                            onToggleSide: () => setState(() =>
                                entry.value.hasSide = !entry.value.hasSide),
                            onDelete: _exercises.length > 1
                                ? () => _tryDeleteExercise(entry.key)
                                : null,
                          ),
                  ),
```

**(g)** Übung-AddEntryButton: `onTap` ersetzen durch:

```dart
                AddEntryButton(
                  label: '+ Übung hinzufügen',
                  onTap: () => setState(() {
                    _addingExercise = true;
                    _editingVariantIndex = null;
                    _editingExerciseIndex = null;
                  }),
                ),
```

- [ ] **Step 4: Tests laufen lassen — grün verifizieren**

Run: `flutter test test/features/config/equipment_detail_screen_test.dart`
Expected: alle 8 Tests grün.

- [ ] **Step 5: Commit**

```bash
git add lib/features/config/equipment_detail_screen.dart test/features/config/equipment_detail_screen_test.dart
git commit -m "feat: inline editing of variants and exercises in detail editor"
```

---

### Task 3: Wizard — Inline-Edit (TDD)

**Files:**
- Test (Create): `test/features/config/equipment_wizard_screen_test.dart`
- Modify: `lib/features/config/equipment_wizard_screen.dart`

- [ ] **Step 1: Fehlschlagenden Test anlegen**

Datei `test/features/config/equipment_wizard_screen_test.dart` mit diesem Inhalt anlegen:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/features/config/equipment_wizard_screen.dart';

// Bild-Asset-Fehler unterdrücken (Icon-Grid in Schritt 1, Header in Schritt 4
// laden Assets, die im Widget-Test nicht gebündelt sind).
void Function(FlutterErrorDetails)? _originalError;

void _suppressImageErrors() {
  _originalError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('Unable to load asset') ||
        msg.contains('HttpException') ||
        msg.contains('ImageCodecException')) {
      return;
    }
    _originalError?.call(details);
  };
}

void _restoreErrorHandler() {
  FlutterError.onError = _originalError;
}

Future<void> _pumpWizard(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: EquipmentWizardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(_suppressImageErrors);
  tearDown(_restoreErrorHandler);

  testWidgets('Im Wizard hinzugefügte Variante ist per Tap editierbar',
      (tester) async {
    await _pumpWizard(tester);

    // Schritt 1: Name eingeben → Weiter
    await tester.enterText(find.byType(TextField).first, 'Testgerät');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter →'));
    await tester.pumpAndSettle();

    // Schritt 2: Variante hinzufügen
    await tester.tap(find.text('+ Variante hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '10 kg');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Variante per Tap editieren
    await tester.tap(find.text('10 kg'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '10 kg'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '12 kg');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('12 kg'), findsOneWidget);
    expect(find.text('10 kg'), findsNothing);

    await tester.tap(find.text('Weiter →'));
    await tester.pumpAndSettle();

    // Schritt 3: Übung hinzufügen → Weiter
    await tester.tap(find.text('+ Übung hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Schwingen');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter →'));
    await tester.pumpAndSettle();

    // Schritt 4: Zusammenfassung zeigt den editierten Wert
    expect(find.text('ZUSAMMENFASSUNG'), findsOneWidget);
    expect(find.text('12 kg'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Test laufen lassen — Fehlschlag verifizieren**

Run: `flutter test test/features/config/equipment_wizard_screen_test.dart`
Expected: FAIL beim Edit-Schritt (`find.widgetWithText(TextField, '10 kg')` findet nichts — Tap auf die Zeile hat noch keinen Handler).

- [ ] **Step 3: Wizard implementieren**

In `lib/features/config/equipment_wizard_screen.dart`:

**(a)** State-Felder ergänzen — nach `bool _addingExercise = false;`:

```dart
  final _editCtrl = TextEditingController();
  int? _editingVariantIndex;
  int? _editingExerciseIndex;
```

**(b)** In `dispose()` vor `super.dispose();` ergänzen:

```dart
    _editCtrl.dispose();
```

**(c)** `_goForward()` und `_goBack()`: in beiden `setState`-Blöcken zusätzlich zu den Adding-Flags zurücksetzen:

```dart
        _editingVariantIndex = null;
        _editingExerciseIndex = null;
```

**(d)** Edit-Start-Helfer ergänzen — nach `_goBack()` einfügen:

```dart
  // ── Inline-Edit (nur eine Edit-/Add-Zeile gleichzeitig) ─────────────────

  void _startEditVariant(int i) {
    setState(() {
      _addingVariant = false;
      _addingExercise = false;
      _editingExerciseIndex = null;
      _editingVariantIndex = i;
      _editCtrl.text = _variants[i].label;
    });
  }

  void _startEditExercise(int i) {
    setState(() {
      _addingVariant = false;
      _addingExercise = false;
      _editingVariantIndex = null;
      _editingExerciseIndex = i;
      _editCtrl.text = _exercises[i].name;
    });
  }
```

**(e)** In `_buildStep2()`: den `..._variants.asMap().entries.map(...)`-Block ersetzen durch:

```dart
          ..._variants.asMap().entries.map(
                (entry) => entry.key == _editingVariantIndex
                    ? InlineAddRow(
                        controller: _editCtrl,
                        hintText: 'z.B. 16 kg',
                        onSubmit: () {
                          final text = _editCtrl.text.trim();
                          if (text.isEmpty) return;
                          setState(() {
                            entry.value.label = text;
                            entry.value.shortLabel = text;
                            _editingVariantIndex = null;
                          });
                        },
                        onCancel: () =>
                            setState(() => _editingVariantIndex = null),
                      )
                    : VariantRow(
                        variant: entry.value,
                        onTap: () => _startEditVariant(entry.key),
                        onDelete: () =>
                            setState(() => _variants.removeAt(entry.key)),
                      ),
              ),
```

**(f)** In `_buildStep2()`: den Variante-`AddEntryButton` ersetzen durch:

```dart
            AddEntryButton(
              label: '+ Variante hinzufügen',
              onTap: () => setState(() {
                _addingVariant = true;
                _editingVariantIndex = null;
                _editingExerciseIndex = null;
              }),
            ),
```

**(g)** In `_buildStep3()`: den `..._exercises.asMap().entries.map(...)`-Block ersetzen durch:

```dart
          ..._exercises.asMap().entries.map(
                (entry) => entry.key == _editingExerciseIndex
                    ? InlineAddRow(
                        controller: _editCtrl,
                        hintText: 'z.B. Clean and Press',
                        onSubmit: () {
                          final text = _editCtrl.text.trim();
                          if (text.isEmpty) return;
                          setState(() {
                            entry.value.name = text;
                            _editingExerciseIndex = null;
                          });
                        },
                        onCancel: () =>
                            setState(() => _editingExerciseIndex = null),
                      )
                    : ExerciseRow(
                        exercise: entry.value,
                        onTap: () => _startEditExercise(entry.key),
                        onToggleSide: () => setState(
                            () => entry.value.hasSide = !entry.value.hasSide),
                        onDelete: () =>
                            setState(() => _exercises.removeAt(entry.key)),
                      ),
              ),
```

**(h)** In `_buildStep3()`: den Übung-`AddEntryButton` ersetzen durch:

```dart
            AddEntryButton(
              label: '+ Übung hinzufügen',
              onTap: () => setState(() {
                _addingExercise = true;
                _editingVariantIndex = null;
                _editingExerciseIndex = null;
              }),
            ),
```

- [ ] **Step 4: Test laufen lassen — grün verifizieren**

Run: `flutter test test/features/config/equipment_wizard_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/config/equipment_wizard_screen.dart test/features/config/equipment_wizard_screen_test.dart
git commit -m "feat: inline editing of variants and exercises in creation wizard"
```

---

### Task 4: Endverifikation

- [ ] **Step 1: Gesamte Suite + Analyse**

Run: `flutter test` → Expected: alle Tests grün (111 bestehende + 5 neue = 116).
Run: `flutter analyze` → Expected: `No issues found!`

- [ ] **Step 2: Manuelle Verifikation** (`flutter run`)

1. Detail-Editor (Tap auf Kettlebell): Tap auf "16 kg" → Feld vorbefüllt → "18 kg" + OK → Zeile zeigt "18 kg"; zurück + erneut öffnen → persistiert.
2. Tap auf eine Übung → umbenennen → L/R-Status unverändert.
3. Edit-Zeile offen, andere Zeile antippen → erste Bearbeitung verworfen, zweite öffnet vorbefüllt.
4. Edit-Zeile offen, "+ Gewicht hinzufügen" → Edit verworfen, Add-Zeile offen.
5. Wizard ("Neues Gerät"): In Schritt 2 Variante anlegen, antippen, korrigieren → Zusammenfassung zeigt korrigierten Wert.
6. In einem Plan verwendete Variante umbenennen → funktioniert (kein Guard) und der neue Name erscheint überall.
