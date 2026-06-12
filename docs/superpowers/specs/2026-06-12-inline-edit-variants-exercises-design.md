# Inline-Editieren von Gewichten und Übungen

**Datum:** 2026-06-12

## Problem

Im Bereich Geräte & Übungen können bestehende Varianten (Gewichte) und Übungen nur gelöscht und neu angelegt werden. Ein Tippfehler oder eine Gewichtsänderung ("16 kg" → "18 kg") erfordert Löschen + Neuanlage — und scheitert ganz, wenn der Eintrag in einem Plan verwendet wird (Lösch-Guard). Umbenennen ist aber gefahrlos, weil Pläne per stabiler `id` referenzieren.

## Lösung: Tap-to-Edit inline (Ansatz A)

### Interaktion

- **Tap auf den Text einer Zeile** (Variante oder Übung) verwandelt die Zeile in eine Inline-Edit-Zeile: Textfeld vorbefüllt mit dem aktuellen Label, autofokussiert, daneben **OK** (übernimmt) und **✕** (verwirft) — gleiche Optik wie die bestehende Inline-Add-Zeile.
- **OK mit nicht-leerem Text** übernimmt den getrimmten Text; **OK mit leerem Text** übernimmt nichts (Edit-Zeile bleibt offen, wie beim Hinzufügen).
- **✕** verwirft und stellt die normale Zeile unverändert wieder her.
- **Nur eine Edit-Zeile gleichzeitig** pro Screen: Das Öffnen einer anderen Edit-Zeile (oder der Add-Zeile) bricht die vorherige ab (verwirft). Umgekehrt schließt das Öffnen einer Edit-Zeile eine offene Add-Zeile.
- L/R-Toggle und ✕-Löschen der normalen Zeilen bleiben unverändert eigene Tap-Ziele; der Tap-to-Edit-Bereich ist nur der Text (Expanded-Bereich der Zeile).

### Geltungsbereich

- **Detail-Editor** (`equipment_detail_screen.dart`): Sektionen GEWICHTE und ÜBUNGEN.
- **Wizard** (`equipment_wizard_screen.dart`): Schritt 2 (Varianten) und Schritt 3 (Übungen) — auch frisch hinzugefügte Einträge sind vor dem Speichern korrigierbar.

### Datenmodell-Semantik

- Die `id` des Eintrags bleibt beim Editieren stabil → Umbenennen wirkt sofort in allen Plänen, **kein Usage-Guard** beim Editieren (im Gegensatz zum Löschen).
- Varianten: Editieren setzt `label` **und** `shortLabel` auf den neuen Text (gleiche Semantik wie beim Anlegen).
- Übungen: Editieren setzt nur `name`; `hasSide` bleibt unberührt (dafür gibt es den L/R-Toggle).
- Persistiert wird wie bisher: Detail-Editor speichert beim Verlassen (PopScope), Wizard beim "✓ Speichern".

### Technik

In `lib/features/config/widgets/equipment_edit_widgets.dart`:

- Neues Widget `InlineEditRow` — wie `InlineAddRow`, aber mit `initialText`-Parameter (Controller wird vom Screen vorbefüllt). Alternativ wird `InlineAddRow` so generalisiert, dass beide Fälle eine Implementierung teilen (eine Stelle, kein Duplikat).
- `VariantRow` und `ExerciseRow` bekommen einen `onTap`-Callback (Tap auf den Text-Bereich).

In den beiden Screens:

- Neuer State `int? _editingVariantIndex` / `int? _editingExerciseIndex` plus ein Edit-Controller; beim Öffnen wird der Controller mit dem aktuellen Label befüllt.
- Rendering: Ist der Index in Bearbeitung, wird statt der normalen Zeile die Edit-Zeile gerendert.
- Exklusivität: Öffnen einer Edit-/Add-Zeile setzt alle anderen Edit-/Add-Flags zurück.

### Tests

Widget-Tests (Pattern aus `test/features/config/equipment_detail_screen_test.dart`):

1. Detail-Editor: Tap auf Variante → Text ändern → OK → Zeile zeigt neuen Text; Pop → `updateEquipmentType` erhält neues `label`/`shortLabel` bei gleicher `id`.
2. Detail-Editor: ✕ verwirft — Zeile zeigt alten Text.
3. Detail-Editor: OK mit leerem Text übernimmt nichts.
4. Detail-Editor: Übung umbenennen — `hasSide` bleibt erhalten.
5. Wizard: In Schritt 2 hinzugefügte Variante per Tap editieren → Zusammenfassung zeigt neuen Text.

## Nicht im Scope

- Separates Editieren von `shortLabel`
- Drag & Drop-Reihenfolge
- Editieren des Gerätenamens über die Liste (existiert bereits im Detail-Editor)
