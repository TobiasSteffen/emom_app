# Plan-UX Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drei unabhängige UX-Verbesserungen im Plan-Editor und der Plan-Liste: besserer Kontrast, funktionierendes Accordion im Editor, und ein klarer Tap-Bereich in der Plan-Liste.

**Architecture:** Alle Änderungen sind rein UI-seitig und betreffen drei Dateien unabhängig voneinander. Keine neuen Dateien, keine State-Änderungen, keine Tests nötig (Pure-UI, kein testbares Business-Logic-Delta). Verifikation via `flutter analyze`.

**Tech Stack:** Flutter/Dart, Riverpod 2.x

---

## File Map

| File | Change |
|------|--------|
| `lib/features/plans/widgets/minute_row.dart` | `Colors.white24` → `Colors.white38` im nicht-ausgewählten Branch |
| `lib/features/plans/widgets/minute_exact_editor.dart` | `itemExtent: 42` entfernen |
| `lib/features/plans/plan_library_screen.dart` | Dot = Aktivieren (32px Tap-Target), Rest der Zeile = Editor öffnen |

---

### Task 1: Kontrast nicht-ausgewählter Zeilen im Plan-Editor

**Files:**
- Modify: `lib/features/plans/widgets/minute_row.dart`

Im nicht-ausgewählten Branch (`} else ...[`) sind alle Texte und das Icon mit `Colors.white24` gerendert — zu wenig Kontrast. Änderung auf `Colors.white38` und `Colors.white54` für Zahlen.

- [ ] **Step 1: Änderungen in `minute_row.dart` vornehmen**

Im `build`-Method, im `else`-Branch (ab ca. Zeile 254), alle `Colors.white24` durch `Colors.white38` ersetzen. Außerdem die `Min X`-Label-Farbe im nicht-ausgewählten Zustand von `Colors.white24` auf `Colors.white38` anpassen:

```dart
// Min-Label (ca. Zeile 194-199):
// ALT:
color: widget.isSelected ? Colors.white38 : Colors.white24,
// NEU:
color: widget.isSelected ? Colors.white54 : Colors.white38,

// else-Branch (ca. Zeile 254-272), alle Vorkommen:
// ALT: color: Colors.white24
// NEU: color: Colors.white38
```

Vollständiger else-Branch nach der Änderung:

```dart
} else ...[
  Image.asset(iv.equipment.iconPath,
      width: 14, height: 14, color: Colors.white38),
  const SizedBox(width: 4),
  Text(iv.equipment.label,
      style:
          const TextStyle(fontSize: 11, color: Colors.white38)),
  const SizedBox(width: 6),
  Text(iv.exercise.label,
      style:
          const TextStyle(fontSize: 11, color: Colors.white38)),
  const SizedBox(width: 6),
  Text('${iv.reps}R',
      style:
          const TextStyle(fontSize: 12, color: Colors.white38)),
  const SizedBox(width: 6),
  Text('${iv.durationSeconds}s',
      style:
          const TextStyle(fontSize: 12, color: Colors.white38)),
],
```

- [ ] **Step 2: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/plans/widgets/minute_row.dart
```

Erwartet: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add lib/features/plans/widgets/minute_row.dart
git commit -m "fix: increase contrast of non-selected minute rows from white24 to white38"
```

---

### Task 2: Accordion-Fix — `itemExtent` entfernen

**Files:**
- Modify: `lib/features/plans/widgets/minute_exact_editor.dart`

`itemExtent: 42` erzwingt eine fixe Zeilenhöhe von 42px für alle 30 Items. Wenn eine Zeile ausgewählt ist und der Gerät/Übung-Picker aufklappt, wächst die Zeilenhöhe über 42px — der überschüssige Inhalt überlagert die Folgezeilen optisch. Ohne `itemExtent` reserviert der ListView dynamisch so viel Platz wie jede Zeile braucht.

- [ ] **Step 1: `itemExtent` entfernen**

In `lib/features/plans/widgets/minute_exact_editor.dart`, im `ListView.builder` (ca. Zeile 29–42):

```dart
// ALT:
ListView.builder(
  key: const PageStorageKey<String>('planMinuteExactList'),
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemExtent: 42,
  itemCount: 30,
  itemBuilder: (_, i) => PlanMinuteRow(...),
),

// NEU (itemExtent entfernt):
ListView.builder(
  key: const PageStorageKey<String>('planMinuteExactList'),
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: 30,
  itemBuilder: (_, i) => PlanMinuteRow(...),
),
```

- [ ] **Step 2: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/plans/widgets/minute_exact_editor.dart
```

Erwartet: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add lib/features/plans/widgets/minute_exact_editor.dart
git commit -m "fix: remove fixed itemExtent so equipment/exercise picker expands inline (accordion)"
```

---

### Task 3: Plan-Liste — Dot aktiviert, Zeile öffnet Editor

**Files:**
- Modify: `lib/features/plans/plan_library_screen.dart`

**Aktuelle Struktur:**
- Äußerer `GestureDetector`: `onLongPress` → Umbenennen
- Innerer `GestureDetector` (ganze Zeile): `onTap` → `setActivePlan`
- Innerster `GestureDetector` (Pfeil `›`): `onTap` → Editor öffnen

**Neue Struktur:**
- Äußerer `GestureDetector`: `onLongPress` → Umbenennen **+ `onTap` → Editor öffnen**
- Dot-Bereich: eigener `GestureDetector` mit `onTap` → `setActivePlan`, 32×32px Tap-Target
- Pfeil `›`: bleibt als visueller Hinweis, aber ohne eigenen `GestureDetector`

Flutter's GestureArena sorgt dafür: wenn der inner Dot-GestureDetector den Tap gewinnt, feuert der äußere `onTap` **nicht**. Tap auf Rest der Zeile → äußerer `onTap` (Editor) feuert.

- [ ] **Step 1: `plan_library_screen.dart` umstrukturieren**

Den `itemBuilder` (ca. Zeile 207–300) wie folgt ersetzen:

```dart
itemBuilder: (_, i) {
  final plan = library.plans[i];
  final isActive = plan.id == library.activePlanId;
  return GestureDetector(
    onLongPress: () => _renamePlan(context, ref, plan),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PlanEditorScreen(plan: plan)),
    ),
    child: Dismissible(
      key: ValueKey(plan.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDelete(context, ref, plan,
            isActive: isActive,
            isLast: library.plans.length == 1);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref
                  .read(planLibraryNotifierProvider.notifier)
                  .setActivePlan(plan.id),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFFF6B00)
                          : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 15,
                      color: isActive
                          ? Colors.white70
                          : Colors.white38,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${plan.intervals.length} Intervalle · ${_formatDuration(plan.totalDurationSeconds)}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white24),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    ),
  );
},
```

- [ ] **Step 2: `flutter analyze` ausführen**

```powershell
flutter analyze lib/features/plans/plan_library_screen.dart
```

Erwartet: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add lib/features/plans/plan_library_screen.dart
git commit -m "feat: plan list row opens editor on tap; dot activates plan (32px tap target)"
```

---

## Self-Review

**Spec-Abgleich:**

| Anforderung | Task |
|-------------|------|
| Nicht-ausgewählte Zeilen heller (`white38`) | Task 1 |
| Picker klappt als Accordion auf, nicht als Overlay | Task 2 |
| Tap auf Dot → Plan aktivieren (≥ 32px) | Task 3 |
| Tap auf Rest der Zeile → Editor öffnen | Task 3 |
| Langer Druck → Umbenennen bleibt erhalten | Task 3 |
| Wisch links → Löschen bleibt erhalten | Task 3 |

**Placeholder-Scan:** Keine TBDs, alle Code-Blöcke vollständig.

**Type-Konsistenz:** Keine neuen Typen eingeführt, alle existierenden Methoden (`_renamePlan`, `_confirmDelete`, `setActivePlan`, `PlanEditorScreen`) unverändert genutzt.
