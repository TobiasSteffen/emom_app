# Design: Dynamischer Geräte- & Übungskatalog

**Datum:** 2026-05-30
**Feature:** Enums → Datenmodell + Editor in Einstellungen

---

## Zusammenfassung

Die hardcodierten `Equipment`- und `Exercise`-Enums werden durch ein vollständig dynamisches Datenmodell ersetzt. Geräte und Übungen werden als JSON gespeichert und sind in der App editierbar. Ein neuer Screen in den Einstellungen ermöglicht es, vorhandene Geräte zu erweitern oder neue anzulegen. Liegestütz (Körpergewicht) ist Teil des Standardkatalogs.

---

## Scope

Zwei Phasen, eine Spec:

- **Phase 1 — Datenmodell-Migration:** Enums raus, neue Klassen rein, Migration bestehender Pläne, Provider, `IntervalEditForm` anpassen
- **Phase 2 — Editor-UI:** Wizard + Bearbeitungsscreen in ConfigScreen, CRUD auf den Katalog

---

## Betroffene Dateien

| Datei | Änderung |
|---|---|
| `lib/core/models/settings.dart` | `Equipment`- und `Exercise`-Enums entfernen |
| `lib/core/models/equipment_catalog.dart` | Neu: `EquipmentType`, `EquipmentVariant`, `ExerciseType`, `EquipmentCatalog`, `EquipmentCatalogStorage` |
| `lib/core/models/training_plan.dart` | `IntervalConfig` auf String-IDs umstellen, Migration in `fromJson` |
| `lib/core/providers/equipment_catalog_notifier.dart` | Neu: `EquipmentCatalogNotifier` |
| `lib/features/shared/widgets/interval_edit_form.dart` | Liest Katalog aus Provider statt Enums |
| `lib/features/config/config_screen.dart` | Neuer Abschnitt „Geräte & Übungen" |
| `lib/features/config/equipment_catalog_screen.dart` | Neu: Liste aller Gerätetypen |
| `lib/features/config/equipment_wizard_screen.dart` | Neu: Wizard (neu) + Bearbeitungsformular (vorhandene) |

---

## Phase 1: Datenmodell

### Neue Klassen (`equipment_catalog.dart`)

```dart
class ExerciseType {
  final String id;
  String name;         // "Swing beidarmig"
  bool hasSide;        // true → Links/Rechts-Picker erscheint
}

class EquipmentVariant {
  final String id;
  String label;        // "16 kg"
  String shortLabel;   // "16 kg"
}

class EquipmentType {
  final String id;
  String name;                       // "Kettlebell"
  String iconAsset;                  // "assets/icon/kettlebell.png"
  List<EquipmentVariant> variants;   // leer = kein Gewicht (Körpergewicht)
  List<ExerciseType> exercises;      // mind. 1
}

class EquipmentCatalog {
  final List<EquipmentType> types;
}
```

IDs für den eingebauten Standardkatalog sind feste Strings (z.B. `"kettlebell"`, `"swing_beidarmig"`). Neu angelegte Einträge bekommen UUIDs.

### Standardkatalog (wird beim ersten Start angelegt)

| Gerät | Icon | Varianten | Übungen |
|---|---|---|---|
| Kettlebell | `kettlebell.png` | 16kg, 20kg, 24kg | Swing beidarmig, Swing einarmig, Snatch, Push Press |
| Steel Mace | `steelmace.png` | 8kg, 12kg | 360s, Schulterheben |
| Pezziball | `pezziball.png` | ohne, +2,5kg, +5kg, +7,5kg, +10kg | Myotatischer Crunch |
| Körpergewicht | `liegestuetz.png` | keine | Liegestütz |

Einarmige Übungen: Swing einarmig, Snatch, Push Press, 360s, Schulterheben → `hasSide: true`.

### Storage (`EquipmentCatalogStorage`)

- Datei: `documents/equipment_catalog.json` (neben `plans.json`)
- `load()`: Datei existiert nicht → `defaultCatalog()` anlegen und speichern
- `save(catalog)`: JSON schreiben

### `IntervalConfig` — geänderte Felder

```dart
// Vorher:
Equipment equipment;
Exercise exercise;

// Nachher:
String equipmentTypeId;
String? variantId;      // null wenn keine Varianten (z.B. Körpergewicht)
String exerciseTypeId;
```

`planKey` in `TrainingPlan` wird entsprechend angepasst (IDs statt Enum-Indices).

### Migration in `IntervalConfig.fromJson`

Altes Format erkennbar durch `'x'`-Key mit `int`-Wert und fehlendem `'et'`-Key. Mapping:

| Alter `e`-Index | `equipmentTypeId` | `variantId` |
|---|---|---|
| 0 (kb16) | `"kettlebell"` | `"kb_16"` |
| 1 (kb20) | `"kettlebell"` | `"kb_20"` |
| 2 (kb24) | `"kettlebell"` | `"kb_24"` |
| 3 (sm8)  | `"steelmace"` | `"sm_8"` |
| 4 (sm12) | `"steelmace"` | `"sm_12"` |
| 5–9 (pb…) | `"pezziball"` | `"pb_0"` … `"pb_10"` |

Alter `x`-Index → `exerciseTypeId` analog.

Neues Format: Keys `'et'` (equipmentTypeId), `'v'` (variantId, optional), `'x'` (exerciseTypeId als String).

### `EquipmentCatalogNotifier`

Riverpod-Notifier, gleiches Pattern wie `PlanLibraryNotifier`:

```dart
@riverpod
class EquipmentCatalogNotifier extends _$EquipmentCatalogNotifier {
  @override
  Future<EquipmentCatalog> build() async => EquipmentCatalogStorage.load();

  Future<void> addEquipmentType(EquipmentType t) async { … }
  Future<void> updateEquipmentType(EquipmentType t) async { … }

  /// Geblockt wenn Gerätetyp in irgendeinem Plan verwendet wird.
  /// Wirft StateError wenn noch referenziert.
  Future<void> deleteEquipmentType(String id) async { … }

  Future<void> addVariant(String equipmentTypeId, EquipmentVariant v) async { … }
  Future<void> updateVariant(String equipmentTypeId, EquipmentVariant v) async { … }

  /// Geblockt wenn diese Variante in irgendeinem Plan verwendet wird.
  Future<void> deleteVariant(String equipmentTypeId, String variantId) async { … }

  Future<void> addExercise(String equipmentTypeId, ExerciseType e) async { … }
  Future<void> updateExercise(String equipmentTypeId, ExerciseType e) async { … }

  /// Geblockt wenn Übung in irgendeinem Plan verwendet wird.
  Future<void> deleteExercise(String equipmentTypeId, String exerciseId) async { … }
}
```

Für "geblockt wenn verwendet": prüft via `planLibraryNotifierProvider` alle `IntervalConfig`-Einträge.

### `IntervalEditForm` anpassen

- Liest `equipmentCatalogNotifierProvider` (kein direkter Zugriff auf Enums mehr)
- Gruppiert Geräte nach `EquipmentType`
- Zeigt Varianten als Chips (oder kein Varianten-Picker wenn `variants.isEmpty`)
- Zeigt Übungen für den gewählten `EquipmentType`
- Seiten-Picker erscheint wenn `exercise.hasSide == true`

---

## Phase 2: Editor-UI

### ConfigScreen — neuer Abschnitt

```
GERÄTE & ÜBUNGEN
⚙  Geräte & Übungen verwalten  ›
```

Öffnet `EquipmentCatalogScreen` via `Navigator.push`.

### `EquipmentCatalogScreen`

Liste aller `EquipmentType`s + „+" Button oben rechts.

- Jede Zeile: Icon + Name + „X Varianten · Y Übungen" + `›`
- Antippen → `EquipmentWizardScreen` im **Bearbeiten-Modus** (vorausgefüllt, springt direkt zu Schritt 4)
- „+" → `EquipmentWizardScreen` im **Neu-Modus** (startet Wizard ab Schritt 1)
- Swipe-to-Delete: geblockt (zeigt Dialog) wenn noch in Plänen referenziert

### `EquipmentWizardScreen` — Wizard-Flow

**Neu-Modus (4 Schritte):**

| Schritt | Inhalt |
|---|---|
| 1 | Name-Eingabe + Icon-Picker (Grid der PNGs aus `assets/icon/`) |
| 2 | Varianten-Frage: „Mit Gewichten" / „Körpergewicht (keine Varianten)" |
| 3 | Variantenliste (nur wenn „Mit Gewichten") — inline hinzufügen/löschen |
| 4 | Übungsliste — Name + `hasSide`-Toggle — inline hinzufügen/löschen, mind. 1 |

Jeder Schritt hat „← Zurück" und „Weiter →" (bzw. „Fertig ✓" im letzten Schritt).

**Bearbeiten-Modus:**

Springt direkt zu einem kombinierten Screen mit allen Feldern (Name, Icon, Varianten, Übungen) — kein Wizard. Speichern-Button unten. Lösch-Buttons für Varianten/Übungen sind geblockt wenn referenziert.

### Icon-Picker

Zeigt alle PNG-Dateien aus `assets/icon/` als Grid. Neue Icons = neue PNG in den Ordner legen (beim nächsten Build verfügbar). Ausgewähltes Icon erhält orange Umrandung.

---

## Nicht im Scope

- Icons aus dem Dateisystem des Geräts importieren
- Übungen geräteübergreifend teilen
- Redo für den Katalog-Editor
- Cloud-Sync des Katalogs

---

## Testplan

- Unit-Tests für `EquipmentCatalogStorage.load()` (first run, migration, normal load)
- Unit-Tests für `EquipmentCatalogNotifier`: delete geblockt wenn referenziert, CRUD-Roundtrip
- Unit-Tests für `IntervalConfig.fromJson` Migration (alle alten Enum-Indices)
- Widget-Test: `IntervalEditForm` zeigt Varianten-Picker nur wenn `variants.isNotEmpty`
- Widget-Test: Wizard-Schritt 3 (Variantenliste) wird übersprungen wenn in Schritt 2 „Körpergewicht" gewählt wurde
