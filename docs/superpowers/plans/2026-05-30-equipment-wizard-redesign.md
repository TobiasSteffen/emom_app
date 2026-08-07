# Equipment Wizard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix Liegestütz-Migration, grünes Icon im ConfigScreen, und 5-stufiger einheitlicher Equipment-Wizard für Neu und Bearbeiten.

**Architecture:** Drei unabhängige Änderungen: (1) pure Migrationsfunktion in `EquipmentCatalog`, (2) Ein-Zeilen-Farbfix, (3) komplette Neufassung von `EquipmentWizardScreen` mit unified 5-step flow für Neu und Bearbeiten.

**Tech Stack:** Flutter, Riverpod (ConsumerStatefulWidget), dart:async, SharedPreferences, JSON file storage.

---

## Task 1: Liegestütz-Migration

Bestehende Geräte-Katalog-Dateien enthalten keinen `bodyweight`-Eintrag, weil er erst später zu `defaultCatalog()` hinzugefügt wurde. Wir fügen eine pure Migrationsfunktion `addMissingDefaults` hinzu und rufen sie beim Laden auf.

**Files:**
- Modify: `lib/core/models/equipment_catalog.dart`
- Test: `test/core/models/equipment_catalog_test.dart`

- [ ] **Schritt 1: Test schreiben**

Am Ende der `group('EquipmentCatalog', ...)` in `test/core/models/equipment_catalog_test.dart` hinzufügen:

```dart
group('addMissingDefaults migration', () {
  test('adds bodyweight to catalog that lacks it', () {
    final old = EquipmentCatalog(types: [
      const EquipmentType(
        id: 'kettlebell',
        name: 'Kettlebell',
        iconAsset: 'assets/icon/kettlebell.png',
        variants: [],
        exercises: [],
      ),
    ]);
    final result = EquipmentCatalog.addMissingDefaults(old);
    expect(result.types.any((t) => t.id == 'bodyweight'), isTrue);
    expect(result.types.length, 2);
  });

  test('does not duplicate existing types', () {
    final full = EquipmentCatalog.defaultCatalog();
    final result = EquipmentCatalog.addMissingDefaults(full);
    expect(result.types.length, full.types.length);
  });

  test('preserves original type order', () {
    final old = EquipmentCatalog(types: [
      const EquipmentType(
        id: 'kettlebell',
        name: 'Kettlebell',
        iconAsset: 'assets/icon/kettlebell.png',
        variants: [],
        exercises: [],
      ),
    ]);
    final result = EquipmentCatalog.addMissingDefaults(old);
    expect(result.types.first.id, 'kettlebell');
  });
});
```

- [ ] **Schritt 2: Test laufen lassen (muss scheitern)**

```
flutter test test/core/models/equipment_catalog_test.dart
```

Erwartet: FAIL mit `"addMissingDefaults" not defined`

- [ ] **Schritt 3: `addMissingDefaults` implementieren**

In `lib/core/models/equipment_catalog.dart`, in der `EquipmentCatalog`-Klasse nach `findType(...)` hinzufügen:

```dart
static EquipmentCatalog addMissingDefaults(EquipmentCatalog catalog) {
  final defaults = defaultCatalog();
  var types = List<EquipmentType>.from(catalog.types);
  for (final d in defaults.types) {
    if (!types.any((t) => t.id == d.id)) {
      types.add(d);
    }
  }
  return EquipmentCatalog(types: types);
}
```

- [ ] **Schritt 4: In `load()` aufrufen**

In `EquipmentCatalogStorage.load()` den Abschnitt nach dem `fromJson`-Aufruf so anpassen:

```dart
static Future<EquipmentCatalog> load() async {
  try {
    final file = await _file();
    if (!await file.exists()) {
      final catalog = EquipmentCatalog.defaultCatalog();
      await save(catalog);
      return catalog;
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final catalog = EquipmentCatalog.fromJson(json);
    final migrated = EquipmentCatalog.addMissingDefaults(catalog);
    if (migrated.types.length != catalog.types.length) {
      await save(migrated);
    }
    return migrated;
  } catch (_) {
    return EquipmentCatalog.defaultCatalog();
  }
}
```

- [ ] **Schritt 5: Tests laufen lassen (müssen bestehen)**

```
flutter test test/core/models/equipment_catalog_test.dart
```

Erwartet: alle Tests PASS

- [ ] **Schritt 6: Commit**

```
git add lib/core/models/equipment_catalog.dart test/core/models/equipment_catalog_test.dart
git commit -m "feat: migrate bodyweight entry into existing equipment catalogs"
```

---

## Task 2: ConfigScreen — Grünes Icon

**Files:**
- Modify: `lib/features/config/config_screen.dart`

- [ ] **Schritt 1: Icon-Farbe ändern**

In `lib/features/config/config_screen.dart`, Zeile ~82, die Farbe des `Icon(Icons.fitness_center, ...)` von Orange auf Grün ändern:

```dart
// Vorher:
Icon(Icons.fitness_center, color: Color(0xFFFF6B00), size: 18),

// Nachher:
Icon(Icons.fitness_center, color: Color(0xFF4CAF50), size: 18),
```

- [ ] **Schritt 2: Visuell prüfen**

```
flutter run
```

Einstellungen öffnen → "Geräte & Übungen verwalten"-Zeile muss ein grünes Icon zeigen, konsistent mit den anderen Einstellungsbereichen.

- [ ] **Schritt 3: Commit**

```
git add lib/features/config/config_screen.dart
git commit -m "fix: green icon for Geräte & Übungen in ConfigScreen"
```

---

## Task 3: Wizard-Redesign (5 Schritte)

Komplett neue Implementierung von `EquipmentWizardScreen`. Der Wizard ist jetzt einheitlich für Neu und Bearbeiten. `EquipmentCatalogScreen` bleibt unverändert — der "+" Button öffnet den Wizard ohne Vorauswahl, Tippen auf ein Gerät öffnet ihn mit Vorauswahl in Schritt 1.

**Files:**
- Modify: `lib/features/config/equipment_wizard_screen.dart`

### State-Überblick (neu)

| Variable | Typ | Bedeutung |
|---|---|---|
| `_step` | `int` | Aktueller Schritt 1–5 (Schritt 2 wird bei Bearbeiten übersprungen) |
| `_isNewSelected` | `bool` | Benutzer hat "Neues Gerät" gewählt |
| `_selectedType` | `EquipmentType?` | Vorhandenes Gerät ausgewählt; `null` bei Neu |
| `_name` | `String` | Gerätname (nur bei Neu editierbar) |
| `_iconAsset` | `String` | Icon-Pfad (nur bei Neu editierbar) |
| `_variants` | `List<_EditableVariant>` | Gewichtsvarianten |
| `_exercises` | `List<_EditableExercise>` | Übungen |

**Entfernt:** `_hasVariants`, `_isEdit`, `_buildEditMode()`, `_buildStep2()` (alte Ja/Nein-Varianten-Frage)

### Berechnete Properties

```dart
bool get _hasSelection => _isNewSelected || _selectedType != null;

int get _displayStep {
  if (_isNewSelected) return _step;
  if (_step == 1) return 1;
  return _step - 1; // Schritt 3→2, 4→3, 5→4 bei Bearbeiten
}

int get _totalSteps => _isNewSelected ? 5 : 4;
```

### Navigation

```dart
void _goForward() {
  if (_step == 1) {
    if (_isNewSelected) {
      setState(() {
        _name = '';
        _iconAsset = _kIconAssets.first;
        _variants = [];
        _exercises = [];
        _step = 2;
      });
    } else {
      final t = _selectedType!;
      setState(() {
        _variants = t.variants
            .map((v) => _EditableVariant(id: v.id, label: v.label, shortLabel: v.shortLabel))
            .toList();
        _exercises = t.exercises
            .map((e) => _EditableExercise(id: e.id, name: e.name, hasSide: e.hasSide))
            .toList();
        _step = 3;
      });
    }
  } else if (_step < 5) {
    setState(() => _step++);
  }
}

void _goBack() {
  if (_step == 3 && !_isNewSelected) {
    setState(() => _step = 1);
  } else if (_step > 1) {
    setState(() => _step--);
  }
}
```

- [ ] **Schritt 1: `initState` und State-Variablen aktualisieren**

Den State-Klassen-Block ersetzen (von `class _EquipmentWizardScreenState` bis `bool get _isEdit => ...`):

```dart
class _EquipmentWizardScreenState extends ConsumerState<EquipmentWizardScreen> {
  // navigation
  int _step = 1;
  bool _isNewSelected = false;
  EquipmentType? _selectedType;

  // editable fields
  String _name = '';
  String _iconAsset = _kIconAssets.first;
  List<_EditableVariant> _variants = [];
  List<_EditableExercise> _exercises = [];

  // inline-add controllers
  final _newVariantCtrl = TextEditingController();
  final _newExerciseCtrl = TextEditingController();
  bool _addingVariant = false;
  bool _addingExercise = false;

  bool get _hasSelection => _isNewSelected || _selectedType != null;

  int get _displayStep {
    if (_isNewSelected) return _step;
    if (_step == 1) return 1;
    return _step - 1;
  }

  int get _totalSteps => _isNewSelected ? 5 : 4;

  @override
  void initState() {
    super.initState();
    if (widget.editType != null) {
      _selectedType = widget.editType;
    }
  }

  @override
  void dispose() {
    _newVariantCtrl.dispose();
    _newExerciseCtrl.dispose();
    super.dispose();
  }
```

- [ ] **Schritt 2: `_save()` für Neu und Bearbeiten**

```dart
Future<void> _save() async {
  final isEdit = _selectedType != null && !_isNewSelected;
  final newType = EquipmentType(
    id: isEdit ? _selectedType!.id : EquipmentCatalog.newId(),
    name: isEdit ? _selectedType!.name : _name.trim(),
    iconAsset: isEdit ? _selectedType!.iconAsset : _iconAsset,
    variants: _variants
        .map((v) => EquipmentVariant(id: v.id, label: v.label, shortLabel: v.shortLabel))
        .toList(),
    exercises: _exercises
        .map((e) => ExerciseType(id: e.id, name: e.name, hasSide: e.hasSide))
        .toList(),
  );
  if (isEdit) {
    await ref.read(equipmentCatalogProvider.notifier).updateEquipmentType(newType);
  } else {
    await ref.read(equipmentCatalogProvider.notifier).addEquipmentType(newType);
  }
  if (mounted) Navigator.of(context).pop();
}
```

- [ ] **Schritt 3: Verwendungs-Checks und Navigation-Methoden**

```dart
bool _variantUsed(String variantId) {
  final library = ref.read(planLibraryProvider).value;
  return library?.plans.any((p) => p.intervals.any((iv) => iv.variantId == variantId)) ?? false;
}

bool _exerciseUsed(String exerciseId) {
  final library = ref.read(planLibraryProvider).value;
  return library?.plans.any((p) => p.intervals.any((iv) => iv.exerciseTypeId == exerciseId)) ?? false;
}

void _tryDeleteVariant(int i) {
  final v = _variants[i];
  if (_variantUsed(v.id)) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Variante "${v.label}" wird in einem Plan verwendet.'),
      backgroundColor: Colors.red[900],
    ));
    return;
  }
  setState(() => _variants.removeAt(i));
}

void _tryDeleteExercise(int i) {
  final e = _exercises[i];
  if (_exerciseUsed(e.id)) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Übung "${e.name}" wird in einem Plan verwendet.'),
      backgroundColor: Colors.red[900],
    ));
    return;
  }
  setState(() => _exercises.removeAt(i));
}

void _goForward() {
  if (_step == 1) {
    if (_isNewSelected) {
      setState(() {
        _name = '';
        _iconAsset = _kIconAssets.first;
        _variants = [];
        _exercises = [];
        _step = 2;
      });
    } else {
      final t = _selectedType!;
      setState(() {
        _variants = t.variants
            .map((v) => _EditableVariant(id: v.id, label: v.label, shortLabel: v.shortLabel))
            .toList();
        _exercises = t.exercises
            .map((e) => _EditableExercise(id: e.id, name: e.name, hasSide: e.hasSide))
            .toList();
        _step = 3;
      });
    }
  } else if (_step < 5) {
    setState(() => _step++);
  }
}

void _goBack() {
  if (_step == 3 && !_isNewSelected) {
    setState(() => _step = 1);
  } else if (_step > 1) {
    setState(() => _step--);
  }
}
```

- [ ] **Schritt 4: UI-Hilfsmethoden**

Die bestehenden `_sectionLabel`, `_iconGrid`, `_nameField`, `_orangeButton`, `_ghostButton`, `_addButton`, `_inlineAddVariant`, `_inlineAddExercise`, `_variantRow`, `_exerciseRow` bleiben unverändert.

`_stepNav` aktualisieren (nutzt jetzt `_goBack()` statt `_step--`):

```dart
Widget _stepNav({
  required bool canGoForward,
  required VoidCallback? onForward,
  required String forwardLabel,
}) =>
    Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_step > 1)
            _ghostButton('← Zurück', _goBack)
          else
            const SizedBox(),
          if (forwardLabel.isNotEmpty)
            _orangeButton(forwardLabel, canGoForward ? onForward : null),
        ],
      ),
    );
```

Neue Hilfsmethoden hinzufügen:

```dart
Widget _stepHeader() => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Schritt $_displayStep von $_totalSteps',
        style: const TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white24),
      ),
    );

Widget _summaryPill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );

String _catalogSubtitle(EquipmentType t) {
  final variantPart = t.variants.isEmpty
      ? 'kein Gewicht'
      : t.variants.map((v) => v.label).join(' · ');
  final exercisePart = t.exercises.length == 1 ? '1 Übung' : '${t.exercises.length} Übungen';
  return '$variantPart · $exercisePart';
}
```

- [ ] **Schritt 5: Schritt 1 — Gerätauswahl**

```dart
Widget _buildStep1(EquipmentCatalog catalog) => Column(
      children: [
        _stepHeader(),
        Expanded(
          child: ListView.separated(
            itemCount: catalog.types.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final t = catalog.types[i];
              return _SelectionCard(
                title: t.name,
                subtitle: _catalogSubtitle(t),
                selected: _selectedType?.id == t.id,
                onTap: () => setState(() {
                  _selectedType = t;
                  _isNewSelected = false;
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _SelectionCard(
          title: '＋ Neues Gerät erstellen',
          subtitle: 'eigener Name & Icon',
          selected: _isNewSelected,
          onTap: () => setState(() {
            _isNewSelected = true;
            _selectedType = null;
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _orangeButton('Weiter →', _hasSelection ? _goForward : null),
            ],
          ),
        ),
      ],
    );
```

- [ ] **Schritt 6: Schritt 2 — Name & Icon (nur bei Neu)**

```dart
Widget _buildStep2() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(),
        _sectionLabel('NAME'),
        _nameField(autofocus: true),
        _sectionLabel('ICON WÄHLEN'),
        _iconGrid(),
        _stepNav(
          canGoForward: _name.trim().isNotEmpty,
          onForward: _goForward,
          forwardLabel: 'Weiter →',
        ),
      ],
    );
```

- [ ] **Schritt 7: Schritt 3 — Gewichte**

```dart
Widget _buildStep3() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(),
        _sectionLabel('VARIANTEN'),
        ..._variants.asMap().entries.map(
              (entry) => _variantRow(entry.value, () => _tryDeleteVariant(entry.key)),
            ),
        if (_addingVariant)
          _inlineAddVariant()
        else
          _addButton('+ Variante hinzufügen', () => setState(() => _addingVariant = true)),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: const Text(
            'Leer lassen für kein Gewicht',
            style: TextStyle(fontSize: 10, color: Colors.white24),
          ),
        ),
        _stepNav(
          canGoForward: true,
          onForward: _goForward,
          forwardLabel: 'Weiter →',
        ),
      ],
    );
```

- [ ] **Schritt 8: Schritt 4 — Übungen**

```dart
Widget _buildStep4() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(),
        _sectionLabel('ÜBUNGEN (mind. 1)'),
        ..._exercises.asMap().entries.map((entry) => _exerciseRow(
              entry.value,
              _exercises.length > 1 ? () => _tryDeleteExercise(entry.key) : null,
            )),
        if (_addingExercise)
          _inlineAddExercise()
        else
          _addButton('+ Übung hinzufügen', () => setState(() => _addingExercise = true)),
        _stepNav(
          canGoForward: _exercises.isNotEmpty,
          onForward: _goForward,
          forwardLabel: 'Weiter →',
        ),
      ],
    );
```

- [ ] **Schritt 9: Schritt 5 — Zusammenfassung**

```dart
Widget _buildStep5() {
  final isEdit = _selectedType != null && !_isNewSelected;
  final iconAsset = isEdit ? _selectedType!.iconAsset : _iconAsset;
  final name = isEdit ? _selectedType!.name : _name.trim();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepHeader(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Image.asset(iconAsset, width: 22, height: 22, color: const Color(0xFFFF6B00)),
            const SizedBox(width: 12),
            Text(name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      if (_variants.isNotEmpty) ...[
        _sectionLabel('GEWICHTE'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _variants.map((v) => _summaryPill(v.label)).toList(),
        ),
      ],
      _sectionLabel('ÜBUNGEN'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _exercises.map((e) => _summaryPill(e.name)).toList(),
      ),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: _save,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '✓ Speichern',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
      _stepNav(
        canGoForward: false,
        onForward: null,
        forwardLabel: '',
      ),
    ],
  );
}
```

- [ ] **Schritt 10: `build()` aktualisieren**

```dart
@override
Widget build(BuildContext context) {
  final catalogAsync = ref.watch(equipmentCatalogProvider);

  final title = switch (_step) {
    1 => 'GERÄT WÄHLEN',
    2 => 'NAME & ICON',
    3 => 'GEWICHTE',
    4 => 'ÜBUNGEN',
    _ => 'ZUSAMMENFASSUNG',
  };

  // Schritt 1 braucht Expanded für die scrollbare Liste — eigenes Layout
  if (_step == 1) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 15, letterSpacing: 4, color: Colors.white38)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: catalogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Fehler: $e', style: const TextStyle(color: Colors.white38))),
          data: _buildStep1,
        ),
      ),
    );
  }

  final body = switch (_step) {
    2 => _buildStep2(),
    3 => _buildStep3(),
    4 => _buildStep4(),
    _ => _buildStep5(),
  };

  return Scaffold(
    backgroundColor: const Color(0xFF000000),
    appBar: AppBar(
      backgroundColor: const Color(0xFF000000),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white38),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 15, letterSpacing: 4, color: Colors.white38)),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: body,
    ),
  );
}
```

- [ ] **Schritt 11: `_SelectionCard` anpassen**

`_SelectionCard` ist bereits am Ende der Datei definiert und bleibt unverändert. Prüfen ob der Konstruktor `title`, `subtitle`, `selected`, `onTap` enthält — er tut es bereits.

- [ ] **Schritt 12: `flutter analyze` ausführen**

```
flutter analyze lib/features/config/equipment_wizard_screen.dart
```

Erwartet: keine Fehler. Warnungen über ungenutzte Imports oder ähnliches beheben.

- [ ] **Schritt 13: Manuell testen**

```
flutter run
```

Prüfen:
1. Einstellungen → "Geräte & Übungen verwalten" → "+" tippen
2. Schritt 1 zeigt alle Geräte aus dem Katalog + "Neues Gerät" fixiert unten
3. Bestehendes Gerät antippen (z.B. Kettlebell) → Weiter → landet bei Schritt 2 von 4 (Gewichte, vorausgefüllt)
4. Zusammenfassung zeigt Gerätname + Icon-Block, Gewichte als Pills, Übungen als Pills
5. "+" tippen, "Neues Gerät erstellen" wählen → Weiter → Schritt 2 von 5 (Name & Icon)
6. Name eingeben, Icon wählen → Schritt 3 (leer), Schritt 4 (Übung hinzufügen), Schritt 5 speichern
7. Zurück-Navigation: in Edit-Modus von Schritt 2 (Gewichte) zurück → direkt zu Schritt 1
8. In den Einstellungen auf ein Gerät in der Katalogliste tippen → öffnet Wizard mit Vorauswahl

- [ ] **Schritt 14: Commit**

```
git add lib/features/config/equipment_wizard_screen.dart
git commit -m "feat: 5-step unified equipment wizard for create and edit"
```

---

## Selbst-Review Checkliste

- [x] Spec-Abdeckung: Migration ✓, Farbfix ✓, Wizard-Redesign ✓, Schritt-Nummerierung bei Bearbeiten ✓, "Neues Gerät" immer sichtbar ✓, Zusammenfassung mit Pills ✓
- [x] Keine Platzhalter: alle Code-Blöcke vollständig
- [x] Typ-Konsistenz: `_EditableVariant`, `_EditableExercise`, `EquipmentType`, `EquipmentVariant`, `ExerciseType` konsistent durch alle Tasks
- [x] `_hasVariants` vollständig entfernt aus State und allen Build-Methoden
- [x] `_buildEditMode()` und alter `_buildStep2()` (Ja/Nein) werden durch neuen Flow ersetzt — kein toter Code bleibt
