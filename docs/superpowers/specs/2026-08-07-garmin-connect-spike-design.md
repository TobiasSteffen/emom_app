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
Dependency `com.garmin.connectiq:ciq-companion-app-sdk` ergänzen (Version zum Umsetzungszeitpunkt auf Maven Central prüfen) inkl. des benötigten Maven-Repositoryeintrags.

**Neue Datei:** `android/app/src/main/kotlin/com/example/emom_app/GarminBridge.kt`
Kapselt `ConnectIQ.getInstance()`, `initialize()`, `getConnectedDevices()`, `getApplicationInfo(applicationId, device, listener)`, `openApplication(device, iqApp, callback)`. Die Watch-App-Application-ID wird als Konstante hinterlegt, sobald sie aus Abschnitt 2 feststeht.

**Datei:** `android/app/src/main/kotlin/com/example/emom_app/MainActivity.kt`
Registriert einen `MethodChannel` (`com.example.emom_app/garmin`) und delegiert an `GarminBridge`. Zwei Methoden:
- `isWatchConnected() -> bool`
- `openWatchApp() -> String` — Ergebnis-Status als String (`"launched"`, `"not_installed"`, `"no_device"`, `"error"`)

---

## Abschnitt 4 — Dart-Service

**Neue Datei:** `lib/core/services/garmin_service.dart`

Schlanker Wrapper um den `MethodChannel` mit `Future<bool> isWatchConnected()` und `Future<String> openWatchApp()`. Als einfacher `Provider<GarminService>` in Riverpod registriert (kein `AsyncNotifier` — es gibt keinen persistenten State, nur zwei einmalige Aufrufe; passt zum YAGNI-Prinzip, während die Service-Instanz trotzdem über die etablierte DI abrufbar bleibt).

---

## Abschnitt 5 — UI-Einstiegspunkt (Test-UI, kein finales Feature)

**Datei:** `lib/features/config/config_screen.dart`

Neuer Eintrag „Garmin-Uhr (Test)" analog zum bestehenden „Geräte & Übungen"-Eintrag: zeigt den Verbindungsstatus (`isWatchConnected()`) und einen Button „Watch-App öffnen" (`openWatchApp()`, Ergebnis als Snackbar). Bewusst als Test-Eintrag markiert — wird ersetzt, sobald die eigentliche Trainings-/Vitaldaten-Anbindung gebaut wird.

---

## Dateistruktur

| Datei | Änderung |
|---|---|
| `garmin_watch_app/` | **Neu** — komplettes Monkey-C/Connect-IQ-Projekt (manifest, View, Delegate) |
| `android/app/build.gradle.kts` | Connect IQ Mobile SDK Dependency + Maven-Repo |
| `android/app/src/main/kotlin/.../GarminBridge.kt` | **Neu** — kapselt ConnectIQ-SDK-Aufrufe |
| `android/app/src/main/kotlin/.../MainActivity.kt` | MethodChannel registrieren |
| `lib/core/services/garmin_service.dart` | **Neu** — Dart-Wrapper um den MethodChannel |
| `lib/features/config/config_screen.dart` | Neuer Test-Eintrag „Garmin-Uhr (Test)" |

---

## Fehlerbehandlung / Risiken

- **Keine Uhr verbunden:** `isWatchConnected()` liefert `false`; Status wird angezeigt, kein Crash.
- **Watch-App nicht auf der Uhr installiert** (noch nicht sideloaded): `getApplicationInfo` liefert einen Fehlerstatus; klar anzeigen („App nicht auf Uhr gefunden"), keine ungefangene Exception.
- **Schwarzbild-Bug bei `openApplication`** (vereinzelte Community-Berichte, gerätespezifisch): muss an der echten Venu 4 verifiziert werden. Falls reproduzierbar, ist das ein Blocker für den gewünschten automatischen Ablauf und braucht eine Rückfalllösung (z.B. Nutzer öffnet die Watch-App einmalig manuell) — wird erst nach tatsächlichem Auftreten angegangen, kein Workaround vorab bauen.
- **Bluetooth-Berechtigungen:** Das Connect IQ Mobile SDK benötigt je nach Android-Version Bluetooth-Berechtigungen (Manifest-Eintrag, ggf. Runtime-Permission-Dialog) — Details werden beim Umsetzungsplan geklärt.

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
- Button in der Handy-App öffnet die Watch-App auf der echten Venu 4 zuverlässig (kein Schwarzbild).
- OK-Button auf der Uhr schließt die Watch-App wieder.

---

## Nicht im Scope

- Trainingsanzeige auf der Uhr
- Vitaldaten (Herzfrequenz etc.) — weder Anzeige noch Speicherung
- Rückkanal Uhr → Handy (App Messages) — erst in einer späteren Iteration
- iOS
- Automatischer Start der Watch-App beim Trainingsstart (dieser Spike hat einen manuellen Test-Button in den Einstellungen)
- Finale/hübsche UI — reiner Test-Eintrag
