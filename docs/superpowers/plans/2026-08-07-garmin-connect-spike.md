# Garmin-Verbindung: Hello-World-Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Handy-App erkennt eine verbundene Garmin Venu 4 und kann gezielt eine neu gebaute Connect-IQ-Watch-App öffnen, die nur "Hello World" zeigt und sich per Tap wieder schließt — als Fundament für die spätere Trainings-/Vitaldaten-Anbindung.

**Architecture:** Drei unabhängige Teile: (1) eine Monkey-C-Watch-App in `garmin_watch_app/`, (2) eine Kotlin-Bridge um Garmins Connect IQ Mobile SDK (Android) hinter einem `MethodChannel`, (3) ein schlanker Dart-Service + Riverpod-Notifier, bedient über zwei UI-Einstiegspunkte: ein Ampel-Icon (grau/rot/grün) im Workout-Header für die Alltagsbedienung, und ein Abschnitt im `ConfigScreen` für Ersteinrichtung/Fehlersuche sowie den Sichtbarkeits-Toggle des Header-Icons. Datenfluss ist einseitig: Dart → Kotlin → Garmin-SDK → Uhr, keine Rückkommunikation in diesem Spike.

**Tech Stack:** Flutter/Dart, Riverpod (`riverpod_annotation`/`riverpod_generator`), Kotlin (Android Platform Channel), Garmin Connect IQ SDK (Monkey C) + Connect IQ Mobile SDK für Android (`com.garmin.connectiq:ciq-companion-app-sdk`).

## Global Constraints

- iOS ist nicht Teil dieses Spikes (App unterstützt kein iOS, siehe `docs/emom_app_spezifikation.md`).
- Kein Rückkanal Uhr → Handy in diesem Spike (kommt erst mit Vitaldaten in einer späteren Iteration).
- Kein automatischer Start beim Trainingsbeginn — Öffnen der Watch-App ist immer ein manueller Tap (Header-Icon oder Einstellungen-Button).
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

- [ ] **Schritt 1: Connect IQ SDK installieren (inkl. Login)**

  Auf https://developer.garmin.com/connect-iq/sdk/ den "Connect IQ SDK Manager" herunterladen und installieren (kein Login zum Herunterladen nötig). Beim ersten Start fragt der SDK Manager nach einem Login — dafür reicht der **normale, bestehende Garmin-Connect-Account** (der auch mit der Uhr verknüpft ist), es ist **keine** separate Developer-Registrierung/-Freischaltung nötig (die auf garmin.com/forms/ciq-registration ist nur für die Store-Veröffentlichung relevant, nicht für lokales Sideload-Testing — verifiziert in Garmins "New Developer FAQ"). Über den SDK Manager danach das aktuelle Connect IQ SDK für den Zielgerätetyp (Venu 4) installieren.

  Die Application-ID pro Watch-App (Task 2) wird rein lokal von der VS-Code-Extension als UUID generiert, keine Server-Registrierung nötig.

- [ ] **Schritt 2: Java 8 sicherstellen**

  Monkey-C-Compiler (`monkeyc`) braucht ein JDK. Prüfen: `java -version`. Falls nicht vorhanden oder falsche Version: JDK 8 oder neuer installieren (der SDK Manager weist beim ersten Start darauf hin, falls es fehlt).

- [ ] **Schritt 3: VS Code Monkey C Extension installieren**

  In VS Code die Extension "Monkey C" (Publisher: Garmin) installieren. Sie erkennt automatisch die vom SDK Manager installierte SDK-Version.

- [ ] **Schritt 4: Venu 4 für Sideloading vorbereiten**

  Uhr per USB mit dem Rechner verbinden. Prüfen, ob sie als Massenspeicher-Laufwerk mit einem `GARMIN/APPS/`-Ordner erscheint (Standard-Sideload-Mechanismus bei Garmin-Uhren). Falls das Gerät keinen Massenspeicher-Modus anbietet oder ein gesonderter Entwicklermodus nötig ist: in den Garmin-Support-Seiten für die Venu 4 nachschlagen (Settings → System → USB-Modus, oder eine Tastenkombination beim Verbinden — Details modellabhängig, hier nicht verlässlich vorab bekannt) und Ergebnis kurz in diesem Plan-Dokument als Notiz ergänzen, bevor Task 3 angegangen wird.

Kein Commit — reine Werkzeug-/Account-Einrichtung, keine Repo-Änderung.

---

### Task 2: Watch-App — Hello World + Exit-bei-Tap

**Files:**
- Create: `garmin_watch_app/manifest.xml` (durch SDK-Tooling generiert, siehe Schritt 1)
- Create: `garmin_watch_app/source/garmin_watch_appApp.mc`
- Create: `garmin_watch_app/source/garmin_watch_appView.mc`
- Create: `garmin_watch_app/source/garmin_watch_appDelegate.mc`
- Deleted (generiert, nicht gebraucht): `garmin_watch_app/source/garmin_watch_appMenuDelegate.mc`, `garmin_watch_app/resources/menus/`, `garmin_watch_app/resources/drawables/monkey.png`

**Interfaces:**
- Produces: eine über den Connect-IQ-Simulator startbare Watch-App; die generierte **Application-ID** aus `manifest.xml` wird in Task 5 als Konstante gebraucht — **`ddb356dd-6f3c-4f7a-bb62-3664460edba8`**, bereits in `GarminBridge.kt` eingetragen.

**Tatsächlich generierte Klassennamen (statt der ursprünglich angenommenen `HelloWorldApp`/`HelloWorldView`/`HelloWorldDelegate`):** Die VS-Code-Extension hat die Klassen nach dem Projektnamen benannt: `garmin_watch_appApp`, `garmin_watch_appView`, `garmin_watch_appDelegate` — Dateien entsprechend `source/garmin_watch_appApp.mc` etc. Zusätzlich wurde ein `garmin_watch_appMenuDelegate` samt Menü-Ressource generiert (Blank-Template kommt mit einem 2-Item-Menü) — das wurde entfernt (Datei gelöscht, `resources/menus/` gelöscht, `onMenu()` aus dem Delegate entfernt), da die Spec ausdrücklich "keine Funktionalität außer Hello World + Schließen" vorgibt. `garmin_watch_appView.mc` nutzt das generierte Ressourcen-Layout (`Rez.Layouts.MainLayout` + `@Strings.prompt`) statt direktem `dc.drawText(...)` — Text wurde über `strings.xml` auf "Hello World" geändert, das mitgelieferte Monkey-Logo-Bitmap aus Layout und Ressourcen entfernt (nicht Teil der Spec).

- [x] **Schritt 1: Projekt über die VS-Code-Extension scaffolden**

  Command Palette → "Monkey C: New Project". Projektname `garmin_watch_app`, im Repo-Root angelegt. Typ: Watch App. Zielgerät: Venu 4 45mm (`venu445mm`). Template: Blank. API-Level: neueste verfügbare (`minApiLevel="6.0.2"`) — kein Grund für ältere/abwärtskompatible Level, da nur das eigene, aktuelle Gerät getestet wird.

  Wie erwartet hat die Extension die Klassen nach dem Projektnamen benannt (nicht `HelloWorldApp`): `garmin_watch_appApp` / `garmin_watch_appView` / `garmin_watch_appDelegate`. Zusätzlich wurde ein Menü samt `garmin_watch_appMenuDelegate` generiert (Blank-Template-Standard) — entfernt, siehe Files-Abschnitt oben.

- [x] **Schritt 2: `garmin_watch_appApp.mc` — Einstiegspunkt**

  Generierter Code unverändert übernommen (referenziert bereits `garmin_watch_appView`/`garmin_watch_appDelegate` korrekt):

  ```javascript
  import Toybox.Application;
  import Toybox.Lang;
  import Toybox.WatchUi;

  class garmin_watch_appApp extends Application.AppBase {
      function initialize() {
          AppBase.initialize();
      }
      function onStart(state as Dictionary?) as Void {}
      function onStop(state as Dictionary?) as Void {}
      function getInitialView() as [Views] or [Views, InputDelegates] {
          return [ new garmin_watch_appView(), new garmin_watch_appDelegate() ];
      }
  }

  function getApp() as garmin_watch_appApp {
      return Application.getApp() as garmin_watch_appApp;
  }
  ```

- [x] **Schritt 3: `garmin_watch_appView.mc` — Anzeige**

  Generierter Code unverändert übernommen — nutzt das Ressourcen-Layout-System (`Rez.Layouts.MainLayout`) statt direktem `dc.drawText(...)`, idiomatischer als ursprünglich geplant:

  ```javascript
  import Toybox.Graphics;
  import Toybox.WatchUi;

  class garmin_watch_appView extends WatchUi.View {
      function initialize() {
          View.initialize();
      }
      function onLayout(dc as Dc) as Void {
          setLayout(Rez.Layouts.MainLayout(dc));
      }
      function onShow() as Void {}
      function onUpdate(dc as Dc) as Void {
          View.onUpdate(dc);
      }
      function onHide() as Void {}
  }
  ```

  Der angezeigte Text kommt aus `resources/layouts/layout.xml` (Label mit `text="@Strings.prompt"`, zentriert über `x="center" y="center"` + `TEXT_JUSTIFY_CENTER|TEXT_JUSTIFY_VCENTER`) und `resources/strings/strings.xml` (`<string id="prompt">Hello World</string>` — war generiert als "Click the menu button", geändert). Das generierte Monkey-Logo-Bitmap wurde aus Layout und `resources/drawables/` entfernt (nicht Teil der Spec).

- [x] **Schritt 4: `garmin_watch_appDelegate.mc` — Tap schließt die App**

  ```javascript
  import Toybox.Lang;
  import Toybox.System;
  import Toybox.WatchUi;

  class garmin_watch_appDelegate extends WatchUi.BehaviorDelegate {
      function initialize() {
          BehaviorDelegate.initialize();
      }
      function onSelect() as Boolean {
          System.exit();
          return true;
      }
  }
  ```

  `onMenu()` (generiert, öffnete das jetzt entfernte Menü) wurde durch `onSelect()` ersetzt. `onSelect()` feuert bei Tap auf den Touchscreen (Venu 4 hat keine dedizierte "OK"-Taste) — ein Tap irgendwo auf dem Bildschirm schließt die App. Compiler-Warnung "Statement is not reachable" für das `return true;` nach `System.exit()` ist erwartet (Compiler weiß, dass `exit()` nicht zurückkehrt) und harmlos.

- [x] **Schritt 5: Im Simulator verifizieren**

  **VS Code GUI ("Monkey C: Run") funktioniert in diesem Repo nicht** — Fehler "Connect IQ project not found. Be sure your project has a jungle file and the project's Jungle Files setting is correct." (VS-Code-Workspace ist das Flutter-Repo-Root, nicht `garmin_watch_app/` selbst; keine `.vscode/settings.json` mit `monkeyC.jungleFiles` vorhanden). Stattdessen über die SDK-CLI-Tools gebaut und verifiziert — vollständiger, funktionierender Befehlsablauf jetzt in `CLAUDE.md` unter "Garmin Watch Integration" dokumentiert (Kurzfassung: Developer-Key per `openssl` einmalig erzeugen, `monkeyc.bat -f monkey.jungle -d venu445mm -o bin/garmin_watch_app.prg -y <key>` baut, Simulator separat starten, dann `monkeydo.bat bin/garmin_watch_app.prg venu445mm` pusht/startet die App darin).

  Ergebnis: **Build erfolgreich**, Simulator zeigt "Hello World" zentriert auf schwarzem Hintergrund, Tap auf den simulierten Touchscreen beendet die App — manuell von Tobias am Simulator bestätigt.

- [x] **Schritt 6: Commit**

  ```bash
  git add garmin_watch_app/ .gitignore
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

  Kein zusätzlicher Repository-Eintrag nötig: `android/build.gradle.kts` deklariert bereits `allprojects { repositories { google(); mavenCentral() } }`, und das SDK wird laut Garmins README genau auf Maven Central veröffentlicht.

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
- Produces: `GarminService.isWatchConnected() → Future<bool>`, `GarminService.openWatchApp() → Future<String>`, `GarminService.hasEverConnected() → Future<bool>`, `GarminService.markEverConnected() → Future<void>` (alle gebraucht in Task 7).

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

  ```dart
  import 'package:flutter/services.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:emom_app/core/services/garmin_service.dart';

  void main() {
    TestWidgetsFlutterBinding.ensureInitialized();

    const channel = MethodChannel('com.example.emom_app/garmin');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      SharedPreferences.setMockInitialValues({});
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

    test('hasEverConnected ist zunaechst false', () async {
      final service = GarminService();
      expect(await service.hasEverConnected(), false);
    });

    test('markEverConnected setzt das Flag dauerhaft auf true', () async {
      final service = GarminService();
      await service.markEverConnected();
      expect(await service.hasEverConnected(), true);

      // Neue Service-Instanz simuliert App-Neustart — Flag muss ueberleben.
      final serviceAfterRestart = GarminService();
      expect(await serviceAfterRestart.hasEverConnected(), true);
    });
  }
  ```

- [ ] **Schritt 2: Test ausführen, Fehlschlag bestätigen**

  Run: `flutter test test/core/services/garmin_service_test.dart`
  Expected: FAIL — `garmin_service.dart` existiert noch nicht (Import-Fehler).

- [ ] **Schritt 3: `GarminService` implementieren**

  ```dart
  import 'package:flutter/services.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  class GarminService {
    static const _channel = MethodChannel('com.example.emom_app/garmin');
    static const _everConnectedKey = 'garminHasEverConnected';

    Future<bool> isWatchConnected() async {
      final result = await _channel.invokeMethod<bool>('isWatchConnected');
      return result ?? false;
    }

    Future<String> openWatchApp() async {
      final result = await _channel.invokeMethod<String>('openWatchApp');
      return result ?? 'error';
    }

    Future<bool> hasEverConnected() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_everConnectedKey) ?? false;
    }

    Future<void> markEverConnected() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_everConnectedKey, true);
    }
  }
  ```

- [ ] **Schritt 4: Test ausführen, Erfolg bestätigen**

  Run: `flutter test test/core/services/garmin_service_test.dart`
  Expected: PASS (alle vier Tests grün)

- [ ] **Schritt 5: Commit**

  ```bash
  git add lib/core/services/garmin_service.dart test/core/services/garmin_service_test.dart
  git commit -m "feat: GarminService als Dart-Wrapper um den MethodChannel + everConnected-Persistenz"
  ```

---

### Task 7: `AppSettings`-Flag + `GarminNotifier` (`GarminConnectionStatus`) + Einstellungen-Abschnitt

**Files:**
- Modify: `lib/core/models/settings.dart`
- Modify: `test/core/models/settings_test.dart`
- Create: `lib/features/config/garmin_notifier.dart`
- Modify: `lib/features/config/config_screen.dart`
- Test: `test/features/config/garmin_config_row_test.dart`

**Interfaces:**
- Consumes: `GarminService` aus Task 6.
- Produces:
  - `AppSettings.garminHeaderIconVisible` (bool, Default `false`) — gebraucht in Task 8.
  - `garminProvider` (liefert `AsyncValue<GarminConnectionStatus>`) und `GarminNotifier.openWatchApp() → Future<String>` — gebraucht in Task 8. (Riverpod-Codegen kürzt das "Notifier"-Suffix im Provider-Namen — vgl. `HistoryNotifier` → `historyProvider` in `history_notifier.g.dart`.)
  - `GarminConnectionStatus { bool connected; bool everConnected; }` — gebraucht in Task 8.

- [ ] **Schritt 1: Fehlschlagenden Test für das neue Settings-Feld schreiben**

  In `test/core/models/settings_test.dart`, am Dateianfang (neben dem bestehenden `import 'package:emom_app/core/models/settings.dart';`) ergänzen:

  ```dart
  import 'package:shared_preferences/shared_preferences.dart';
  ```

  Und innerhalb von `main()`, als neue `group` neben der bestehenden `group('ExerciseSideX', ...)`:

  ```dart
  group('AppSettings.garminHeaderIconVisible', () {
    test('Default ist false', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      expect(settings.garminHeaderIconVisible, false);
    });

    test('wird gespeichert und beim Laden wiederhergestellt', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      settings.garminHeaderIconVisible = true;
      await settings.save();

      final reloaded = await AppSettings.load();
      expect(reloaded.garminHeaderIconVisible, true);
    });
  });
  ```

- [ ] **Schritt 2: Test ausführen, Fehlschlag bestätigen**

  Run: `flutter test test/core/models/settings_test.dart`
  Expected: FAIL — `garminHeaderIconVisible` existiert noch nicht auf `AppSettings`.

- [ ] **Schritt 3: `AppSettings` erweitern**

  In `lib/core/models/settings.dart`: neues Feld, Konstruktor-Parameter, `load()`, `save()` ergänzen (gleiches Muster wie `trainingReminderEnabled`):

  ```dart
  bool garminHeaderIconVisible; // in der Feldliste ergaenzen

  // im Konstruktor:
  this.garminHeaderIconVisible = false,

  // in load():
  garminHeaderIconVisible: prefs.getBool('garminHeaderIconVisible') ?? false,

  // in save():
  await prefs.setBool('garminHeaderIconVisible', garminHeaderIconVisible);
  ```

- [ ] **Schritt 4: Settings-Test ausführen, Erfolg bestätigen**

  Run: `flutter test test/core/models/settings_test.dart`
  Expected: PASS

- [ ] **Schritt 5: Fehlschlagenden Widget-Test für den Garmin-Abschnitt schreiben**

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:emom_app/features/config/config_screen.dart';
  import 'package:emom_app/features/config/garmin_notifier.dart';
  import 'package:emom_app/core/providers/settings_provider.dart';

  void main() {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('zeigt Garmin-Abschnitt mit Verbindungsstatus und Sichtbarkeits-Toggle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            garminProvider.overrideWith(() => _FakeGarminNotifier()),
          ],
          child: const MaterialApp(home: ConfigScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GARMIN-UHR'), findsOneWidget);
      expect(find.text('Watch-App öffnen'), findsOneWidget);
      expect(find.text('In der Hauptansicht anzeigen'), findsOneWidget);
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

    testWidgets('Toggle schaltet garminHeaderIconVisible um', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            garminProvider.overrideWith(() => _FakeGarminNotifier()),
          ],
          child: const MaterialApp(home: ConfigScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ConfigScreen)),
      );
      expect(container.read(settingsProvider).requireValue.garminHeaderIconVisible, false);

      final garminSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('In der Hauptansicht anzeigen'),
          matching: find.byType(Row),
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(garminSwitch);
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).requireValue.garminHeaderIconVisible, true);
    });
  }

  class _FakeGarminNotifier extends GarminNotifier {
    bool openWatchAppCalled = false;

    @override
    Future<GarminConnectionStatus> build() async =>
        const GarminConnectionStatus(connected: true, everConnected: true);

    @override
    Future<String> openWatchApp() async {
      openWatchAppCalled = true;
      return 'launched';
    }
  }
  ```

  Hinweis zum dritten Test: Der Garmin-Abschnitt wird laut Schritt 9 **vor** `FeedbackTab(...)` eingefügt, liegt also vor dessen fünf Toggle-Zeilen (`feedback_tab.dart:218-273`) — ein einfacher `find.byType(Switch).last` würde deshalb den falschen (Trainings-Erinnerung-)Switch treffen, dessen `onChanged` zusätzlich async `NotificationService.instance.requestPermission()` aufruft. Der Finder oben grenzt deshalb bewusst über den umgebenden `Row` mit dem Label-Text ein, unabhängig von der Position auf dem Screen.

- [ ] **Schritt 6: Test ausführen, Fehlschlag bestätigen**

  Run: `flutter test test/features/config/garmin_config_row_test.dart`
  Expected: FAIL — `garmin_notifier.dart` existiert noch nicht, `ConfigScreen` hat noch keinen Garmin-Abschnitt.

- [ ] **Schritt 7: `GarminNotifier` implementieren**

  ```dart
  import 'package:riverpod_annotation/riverpod_annotation.dart';
  import '../../core/services/garmin_service.dart';

  part 'garmin_notifier.g.dart';

  class GarminConnectionStatus {
    final bool connected;
    final bool everConnected;

    const GarminConnectionStatus({
      required this.connected,
      required this.everConnected,
    });
  }

  @riverpod
  class GarminNotifier extends _$GarminNotifier {
    final GarminService _service = GarminService();

    @override
    Future<GarminConnectionStatus> build() async {
      final connected = await _service.isWatchConnected();
      if (connected) {
        await _service.markEverConnected();
      }
      final everConnected = await _service.hasEverConnected();
      return GarminConnectionStatus(connected: connected, everConnected: everConnected);
    }

    Future<String> openWatchApp() async {
      final status = await _service.openWatchApp();
      ref.invalidateSelf();
      await future; // wartet auf den neu ausgeloesten build(), bevor die Methode zurueckkehrt
      return status;
    }
  }
  ```

- [ ] **Schritt 8: `.g.dart` generieren**

  Run: `dart run build_runner build --delete-conflicting-outputs`
  Expected: `lib/features/config/garmin_notifier.g.dart` wird erzeugt, keine Fehler.

- [ ] **Schritt 9: `ConfigScreen` — Garmin-Abschnitt ergänzen**

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
      'GARMIN-UHR',
      style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white24),
    ),
  ),
  Builder(builder: (context) {
    final connectionAsync = ref.watch(garminProvider);
    final connected = connectionAsync.valueOrNull?.connected ?? false;
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'In der Hauptansicht anzeigen',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              Switch(
                value: _s.garminHeaderIconVisible,
                onChanged: (v) {
                  setState(() => _s.garminHeaderIconVisible = v);
                  _save();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }),
  ```

- [ ] **Schritt 10: Test ausführen, Erfolg bestätigen**

  Run: `flutter test test/features/config/garmin_config_row_test.dart`
  Expected: PASS (alle drei Tests grün)

- [ ] **Schritt 11: Gesamte Testsuite + Analyzer prüfen**

  Run: `flutter analyze && flutter test`
  Expected: 0 Analyzer-Fehler, alle Tests grün.

- [ ] **Schritt 12: Commit**

  ```bash
  git add lib/core/models/settings.dart test/core/models/settings_test.dart lib/features/config/garmin_notifier.dart lib/features/config/garmin_notifier.g.dart lib/features/config/config_screen.dart test/features/config/garmin_config_row_test.dart
  git commit -m "feat: Garmin-Einstellungen (Verbindungsstatus, Watch-App oeffnen, Sichtbarkeits-Toggle)"
  ```

---

### Task 8: `GarminHeaderIcon` — Ampel-Icon im Workout-Header

**Files:**
- Create: `lib/features/workout/widgets/garmin_header_icon.dart`
- Modify: `lib/features/workout/widgets/workout_header.dart`
- Test: `test/features/workout/garmin_header_icon_test.dart`

**Interfaces:**
- Consumes: `garminProvider` + `GarminConnectionStatus` und `AppSettings.garminHeaderIconVisible` (via `settingsProvider`) aus Task 7; `WorkoutHeader`s **bestehendes** `onSettings`-Callback.
- **Wichtig:** `GarminHeaderIcon` darf für den grauen Tap-Fall **nicht selbst** `Navigator.push(ConfigScreen)` aufrufen, sondern muss das von `WorkoutHeader` durchgereichte `onSettings` verwenden. Grund: `_openConfig()` in `lib/features/workout/workout_screen.dart:65-76` führt nach der Rückkehr aus den Einstellungen wichtige Folge-Logik aus (`ref.read(workoutProvider.notifier).updateSettings(...)`) — ein eigener, paralleler Navigationsweg würde das umgehen. `WorkoutHeader` bekommt `onSettings` bereits von `workout_screen.dart` übergeben (für das Zahnrad-Icon) und reicht denselben Callback einfach zusätzlich an `GarminHeaderIcon` weiter — keine neue Signatur-Änderung an `WorkoutHeader` von außen nötig.

- [ ] **Schritt 1: Fehlschlagenden Widget-Test schreiben**

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:emom_app/features/workout/widgets/garmin_header_icon.dart';
  import 'package:emom_app/features/config/garmin_notifier.dart';
  import 'package:emom_app/core/theme/app_theme.dart';

  void main() {
    Future<void> pump(
      WidgetTester tester,
      GarminNotifier fakeNotifier,
      VoidCallback onSettings,
    ) async {
      SharedPreferences.setMockInitialValues({'garminHeaderIconVisible': true});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [garminProvider.overrideWith(() => fakeNotifier)],
          child: MaterialApp(
            home: Scaffold(body: GarminHeaderIcon(onSettings: onSettings)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('unsichtbar wenn garminHeaderIconVisible false ist', (tester) async {
      SharedPreferences.setMockInitialValues({'garminHeaderIconVisible': false});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            garminProvider.overrideWith(
              () => _FakeGarminNotifier(connected: true, everConnected: true),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: GarminHeaderIcon(onSettings: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('garminHeaderIcon')), findsNothing);
    });

    testWidgets('gruen wenn verbunden', (tester) async {
      await pump(
        tester,
        _FakeGarminNotifier(connected: true, everConnected: true),
        () {},
      );
      final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
      expect(icon.color, AppTheme.ok);
    });

    testWidgets('rot wenn nicht verbunden aber schon mal verbunden gewesen', (tester) async {
      await pump(
        tester,
        _FakeGarminNotifier(connected: false, everConnected: true),
        () {},
      );
      final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
      expect(icon.color, AppTheme.danger);
    });

    testWidgets('grau wenn noch nie verbunden', (tester) async {
      await pump(
        tester,
        _FakeGarminNotifier(connected: false, everConnected: false),
        () {},
      );
      final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
      expect(icon.color, AppTheme.textMuted);
    });

    testWidgets('Tap bei Grau ruft onSettings auf, nicht openWatchApp', (tester) async {
      var settingsCalled = false;
      final fake = _FakeGarminNotifier(connected: false, everConnected: false);
      await pump(tester, fake, () => settingsCalled = true);

      await tester.tap(find.byKey(const Key('garminHeaderIcon')));
      await tester.pumpAndSettle();

      expect(settingsCalled, true);
      expect(fake.openWatchAppCalled, false);
    });

    testWidgets('Tap bei Rot ruft openWatchApp auf, nicht onSettings', (tester) async {
      var settingsCalled = false;
      final fake = _FakeGarminNotifier(connected: false, everConnected: true);
      await pump(tester, fake, () => settingsCalled = true);

      await tester.tap(find.byKey(const Key('garminHeaderIcon')));
      await tester.pumpAndSettle();

      expect(settingsCalled, false);
      expect(fake.openWatchAppCalled, true);
    });
  }

  class _FakeGarminNotifier extends GarminNotifier {
    final bool connected;
    final bool everConnected;
    bool openWatchAppCalled = false;

    _FakeGarminNotifier({required this.connected, required this.everConnected});

    @override
    Future<GarminConnectionStatus> build() async =>
        GarminConnectionStatus(connected: connected, everConnected: everConnected);

    @override
    Future<String> openWatchApp() async {
      openWatchAppCalled = true;
      return 'launched';
    }
  }
  ```

- [ ] **Schritt 2: Test ausführen, Fehlschlag bestätigen**

  Run: `flutter test test/features/workout/garmin_header_icon_test.dart`
  Expected: FAIL — `garmin_header_icon.dart` existiert noch nicht.

- [ ] **Schritt 3: `GarminHeaderIcon` implementieren**

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../../core/providers/settings_provider.dart';
  import '../../../core/theme/app_theme.dart';
  import '../../config/garmin_notifier.dart';

  class GarminHeaderIcon extends ConsumerWidget {
    final VoidCallback onSettings;

    const GarminHeaderIcon({super.key, required this.onSettings});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final settingsAsync = ref.watch(settingsProvider);
      final visible = settingsAsync.value?.garminHeaderIconVisible ?? false;
      if (!visible) return const SizedBox.shrink();

      final status = ref.watch(garminProvider).value;
      final connected = status?.connected ?? false;
      final everConnected = status?.everConnected ?? false;

      final Color color = connected
          ? AppTheme.ok
          : (everConnected ? AppTheme.danger : AppTheme.textMuted);

      return GestureDetector(
        onTap: () async {
          if (!everConnected) {
            onSettings();
            return;
          }
          final result = await ref.read(garminProvider.notifier).openWatchApp();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Status: $result')),
            );
          }
        },
        child: Icon(Icons.watch, key: const Key('garminHeaderIcon'), color: color, size: 22),
      );
    }
  }
  ```

- [ ] **Schritt 4: Test ausführen, Erfolg bestätigen**

  Run: `flutter test test/features/workout/garmin_header_icon_test.dart`
  Expected: PASS (alle sechs Tests grün)

- [ ] **Schritt 5: In `WorkoutHeader` einbinden**

  In `lib/features/workout/widgets/workout_header.dart`, Import ergänzen:

  ```dart
  import 'garmin_header_icon.dart';
  ```

  In der inneren `Row` (Zeilen 37–61 im aktuellen Stand), zwischen dem Verlauf- und dem Zahnrad-Icon einfügen:

  ```dart
  GestureDetector(
    onTap: onHistory,
    child: Icon(Icons.history, color: AppTheme.textMuted, size: 22),
  ),
  const SizedBox(width: 10),
  GarminHeaderIcon(onSettings: onSettings),
  const SizedBox(width: 10),
  GestureDetector(
    onTap: onSettings,
    child: Icon(Icons.settings, color: AppTheme.textMuted, size: 22),
  ),
  ```

  (Die ersten beiden `GestureDetector`/`SizedBox`-Zeilen existieren schon — hier nur zur Orientierung, wo genau `GarminHeaderIcon` dazwischen muss.)

- [ ] **Schritt 6: Gesamte Testsuite + Analyzer prüfen**

  Run: `flutter analyze && flutter test`
  Expected: 0 Analyzer-Fehler, alle Tests grün.

- [ ] **Schritt 7: Commit**

  ```bash
  git add lib/features/workout/widgets/garmin_header_icon.dart lib/features/workout/widgets/workout_header.dart test/features/workout/garmin_header_icon_test.dart
  git commit -m "feat: Ampel-Icon fuer Garmin-Verbindung im Workout-Header"
  ```

---

### Task 9: Ende-zu-Ende-Verifikation auf echter Hardware

**Manuell, kein Repo-Code.** Finale Abnahme der Erfolgskriterien aus der Spec.

- [ ] **Schritt 1: Debug-APK auf dem Handy installieren**

  Run: `flutter install` (oder `flutter run --release=false` bei verbundenem Test-Handy)

- [ ] **Schritt 2: Venu 4 verbinden**

  Sicherstellen, dass Handy und Venu 4 per Bluetooth gekoppelt und die Garmin-Connect-Mobile-App im Hintergrund aktiv ist (das Connect-IQ-Mobile-SDK baut auf dieser Kopplung auf).

- [ ] **Schritt 3: Verbindungsstatus in den Einstellungen prüfen**

  In der Kettlebell-EMOM-App → Zahnrad-Icon → Einstellungen → Abschnitt "GARMIN-UHR". Erwartung: zeigt "Uhr verbunden" mit grünem Icon. Toggle "In der Hauptansicht anzeigen" einschalten (Default ist aus).

- [ ] **Schritt 4: Header-Icon prüfen**

  Zurück zum Haupt-Workout-Screen. Erwartung: Ampel-Icon erscheint jetzt zwischen Verlauf- und Zahnrad-Icon, grün (Uhr ist ja verbunden).

  `garminProvider` ist wie alle Provider in diesem Projekt `keepAlive` und prüft die Verbindung nur beim ersten Aufbau sowie nach einem Tap neu (kein Polling, siehe Spec-Abschnitt "Fehlerbehandlung / Risiken") — ein passives Live-Update ist also NICHT zu erwarten. Zum Testen: Bluetooth am Handy ausschalten, dann auf das (noch grün angezeigte) Icon tippen. Erwartung: Tap versucht `openWatchApp()`, das schlägt mangels Verbindung fehl (Snackbar mit Fehlerstatus, z.B. "no_device"), und das Icon wechselt danach auf Rot (nicht Grau, da `everConnected` bereits gesetzt ist) — die Korrektur passiert also durch den Tap selbst, nicht von allein. Bluetooth wieder anschalten, erneut tippen → Icon wechselt zurück auf Grün.

- [ ] **Schritt 5: Watch-App über das Header-Icon öffnen**

  Auf das grüne (oder rote) Header-Icon tippen. Erwartung: Auf der Venu 4 öffnet sich die Hello-World-App automatisch (kein Schwarzbild — falls doch, siehe Spec-Abschnitt "Fehlerbehandlung / Risiken", das ist der zu verifizierende Risikofall). Am Handy erscheint eine Snackbar mit dem zurückgemeldeten Status.

- [ ] **Schritt 6: Watch-App schließen**

  Auf der Uhr auf den Bildschirm tippen. Erwartung: App beendet sich.

- [ ] **Schritt 7: Grauen Zustand verifizieren (frische Installation)**

  Nur möglich, wenn `garminHasEverConnected` noch nicht gesetzt ist (z.B. App-Daten löschen und neu installieren, oder die Prüfung vor Schritt 3 durchführen statt danach). Erwartung: Icon zeigt Grau, Tap navigiert zu den Einstellungen statt einen Verbindungsversuch zu starten.

- [ ] **Schritt 8: Ergebnis festhalten**

  Kurze Notiz in `docs/emom_app_spezifikation.md` (Abschnitt "Garmin-Integration") ergänzen: ob der Spike erfolgreich war, und falls der Schwarzbild-Bug aufgetreten ist, welches Verhalten genau beobachtet wurde (Grundlage für die nächste Iteration).

Kein Commit für Schritte 1–7 (reine Verifikation). Falls Schritt 8 die Spec-Datei ändert:

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
| `lib/core/models/settings.dart` + Test | 7 |
| `lib/features/config/garmin_notifier.dart` + `.g.dart` | 7 |
| `lib/features/config/config_screen.dart` | 7 |
| `test/features/config/garmin_config_row_test.dart` | 7 |
| `lib/features/workout/widgets/garmin_header_icon.dart` + Test | 8 |
| `lib/features/workout/widgets/workout_header.dart` | 8 |
