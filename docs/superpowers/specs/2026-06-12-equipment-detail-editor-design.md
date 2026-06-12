# Geräte & Übungen: Wizard zum Erstellen, Detail-Editor zum Bearbeiten

**Datum:** 2026-06-12

## Problem

Der aktuelle Equipment-Wizard (`equipment_wizard_screen.dart`) behandelt Neuanlage und Bearbeiten im selben 5-Schritt-Flow. Das führt zu drei bestätigten Schmerzpunkten:

1. **Doppelte Geräteauswahl** — die Katalog-Liste zeigt alle Geräte; Tap auf eines öffnet den Wizard, der in Schritt 1 dieselbe Liste nochmal zeigt (mit Vorauswahl).
2. **Lineares Durchklicken beim Bearbeiten** — für eine kleine Änderung (z.B. eine Übung ergänzen) müssen alle Schritte durchlaufen werden.
3. **Name & Icon bestehender Geräte sind nicht änderbar** — Schritt 2 wird beim Bearbeiten übersprungen.

## Lösung

Best-Practice-Trennung: **Wizard nur für die Neuanlage, Detail-Editor für das Bearbeiten.**

### 1. Einstiegspunkte

- **Einstellungen** → "Geräte & Übungen verwalten" → `EquipmentCatalogScreen` (unverändert).
- **Neu:** In der AppBar der Plan-Bibliothek (`plan_library_screen.dart`, TRAININGSPLÄNE) kommt rechts ein `Icons.fitness_center`-IconButton in `actions`, der `EquipmentCatalogScreen` per `Navigator.push` öffnet. Die AppBar hat dort bisher keine Actions.

### 2. Katalog-Liste (`EquipmentCatalogScreen`)

Struktur bleibt (Liste + Swipe-to-Delete + "+"-Button in der AppBar). Routing ändert sich:

- **"+"** → öffnet `EquipmentWizardScreen` (nur Neuanlage, kein `editType`-Parameter mehr).
- **Tap auf ein Gerät** → öffnet `EquipmentDetailScreen` für genau dieses Gerät.

### 3. Wizard (`EquipmentWizardScreen`) — nur Neuanlage, 4 Schritte

1. **Name & Icon** — Textfeld + Icon-Grid (4 Assets aus `_kIconAssets`); "Weiter →" erst aktiv wenn Name nicht leer.
2. **Gewichte** — Zeilen mit ✕-Löschen + Inline-Add; leer lassen = kein Gewicht; immer aktiv.
3. **Übungen** — Zeilen mit L/R-Toggle und ✕ + Inline-Add; "Weiter →" erst aktiv wenn ≥ 1 Übung.
4. **Zusammenfassung** — Icon + Name als Header-Block, Gewichte/Übungen als Pills, grüner "✓ Speichern"-Button (`addEquipmentType`), danach Pop zurück zur Katalog-Liste.

**Entfernt wird:**

- Schritt "Gerät wählen" (bisheriger Schritt 1) samt `_SelectionCard`-Liste
- `editType`-Parameter, `_selectedType`, `_isNewSelected`, `_displayStep`, `_totalSteps`-Weiche
- Edit-Zweig in `_save()` (kein `updateEquipmentType` mehr im Wizard)
- Usage-Checks (`_variantUsed`/`_exerciseUsed`) — bei der Neuanlage kann nichts in Plänen verwendet sein

AppBar-Back bzw. "← Zurück" auf Schritt 1 verwirft die Neuanlage kommentarlos — beim Erstellen geht nichts Wertvolles verloren.

### 4. Detail-Editor (neu: `EquipmentDetailScreen`)

Neuer Screen `lib/features/config/equipment_detail_screen.dart`, Konstruktor nimmt `EquipmentType`. Scrollbarer Inhalt mit drei Sektionen, alles direkt editierbar:

- **NAME & ICON** — Name-Textfeld (vorbefüllt) + 4er-Icon-Grid (vorausgewählt).
- **GEWICHTE** — Zeilen mit ✕-Löschen + "+ Gewicht hinzufügen" (Inline-Add). Löschen blockiert mit Snackbar, wenn die Varianten-ID in einem Plan-Intervall verwendet wird (Logik aus `_variantUsed` übernehmen).
- **ÜBUNGEN** — Zeilen mit L/R-Toggle und ✕-Löschen (letzte Übung nicht löschbar, ✕ ausgegraut) + "+ Übung hinzufügen". Löschen blockiert mit Snackbar bei Verwendung in einem Plan (`_exerciseUsed`).

**Speichern:** automatisch beim Verlassen via `PopScope` + `onPopInvokedWithResult` → `updateEquipmentType` — exakt das Muster von `plan_editor_screen.dart`. Kein Speichern-Button, kein Verwerfen-Dialog.

**Sonderfall:** Ist das Namensfeld beim Verlassen leer (nur Whitespace), wird der ursprüngliche Name beibehalten.

### 5. Gemeinsame Widgets

Geteilte Bausteine in neuer Datei `lib/features/config/widgets/equipment_edit_widgets.dart`:

- Varianten-Zeile (Label + ✕)
- Übungs-Zeile (Name + L/R-Toggle + ✕, ✕ optional deaktiviert)
- Inline-Add-Row für Variante und Übung
- Icon-Grid
- Name-Textfeld
- Section-Label

Die lokalen Mutable-Klassen `_EditableVariant`/`_EditableExercise` wandern als nicht-private Klassen mit dorthin, damit beide Screens sie nutzen können.

### 6. Tests & Verifikation

- Datenmodell (`equipment_catalog.dart`) ändert sich nicht; `test/core/models/equipment_catalog_test.dart` bleibt unberührt.
- Verifikation: `flutter analyze` + `flutter test` grün; manueller Durchstich: Neuanlage über Wizard, Umbenennen + Icon-Wechsel + Übung ergänzen über Detail-Editor, Einstieg über Plan-Bibliothek.

## Nicht im Scope

- Inline-Editieren einzelner Varianten/Übungen (Tippfehler korrigieren) — weiterhin löschen + neu anlegen
- Drag & Drop-Reihenfolge
- Icon-Upload (nur die 4 vorhandenen Assets)
- Mehrsprachigkeit
