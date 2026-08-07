# Garmin-Verbindung: Hello-World-Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Handy-App erkennt eine verbundene Garmin Venu 4 und kann gezielt eine neu gebaute Connect-IQ-Watch-App öffnen, die nur "Hello World" zeigt und sich per Tap wieder schließt — als Fundament für die spätere Trainings-/Vitaldaten-Anbindung.

**Architecture:** Drei unabhängige Teile: (1) eine Monkey-C-Watch-App in `garmin_watch_app/`, (2) eine Kotlin-Bridge um Garmins Connect IQ Mobile SDK (Android) hinter einem `MethodChannel`, (3) ein schlanker Dart-Service + Riverpod-Notifier, der von einem neuen Test-Eintrag im `ConfigScreen` aus aufgerufen wird. Datenfluss ist einseitig: Dart → Kotlin → Garmin-SDK → Uhr, keine Rückkommunikation in diesem Spike.

**Tech Stack:** Flutter/Dart, Riverpod (`riverpod_annotation`/`riverpod_generator`), Kotlin (Android Platform Channel), Garmin Connect IQ SDK (Monkey C) + Connect IQ Mobile SDK für Android (`com.garmin.connectiq:ciq-companion-app-sdk`).

## Global Constraints

- iOS ist nicht Teil dieses Spikes (App unterstützt kein iOS, siehe `docs/emom_app_spezifikation.md`).
- Kein Rückkanal Uhr → Handy in diesem Spike (kommt erst mit Vitaldaten in einer späteren Iteration).
- Kein automatischer Start beim Trainingsbeginn — dieser Spike hat einen manuellen Test-Button in den Einstellungen.
- `flutter analyze` muss nach jedem Dart/Kotlin-Task weiterhin 0 Fehler liefern; `flutter test` muss grün bleiben.
- Neue `@riverpod`-Provider brauchen `dart run build_runner build` zur Regenerierung der `.g.dart`-Datei (siehe `CLAUDE.md`).
- Package-Name des Projekts: `emom_app`; Android-`applicationId`: `com.example.emom_app`.

Referenz: `docs/superpowers/specs/2026-08-07-garmin-connect-spike-design.md`

---

## Wichtiger Hinweis zu Wissenslücken

Zwei Details sind aus reiner Dokumentenrecherche nicht zweifelsfrei zu klären (Garmins offizielle Doku-Seiten sind JS-gerendert und lieferten beim Abruf nur die Navigationsleiste, nicht den Artikeltext): die exakten Schritte zur Aktivierung eines eventuellen "Entwicklermodus" auf der Venu 4, und ob das Sideloaden per USB-Massenspeicher (`GARMIN/APPS/`-Ordner) auf diesem Modell ohne Weiteres funktioniert. Task 1 und Task 3 sind deshalb als Recherche-plus-Ausführung formuliert statt als reines Abhaken — im Zweifel Garmins Support-Seite für die Venu 4 bzw. das Connect-IQ-Entwicklerforum konsultieren, bevor an der Hardware geschraubt wird.

---

### Task 1: Entwicklungsumgebung einrichten

**Manuell, kein Repo-Code.** Diese Schritte macht Tobias selbst (Software-Installation, Account-Anlage, Hardware-Pairing) — keine Subagent-Ausführung möglich.

- [ ] **Schritt 1: Connect IQ SDK installieren**

  Auf https://developer.garmin.com/connect-iq/sdk/ den "Connect IQ SDK Manager" herunterladen und installieren. Über den SDK Manager das aktuelle Connect IQ SDK für den Zielgerätetyp (Venu 4) installieren.

- [ ] **Schritt 2: Java 8 sicherstellen**

  Monkey-C-Compiler (`monkeyc`) braucht ein JDK. Prüfen: `java -version`. Falls nicht vorhanden oder falsche Version: JDK 8 oder neuer installieren (der SDK Manager weist beim ersten Start darauf hin, falls es fehlt).

- [ ] **Schritt 3: VS Code Monkey C Extension installieren**

  In VS Code die Extension "Monkey C" (Publisher: Garmin) installieren. Sie erkennt automatisch die vom SDK Manager installierte SDK-Version.

- [ ] **Schritt 4: Garmin Connect Developer Account anlegen**

  Auf https://developer.garmin.com mit dem bestehenden Garmin-Connect-Account anmelden bzw. Developer-Zugang freischalten. Wird für die App-Registrierung (Application-ID) in Task 2 gebraucht.

- [ ] **Schritt 5: Venu 4 für Sideloading vorbereiten**

  Uhr per USB mit dem Rechner verbinden. Prüfen, ob sie als Massenspeicher-Laufwerk mit einem `GARMIN/APPS/`-Ordner erscheint (Standard-Sideload-Mechanismus bei Garmin-Uhren). Falls das Gerät keinen Massenspeicher-Modus anbietet oder ein gesonderter Entwicklermodus nötig ist: in den Garmin-Support-Seiten für die Venu 4 nachschlagen (Settings → System → USB-Modus, oder eine Tastenkombination beim Verbinden — Details modellabhängig, hier nicht verlässlich vorab bekannt) und Ergebnis kurz in diesem Plan-Dokument als Notiz ergänzen, bevor Task 3 angegangen wird.

Kein Commit — reine Werkzeug-/Account-Einrichtung, keine Repo-Änderung.

---

### Task 2: Watch-App — Hello World + Exit-bei-Tap

**Files:**
- Create: `garmin_watch_app/manifest.xml` (durch SDK-Tooling generiert, siehe Schritt 1)
- Create: `garmin_watch_app/source/HelloWorldApp.mc`
- Create: `garmin_watch_app/source/HelloWorldView.mc`
- Create: `garmin_watch_app/source/HelloWorldDelegate.mc`

**Interfaces:**
- Produces: eine über den Connect-IQ-Simulator startbare Watch-App; die generierte **Application-ID** aus `manifest.xml` (Attribut `id` im `<iq:application>`-Tag) wird in Task 6 als Konstante gebraucht — nach Abschluss dieses Tasks hier notieren: `______________________________`

- [ ] **Schritt 1: Projekt über die VS-Code-Extension scaffolden**

  Command Palette → "Monkey C: New Project". Projektname: `garmin_watch_app` (im Repo-Root anlegen, sibling zu `android/`, `ios/`, `lib/`). Typ: **Watch App**. Zielgerät: **Venu 4**. Template: **Blank**. Die Extension generiert `manifest.xml`, `source/HelloWorldApp.mc` (oder ähnlich benannt — beim Anlegen den Klassennamen `HelloWorldApp` wählen, falls die Extension danach fragt) sowie Resource-Ordner.

  Falls die Extension einen anderen Einstiegs-Klassennamen vorschlägt: die Dateien in diesem Task konsequent an den generierten Namen anpassen (nicht blind `HelloWorldApp` erzwingen).

- [ ] **Schritt 2: `HelloWorldApp.mc` — Einstiegspunkt**

  Ersetze den generierten Inhalt durch:

  ```javascript
  import Toybox.Application;
  import Toybox.Lang;
  import Toybox.WatchUi;

  class HelloWorldApp extends Application.AppBase {
      function initialize() {
          AppBase.initialize();
      }

      function getInitialView() as [Views] or [Views, InputDelegates] {
          return [ new HelloWorldView(), new HelloWorldDelegate() ];
      }
  }
  ```

- [ ] **Schritt 3: `HelloWorldView.mc` — Anzeige**

  ```javascript
  import Toybox.WatchUi;
  import Toybox.Graphics;

  class HelloWorldView extends WatchUi.View {
      function initialize() {
          View.initialize();
      }

      function onUpdate(dc as Graphics.Dc) as Void {
          View.onUpdate(dc);
          dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
          dc.clear();
          dc.drawText(
              dc.getWidth() / 2,
              dc.getHeight() / 2,
              Graphics.FONT_MEDIUM,
              "Hello World",
              Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
          );
      }
  }
  ```

- [ ] **Schritt 4: `HelloWorldDelegate.mc` — Tap schließt die App**

  ```javascript
  import Toybox.WatchUi;
  import Toybox.Lang;
  import Toybox.System;

  class HelloWorldDelegate extends WatchUi.BehaviorDelegate {
      function initialize() {
          BehaviorDelegate.initialize();
      }

      function onSelect() as Boolean {
          System.exit();
          return true;
      }
  }
  ```

  `onSelect()` feuert bei einem Tap auf den Touchscreen (Venu 4 hat keine dedizierte "OK"-Taste) — ein Tap irgendwo auf dem Bildschirm dient als OK/Schließen-Aktion. Das ist eine bewusste Vereinfachung für den Spike, kein eigens gezeichneter Button.

- [ ] **Schritt 5: Im Simulator verifizieren**

  Im Connect-IQ-Simulator für Venu 4 bauen und starten (VS Code: "Monkey C: Run" oder `monkeydo` über die Kommandozeile, je nachdem was die installierte Extension anbietet). Erwartung: Simulator zeigt "Hello World" zentriert auf schwarzem Hintergrund. Tap auf den simulierten Touchscreen → App beendet sich (Simulator kehrt zur Geräte-Übersicht zurück oder zeigt "App terminated" — je nach Simulator-Version).

- [ ] **Schritt 6: Commit**

  ```bash
  git add garmin_watch_app/
  git commit -m "feat: Garmin Watch-App Hello-World-Spike (Monkey C)"
  ```

---

### Task 3: Watch-App auf die Venu 4 sideloaden

**Manuell, kein Repo-Code** (reine Hardware-Verifikation).

- [ ] **Schritt 1: `.prg` bauen**

  Über die VS-Code-Extension "Monkey C: Build for Device" (Zielgerät Venu 4) ausführen. Ergebnis: eine `.prg`-Datei im `bin/`-Ordner von `garmin_watch_app/`.

- [ ] **Schritt 2: Kopieren**

  Venu 4 per USB verbinden (siehe Task 1, Schritt 5). Die gebaute `.prg`-Datei in den `GARMIN/APPS/`-Ordner des Uhr-Laufwerks kopieren. Uhr sicher auswerfen/trennen.

- [ ] **Schritt 3: Auf der Uhr verifizieren**

  Auf der Venu 4 zur App-Liste navigieren, "HelloWorldApp" (bzw. den in Task 2 gewählten Namen) suchen und einmal manuell öffnen. Erwartung: "Hello World" erscheint, Tap beendet die App wieder — identisches Verhalten wie im Simulator (Task 2, Schritt 5), jetzt auf echter Hardware bestätigt.

Kein Commit — reine Geräte-Verifikation, keine Repo-Änderung.

---

### Task 4: Connect IQ Mobile SDK als Android-Dependency einbinden

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: `com.garmin.android.connectiq.*`-Klassen (`ConnectIQ`, `IQDevice`, `IQApp`) stehen im Kotlin-Code zur Verfügung (gebraucht in Task 5).

- [ ] **Schritt 1: Dependency ergänzen**

  In `android/app/build.gradle.kts`, im `dependencies { ... }`-Block:

  ```kotlin
  implementation("com.garmin.connectiq:ciq-companion-app-sdk:2.2.0@aar")
  ```

  (Versionsnummer beim Umsetzen auf Maven Central unter "CIQ Companion APP SDK" gegenprüfen — `2.2.0` ist der zum Zeitpunkt dieser Recherche aktuelle Stand.)

- [ ] **Schritt 2: Bluetooth-Berechtigungen ergänzen**

  In `android/app/src/main/AndroidManifest.xml`, falls noch nicht vorhanden:

  ```xml
  <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
  ```

  (Für Android 12+/API 31+ nötig, da das Connect-IQ-SDK intern Bluetooth nutzt, um Geräte zu erkennen.)

- [ ] **Schritt 3: Gradle-Sync verifizieren**

  Run: `flutter pub get && cd android && ./gradlew.bat :app:dependencies --configuration debugRuntimeClasspath`
  Expected: Build-Output enthält `com.garmin.connectiq:ciq-companion-app-sdk:2.2.0`, keine Resolution-Fehler.

  Zusätzlich: `flutter build apk --debug` läuft ohne neue Fehler durch (bestätigt, dass die App inkl. neuer Dependency weiterhin baut, auch wenn `GarminBridge.kt` erst in Task 5 entsteht).

- [ ] **Schritt 4: Commit**

  ```bash
  git add android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml
  git commit -m "chore: Connect IQ Mobile SDK Dependency + Bluetooth-Berechtigungen"
  ```

---

### Task 5: Kotlin-Bridge (`GarminBridge` + MethodChannel)

**Files:**
- Create: `android/app/src/main/kotlin/com/example/emom_app/GarminBridge.kt`
- Modify: `android/app/src/main/kotlin/com/example/emom_app/MainActivity.kt`

**Interfaces:**
- Consumes: Application-ID aus Task 2 (Watch-App-Manifest); Connect-IQ-Klassen aus Task 4.
- Produces: `MethodChannel("com.example.emom_app/garmin")` mit zwei Methoden:
  - `isWatchConnected` → `Boolean`
  - `openWatchApp` → `String` (einer von `"launched"`, `"not_installed"`, `"no_device"`, `"error"`)

- [ ] **Schritt 1: `GarminBridge.kt` schreiben**

  ```kotlin
  package com.example.emom_app

  import android.content.Context
  import com.garmin.android.connectiq.ConnectIQ
  import com.garmin.android.connectiq.IQApp
  import com.garmin.android.connectiq.IQDevice
  import com.garmin.android.connectiq.exception.InvalidStateException
  import com.garmin.android.connectiq.exception.ServiceUnavailableException

  class GarminBridge(private val context: Context) {

      // Application-ID aus garmin_watch_app/manifest.xml (Task 2) eintragen:
      private val watchAppId = "REPLACE_WITH_MANIFEST_APP_ID"

      private val connectIQ: ConnectIQ = ConnectIQ.getInstance(context, ConnectIQ.IQConnectType.WIRELESS)

      fun isWatchConnected(callback: (Boolean) -> Unit) {
          connectIQ.initialize(context, true, object : ConnectIQ.ConnectIQListener {
              override fun onSdkReady() {
                  val devices = connectIQ.connectedDevices
                  callback(devices != null && devices.isNotEmpty())
              }
              override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
                  callback(false)
              }
              override fun onSdkShutDown() {}
          })
      }

      fun openWatchApp(callback: (String) -> Unit) {
          connectIQ.initialize(context, true, object : ConnectIQ.ConnectIQListener {
              override fun onSdkReady() {
                  try {
                      val devices = connectIQ.connectedDevices
                      val device: IQDevice? = devices?.firstOrNull()
                      if (device == null) {
                          callback("no_device")
                          return
                      }
                      connectIQ.getApplicationInfo(watchAppId, device, object : ConnectIQ.IQApplicationInfoListener {
                          override fun onApplicationInfoReceived(app: IQApp) {
                              try {
                                  connectIQ.openApplication(device, app) { _, _, status ->
                                      callback(status.name)
                                  }
                              } catch (e: InvalidStateException) {
                                  callback("error")
                              } catch (e: ServiceUnavailableException) {
                                  callback("error")
                              }
                          }
                          override fun onApplicationNotInstalled(applicationId: String) {
                              callback("not_installed")
                          }
                      })
                  } catch (e: InvalidStateException) {
                      callback("error")
                  } catch (e: ServiceUnavailableException) {
                      callback("error")
                  }
              }
              override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
                  callback("error")
              }
              override fun onSdkShutDown() {}
          })
      }
  }
  ```

  Hinweis: Die exakten Methodennamen/Signaturen der `ConnectIQ`-Klasse (`connectedDevices` als Property vs. `getConnectedDevices()`-Methode, exakte Exception-Typen) stammen aus Community-Beispielcode und der `2.2.0`-AAR — beim Kompilieren gegen die tatsächlich aufgelöste SDK-Version in Android Studio/IntelliJ gegenprüfen und bei Abweichungen anpassen (Autovervollständigung der IDE nutzen).

- [ ] **Schritt 2: `MainActivity.kt` — MethodChannel registrieren**

  ```kotlin
  package com.example.emom_app

  import io.flutter.embedding.android.FlutterActivity
  import io.flutter.embedding.engine.FlutterEngine
  import io.flutter.plugin.common.MethodChannel

  class MainActivity : FlutterActivity() {
      private val channelName = "com.example.emom_app/garmin"

      override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
          super.configureFlutterEngine(flutterEngine)
          val bridge = GarminBridge(applicationContext)

          MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
              when (call.method) {
                  "isWatchConnected" -> bridge.isWatchConnected { connected -> result.success(connected) }
                  "openWatchApp" -> bridge.openWatchApp { status -> result.success(status) }
                  else -> result.notImplemented()
              }
          }
      }
  }
  ```

- [ ] **Schritt 3: Application-ID eintragen**

  In `GarminBridge.kt` den Platzhalter `"REPLACE_WITH_MANIFEST_APP_ID"` durch die in Task 2 notierte Application-ID aus `garmin_watch_app/manifest.xml` ersetzen.

- [ ] **Schritt 4: Build verifizieren**

  Run: `flutter build apk --debug`
  Expected: Build erfolgreich, keine Kotlin-Compile-Fehler.

- [ ] **Schritt 5: Commit**

  ```bash
  git add android/app/src/main/kotlin/com/example/emom_app/GarminBridge.kt android/app/src/main/kotlin/com/example/emom_app/MainActivity.kt
  git commit -m "feat: Kotlin-Bridge fuer Connect IQ Mobile SDK ueber MethodChannel"
  ```

---

### Task 6: `GarminService` (Dart-Wrapper um den MethodChannel)

**Files:**
- Create: `lib/core/services/garmin_service.dart`
- Test: `test/core/services/garmin_service_test.dart`

**Interfaces:**
- Consumes: `MethodChannel("com.example.emom_app/garmin")` aus Task 5, Methoden `isWatchConnected`/`openWatchApp`.
- Produces: `GarminService.isWatchConnected() → Future<bool>`, `GarminService.openWatchApp() → Future<String>` (gebraucht in Task 7).

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

  ```dart
  import 'package:flutter/services.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:emom_app/core/services/garmin_service.dart';

  void main() {
    TestWidgetsFlutterBinding.ensureInitialized();

    const channel = MethodChannel('com.example.emom_app/garmin');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        switch (call.method) {
          case 'isWatchConnected':
            return true;
          case 'openWatchApp':
            return 'launched';
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('isWatchConnected ruft den MethodChannel auf und gibt das Ergebnis zurueck', () async {
      final service = GarminService();
      final result = await service.isWatchConnected();
      expect(result, true);
      expect(calls.single.method, 'isWatchConnected');
    });

    test('openWatchApp gibt den nativen Status-String zurueck', () async {
      final service = GarminService();
      final result = await service.openWatchApp();
      expect(result, 'launched');
    });
  }
  ```

- [ ] **Schritt 2: Test ausführen, Fehlschlag bestätigen**

  Run: `flutter test test/core/services/garmin_service_test.dart`
  Expected: FAIL — `garmin_service.dart` existiert noch nicht (Import-Fehler).

- [ ] **Schritt 3: `GarminService` implementieren**

  ```dart
  import 'package:flutter/services.dart';

  class GarminService {
    static const _channel = MethodChannel('com.example.emom_app/garmin');

    Future<bool> isWatchConnected() async {
      final result = await _channel.invokeMethod<bool>('isWatchConnected');
      return result ?? false;
    }

    Future<String> openWatchApp() async {
      final result = await _channel.invokeMethod<String>('openWatchApp');
      return result ?? 'error';
    }
  }
  ```

- [ ] **Schritt 4: Test ausführen, Erfolg bestätigen**

  Run: `flutter test test/core/services/garmin_service_test.dart`
  Expected: PASS (beide Tests grün)

- [ ] **Schritt 5: Commit**

  ```bash
  git add lib/core/services/garmin_service.dart test/core/services/garmin_service_test.dart
  git commit -m "feat: GarminService als Dart-Wrapper um den MethodChannel"
  ```

---

### Task 7: `GarminNotifier` + Test-Eintrag in `ConfigScreen`

**Files:**
- Create: `lib/features/config/garmin_notifier.dart`
- Modify: `lib/features/config/config_screen.dart`
- Test: `test/features/config/garmin_config_row_test.dart`

**Interfaces:**
- Consumes: `GarminService` aus Task 6.
- Produces: `garminProvider` (liefert `AsyncValue<bool>` = Verbindungsstatus) und `GarminNotifier.openWatchApp() → Future<String>`, aufgerufen aus `ConfigScreen`. (Riverpod-Codegen kürzt das "Notifier"-Suffix im Provider-Namen — vgl. `HistoryNotifier` → `historyProvider` in `history_notifier.g.dart`.)

- [ ] **Schritt 1: Fehlschlagenden Widget-Test schreiben**

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:emom_app/features/config/config_screen.dart';
  import 'package:emom_app/features/config/garmin_notifier.dart';

  void main() {
    testWidgets('zeigt Garmin-Test-Eintrag mit Verbindungsstatus', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            garminProvider.overrideWith(() => _FakeGarminNotifier()),
          ],
          child: const MaterialApp(home: ConfigScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Garmin-Uhr (Test)'), findsOneWidget);
      expect(find.text('Watch-App öffnen'), findsOneWidget);
    });

    testWidgets('Tap auf "Watch-App öffnen" ruft openWatchApp auf', (tester) async {
      final fake = _FakeGarminNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            garminProvider.overrideWith(() => fake),
          ],
          child: const MaterialApp(home: ConfigScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Watch-App öffnen'));
      await tester.pumpAndSettle();

      expect(fake.openWatchAppCalled, true);
    });
  }

  class _FakeGarminNotifier extends GarminNotifier {
    bool openWatchAppCalled = false;

    @override
    Future<bool> build() async => true;

    @override
    Future<String> openWatchApp() async {
      openWatchAppCalled = true;
      return 'launched';
    }
  }
  ```

- [ ] **Schritt 2: Test ausführen, Fehlschlag bestätigen**

  Run: `flutter test test/features/config/garmin_config_row_test.dart`
  Expected: FAIL — `garmin_notifier.dart` existiert noch nicht, `ConfigScreen` hat noch keinen "Garmin-Uhr (Test)"-Eintrag.

- [ ] **Schritt 3: `GarminNotifier` implementieren**

  ```dart
  import 'package:riverpod_annotation/riverpod_annotation.dart';
  import '../../core/services/garmin_service.dart';

  part 'garmin_notifier.g.dart';

  @riverpod
  class GarminNotifier extends _$GarminNotifier {
    final GarminService _service = GarminService();

    @override
    Future<bool> build() => _service.isWatchConnected();

    Future<String> openWatchApp() => _service.openWatchApp();

    Future<void> refresh() async {
      state = const AsyncLoading();
      state = AsyncData(await _service.isWatchConnected());
    }
  }
  ```

- [ ] **Schritt 4: `.g.dart` generieren**

  Run: `dart run build_runner build --delete-conflicting-outputs`
  Expected: `lib/features/config/garmin_notifier.g.dart` wird erzeugt, keine Fehler.

- [ ] **Schritt 5: `ConfigScreen` — neuen Eintrag ergänzen**

  In `lib/features/config/config_screen.dart`, Import ergänzen:

  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../core/theme/app_theme.dart';
  import 'garmin_notifier.dart';
  ```

  (Die ersten beiden Imports existieren vermutlich schon — nur `garmin_notifier.dart` ist neu.)

  Im `build`-Method, nach dem bestehenden "Geräte & Übungen"-Block (vor `FeedbackTab(...)`), einfügen:

  ```dart
  const SizedBox(height: 24),
  const Padding(
    padding: EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      'GARMIN-UHR (TEST)',
      style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white24),
    ),
  ),
  Builder(builder: (context) {
    final connection = ref.watch(garminProvider);
    final connected = connection.valueOrNull ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.watch : Icons.watch_off,
                color: connected ? AppTheme.ok : AppTheme.danger,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  connected ? 'Uhr verbunden' : 'Uhr nicht verbunden',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final status = await ref.read(garminProvider.notifier).openWatchApp();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Status: $status')),
                  );
                }
              },
              child: const Text('Watch-App öffnen'),
            ),
          ),
        ],
      ),
    );
  }),
  ```

- [ ] **Schritt 6: Test ausführen, Erfolg bestätigen**

  Run: `flutter test test/features/config/garmin_config_row_test.dart`
  Expected: PASS (beide Tests grün)

- [ ] **Schritt 7: Gesamte Testsuite + Analyzer prüfen**

  Run: `flutter analyze && flutter test`
  Expected: 0 Analyzer-Fehler, alle Tests grün.

- [ ] **Schritt 8: Commit**

  ```bash
  git add lib/features/config/garmin_notifier.dart lib/features/config/garmin_notifier.g.dart lib/features/config/config_screen.dart test/features/config/garmin_config_row_test.dart
  git commit -m "feat: Garmin-Test-Eintrag im ConfigScreen (Verbindungsstatus + Watch-App oeffnen)"
  ```

---

### Task 8: Ende-zu-Ende-Verifikation auf echter Hardware

**Manuell, kein Repo-Code.** Finale Abnahme der Erfolgskriterien aus der Spec.

- [ ] **Schritt 1: Debug-APK auf dem Handy installieren**

  Run: `flutter install` (oder `flutter run --release=false` bei verbundenem Test-Handy)

- [ ] **Schritt 2: Venu 4 verbinden**

  Sicherstellen, dass Handy und Venu 4 per Bluetooth gekoppelt und die Garmin-Connect-Mobile-App im Hintergrund aktiv ist (das Connect-IQ-Mobile-SDK baut auf dieser Kopplung auf).

- [ ] **Schritt 3: Verbindungsstatus prüfen**

  In der Kettlebell-EMOM-App → Einstellungen → "Garmin-Uhr (Test)". Erwartung: zeigt "Uhr verbunden" mit grünem Icon.

- [ ] **Schritt 4: Watch-App öffnen**

  Auf "Watch-App öffnen" tippen. Erwartung: Auf der Venu 4 öffnet sich die Hello-World-App automatisch (kein Schwarzbild — falls doch, siehe Spec-Abschnitt "Fehlerbehandlung / Risiken", das ist der zu verifizierende Risikofall). Am Handy erscheint eine Snackbar mit dem zurückgemeldeten Status.

- [ ] **Schritt 5: Watch-App schließen**

  Auf der Uhr auf den Bildschirm tippen. Erwartung: App beendet sich.

- [ ] **Schritt 6: Ergebnis festhalten**

  Kurze Notiz in `docs/emom_app_spezifikation.md` (Abschnitt "Garmin-Integration") ergänzen: ob der Spike erfolgreich war, und falls der Schwarzbild-Bug aufgetreten ist, welches Verhalten genau beobachtet wurde (Grundlage für die nächste Iteration).

Kein Commit für Schritte 1–5 (reine Verifikation). Falls Schritt 6 die Spec-Datei ändert:

```bash
git add docs/emom_app_spezifikation.md
git commit -m "docs: Ergebnis des Garmin-Verbindungs-Spikes festgehalten"
```

---

## Zusammenfassung Dateistruktur

| Datei | Task |
|---|---|
| `garmin_watch_app/` (Monkey-C-Projekt) | 2 |
| `android/app/build.gradle.kts` | 4 |
| `android/app/src/main/AndroidManifest.xml` | 4 |
| `android/app/src/main/kotlin/.../GarminBridge.kt` | 5 |
| `android/app/src/main/kotlin/.../MainActivity.kt` | 5 |
| `lib/core/services/garmin_service.dart` + Test | 6 |
| `lib/features/config/garmin_notifier.dart` + `.g.dart` | 7 |
| `lib/features/config/config_screen.dart` | 7 |
| `test/features/config/garmin_config_row_test.dart` | 7 |
