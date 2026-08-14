# Garmin Watch Hauptscreen — Nachbesserungen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four independent issues found during real-hardware verification of the Garmin Watch main-screen mirroring feature: overlapping text on all three watch screens, a missing equipment icon on the running screen, gestures that can accidentally trigger app actions, and a phone-side connectivity icon that goes stale until app restart.

**Architecture:** Three of the four fixes live entirely in the Monkey C watch app (`garmin_watch_app/source/`); one lives entirely in the Flutter phone app (`lib/`). None of the four share code, so each is independently testable and committable. The watch-side fixes are verified via a local Connect IQ Simulator loop (build → `monkeydo` → screenshot/interaction) instead of real hardware — see Task 2 for the exact commands.

**Tech Stack:** Flutter/Dart (phone side, Riverpod with code generation), Monkey C / Connect IQ SDK 9.2.0 (watch side, `venu445mm` target).

**Spec:** `docs/superpowers/specs/2026-08-14-garmin-watch-hauptscreen-nachbesserungen-design.md` (latest revision `ef0a766`, reviewed four times — the fourth pass reviewed this plan's generated code against the spec and found §4's `invalidate()` approach introduced a new regression, corrected to `refreshConnection()` below).

## Global Constraints

- Connect IQ SDK version: `9.2.0` (installed at `$HOME/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2`)
- Watch target device: `venu445mm` (manifest `minApiLevel="6.0.2"`)
- Hold-to-exit threshold: exactly `600` ms
- Equipment icon IDs are a **fixed, closed set of 7**: `kettlebell`, `steelmace`, `pezziball`, `liegestuetz`, `kniebeuge`, `plank`, `dehnen` (source PNGs are `256x256`, confirmed)
- Monkey C has **no automated test framework in this project** — every watch-side task is verified manually via the local Simulator loop, not `flutter test`
- All new UI text and code comments in this codebase are German, matching existing files — keep that convention
- Dart tests use the existing `flutter_test` + `flutter_riverpod` `ProviderContainer` pattern already present in `test/features/config/garmin_notifier_test.dart` and `test/features/workout/garmin_watch_snapshot_test.dart` — follow it, don't introduce a new test style
- Never commit `garmin_watch_app/bin/` build output or the developer signing key (already gitignored)

---

## File Structure

| File | Responsibility | Touched by |
|---|---|---|
| `lib/features/workout/garmin_watch_snapshot.dart` | Builds the `state_snapshot` payload sent to the watch | Task 1 |
| `test/features/workout/garmin_watch_snapshot_test.dart` | Tests for the above | Task 1 |
| `garmin_watch_app/source/garmin_watch_appView.mc` | All watch screen rendering (`onUpdate`, `drawRunning`/`drawConfirming`/`drawFinished`, now `drawStack`) | Tasks 2, 3 |
| `garmin_watch_app/resources/drawables/drawables.xml` | Registers watch-side bitmap resources (`Rez.Drawables.*`) | Task 3 |
| `garmin_watch_app/resources/drawables/*.png` | The 7 equipment icon bitmaps, copied in from the phone's assets | Task 3 |
| `garmin_watch_app/source/garmin_watch_appDelegate.mc` | All button/gesture input handling | Task 4 |
| `lib/features/config/garmin_notifier.dart` | `GarminNotifier` — connection/watch-app status | Task 5 |
| `lib/features/workout/workout_screen.dart` | Owns `_openConfig()`, the Settings-return hook | Task 5 |
| `test/features/config/garmin_notifier_test.dart` | Tests for `GarminNotifier` | Task 5 |

---

### Task 1: `equipmentIcon` field in the state snapshot

**Files:**
- Modify: `lib/features/workout/garmin_watch_snapshot.dart`
- Test: `test/features/workout/garmin_watch_snapshot_test.dart`

**Interfaces:**
- Produces: `buildStateSnapshot()`'s returned `Map<String, dynamic>` gains a new key `'equipmentIcon': String` — one of `kettlebell`/`steelmace`/`pezziball`/`liegestuetz`/`kniebeuge`/`plank`/`dehnen`, or `''` if the interval is a pause or its `equipmentTypeId` isn't found in the catalog. Task 3 (Monkey C) consumes this key.

- [ ] **Step 1: Write the failing tests**

Add to the `group('buildStateSnapshot', ...)` block in `test/features/workout/garmin_watch_snapshot_test.dart` (after the existing `'totalReps ist die Plan-Summe...'` test, before the `isTimed` test — anywhere inside the group works):

```dart
    test('equipmentIcon ist der Dateiname ohne Pfad/Extension aus iconAsset', () {
      final iv = _iv(equipmentTypeId: 'kettlebell');
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['equipmentIcon'], 'kettlebell');
    });

    test('equipmentIcon ist leer bei Pause-Intervallen', () {
      final iv = _iv(isPause: true, reps: 0);
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['equipmentIcon'], '');
    });

    test('equipmentIcon ist leer, wenn equipmentTypeId nicht im Katalog ist', () {
      final iv = _iv(equipmentTypeId: 'does_not_exist');
      final s = _state(intervals: [iv, _iv()]);
      final snap = buildStateSnapshot(s, _catalog);
      expect(snap['equipmentIcon'], '');
    });

    // Deckt alle 4 eingebauten Ausruestungen ab (nicht nur Kettlebell wie
    // oben) -- die restlichen 3 der 7 Icon-IDs (kniebeuge/plank/dehnen)
    // sind nur ueber selbst angelegte Ausruestung im Wizard erreichbar,
    // nicht ueber BuiltInEquipment, und bräuchten einen eigens gebauten
    // Katalog, um sie zu testen -- hier bewusst nicht mitgemacht (final
    // review: als "defensible" eingestuft, da alle 7 denselben Code-Pfad
    // durchlaufen). Faengt trotzdem Drift zwischen kEquipmentIconAssets
    // und den eingebauten Icon-Dateinamen ab.
    for (final entry in const {
      'kettlebell': 'kettlebell',
      'steelmace': 'steelmace',
      'pezziball': 'pezziball',
      'bodyweight': 'liegestuetz',
    }.entries) {
      test('equipmentIcon fuer eingebaute Ausruestung ${entry.key}', () {
        final iv = _iv(equipmentTypeId: entry.key);
        final s = _state(intervals: [iv, _iv()]);
        final snap = buildStateSnapshot(s, _catalog);
        expect(snap['equipmentIcon'], entry.value);
      });
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/workout/garmin_watch_snapshot_test.dart`
Expected: the three new tests FAIL (existing `expect(snap['equipmentIcon'], ...)` reads `null` from the map, not the expected string — `snap['equipmentIcon']` isn't set yet).

- [ ] **Step 3: Implement `equipmentIcon` in `garmin_watch_snapshot.dart`**

Add this private helper near `_formatInterval` (same file, e.g. directly below it):

```dart
String _equipmentIconFor(IntervalConfig iv, EquipmentCatalog catalog) {
  if (iv.isPause) return '';
  final eqType = catalog.findType(iv.equipmentTypeId);
  if (eqType == null) return '';
  final filename = eqType.iconAsset.split('/').last;
  final dot = filename.lastIndexOf('.');
  return dot == -1 ? filename : filename.substring(0, dot);
}
```

In `buildStateSnapshot()`, add the new key to the returned map (insert after `'isPause': iv.isPause,`):

```dart
    'isPause': iv.isPause,
    'equipmentIcon': _equipmentIconFor(iv, catalog),
```

(Use `iv`, the current interval — the same source `isPause`/`reps`/`duration` already read from — not the backward-searching `_lastNonPauseLines` used for `line1`/`line2` on the finished screen. The icon is only ever rendered on the running screen per the spec's "Nicht-Ziel", so it doesn't need the finished-screen's backward search.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/workout/garmin_watch_snapshot_test.dart`
Expected: all tests PASS, including the three new ones and all pre-existing ones (the new map key must not break any existing test that inspects the full map).

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/garmin_watch_snapshot.dart test/features/workout/garmin_watch_snapshot_test.dart
git commit -m "feat(garmin): equipmentIcon-Feld im state_snapshot-Payload"
```

---

### Task 2: `drawStack()` helper — fix the screen-layout overlap

**Files:**
- Modify: `garmin_watch_app/source/garmin_watch_appView.mc`

**Interfaces:**
- Produces: `drawStack(dc as Dc, elements as Array, startY as Number) as Number` (returns `endY`), `stackHeight(dc as Dc, elements as Array) as Number` (total height without drawing — lets a caller anchor a stack's *end* at a fixed point instead of only growing top-down from a guess), plus two factory helpers `textElement(text as String, font, color as Number) as Dictionary` and `bitmapElement(bitmap, color as Number) as Dictionary`. Task 3 uses `bitmapElement()` and passes a bitmap-containing element into `headerElements` — `stackHeight()` already handles bitmap elements (same kind-dispatch as `drawStack()`), so Task 3 needs no changes to it.

This task fixes the overlap bug using **text-only** stacks (matches current content exactly, just repositions it correctly). Task 3 adds the icon on top of this.

- [ ] **Step 1: Read the current file for context**

`garmin_watch_app/source/garmin_watch_appView.mc` currently has `drawCentered()`, `drawRunning()`, `drawConfirming()`, `drawFinished()`, `drawButtonHints()`, `phaseColorForMinute()`, `formatSeconds()`. `drawRunning`/`drawConfirming`/`drawFinished` each call `drawCentered()` multiple times with hand-guessed Y-offsets from `cy` — that's the bug (see spec §1 for the `Graphics.TEXT_JUSTIFY_TOP`-doesn't-exist root cause).

- [ ] **Step 2: Add `textElement()`, `bitmapElement()`, and `drawStack()`**

Add these three private functions to the `garmin_watch_appView` class (e.g. right after `drawCentered()`):

```javascript
    private function textElement(text as String, font, color as Number) as Dictionary {
        return {:kind => "text", :value => text, :font => font, :color => color};
    }

    private function bitmapElement(bitmap, color as Number) as Dictionary {
        return {:kind => "bitmap", :value => bitmap, :color => color};
    }

    // Zeichnet Elemente (Text oder Bitmap) buendig untereinander, ohne
    // Ueberlappung, unabhaengig von den jeweiligen Schriftgroessen/Bitmap-
    // Hoehen (siehe Design-Spec Abschnitt 1 -- Graphics.TEXT_JUSTIFY_TOP
    // existiert in diesem SDK nicht, deshalb VCENTER + kumulierte
    // dc.getFontHeight()/bitmap.getHeight()-Werte statt geschaetzter
    // Pixel-Offsets). Gibt die Y-Position direkt unterhalb des letzten
    // Elements zurueck, damit nachfolgende Elemente (z.B. die grosse
    // Reps-Zahl) ihre Position daraus ableiten koennen statt sie zu raten.
    private function drawStack(dc as Dc, elements as Array, startY as Number) as Number {
        var cx = dc.getWidth() / 2;
        var y = startY;
        for (var i = 0; i < elements.size(); i++) {
            var element = elements[i];
            var kind = element.get(:kind) as String;
            var h;
            if (kind.equals("text")) {
                h = dc.getFontHeight(element.get(:font));
            } else {
                h = element.get(:value).getHeight();
            }
            var centerY = y + h / 2;
            if (kind.equals("text")) {
                dc.setColor(element.get(:color) as Number, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, centerY, element.get(:font), element.get(:value) as String,
                            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                var bitmap = element.get(:value);
                var w = bitmap.getWidth();
                dc.drawBitmap2(cx - w / 2, centerY - h / 2, bitmap,
                               {:tintColor => element.get(:color) as Number});
            }
            y += h;
        }
        return y;
    }
```

- [ ] **Step 3: Add `stackHeight()`, then rewrite `drawRunning()` to use it + `drawStack()`**

**Design note (found during implementation, not in the original brief — read before writing code):** A pure top-down cascade starting from a guessed `cy - 60` — summing real measured font heights sequentially — overflows the physical display. Real measurements on venu445mm: `FONT_XTINY` = 37px, `FONT_NUMBER_MEDIUM` = **152px** (a third of the whole 454px screen), `FONT_MEDIUM` = 61px. A `cy - 60` start plus two `FONT_XTINY` header lines plus `FONT_NUMBER_MEDIUM` plus `FONT_MEDIUM` plus a `FONT_XTINY` next-text line needs ~340px of vertical space, but only ~287px is available before the bottom of the 454px circle — so `nextText` renders entirely off-canvas and the countdown gets clipped by the round bezel.

Fix: anchor the big number at `cy` (screen center — this is the visual focus, same role the progress ring already plays there) and grow the header **upward** from it instead of cascading everything downward from a guessed top offset. This needs each stack's total height computed **before** it's drawn, so add a second small helper alongside `drawStack()`:

```javascript
    // Wie drawStack(), aber ohne zu zeichnen -- damit ein Aufrufer weiss,
    // wie viel Platz ein Stack braucht, BEVOR er seine Startposition
    // festlegt (z.B. um direkt oberhalb eines fix positionierten Ankers
    // wie der grossen Zahl zu enden, statt nur top-down von einer
    // geschaetzten Konstante aus zu wachsen -- siehe Design-Notiz oben).
    private function stackHeight(dc as Dc, elements as Array) as Number {
        var total = 0;
        for (var i = 0; i < elements.size(); i++) {
            var element = elements[i];
            if (element.get(:kind).equals("text")) {
                total += dc.getFontHeight(element.get(:font));
            } else {
                total += element.get(:value).getHeight();
            }
        }
        return total;
    }
```

Add this directly after `drawStack()`. **This same centering technique must also be applied to `drawConfirming()`/`drawFinished()` in Step 4 below** — they were not touched by this overflow fix originally, but they have the identical latent problem: their `cy - 30`/`cy - 60` starting offsets predate `drawStack()`'s cumulative-real-height cascade and were only ever safe under the old independent-`VCENTER`-per-element scheme. Once `drawStack()` cascades from them, they push content too far off `cy` on a round display (verified during final review: the finished screen's summary line moved into a ~150px-narrower part of the bezel than it occupied before this task). Step 4's code block already reflects the fix (`cy - stackHeight(dc, elements) / 2` as the `startY` argument) — implement it as given there, don't reintroduce the old constants.

**Also fold in the DRY cleanup found during final review:** `drawStack()`/`stackHeight()` (and now, with three call sites, would have a third copy) duplicate the identical "kind == text ? getFontHeight : bitmap.getHeight()" branch. Extract it once:

```javascript
    private function elementHeight(dc as Dc, element as Dictionary) as Number {
        if (element.get(:kind).equals("text")) {
            return dc.getFontHeight(element.get(:font));
        }
        return element.get(:value).getHeight();
    }
```

and have both `drawStack()` and `stackHeight()` call `elementHeight(dc, element)` instead of repeating the branch inline.

**Round-display verification caveat (add to your mental checklist, not just vertical fit):** a Y-position within `[0, 454]` is necessary but not sufficient on a round display — usable horizontal width at a given Y is `2 * sqrt(227^2 - (y - 227)^2)`, shrinking fast near the top/bottom. A vertically-safe layout can still horizontally clip long strings. `nextText` on the running screen does this on long strings (see Step 6's accepted-trade-off note) — that's a known, documented limitation, not something Step 6 needs to newly re-discover.

Then replace the whole `drawRunning` function body with:

```javascript
    private function drawRunning(dc as Dc, snapshot as Dictionary) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var isPause = snapshot.get("isPause") as Boolean;
        var ringColor = isPause ? Graphics.COLOR_DK_GRAY : phaseColorForMinute(snapshot.get("minute") as Number);

        dc.setPenWidth(6);
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        var totalMinutes = snapshot.get("totalMinutes") as Number;
        var minute = snapshot.get("minute") as Number;
        var degrees = totalMinutes > 0 ? (360.0 * minute / totalMinutes) : 0.0;
        if (degrees >= 1) {
            dc.drawArc(cx, cy, cx - 6, Graphics.ARC_CLOCKWISE, 90, 90 - degrees);
        }

        var headerElements = [] as Array;
        var line1 = snapshot.get("line1") as String;
        var line2 = snapshot.get("line2") as String;
        if (!line1.equals("")) {
            headerElements.add(textElement(line1, Graphics.FONT_XTINY, Graphics.COLOR_WHITE));
        }
        if (!line2.equals("")) {
            headerElements.add(textElement(line2, Graphics.FONT_XTINY, Graphics.COLOR_WHITE));
        }

        var isTimed = snapshot.get("isTimed") as Boolean;
        var numberFont = Graphics.FONT_NUMBER_MEDIUM;
        var numberY = cy;
        var headerStartY = numberY - dc.getFontHeight(numberFont) / 2 - 6 - stackHeight(dc, headerElements);
        drawStack(dc, headerElements, headerStartY);

        if (!isPause) {
            var big = isTimed ? snapshot.get("duration").toString() : snapshot.get("reps").toString();
            drawCentered(dc, big, numberY, numberFont, ringColor);
        }

        var countdownFont = Graphics.FONT_MEDIUM;
        var countdownY = numberY + dc.getFontHeight(numberFont) / 2 + dc.getFontHeight(countdownFont) / 2 + 6;
        drawCentered(dc, formatSeconds(WatchState.localSecondsLeft), countdownY, countdownFont, Graphics.COLOR_WHITE);

        var nextText = snapshot.get("nextText") as String;
        if (!nextText.equals("")) {
            var nextFont = Graphics.FONT_XTINY;
            var nextY = countdownY + dc.getFontHeight(countdownFont) / 2 + dc.getFontHeight(nextFont) / 2 + 6;
            drawCentered(dc, nextText, nextY, nextFont, Graphics.COLOR_LT_GRAY);
        }
    }
```

Verified by arithmetic against the real measured heights above (2-line header, next-text present — the fullest case): header spans `[71, 145]`, number spans `[151, 303]`, countdown spans `[309, 369]`, next-text spans `[375, 411]` — all within the `[0, 454]` display, with margin on both ends. Confirm this visually in Step 6 anyway; the arithmetic covers the fullest case but Step 6 is what actually proves it.

- [ ] **Step 4: Rewrite `drawConfirming()` and `drawFinished()` to use `drawStack()`**

Replace both function bodies. Note the `startY` argument: **centered** (`cy - stackHeight(...) / 2`), not the old guessed absolute offset — this is the fix described above Step 3, applied here where the original overflow investigation didn't reach:

```javascript
    private function drawConfirming(dc as Dc, snapshot as Dictionary) as Void {
        var cy = dc.getHeight() / 2;
        var elements = [
            textElement("NÄCHSTE ÜBUNG", Graphics.FONT_SMALL, Graphics.COLOR_ORANGE),
            textElement(snapshot.get("nextText") as String, Graphics.FONT_XTINY, Graphics.COLOR_WHITE),
        ] as Array;
        drawStack(dc, elements, cy - stackHeight(dc, elements) / 2);
    }

    private function drawFinished(dc as Dc, snapshot as Dictionary) as Void {
        var cy = dc.getHeight() / 2;
        var summary = (snapshot.get("line1") as String) + " · " + (snapshot.get("line2") as String);
        var elements = [
            textElement("TRAINING BEENDET", Graphics.FONT_SMALL, Graphics.COLOR_ORANGE),
            textElement(snapshot.get("totalReps").toString(), Graphics.FONT_NUMBER_MEDIUM, Graphics.COLOR_WHITE),
            textElement(summary, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY),
        ] as Array;
        drawStack(dc, elements, cy - stackHeight(dc, elements) / 2);
    }
```

- [ ] **Step 5: Build**

```bash
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
SDK="$HOME/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2/bin"
KEY="$HOME/AppData/Roaming/Garmin/ConnectIQ/developer_key.der"
cd garmin_watch_app
"$SDK/monkeyc.bat" -f monkey.jungle -d venu445mm -o bin/garmin_watch_app.prg -y "$KEY" -w
```
Expected: `BUILD SUCCESSFUL` (existing harmless warnings about the launcher icon size and manifest languages are fine; no new warnings/errors about `drawStack`, `textElement`, `bitmapElement`, or `drawBitmap2` — if `drawBitmap2` isn't recognized yet, re-check Task 3 hasn't been done out of order, `drawBitmap2` is only called from inside `drawStack`'s bitmap branch, which is dead code until Task 3 supplies a bitmap element, so it must still compile even though never hit).

- [ ] **Step 6: Verify visually via the Simulator loop** *(requires a human to look at the simulator window/screenshot)*

```bash
# Terminal A (PowerShell) — start the simulator once, leave it running:
$SDK = "$env:USERPROFILE\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2\bin"
Start-Process "$SDK\simulator.exe"

# Terminal B (bash) — push the build:
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
SDK="$HOME/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2/bin"
cd garmin_watch_app
"$SDK/monkeydo.bat" bin/garmin_watch_app.prg venu445mm
```

The app has no phone connected, so it shows "Verbinde..." (this is `WatchState.current == null`, expected — see `onUpdate()`). To see `drawRunning`/`drawConfirming`/`drawFinished` rendered with real data, temporarily add this call at the top of `garmin_watch_appApp.onStart()` in `garmin_watch_app/source/garmin_watch_appApp.mc` (right after `WatchState.startTicking();`):

```javascript
        WatchState.update({
            "type" => "state_snapshot",
            "minute" => 10,
            "totalMinutes" => 30,
            "line1" => "Kettlebell 16kg",
            "line2" => "Swing beidarmig",
            "isPause" => false,
            "isTimed" => false,
            "isRunning" => true,
            "reps" => 15,
            "secondsLeft" => 25,
            "duration" => 40,
            "screenState" => "running",
            "nextText" => "Nächste: Kettlebell 16kg · Snatch",
            "totalReps" => 142,
        });
```

Rebuild, re-run `monkeydo`, look at the simulator window (or take a screenshot), confirm no two text elements overlap. Repeat with `"screenState" => "confirming"` (also needs `"nextText"` non-empty) and `"screenState" => "finished"` (also needs `"totalReps"` set — already is above). **Revert the temporary `WatchState.update()` mock call before committing** — it must not ship.

**Bewusst akzeptierter Trade-off (final review, nicht "pre-existing" wie ein früherer Implementer-
Report es einordnete):** `nextText` auf dem Running-Screen sitzt bei langen Strings (z. B.
`"Nächste: Kettlebell 16kg · Snatch"`) so weit von `cy` entfernt im Stack, dass die runde
Displayform an dieser Y-Position nur noch ~266px Breite erlaubt (statt ~435px vor diesem Fix) —
der Text wird horizontal abgeschnitten. Ursache: `FONT_NUMBER_MEDIUM` beansprucht allein 152px
(ein Drittel des 454px-Displays), wodurch `nextText` zwangsläufig weit von `cy` entfernt landet,
unabhängig von der Stack-Ankerstrategie. Echte Behebung (kleinere Gaps, `"Nächste: "`-Präfix
weglassen, kleinere Zahlen-Schrift) ist eine Design-Entscheidung außerhalb des Scopes dieses
Zyklus — explizit als bekannte Einschränkung dokumentiert statt stillschweigend als "schon immer
so" abgetan.

- [ ] **Step 7: Commit**

```bash
git add garmin_watch_app/source/garmin_watch_appView.mc
git commit -m "fix(garmin-watch): drawStack()-Helper behebt Zeilen-Overlap auf allen drei Screens"
```

---

### Task 3: Equipment icon on the running screen

**Files:**
- Modify: `garmin_watch_app/source/garmin_watch_appView.mc`
- Modify: `garmin_watch_app/resources/drawables/drawables.xml`
- Create: `garmin_watch_app/resources/drawables/kettlebell.png`, `steelmace.png`, `pezziball.png`, `liegestuetz.png`, `kniebeuge.png`, `plank.png`, `dehnen.png` (copied from `assets/icon/`)

**Interfaces:**
- Consumes: `snapshot.get("equipmentIcon") as String` (Task 1), `drawStack()`/`bitmapElement()`/`textElement()` (Task 2)

- [ ] **Step 1: Copy the icon PNGs into the watch app's resources**

The phone's `assets/icon/*.png` are `256x256`, PNG color type 6 (RGBA, real alpha channel). The resource compiler can downscale on load via `scaleX`/`scaleY` — **these must be a pixel size or a percentage, per the SDK docs' `<bitmap>` attribute table** (a bare decimal fraction like `0.15625` is neither and silently does something other than intended). Use explicit pixel values for a ~40×40px target — unambiguous, doesn't depend on `scaleRelativeTo` (which defaults to `screen`, not `image`, so a percentage would need `scaleRelativeTo="image"` to mean what you'd expect):

```bash
cp assets/icon/kettlebell.png assets/icon/steelmace.png assets/icon/pezziball.png \
   assets/icon/liegestuetz.png assets/icon/kniebeuge.png assets/icon/plank.png \
   assets/icon/dehnen.png garmin_watch_app/resources/drawables/
```

- [ ] **Step 2: Register the 7 bitmaps in `drawables.xml`**

Replace the contents of `garmin_watch_app/resources/drawables/drawables.xml`. Each `<bitmap>` needs `automaticPalette="false"` — **found during implementation, confirmed by a real runtime crash, not a hypothetical**: without it, the resource compiler auto-selects palette/indexed packing for these small 40×40 icons (the default `automaticPalette="true"` behavior on 16-bit-color devices), and `dc.drawBitmap2(..., {:tintColor => ...})` (needed for the icon tinting in Step 3) requires a true-color, non-indexed source bitmap — the simulator crashes with `Exception: Source must not use a color palette` the moment a tinted icon is drawn. `automaticPalette="false"` forces true-color packing and resolves it; verified working end-to-end in the simulator. (This is a different, more specific failure than the generic `InvalidPaletteException` risk flagged during design — that one turned out to be a non-issue given the default packing format's alpha support; this one is real and specifically about tinting a palette-packed bitmap.) No `<palette>` block is needed.

```xml
<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">
    <bitmap id="LauncherIcon" filename="launcher_icon.png" dithering="none" />
    <bitmap id="kettlebell" filename="kettlebell.png" scaleX="40" scaleY="40" automaticPalette="false" />
    <bitmap id="steelmace" filename="steelmace.png" scaleX="40" scaleY="40" automaticPalette="false" />
    <bitmap id="pezziball" filename="pezziball.png" scaleX="40" scaleY="40" automaticPalette="false" />
    <bitmap id="liegestuetz" filename="liegestuetz.png" scaleX="40" scaleY="40" automaticPalette="false" />
    <bitmap id="kniebeuge" filename="kniebeuge.png" scaleX="40" scaleY="40" automaticPalette="false" />
    <bitmap id="plank" filename="plank.png" scaleX="40" scaleY="40" automaticPalette="false" />
    <bitmap id="dehnen" filename="dehnen.png" scaleX="40" scaleY="40" automaticPalette="false" />
</drawables>
```

- [ ] **Step 3: Add the icon lookup map, cache, and loader to `garmin_watch_appView.mc`**

Add these as class-level fields and a private method (e.g. right after the class's opening, before `initialize()`):

```javascript
    private var _iconCacheId as String = "";
    private var _iconCacheBitmap;

    private function iconBitmapFor(iconId as String) {
        if (iconId.equals(_iconCacheId)) {
            return _iconCacheBitmap;
        }
        var resource = _iconResource(iconId);
        if (resource == null) {
            return null;
        }
        // _iconCacheId erst NACH erfolgreichem loadResource() setzen
        // (gefunden im finalen Review): waere die ID schon vorher gesetzt
        // und loadResource() wuerfe, bliebe der Cache auf der ID "gepinnt",
        // waehrend _iconCacheBitmap noch das alte Icon haelt -- jeder
        // spaetere Aufruf mit derselben ID traefe den Cache-Hit-Pfad und
        // laege fuer den Rest der Session falsch.
        var bitmap = WatchUi.loadResource(resource);
        _iconCacheId = iconId;
        _iconCacheBitmap = bitmap;
        return _iconCacheBitmap;
    }

    // Rez.Drawables.* sind Compile-Zeit-Konstanten, koennen nicht per
    // Laufzeit-String indiziert werden -- deshalb diese explizite Map
    // (siehe Design-Spec Abschnitt 2).
    private function _iconResource(iconId as String) {
        if (iconId.equals("kettlebell")) { return Rez.Drawables.kettlebell; }
        if (iconId.equals("steelmace")) { return Rez.Drawables.steelmace; }
        if (iconId.equals("pezziball")) { return Rez.Drawables.pezziball; }
        if (iconId.equals("liegestuetz")) { return Rez.Drawables.liegestuetz; }
        if (iconId.equals("kniebeuge")) { return Rez.Drawables.kniebeuge; }
        if (iconId.equals("plank")) { return Rez.Drawables.plank; }
        if (iconId.equals("dehnen")) { return Rez.Drawables.dehnen; }
        return null;
    }
```

- [ ] **Step 4: Wire the icon into `drawRunning()`'s header stack**

In `drawRunning()` (from Task 2), replace the `headerElements` construction block:

```javascript
        var headerElements = [] as Array;
        var line1 = snapshot.get("line1") as String;
        var line2 = snapshot.get("line2") as String;
        if (!line1.equals("")) {
            headerElements.add(textElement(line1, Graphics.FONT_XTINY, Graphics.COLOR_WHITE));
        }
        if (!line2.equals("")) {
            headerElements.add(textElement(line2, Graphics.FONT_XTINY, Graphics.COLOR_WHITE));
        }
```

with:

```javascript
        var headerElements = [] as Array;
        var line1 = snapshot.get("line1") as String;
        var line2 = snapshot.get("line2") as String;
        var iconId = snapshot.get("equipmentIcon");
        var icon = (iconId != null && !iconId.equals("")) ? iconBitmapFor(iconId as String) : null;
        if (icon != null) {
            headerElements.add(bitmapElement(icon, ringColor));
        } else if (!line1.equals("")) {
            // Fallback, falls kein equipmentIcon ankam (Pause, unbekannte
            // Ausruestung, oder ein aelterer Handy-Build ohne dieses Feld) --
            // zeigt den Text statt gar nichts (siehe Design-Spec Abschnitt 2).
            headerElements.add(textElement(line1, Graphics.FONT_XTINY, Graphics.COLOR_WHITE));
        }
        if (!line2.equals("")) {
            headerElements.add(textElement(line2, Graphics.FONT_XTINY, Graphics.COLOR_WHITE));
        }
```

- [ ] **Step 5: Build**

```bash
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
SDK="$HOME/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2/bin"
KEY="$HOME/AppData/Roaming/Garmin/ConnectIQ/developer_key.der"
cd garmin_watch_app
"$SDK/monkeyc.bat" -f monkey.jungle -d venu445mm -o bin/garmin_watch_app.prg -y "$KEY" -w
```
Expected: `BUILD SUCCESSFUL`. If it fails with an `InvalidPaletteException`-related build/runtime issue, that only surfaces at runtime (Step 6), not build time — a build failure here would more likely mean a typo in `drawables.xml` or a missing PNG file.

- [ ] **Step 6: Verify visually via the Simulator loop** *(requires a human to look at the simulator window/screenshot)*

Same procedure as Task 2 Step 6 (temporary `WatchState.update()` mock in `onStart()`, rebuild, `monkeydo`). Add `"equipmentIcon" => "kettlebell"` to the mock dictionary from Task 2 Step 6 (keep `"line2"` non-empty). Confirm: the icon renders (not blank, not a crash — a crash in the simulator here would point at the `<bitmap>` resource definition in `drawables.xml`, see the fallback note in Step 2), it's tinted to match the ring color (not the original baked-in PNG color), and it doesn't overlap `line2` below it. Also test with `"equipmentIcon" => "does_not_exist"` to confirm the fallback shows `line1` text ("Kettlebell 16kg") instead of a blank space. **Revert the temporary mock before committing.**

- [ ] **Step 7: Commit**

```bash
git add garmin_watch_app/resources/drawables/ garmin_watch_app/source/garmin_watch_appView.mc
git commit -m "feat(garmin-watch): Equipment-Icon auf dem Running-Screen"
```

---

### Task 4: Gesture overhaul — only physical buttons control the app

**Files:**
- Modify: `garmin_watch_app/source/garmin_watch_appDelegate.mc`

**Interfaces:**
- Consumes: `sendWatchCommand(command as String)` (existing, in `garmin_watch_appApp.mc`), `WatchState.current` (existing, in `WatchState.mc`)

- [ ] **Step 1: Discover the exact `WatchUi.KEY_*` constant for the bottom button** *(requires a human at the machine — the simulator's button controls need clicking)*

Both `WatchUi.KEY_ESC` and `WatchUi.KEY_LAP` exist and compile — only the simulator/hardware tells you which one the bottom button actually sends. This only works if `onBack()`/`onSelect()` **decline** (`return false`) during discovery — per the SDK docs, `onKey()` is only reached as a fallthrough when the higher-level behavior method returns `false`: *"On these devices, returning `false` will cause `onKey()` to be called rather than `onSwipe()`"* (same fallthrough rule applies to `onBack()`/`onSelect()` and `onKey()`). Temporarily replace the whole file's contents with:

```javascript
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class garmin_watch_appDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        System.println("onSelect fired (should NOT print if discovery is set up right)");
        return false;
    }

    function onBack() as Boolean {
        System.println("onBack fired (should NOT print if discovery is set up right)");
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        System.println("onKey: " + keyEvent.getKey());
        return true;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        System.println("onKeyPressed: " + keyEvent.getKey());
        return false;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        System.println("onKeyReleased: " + keyEvent.getKey());
        return false;
    }

}
```

Build and push to the simulator (same commands as Task 2 Step 6). Click the simulator's top-button control once — read the console output where `monkeydo` is running, confirm `onKey: 4` appears (4 is `KEY_ENTER`'s value) and neither `onSelect fired` nor `onKeyPressed`/`onKeyReleased` printed anything (top button has no hold behavior in this design). Click the bottom-button control once, briefly — confirm `onKey`, `onKeyPressed`, and `onKeyReleased` all print the same key value (this is `BACK_KEY` — expected `5` for `KEY_ESC` or `19` for `KEY_LAP`; use whichever the log actually shows) and `onBack fired` did not print. This whole file is discovery-only scaffolding — Step 2 replaces it entirely, so nothing here needs to be individually reverted.

- [ ] **Step 2: Replace the whole delegate with the final implementation**

Replace the entire contents of `garmin_watch_app/source/garmin_watch_appDelegate.mc`:

```javascript
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Ziel: nur physische Tastendruecke steuern die App, keine Geste loest je
// etwas aus (siehe Design-Spec Abschnitt 3). onSelect()/onBack() lehnen
// bewusst ab (return false), damit die eigentliche Logik ausschliesslich
// ueber die darunterliegenden Events laeuft, die sich pro Ausloeser
// unterscheiden lassen: onKey(KEY_ENTER) fuer den oberen Knopf,
// onKeyPressed/onKeyReleased(KEY_ESC) fuer Kurz/Lang-Druck am unteren
// Knopf. onTap()/onHold()/onRelease()/onDrag()/onFlick()/onSwipe() sind
// No-ops, damit wirklich keine Geste etwas ausloest.
class garmin_watch_appDelegate extends WatchUi.BehaviorDelegate {

    private const HOLD_THRESHOLD_MS = 600;

    // Ergebnis der Laufzeit-Discovery (s. Task 4, Schritt 1). Falls euer
    // Simulator-Log KEY_LAP statt KEY_ESC zeigte, hier WatchUi.KEY_LAP
    // eintragen.
    private const BACK_KEY = WatchUi.KEY_ESC;

    private var _backPressStart as Number?;
    private var _backPressKey as Number?;

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onRelease(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onDrag(dragEvent as WatchUi.DragEvent) as Boolean {
        return true;
    }

    function onFlick(flickEvent as WatchUi.FlickEvent) as Boolean {
        return true;
    }

    function onBack() as Boolean {
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            var snapshot = WatchState.current;
            if (snapshot != null) {
                var screenState = snapshot.get("screenState");
                if (screenState.equals("confirming")) {
                    sendWatchCommand("cmd_confirm");
                } else if (screenState.equals("running")) {
                    sendWatchCommand("cmd_pause");
                } else if (!screenState.equals("finished")) {
                    sendWatchCommand("cmd_resume");
                }
            }
        }
        // Jede andere Taste, insbesondere KEY_ESC (echter unterer Knopf UND
        // eine auf manchen Geraeten als KEY_ESC getarnte Swipe-Geste), wird
        // hier bewusst ignoriert -- die Skip/Exit-Logik dafuer laeuft
        // ausschliesslich ueber onKeyPressed/onKeyReleased unten. Wuerde
        // onKey() hier zusaetzlich auf KEY_ESC reagieren, wuerde ein
        // einzelner unterer Tastendruck Skip doppelt ausloesen.
        return true;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() != BACK_KEY) { return false; }
        _backPressStart = System.getTimer();
        _backPressKey = BACK_KEY;
        return true;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() != BACK_KEY || _backPressKey != BACK_KEY || _backPressStart == null) {
            return false;
        }
        var heldMs = System.getTimer() - _backPressStart;
        _backPressStart = null;
        _backPressKey = null;
        if (heldMs >= HOLD_THRESHOLD_MS) {
            System.exit();
            return true;
        }
        var snapshot = WatchState.current;
        if (snapshot == null) {
            return true;
        }
        var screenState = snapshot.get("screenState");
        if (!screenState.equals("confirming") && !screenState.equals("finished")) {
            sendWatchCommand("cmd_skip");
        }
        return true;
    }

    // Befristeter Fallback (siehe Design-Spec Abschnitt 3): bleibt aktiv,
    // bis Halten-zum-Beenden auf echter Hardware bestaetigt ist, dann in
    // einem eigenen Folge-Commit entfernen (dann no-op fuer alle
    // Richtungen wie unten fuer den Nicht-SWIPE_LEFT-Fall bereits der
    // Fall). Bewusst SWIPE_LEFT (rechts nach links), nicht SWIPE_RIGHT --
    // Letzteres kollidiert auf manchen Geraeten mit KEY_ESC und kaeme
    // vermutlich nie hier an.
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        if (swipeEvent.getDirection() == WatchUi.SWIPE_LEFT) {
            System.exit();
        }
        return true;
    }

}
```

- [ ] **Step 3: Build**

```bash
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
SDK="$HOME/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2/bin"
KEY="$HOME/AppData/Roaming/Garmin/ConnectIQ/developer_key.der"
cd garmin_watch_app
"$SDK/monkeyc.bat" -f monkey.jungle -d venu445mm -o bin/garmin_watch_app.prg -y "$KEY" -w
```
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Verify in the Simulator** *(requires a human to click the simulator's button/screen controls)*

Push to the simulator (same as Task 2 Step 6), with the mock `WatchState.update()` snapshot from Task 2 Step 6 (`"screenState" => "running"`) so button behavior is observable. In the simulator:
1. Click the top button once → confirm a pause/resume command fires (watch this via a temporary `System.println()` in `sendWatchCommand()` if there's no other visible feedback, or trust the existing `AppStatusListener`/console output — remove the temporary println before committing).
2. Click the bottom button briefly → confirm Skip fires (same observability approach), not Exit.
3. Click-and-hold the bottom button for over 600ms → confirm the simulator app exits (`System.exit()` — the simulator window will show the watch's home/launcher state instead of this app).
4. Tap the middle of the screen → confirm nothing happens (no pause/resume, no exit).
5. Swipe left → confirm the app exits (temporary fallback, expected to still work).

Revert any temporary debug logging added for observability before committing (keep only what Step 2 specified).

- [ ] **Step 5: Commit**

```bash
git add garmin_watch_app/source/garmin_watch_appDelegate.mc
git commit -m "fix(garmin-watch): nur physische Knoepfe steuern die App, keine Geste loest mehr etwas aus"
```

---

### Task 5: Cold-start connectivity icon refresh

**Files:**
- Modify: `lib/features/config/garmin_notifier.dart`
- Modify: `lib/features/workout/workout_screen.dart`
- Test: `test/features/config/garmin_notifier_test.dart`

**Interfaces:**
- Produces: `GarminNotifier.refreshConnection() as Future<void>` — re-queries Bluetooth connectivity in place (same non-invalidating pattern as the existing `openWatchApp()`), leaves `watchAppStatus` untouched.
- Consumes: `garminProvider` (existing, `lib/features/config/garmin_notifier.dart`)

**Important — do not use `ref.invalidate(garminProvider)` for this fix.** An earlier version of this plan did exactly that; it fixes the reported icon bug but introduces a worse one: `GarminNotifier.build()` always starts a fresh `GarminConnectionStatus` with `watchAppStatus: WatchAppStatus.unknown` (there's no previous state to carry forward on a from-scratch rebuild), and `GarminWorkoutSyncNotifier._send()` (`lib/features/workout/garmin_workout_sync_notifier.dart:100`) silently drops every outbound snapshot whenever `watchAppStatus != WatchAppStatus.running`. Invalidating would silently stop the live workout mirroring to the watch on every single Settings visit, until the user manually closes and reopens the watch app. `refreshConnection()` avoids this entirely by never disposing the notifier — it just re-runs the Bluetooth check and writes `state` in place, carrying `watchAppStatus` forward unchanged (identical technique to the existing `openWatchApp()`, lines 55-69 of the same file).

- [ ] **Step 1: Write the failing test**

Add to `test/features/config/garmin_notifier_test.dart`, inside `main()` after the existing two `test(...)` blocks:

```dart
  test('refreshConnection() fragt Bluetooth erneut ab, ohne watchAppStatus zurueckzusetzen',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(garminProvider, (_, _) {});
    addTearDown(sub.close);

    var isWatchConnectedCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'isWatchConnected':
          isWatchConnectedCalls++;
          return true;
        case 'openWatchApp':
          return 'launched';
      }
      return null;
    });

    await container.read(garminProvider.future);
    expect(isWatchConnectedCalls, 1);

    // watchAppStatus auf "running" bringen, wie es ein echtes "opened"-Event
    // von der Uhr taete.
    watchEvents.add('opened');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.watchAppStatus, WatchAppStatus.running);

    await container.read(garminProvider.notifier).refreshConnection();

    expect(isWatchConnectedCalls, 2);
    expect(container.read(garminProvider).value?.watchAppStatus, WatchAppStatus.running);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/config/garmin_notifier_test.dart`
Expected: FAIL with a compile error — `refreshConnection` isn't defined on `GarminNotifier` yet (`The method 'refreshConnection' isn't defined for the type 'GarminNotifier'` or similar).

- [ ] **Step 3: Implement `refreshConnection()` in `garmin_notifier.dart`**

Add this method to the `GarminNotifier` class (e.g. directly after `openWatchApp()`):

```dart
  /// Wie openWatchApp(), aber ohne die Watch-App zu starten -- fuer den
  /// Cold-Start-Icon-Refresh beim Verlassen der Settings (siehe Design-
  /// Spec). Schreibt state per AsyncData(...) direkt fest statt
  /// invalidateSelf()/ref.invalidate() zu nutzen -- das wuerde
  /// watchAppStatus auf unknown zuruecksetzen (kein Vorzustand bei einem
  /// kompletten Neuaufbau) und GarminWorkoutSyncNotifier._send() wuerde
  /// daraufhin jeden Snapshot-Versand stillschweigend unterdruecken, bis
  /// die naechste "opened"-Transition eintrifft.
  ///
  /// Guard (gefunden im finalen Review): garminProvider ist autoDispose.
  /// Ist beim Rueckkehren aus den Settings weder das Header-Icon sichtbar
  /// noch hasEverConnected() schon true (GarminWorkoutSyncNotifier haelt
  /// den Provider dann nicht am Leben, s. Root-Cause oben), kann er
  /// waehrend der await-Strecke hier disposed werden. `state = ...`
  /// (der generierte Setter ruft intern ref._throwIfInvalidUsage() auf,
  /// riverpod 3.3.2 lib/src/core/provider/notifier_provider.dart:89-94)
  /// wirft dann eine UnmountedRefException -- ohne dieses Guard wuerde
  /// dieser Fehler aus _openConfig() herauspropagieren und den
  /// nachfolgenden updateSettings()-Aufruf verhindern.
  Future<void> refreshConnection() async {
    final connected = await _service.isWatchConnected();
    if (connected) {
      await _service.markEverConnected();
    }
    final everConnected = await _service.hasEverConnected();
    if (!ref.mounted) return;
    final watchAppStatus = state.value?.watchAppStatus ?? WatchAppStatus.unknown;
    state = AsyncData(GarminConnectionStatus(
      connected: connected,
      everConnected: everConnected,
      watchAppStatus: watchAppStatus,
    ));
  }
```

Add a second test right after the first one, in the same file, proving this guard matters (the existing test's `container.listen(garminProvider, ...)` pins the provider alive and can't exercise the no-listener path `_openConfig()` actually hits):

```dart
  test('refreshConnection() wirft nicht, wenn niemand mehr zuhoert (Provider zwischendurch disposed)',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Kein container.listen() hier -- garminProvider ist autoDispose und
    // hat direkt nach dem ersten await keinen Watcher mehr, genau wie bei
    // _openConfig() im echten Fall (Header-Icon aus, noch nie verbunden).
    final notifier = container.read(garminProvider.notifier);
    await expectLater(notifier.refreshConnection(), completes);
  });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/config/garmin_notifier_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire `refreshConnection()` into `_openConfig()`**

In `lib/features/workout/workout_screen.dart`, add the import (alongside the existing `import '../config/config_screen.dart';`):

```dart
import '../config/garmin_notifier.dart';
```

Then modify `_openConfig()` (currently at lines 65-76):

```dart
  Future<void> _openConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigScreen(onBack: () => Navigator.pop(context)),
      ),
    );
    if (!mounted) return;
    // Erzwingt einen frischen Bluetooth-Check beim Verlassen der Settings
    // (garminProvider prueft sonst nur beim allerersten Build, s. Design-
    // Spec "Cold-Start-Icon-Refresh"). refreshConnection() statt
    // ref.invalidate(garminProvider) -- Invalidieren wuerde watchAppStatus
    // auf unknown zuruecksetzen und die laufende Snapshot-Zustellung zur
    // Uhr stoppen (s. GarminWorkoutSyncNotifier._send()).
    await ref.read(garminProvider.notifier).refreshConnection();
    if (!mounted) return;
    ref
        .read(workoutProvider.notifier)
        .updateSettings(ref.read(settingsProvider).requireValue);
  }
```

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: all tests PASS, including the new one and every pre-existing test (this change must not affect `workout_screen`'s other behavior — no widget test exists for `_openConfig()` itself in this codebase, so this is checking for the absence of regressions elsewhere, e.g. in `garmin_config_row_test.dart` or `garmin_header_icon_test.dart`).

- [ ] **Step 7: Run static analysis**

Run: `flutter analyze`
Expected: no new warnings/errors (in particular, no "unused import" if `garmin_notifier.dart` wasn't already imported transitively).

- [ ] **Step 8: Commit**

```bash
git add lib/features/config/garmin_notifier.dart lib/features/workout/workout_screen.dart test/features/config/garmin_notifier_test.dart
git commit -m "fix(garmin): Cold-Start-Icon aktualisiert sich beim Verlassen der Settings"
```

---

## Final Verification

After all 5 tasks:

- [ ] `flutter test` — full suite passes
- [ ] `flutter analyze` — no new issues
- [ ] `garmin_watch_app` builds clean (`monkeyc` `BUILD SUCCESSFUL`, no new warnings beyond the two pre-existing harmless ones)
- [ ] Simulator screenshots confirm no overlap on running/confirming/finished screens (Task 2)
- [ ] Simulator screenshot confirms the equipment icon renders, tinted, non-overlapping (Task 3)
- [ ] Simulator interaction confirms: top button = pause/resume, bottom short = skip, bottom hold (≥600ms) = exit, screen tap = no-op (Task 4)
- [ ] No temporary debug `System.println()` or `WatchState.update()` mock calls remain in any committed `.mc` file
- [ ] Note for the human partner: Task 4's `SWIPE_LEFT` fallback and the exact `BACK_KEY` constant still need confirmation on **real Venu 4 hardware** (per spec §3's seven-point checklist) — the simulator cannot reproduce the SWIPE_RIGHT→KEY_ESC device quirk this whole task exists to work around
