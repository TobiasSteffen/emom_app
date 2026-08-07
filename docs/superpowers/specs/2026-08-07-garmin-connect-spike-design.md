# Garmin-Verbindung: Hello-World-Spike – Design Spec
**Datum:** 2026-08-07
**Ansatz:** Natives Connect IQ Mobile SDK (Android) über Platform Channel — kein Flutter-Community-Package

---

## Ziel

Technischer Spike, der die Ende-zu-Ende-Verbindungskette Handy ↔ Garmin-Uhr einmal nachweist, bevor Trainingsanzeige/Vitaldaten gebaut werden: Die Kettlebell-EMOM-App erkennt, dass eine Garmin-Uhr verbunden ist, und kann gezielt eine eigene, noch zu bauende Connect-IQ-Watch-App auf der Uhr öffnen. Die Watch-App selbst hat keine Funktionalität — sie zeigt nur „Hello World" und einen OK-Button, der sie wieder schließt.

Grundlage für die spätere Anbindung (Trainingsanzeige, Vitaldaten, Speicherung in der Historie), siehe `docs/emom_app_spezifikation.md`, Abschnitt „Garmin-Integration". Zielgerät: Garmin Venu 4 (vorhanden), Android-Handy (die App unterstützt ohnehin kein iOS).

---

## Warum natives SDK statt Flutter-Package

Das naheliegende `watch_connectivity_garmin`-Package (pub.dev) wurde geprüft und verworfen: Es bildet lediglich Apples `WatchConnectivity`-API nach (Nachrichten senden/empfangen zwischen Handy und einer bereits laufenden Watch-App). Ein ferngesteuertes Öffnen einer bestimmten Watch-App vom Handy aus — die Kernanforderung dieses Spikes — bietet es nicht an.

Garmins offizielles **Connect IQ Mobile SDK für Android** (`com.garmin.connectiq:ciq-companion-app-sdk`, Maven Central) hat dafür `ConnectIQ.openApplication()`, mit belegtem Beispielcode aus dem Garmin-Entwickler-Forum (`getConnectedDevices()` → `getApplicationInfo()` → `openApplication()`). Zwei Einschränkungen sind bekannt und müssen im Spike selbst verifiziert werden, nicht vorab angenommen werden:
- Die Methode wird von Garmin kaum dokumentiert (Community nennt sie „undocumented").
- Vereinzelte Forumsberichte über einen Schwarzbild-Bug beim Aufruf von `openApplication()` auf manchen Geräten/SDK-Versionen.

iOS ist nicht Teil dieses Spikes (App unterstützt kein iOS).

---

## Architektur

Drei unabhängig verständliche Teile:

1. **Watch-App (Monkey C / Connect IQ)** — eigenständiges Projekt, komplett getrennte Toolchain von Flutter.
2. **Native Android-Bridge (Kotlin)** — kapselt die Connect-IQ-SDK-Aufrufe, exponiert sie über einen `MethodChannel`.
3. **Dart-Service** — ruft den Channel auf, liefert Connection-Status und `openWatchApp()` an die UI.

Datenfluss ist für diesen Spike bewusst einseitig: Dart → Kotlin-Bridge → Garmin SDK → Uhr. Es gibt **keine** Rückkommunikation von der Uhr zum Handy (App Messages für Vitaldaten folgen erst in einer späteren Iteration) — das hält den Spike klein.

---

## Abschnitt 1 — Entwicklungsumgebung (einmaliges Setup, kein App-Code)

- Connect IQ SDK Manager installieren (developer.garmin.com/connect-iq/sdk/)
- VS Code + Monkey C Extension
- Java 8 (JDK) für den Monkey-C-Compiler
- Garmin Connect Developer Account anlegen — wird für die App-Registrierung/Application-ID gebraucht
- Venu 4 in den Entwicklermodus versetzen, damit die Watch-App per USB sideloaded werden kann — die genauen Schritte dafür sind nicht Teil dieser Spec und werden beim Umsetzungsplan recherchiert, da die Venu 4 ein sehr neues Modell ist

---

## Abschnitt 2 — Watch-App (Monkey C)

**Neues Verzeichnis:** `garmin_watch_app/` im Repo-Root (sibling zu `android/`, `ios/`, `lib/`) — eigenständiges Connect-IQ-Projekt, nicht Teil des Flutter-Builds.

- `manifest.xml` — App-Typ `watchApp`, eigene Application-ID (UUID), wird beim Anlegen des Projekts über die SDK-Tools generiert
- Eine `View`-Klasse zeigt den Text „Hello World"
- Ein `BehaviorDelegate` reagiert auf `onSelect()` (Touch-Tap bzw. physische Taste) und beendet die App über `System.exit()`

---

## Abschnitt 3 — Android-Bridge (Kotlin)

**Datei:** `android/app/build.gradle.kts`
Dependency `com.garmin.connectiq:ciq-companion-app-sdk` ergänzen (Version zum Umsetzungszeitpunkt auf Maven Central prüfen). Kein zusätzlicher Repository-Eintrag nötig — `android/build.gradle.kts` deklariert bereits `mavenCentral()`, und das SDK wird laut Garmins eigenem README genau dort veröffentlicht (verifiziert).

**Neue Datei:** `android/app/src/main/kotlin/com/example/emom_app/GarminBridge.kt`
Kapselt `ConnectIQ.getInstance()`, `initialize()`, `getConnectedDevices()`, `getApplicationInfo(applicationId, device, listener)`, `openApplication(device, iqApp, callback)`. Die Watch-App-Application-ID wird als Konstante hinterlegt, sobald sie aus Abschnitt 2 feststeht.

**Datei:** `android/app/src/main/kotlin/com/example/emom_app/MainActivity.kt`
Registriert einen `MethodChannel` (`com.example.emom_app/garmin`) und delegiert an `GarminBridge`. Zwei Methoden:
- `isWatchConnected() -> bool`
- `openWatchApp() -> String` — Ergebnis-Status als String (`"launched"`, `"not_installed"`, `"no_device"`, `"error"`)

---

## Abschnitt 4 — Dart-Service

**Neue Datei:** `lib/core/services/garmin_service.dart`

Schlanker Wrapper um den `MethodChannel` mit `Future<bool> isWatchConnected()` und `Future<String> openWatchApp()`. Verwaltet zusätzlich eine dauerhafte „schon mal erfolgreich verbunden"-Historie (siehe Abschnitt 5): `Future<bool> hasEverConnected()` / `Future<void> markEverConnected()`, gesichert über ein eigenes SharedPreferences-Flag (`garminHasEverConnected`), unabhängig vom `AppSettings`-Speicherzyklus — muss sofort beim ersten erfolgreichen Verbindungscheck geschrieben werden, auch wenn der Nutzer sich gerade nicht im `ConfigScreen` befindet.

Ein `@riverpod`-Notifier `GarminNotifier` (`lib/features/config/garmin_notifier.dart`, gleiche Konvention wie `HistoryNotifier`) kapselt `GarminService` für die UI. State-Typ `GarminConnectionStatus { bool connected; bool everConnected; }`: `build()` prüft `isWatchConnected()` und aktualisiert bei Erfolg sofort `everConnected`; `openWatchApp()` ruft den Service auf und invalidiert sich danach selbst, damit der Status neu geladen wird.

---

## Abschnitt 5 — UI: Ampel-Icon im Header + Einstellungen

**Header-Icon** (**neue Datei** `lib/features/workout/widgets/garmin_header_icon.dart`; eingebunden in `lib/features/workout/widgets/workout_header.dart`, zwischen dem bestehenden Verlauf- und Zahnrad-Icon):

Liest `garminProvider` (→ `GarminConnectionStatus`) und `settingsProvider` (→ `AppSettings.garminHeaderIconVisible`). Rendert `SizedBox.shrink()`, wenn der Toggle aus ist. Sonst ein Uhr-Icon in drei Farben:
- `connected == true` → **grün** (`AppTheme.ok`)
- `connected == false && everConnected == true` → **rot** (`AppTheme.danger`) — deckt auch triviale/transiente Gründe ab, z.B. Bluetooth am Handy gerade aus
- `connected == false && everConnected == false` → **grau** — reiner Erstzustand, „hier war noch nie eine Verbindung"

Tap-Verhalten:
- Grau → navigiert zum `ConfigScreen` (Ersteinrichtung dort, kein Verbindungsversuch)
- Rot/Grün → `GarminNotifier.openWatchApp()` (verbindet bei Bedarf und öffnet die Watch-App in einem Aufruf)

**Einstellungen** (`lib/features/config/config_screen.dart`, Abschnitt „Garmin-Uhr" — ersetzt den ursprünglich geplanten reinen Test-Eintrag):
- Verbindungsstatus + „Watch-App öffnen"-Button bleiben erhalten, dienen jetzt der Ersteinrichtung/Fehlersuche statt der primären Bedienung (die läuft über das Header-Icon)
- Neuer Toggle „In der Hauptansicht anzeigen" → `AppSettings.garminHeaderIconVisible` (bool, Default `false`), gespeichert nach dem Muster von `trainingReminderEnabled` (`feedback_tab.dart:265-273`) — sofortiges Speichern beim Umschalten, nicht erst beim Verlassen des Screens

---

## Dateistruktur

| Datei | Änderung |
|---|---|
| `garmin_watch_app/` | **Neu** — komplettes Monkey-C/Connect-IQ-Projekt (manifest, View, Delegate) |
| `android/app/build.gradle.kts` | Connect IQ Mobile SDK Dependency (Maven Central, bereits konfiguriert) |
| `android/app/src/main/kotlin/.../GarminBridge.kt` | **Neu** — kapselt ConnectIQ-SDK-Aufrufe |
| `android/app/src/main/kotlin/.../MainActivity.kt` | MethodChannel registrieren |
| `lib/core/services/garmin_service.dart` | **Neu** — Dart-Wrapper um den MethodChannel + everConnected-Persistenz |
| `lib/features/config/garmin_notifier.dart` | **Neu** — `@riverpod`-Notifier mit `GarminConnectionStatus` |
| `lib/core/models/settings.dart` | `AppSettings.garminHeaderIconVisible` (neues Feld) |
| `lib/features/config/config_screen.dart` | Garmin-Abschnitt: Status/Test-Button + Sichtbarkeits-Toggle |
| `lib/features/workout/widgets/garmin_header_icon.dart` | **Neu** — Ampel-Icon (grau/rot/grün) |
| `lib/features/workout/widgets/workout_header.dart` | Neues Icon zwischen Verlauf und Zahnrad |

---

## Fehlerbehandlung / Risiken

- **Keine Uhr verbunden:** `isWatchConnected()` liefert `false`; Status wird angezeigt, kein Crash.
- **Watch-App nicht auf der Uhr installiert** (noch nicht sideloaded): `getApplicationInfo` liefert einen Fehlerstatus; klar anzeigen („App nicht auf Uhr gefunden"), keine ungefangene Exception.
- **Schwarzbild-Bug bei `openApplication`** (vereinzelte Community-Berichte, gerätespezifisch): muss an der echten Venu 4 verifiziert werden. Falls reproduzierbar, ist das ein Blocker für den gewünschten automatischen Ablauf und braucht eine Rückfalllösung (z.B. Nutzer öffnet die Watch-App einmalig manuell) — wird erst nach tatsächlichem Auftreten angegangen, kein Workaround vorab bauen.
- **Bluetooth-Berechtigungen:** Das Connect IQ Mobile SDK benötigt je nach Android-Version Bluetooth-Berechtigungen (Manifest-Eintrag, ggf. Runtime-Permission-Dialog) — Details werden beim Umsetzungsplan geklärt.
- **Kein Live-Update des Header-Icons:** `garminProvider` ist wie alle Provider in diesem Projekt `keepAlive` und prüft die Verbindung nur beim ersten Aufbau sowie nach einem Tap (über `invalidateSelf()`) neu — es gibt kein Polling und keinen nativen Connect/Disconnect-Event-Stream. Schaltet der Nutzer z.B. Bluetooth während offener App aus, bleibt das Icon bis zum nächsten Tap oder App-Neustart auf dem zuletzt bekannten Stand. Ein Tap auf ein fälschlich noch grün angezeigtes Icon schlägt dann einfach fehl (Status wird dabei korrigiert) — kein Absturz, aber bewusst kein Live-Verhalten in diesem Spike.

---

## Testing

- Watch-App-Logik zuerst im Connect-IQ-Simulator (Teil des SDKs) prüfen.
- End-to-End (Handy ↔ echte Venu 4) nur manuell testbar — Bluetooth-Hardware-Interaktion lässt sich nicht sinnvoll automatisieren.
- Kein `flutter test`-Unit-Test für die Bridge selbst sinnvoll (reiner Hardware-Wrapper), aber `flutter analyze` muss weiterhin fehlerfrei bleiben.

---

## Erfolgskriterien

- Entwicklungsumgebung (SDK, VS Code Extension, Developer Account) eingerichtet.
- Watch-App baut und läuft im Simulator, zeigt „Hello World", OK-Button beendet sie.
- Watch-App erfolgreich per USB auf die Venu 4 sideloaded.
- Handy-App erkennt über `isWatchConnected()` korrekt den Verbindungsstatus der Uhr.
- Header-Icon zeigt den korrekten Farbzustand (grau/rot/grün) je nach `connected`/`everConnected` und reagiert korrekt auf den Sichtbarkeits-Toggle in den Einstellungen.
- Tap auf das Header-Icon öffnet die Watch-App auf der echten Venu 4 zuverlässig, wenn rot/grün (kein Schwarzbild); Tap bei grau navigiert zu den Einstellungen.
- OK-Button auf der Uhr schließt die Watch-App wieder.

---

## Nicht im Scope

- Trainingsanzeige auf der Uhr
- Vitaldaten (Herzfrequenz etc.) — weder Anzeige noch Speicherung
- Rückkanal Uhr → Handy (App Messages) — erst in einer späteren Iteration
- iOS
- Automatischer Start der Watch-App beim Trainingsstart
- Finale/hübsche UI für den Einstellungs-Abschnitt (reiner Status/Test-Bereich, keine Gestaltung)
- **Zurücksetzen der Verbindungshistorie:** Eine Möglichkeit, `everConnected` in den Einstellungen manuell zurückzusetzen (Icon wird wieder grau), ist nicht Teil dieses Spikes — als Wunsch für eine spätere Iteration hier festgehalten.
- **Live-Update des Header-Icons** (Polling oder nativer Connect/Disconnect-Event-Stream, damit das Icon ohne Tap automatisch aktuell bleibt) — siehe "Fehlerbehandlung / Risiken", ebenfalls für eine spätere Iteration.
