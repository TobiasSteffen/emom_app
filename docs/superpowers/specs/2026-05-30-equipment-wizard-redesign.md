# Equipment Wizard Redesign + Config Fixes

**Date:** 2026-05-30

## Scope

Three targeted changes to the Geräte & Übungen area:

1. **Liegestütz-Icon-Migration** — `bodyweight`-Eintrag in bestehende Kataloge nachträglich einfügen
2. **ConfigScreen-Farbe** — "Geräte & Übungen"-Zeile von Orange auf Grün
3. **Wizard-Redesign** — einheitlicher 5-Schritt-Flow für Neu und Bearbeiten

---

## 1. Liegestütz-Icon-Migration

### Problem
`defaultCatalog()` enthält bereits den `bodyweight`-Eintrag (`iconAsset: 'assets/icon/liegestuetz.png'`). Wer die App aber bereits installiert hatte, hat eine ältere `equipment_catalog.json` gespeichert, die diesen Eintrag nicht enthält. `EquipmentCatalogStorage.load()` nutzt `defaultCatalog()` nur wenn die Datei fehlt.

### Fix
In `EquipmentCatalogStorage.load()`: nach dem Laden prüfen ob ein Eintrag mit `id == 'bodyweight'` fehlt. Falls ja, den `bodyweight`-Eintrag aus `defaultCatalog()` anhängen und sofort speichern.

---

## 2. ConfigScreen-Farbe

### Problem
Das Fitness-Icon im "Geräte & Übungen verwalten"-Row in `config_screen.dart` ist Orange (`Color(0xFFFF6B00)`). Die anderen Einstellungsbereiche nutzen Grün (`Color(0xFF4CAF50)`).

### Fix
Icon-Farbe auf `Color(0xFF4CAF50)` ändern.

---

## 3. Wizard-Redesign

### Aktueller Stand
- **Neu-Flow**: 4 Schritte (Name+Icon → Varianten? → Varianten → Übungen), kein Summary-Schritt
- **Edit-Flow**: Separates Flat-Form (kein Wizard)
- Beide Flows sind getrennte Code-Pfade

### Neuer Flow (5 Schritte, einheitlich)

**Schritt 1 – Gerät wählen**
- Liste aller vorhandenen Geräte aus dem Katalog, scrollbar in einer `Expanded`-ListView
- "＋ Neues Gerät erstellen" immer am unteren Rand fixiert (außerhalb der ScrollView)
- Auswahl eines vorhandenen Geräts lädt dessen Daten vor (pre-filled)
- "Weiter →" aktiviert sobald eine Auswahl getroffen wurde (immer aktiv bei Neu)

**Schritt 2 – Name & Icon** *(nur bei Neu)*
- Wird übersprungen wenn ein bestehendes Gerät ausgewählt wurde
- Name-Textfeld + Icon-Grid (4 auswählbare Assets aus `_kIconAssets`)
- "Weiter →" erst aktiv wenn Name nicht leer

**Schritt 3 – Gewichte**
- Liste der bestehenden Varianten als Chip-Rows mit ✕-Löschen
- Inline-Add-Row (wie bisher)
- Hinweis: "Leer lassen = kein Gewicht"
- Immer aktiv (leere Variantenliste = kein Gewicht)

**Schritt 4 – Übungen**
- Liste der bestehenden Übungen als Chip-Rows mit L/R-Toggle und ✕-Löschen
- Inline-Add-Row (wie bisher)
- "Weiter →" erst aktiv wenn ≥ 1 Übung vorhanden

**Schritt 5 – Zusammenfassung**
- Gerät: Icon + Name als kompakter Header-Block
- Gewichte: Pills nebeneinander (Wrap)
- Übungen: Pills nebeneinander (Wrap)
- Grüner "✓ Speichern"-Button
- "← Zurück" links unten

### Navigation
- "← Zurück" in jedem Schritt: geht zum vorherigen Schritt, überspringt Schritt 2 wenn bestehendes Gerät gewählt
- AppBar-Back-Button: poppt den Screen (verwirft Änderungen)
- Schritt-Anzeige: "Schritt N von M" — M ist 5 bei Neu, 4 bei Bearbeiten (Schritt 2 existiert nicht); N zählt die tatsächlich durchlaufenen Schritte

### State
Der bestehende State (`_name`, `_iconAsset`, `_variants`, `_exercises`) bleibt. Neu hinzu:
- `_selectedType` (EquipmentType?): das gewählte bestehende Gerät; `null` = Neues Gerät
- `_hasVariants` entfällt; ob Varianten vorhanden sind, ergibt sich aus `_variants.isNotEmpty`

### Entfernter Code
- `_isEdit`-Zweig / `_buildEditMode()` komplett entfernen
- `_step == 2` ("Varianten?"-Ja/Nein-Screen) entfernen — diese Frage entfällt; Varianten einfach leer lassen
- `_kHasVariants`-Toggle entfernen

### Catalog-Liste bleibt
`EquipmentCatalogScreen` bleibt wie bisher (Liste + "+" Button). Der "+" Button öffnet den Wizard bei Schritt 1 ohne Vorauswahl. Tippen auf ein bestehendes Gerät öffnet den Wizard bei Schritt 1 mit diesem Gerät vorausgewählt.

---

## Nicht im Scope

- Reihenfolge der Geräte oder Übungen per Drag & Drop ändern
- Mehrsprachigkeit
- Icon-Upload (nur die 4 vorhandenen Assets)
