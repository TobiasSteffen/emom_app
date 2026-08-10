# Garmin App-Status-Rückkanal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Watch-App meldet sich beim Handy zurück (App Messages), sodass das Ampel-Icon im Workout-Header live zeigt, ob die Watch-App tatsächlich gerade läuft — nicht nur, ob die Uhr per Bluetooth erreichbar ist.

**Architecture:** Zweiter, entgegengesetzt gerichteter Kanal neben dem bestehenden `MethodChannel` (Dart→Kotlin→Uhr): Watch-App sendet in `Application.onStart()`/`onStop()` per `Communications.transmit()`; `GarminBridge.kt` registriert einen dauerhaften Connect-IQ-Listener und reicht Events über einen neuen `EventChannel` an Dart weiter; `garmin_service.dart` exponiert das als `Stream<bool>`; `GarminNotifier` abonniert ihn einmalig in `build()` und aktualisiert ein neues `appRunning`-Feld live; das Header-Icon zeigt grün nur noch, wenn `appRunning == true`.

**Tech Stack:** Flutter/Dart (Riverpod mit Codegen), Kotlin (Android, Connect IQ Mobile SDK), Monkey C (Connect IQ Watch-App).

## Global Constraints

- `flutter analyze` muss nach jedem Dart/Kotlin-Task sauber bleiben.
- Nach jeder Änderung an der `@riverpod`-Klasse `GarminNotifier` muss `dart run build_runner build` laufen, um `garmin_notifier.g.dart` zu regenerieren (siehe `CLAUDE.md`).
- Bestehende Tap-Funktionalität des Icons (öffnet Watch-App bei rot/grün, navigiert zu Settings bei grau) bleibt unverändert.
- Für die Kotlin-Bridge und die Watch-App gibt es keine automatisierten Tests (reine Hardware-Wrapper, bestehende Projektkonvention) — Verifikation dort ist Simulator + manuelle Prüfung auf echter Hardware.
- Kommentare nur wo das WARUM nicht aus dem Code hervorgeht (bestehende Projektkonvention).
- Commit-Messages auf Deutsch, `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` in jedem Commit.
- Referenz-Dokument für alle Detailentscheidungen: `docs/superpowers/specs/2026-08-08-garmin-app-status-rueckkanal-design.md`.

---

### Task 1: Watch-App sendet "opened"/"closed" beim Start/Beenden

**Files:**
- Modify: `garmin_watch_app/manifest.xml`
- Modify: `garmin_watch_app/source/garmin_watch_appApp.mc`
- Create: `garmin_watch_app/source/AppStatusListener.mc`

**Interfaces:**
- Produces: Watch-seitige `Communications.transmit()`-Aufrufe, die als String `"opened"`/`"closed"` beim Android-`GarminBridge` (Task 2) ankommen.

Kein automatisierter Test möglich (Monkey C, reine Hardware-Seite). Verifikation über den Connect-IQ-Simulator; die Build/Run-Befehle sind bereits in `CLAUDE.md` unter "Garmin Watch Integration" dokumentiert (SDK-Pfad, Developer-Key, `monkeyc.bat`/`monkeydo.bat`).

- [ ] **Step 1: Communications-Permission im Manifest ergänzen**

`garmin_watch_app/manifest.xml` aktuell (Zeile 23):
```xml
        <iq:permissions/>
```

Ersetzen durch:
```xml
        <iq:permissions>
            <iq:uses-permission id="Communications"/>
        </iq:permissions>
```

Ohne diesen Eintrag scheitert `Communications.transmit()` zur Laufzeit (siehe [`Toybox.Communications`-Doku](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html): "Requires Permission: Communications").

- [ ] **Step 2: `AppStatusListener.mc` anlegen**

```monkeyc
import Toybox.Communications;
import Toybox.System;

// Sendebestaetigung fuer die App-Status-Nachricht ("opened"/"closed").
// Fehler werden nur geloggt, kein Retry -- siehe "Nachrichten-Zustellung
// ist best-effort" in der Design-Spec.
class AppStatusListener extends Communications.ConnectionListener {
    function initialize() {
        ConnectionListener.initialize();
    }

    function onComplete() as Void {
    }

    function onError() as Void {
        System.println("garmin_watch_app: Communications.transmit fehlgeschlagen");
    }
}
```

- [ ] **Step 3: `garmin_watch_appApp.mc` um `onStart()`/`onStop()` erweitern**

Vollständiger neuer Inhalt von `garmin_watch_app/source/garmin_watch_appApp.mc`:

```monkeyc
import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

class garmin_watch_appApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        Communications.transmit("opened", {}, new AppStatusListener());
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        Communications.transmit("closed", {}, new AppStatusListener());
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new garmin_watch_appView(), new garmin_watch_appDelegate() ];
    }

}

function getApp() as garmin_watch_appApp {
    return Application.getApp() as garmin_watch_appApp;
}
```

`onStop()` sendet bewusst unabhängig vom `state[:suspend]`-Flag "closed" — siehe Design-Spec, Architektur Punkt 1.

- [ ] **Step 4: Im Connect-IQ-Simulator bauen und prüfen**

Aus `garmin_watch_app/` (Pfade/Key wie in `CLAUDE.md` beschrieben):

```bash
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
SDK="$HOME/AppData/Roaming/Garmin/ConnectIQ/Sdks/<installed-version>/bin"
KEY="$HOME/AppData/Roaming/Garmin/ConnectIQ/developer_key.der"
"$SDK/monkeyc.bat" -f monkey.jungle -d venu445mm -o bin/garmin_watch_app.prg -y "$KEY" -w
```

Simulator starten (PowerShell: `Start-Process "$SDK\simulator.exe"`), dann:

```bash
"$SDK/monkeydo.bat" bin/garmin_watch_app.prg venu445mm
```

Erwartet: Simulator-Konsole zeigt keine Fehlermeldung von `AppStatusListener.onError()`. App über den OK-Button schließen — auch hier keine Fehlermeldung. (Die Simulator-Konsole loggt `System.println()`-Ausgaben; bleibt sie bei `onError()` still, ist `transmit()` ohne Fehler durchgelaufen.)

- [ ] **Step 5: Commit**

```bash
git add garmin_watch_app/manifest.xml garmin_watch_app/source/garmin_watch_appApp.mc garmin_watch_app/source/AppStatusListener.mc
git commit -m "$(cat <<'EOF'
feat(watch): Watch-App sendet App-Status per Communications.transmit

onStart()/onStop() (Application-Lifecycle, nicht View-Lifecycle --
siehe Design-Spec fuer die Begruendung) senden "opened"/"closed" als
Grundlage fuer den Rueckkanal zum Handy.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Kotlin-Bridge registriert einen App-Event-Listener

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/emom_app/GarminBridge.kt`

**Interfaces:**
- Consumes: nichts Neues (nutzt bestehendes `ensureSdkReady`, `connectIQ`, `watchAppId`).
- Produces: `fun registerAppEventListener(onEvent: (String) -> Unit)` — ruft `onEvent` bei jeder eingehenden `"opened"`/`"closed"`-Nachricht auf. Wird von `MainActivity.kt` (Task 3) konsumiert.

Kein automatisierter Test (reiner Hardware-Wrapper, bestehende Konvention für diese Datei). Verifikation: Kotlin kompiliert (`flutter build apk --debug` oder `flutter analyze`, das den Android-Build nicht abdeckt — daher explizit einen Debug-Build anstoßen).

- [ ] **Step 1: `registerAppEventListener` zu `GarminBridge.kt` hinzufügen**

Am Ende der Klasse `GarminBridge` (nach der bestehenden `openWatchApp`-Methode, vor der schließenden `}` der Klasse) einfügen:

```kotlin
    fun registerAppEventListener(onEvent: (String) -> Unit) {
        ensureSdkReady { ready ->
            if (!ready) return@ensureSdkReady
            val devices = connectIQ.connectedDevices
            val device: IQDevice? = devices?.firstOrNull()
            if (device == null) return@ensureSdkReady
            try {
                connectIQ.getApplicationInfo(watchAppId, device, object : ConnectIQ.IQApplicationInfoListener {
                    override fun onApplicationInfoReceived(app: IQApp) {
                        try {
                            connectIQ.registerForAppEvents(device, app, object : ConnectIQ.IQApplicationEventListener {
                                override fun onMessageReceived(
                                    receivedDevice: IQDevice,
                                    receivedApp: IQApp,
                                    message: MutableList<Any>,
                                    status: ConnectIQ.IQMessageStatus
                                ) {
                                    if (status != ConnectIQ.IQMessageStatus.SUCCESS) {
                                        Log.w(TAG, "App-Event mit Fehlerstatus verworfen: $status")
                                        return
                                    }
                                    val payload = message.firstOrNull() as? String ?: return
                                    onEvent(payload)
                                }
                            })
                        } catch (e: InvalidStateException) {
                            Log.e(TAG, "registerForAppEvents failed", e)
                        } catch (e: ServiceUnavailableException) {
                            Log.e(TAG, "registerForAppEvents failed", e)
                        }
                    }
                    override fun onApplicationNotInstalled(applicationId: String) {
                        Log.w(TAG, "App-Event-Registrierung: Watch-App nicht installiert")
                    }
                })
            } catch (e: InvalidStateException) {
                Log.e(TAG, "getApplicationInfo failed", e)
            } catch (e: ServiceUnavailableException) {
                Log.e(TAG, "getApplicationInfo failed", e)
            }
        }
    }
```

`registerForAppEvents(IQDevice, IQApp, IQApplicationEventListener)` ist die per Dekompilierung des tatsächlich genutzten `ciq-companion-app-sdk`-AARs verifizierte Signatur (siehe Design-Spec, Fehlerbehandlung).

- [ ] **Step 2: Android-Debug-Build anstoßen, um Kotlin-Kompilierung zu prüfen**

Run: `flutter build apk --debug`
Expected: Build erfolgreich, keine Kotlin-Compile-Fehler in `GarminBridge.kt`.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/emom_app/GarminBridge.kt
git commit -m "$(cat <<'EOF'
feat(android): GarminBridge registriert Connect-IQ-App-Event-Listener

registerAppEventListener() kapselt connectIQ.registerForAppEvents(),
Grundlage fuer den EventChannel in MainActivity.kt.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: EventChannel in MainActivity registrieren

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/emom_app/MainActivity.kt`

**Interfaces:**
- Consumes: `GarminBridge.registerAppEventListener(onEvent: (String) -> Unit)` (Task 2).
- Produces: Flutter-`EventChannel` unter dem Namen `com.example.emom_app/garmin_events`, konsumiert von `garmin_service.dart` (Task 4).

Kein automatisierter Test (gleicher Charakter wie Task 2). Verifikation: Debug-Build erfolgreich.

- [ ] **Step 1: `MainActivity.kt` um den EventChannel erweitern**

Vollständiger neuer Inhalt von `android/app/src/main/kotlin/com/example/emom_app/MainActivity.kt`:

```kotlin
package com.example.emom_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.emom_app/garmin"
    private val eventChannelName = "com.example.emom_app/garmin_events"

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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    bridge.registerAppEventListener { payload -> events.success(payload) }
                }

                // Kein explizites Abmelden beim Connect-IQ-SDK -- der Listener
                // lebt fuer die Prozesslaufzeit der App, siehe Design-Spec
                // ("nur im Vordergrund", kein Hintergrund-Betrieb im Scope).
                override fun onCancel(arguments: Any?) {
                }
            }
        )
    }
}
```

- [ ] **Step 2: Android-Debug-Build anstoßen**

Run: `flutter build apk --debug`
Expected: Build erfolgreich.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/emom_app/MainActivity.kt
git commit -m "$(cat <<'EOF'
feat(android): EventChannel fuer Garmin-App-Status neben MethodChannel

com.example.emom_app/garmin_events leitet registerAppEventListener()-
Events an Dart weiter.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Dart-Service exponiert den Event-Stream

**Files:**
- Modify: `lib/core/services/garmin_service.dart`
- Modify: `test/core/services/garmin_service_test.dart`

**Interfaces:**
- Consumes: `EventChannel('com.example.emom_app/garmin_events')` (Task 3).
- Produces: `Stream<bool> watchAppRunningEvents()` — `true` für `"opened"`, `false` für `"closed"`, unbekannte Payloads werden gefiltert. Wird von `garmin_notifier.dart` (Task 5) konsumiert.

- [ ] **Step 1: Failing Test schreiben**

In `test/core/services/garmin_service_test.dart` am Ende der `main()`-Funktion, vor der schließenden `}`, einfügen:

```dart
  group('watchAppRunningEvents', () {
    const eventChannel = EventChannel('com.example.emom_app/garmin_events');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('mappt "opened" auf true und "closed" auf false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            events.success('opened');
            events.success('closed');
          },
        ),
      );

      final service = GarminService();
      final results = await service.watchAppRunningEvents().take(2).toList();
      expect(results, [true, false]);
    });

    test('ignoriert unbekannte Payloads', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            events.success('garbage');
            events.success('opened');
          },
        ),
      );

      final service = GarminService();
      final result = await service.watchAppRunningEvents().first;
      expect(result, true);
    });
  });
```

- [ ] **Step 2: Test ausführen, Fehlschlag bestätigen**

Run: `flutter test test/core/services/garmin_service_test.dart`
Expected: FAIL — `The method 'watchAppRunningEvents' isn't defined for the type 'GarminService'`.

- [ ] **Step 3: `watchAppRunningEvents()` implementieren**

In `lib/core/services/garmin_service.dart`, nach der Konstante `_everConnectedKey` (Zeile 8) einfügen:

```dart
  static const _eventChannel = EventChannel('com.example.emom_app/garmin_events');
```

Am Ende der Klasse `GarminService`, nach `markEverConnected()`, vor der schließenden `}`, einfügen:

```dart

  /// Live-Ereignisse der Watch-App: `true` bei "opened", `false` bei
  /// "closed". Unbekannte Payloads werden verworfen statt einen Fehler
  /// zu werfen (best-effort BLE-Zustellung, siehe Design-Spec).
  Stream<bool> watchAppRunningEvents() {
    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event == 'opened' || event == 'closed')
        .map((event) => event == 'opened');
  }
```

- [ ] **Step 4: Test ausführen, Erfolg bestätigen**

Run: `flutter test test/core/services/garmin_service_test.dart`
Expected: PASS — alle Tests inkl. der beiden neuen grün.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/garmin_service.dart test/core/services/garmin_service_test.dart
git commit -m "$(cat <<'EOF'
feat(dart): GarminService exponiert watchAppRunningEvents()-Stream

Wrappt den neuen EventChannel; "opened"/"closed" werden zu bool
gemappt, unbekannte Payloads gefiltert.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: GarminNotifier — appRunning-Feld, Stream-Abo, invalidateSelf-Fix

**Files:**
- Modify: `lib/features/config/garmin_notifier.dart`
- Create: `test/features/config/garmin_notifier_test.dart`
- Generate: `lib/features/config/garmin_notifier.g.dart` (via build_runner)

**Interfaces:**
- Consumes: `GarminService.watchAppRunningEvents()` (Task 4).
- Produces: `GarminConnectionStatus` bekommt drittes Feld `bool appRunning` (Default `false`). `GarminNotifier.openWatchApp()` ruft `ref.invalidateSelf()` **nicht mehr** auf. Konsumiert von `garmin_header_icon.dart` (Task 6).

- [ ] **Step 1: Failing Test schreiben**

Neue Datei `test/features/config/garmin_notifier_test.dart`:

```dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emom_app/features/config/garmin_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.example.emom_app/garmin');
  const eventChannel = EventChannel('com.example.emom_app/garmin_events');
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  late StreamController<String> watchEvents;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    watchEvents = StreamController<String>.broadcast();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'isWatchConnected':
          return true;
        case 'openWatchApp':
          return 'launched';
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
      if (call.method == 'requestPermissions') {
        final requested = List<int>.from(call.arguments as List);
        return {for (final code in requested) code: 1};
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink events) {
          watchEvents.stream.listen(events.success);
        },
      ),
    );
  });

  tearDown(() async {
    await watchEvents.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  test('appRunning wird durch "opened"/"closed"-Events live aktualisiert',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initial = await container.read(garminProvider.future);
    expect(initial.appRunning, false);

    watchEvents.add('opened');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.appRunning, true);

    watchEvents.add('closed');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.appRunning, false);
  });

  test('openWatchApp() ueberschreibt den laufenden appRunning-Wert nicht',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(garminProvider.future);
    watchEvents.add('opened');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(garminProvider).value?.appRunning, true);

    await container.read(garminProvider.notifier).openWatchApp();

    expect(container.read(garminProvider).value?.appRunning, true);
  });
}
```

- [ ] **Step 2: Test ausführen, Fehlschlag bestätigen**

Run: `flutter test test/features/config/garmin_notifier_test.dart`
Expected: FAIL — `The getter 'appRunning' isn't defined for the type 'GarminConnectionStatus'`.

- [ ] **Step 3: `garmin_notifier.dart` implementieren**

Vollständiger neuer Inhalt von `lib/features/config/garmin_notifier.dart`:

```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/services/garmin_service.dart';

part 'garmin_notifier.g.dart';

class GarminConnectionStatus {
  final bool connected;
  final bool everConnected;
  final bool appRunning;

  const GarminConnectionStatus({
    required this.connected,
    required this.everConnected,
    this.appRunning = false,
  });
}

@riverpod
class GarminNotifier extends _$GarminNotifier {
  final GarminService _service = GarminService();
  StreamSubscription<bool>? _appRunningSub;

  @override
  Future<GarminConnectionStatus> build() async {
    final connected = await _service.isWatchConnected();
    if (connected) {
      await _service.markEverConnected();
    }
    final everConnected = await _service.hasEverConnected();

    _appRunningSub?.cancel();
    _appRunningSub = _service.watchAppRunningEvents().listen((running) {
      final current = state.value;
      if (current == null) return;
      state = AsyncData(GarminConnectionStatus(
        connected: current.connected,
        everConnected: current.everConnected,
        appRunning: running,
      ));
    });
    ref.onDispose(() => _appRunningSub?.cancel());

    return GarminConnectionStatus(connected: connected, everConnected: everConnected);
  }

  /// Fragt den Bluetooth-Status neu ab und liefert das Ergebnis von
  /// openWatchApp() zurueck, OHNE den Notifier per invalidateSelf() neu
  /// aufzubauen -- das wuerde die appRunning-Stream-Subscription aus
  /// build() abreissen und neu aufsetzen, mit einer Event-Luecke genau in
  /// dem Moment, in dem die gerade gestartete Watch-App ihr "opened"
  /// sendet (siehe Design-Spec, Architektur Punkt 5).
  Future<String> openWatchApp() async {
    final status = await _service.openWatchApp();
    final connected = await _service.isWatchConnected();
    if (connected) {
      await _service.markEverConnected();
    }
    final everConnected = await _service.hasEverConnected();
    final appRunning = state.value?.appRunning ?? false;
    state = AsyncData(GarminConnectionStatus(
      connected: connected,
      everConnected: everConnected,
      appRunning: appRunning,
    ));
    return status;
  }
}
```

- [ ] **Step 4: `.g.dart` regenerieren**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/features/config/garmin_notifier.g.dart` wird neu geschrieben (neuer Hash in `_$garminNotifierHash()`), keine Fehler.

- [ ] **Step 5: Test ausführen, Erfolg bestätigen**

Run: `flutter test test/features/config/garmin_notifier_test.dart`
Expected: PASS.

- [ ] **Step 6: `flutter analyze` prüfen**

Run: `flutter analyze`
Expected: No issues found!

- [ ] **Step 7: Commit**

```bash
git add lib/features/config/garmin_notifier.dart lib/features/config/garmin_notifier.g.dart test/features/config/garmin_notifier_test.dart
git commit -m "$(cat <<'EOF'
feat(dart): GarminNotifier fuehrt appRunning live nach, kein invalidateSelf mehr

build() abonniert watchAppRunningEvents() einmalig; openWatchApp()
aktualisiert connected/everConnected direkt statt den ganzen Notifier
per invalidateSelf() neu aufzubauen (das haette die Stream-Subscription
abgerissen, siehe Design-Spec).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Header-Icon zeigt grün nur bei appRunning

**Files:**
- Modify: `lib/features/workout/widgets/garmin_header_icon.dart`
- Modify: `test/features/workout/garmin_header_icon_test.dart`

**Interfaces:**
- Consumes: `GarminConnectionStatus.appRunning` (Task 5).

- [ ] **Step 1: Icon-Farblogik anpassen**

In `lib/features/workout/widgets/garmin_header_icon.dart`, Zeilen 18–24 ersetzen:

Alt:
```dart
    final status = ref.watch(garminProvider).value;
    final connected = status?.connected ?? false;
    final everConnected = status?.everConnected ?? false;

    final Color color = connected
        ? AppTheme.ok
        : (everConnected ? AppTheme.danger : AppTheme.textMuted);
```

Neu:
```dart
    final status = ref.watch(garminProvider).value;
    final everConnected = status?.everConnected ?? false;
    final appRunning = status?.appRunning ?? false;

    final Color color = appRunning
        ? AppTheme.ok
        : (everConnected ? AppTheme.danger : AppTheme.textMuted);
```

(Tap-Verhalten darunter bleibt unverändert — weiterhin `if (!everConnected) { onSettings(); return; }`.)

- [ ] **Step 2: Bestehenden Test-Lauf als Regression bestätigen**

Run: `flutter test test/features/workout/garmin_header_icon_test.dart`
Expected: FAIL — Test `gruen wenn verbunden` schlägt fehl, weil `_FakeGarminNotifier(connected: true, ...)` kein `appRunning` setzt und die neue Logik jetzt korrekterweise nicht mehr grün liefert. Das ist erwartet (siehe Design-Spec: diese Tests müssen umgeschrieben werden, nicht nur ergänzt).

- [ ] **Step 3: Testdatei komplett neu schreiben**

Vollständiger neuer Inhalt von `test/features/workout/garmin_header_icon_test.dart`:

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
            () => _FakeGarminNotifier(everConnected: true, appRunning: true),
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

  testWidgets('gruen wenn appRunning', (tester) async {
    await pump(
      tester,
      _FakeGarminNotifier(everConnected: true, appRunning: true),
      () {},
    );
    final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.ok);
  });

  testWidgets('rot wenn everConnected aber appRunning false', (tester) async {
    await pump(
      tester,
      _FakeGarminNotifier(everConnected: true, appRunning: false),
      () {},
    );
    final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.danger);
  });

  testWidgets('grau wenn noch nie verbunden', (tester) async {
    await pump(
      tester,
      _FakeGarminNotifier(everConnected: false, appRunning: false),
      () {},
    );
    final icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.textMuted);
  });

  testWidgets('appRunning-Wechsel aktualisiert die Icon-Farbe live', (tester) async {
    final fake = _FakeGarminNotifier(everConnected: true, appRunning: false);
    await pump(tester, fake, () {});

    var icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.danger);

    fake.setAppRunning(true);
    await tester.pump();

    icon = tester.widget<Icon>(find.byKey(const Key('garminHeaderIcon')));
    expect(icon.color, AppTheme.ok);
  });

  testWidgets('Tap bei Grau ruft onSettings auf, nicht openWatchApp', (tester) async {
    var settingsCalled = false;
    final fake = _FakeGarminNotifier(everConnected: false, appRunning: false);
    await pump(tester, fake, () => settingsCalled = true);

    await tester.tap(find.byKey(const Key('garminHeaderIcon')));
    await tester.pumpAndSettle();

    expect(settingsCalled, true);
    expect(fake.openWatchAppCalled, false);
  });

  testWidgets('Tap bei Rot ruft openWatchApp auf, nicht onSettings', (tester) async {
    var settingsCalled = false;
    final fake = _FakeGarminNotifier(everConnected: true, appRunning: false);
    await pump(tester, fake, () => settingsCalled = true);

    await tester.tap(find.byKey(const Key('garminHeaderIcon')));
    await tester.pumpAndSettle();

    expect(settingsCalled, false);
    expect(fake.openWatchAppCalled, true);
  });
}

class _FakeGarminNotifier extends GarminNotifier {
  final bool everConnected;
  final bool appRunning;
  bool openWatchAppCalled = false;

  _FakeGarminNotifier({required this.everConnected, required this.appRunning});

  @override
  Future<GarminConnectionStatus> build() async => GarminConnectionStatus(
        connected: everConnected,
        everConnected: everConnected,
        appRunning: appRunning,
      );

  @override
  Future<String> openWatchApp() async {
    openWatchAppCalled = true;
    return 'launched';
  }

  /// Simuliert ein eingehendes "opened"/"closed"-Event fuer Widget-Tests,
  /// ohne echte Plattform-Kanaele zu mocken.
  void setAppRunning(bool value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(GarminConnectionStatus(
      connected: current.connected,
      everConnected: current.everConnected,
      appRunning: value,
    ));
  }
}
```

- [ ] **Step 4: Test ausführen, Erfolg bestätigen**

Run: `flutter test test/features/workout/garmin_header_icon_test.dart`
Expected: PASS — alle 7 Tests grün.

- [ ] **Step 5: Vollständige Test-Suite und Analyzer prüfen**

Run: `flutter test`
Expected: alle Tests grün.

Run: `flutter analyze`
Expected: No issues found!

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/widgets/garmin_header_icon.dart test/features/workout/garmin_header_icon_test.dart
git commit -m "$(cat <<'EOF'
feat: Ampel-Icon zeigt gruen nur wenn Watch-App wirklich laeuft

Farblogik haengt jetzt an appRunning statt am reinen Bluetooth-
Erreichbarkeits-Flag. Bestehende Farb-Tests umgeschrieben (nicht nur
ergaenzt) plus ein Live-Update-Test fuer den neuen Rueckkanal.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Manuelle Verifikation auf echter Hardware

**Files:** keine (reine Verifikation, kein Repo-Code)

Kein automatisierter Test möglich — Bluetooth-Hardware-Interaktion und echtes Watch-App-Verhalten (bestehende Projektkonvention, siehe Design-Spec Testing-Abschnitt).

- [ ] **Step 1: Watch-App auf die Venu 4 sideloaden**

`bin/garmin_watch_app.prg` aus Task 1 über MTP in `GARMIN\Apps\` auf der Uhr kopieren (siehe `CLAUDE.md`, "Sideloading to the real watch" — nicht per CLI möglich).

- [ ] **Step 2: Debug-APK installieren und Icon-Sichtbarkeit einschalten**

`flutter run` auf ein verbundenes Testgerät; in den Einstellungen unter "GARMIN-UHR" den Toggle "In der Hauptansicht anzeigen" aktivieren.

- [ ] **Step 3: Grundfall — Watch-App öffnen/schließen**

Auf das Ampel-Icon tippen (öffnet die Watch-App). Erwartet: Icon wird zeitnah grün. Auf der Uhr den OK-Button drücken (schließt die Watch-App). Erwartet: Icon wird zeitnah rot — **ohne erneuten Tap, ohne Warten auf einen Timer.**

- [ ] **Step 4: Passiver Bildschirm-Timeout**

Watch-App öffnen (Icon grün), Uhr einfach liegen lassen, bis der Bildschirm automatisch dunkel wird. Erwartet: Icon bleibt grün (verifiziert die zentrale Entscheidung `onStop()` statt `onHide()`).

- [ ] **Step 5: Handfläche/Zurück-Swipe (bekanntes Risiko aus der Recherche)**

Watch-App öffnen (Icon grün), kurz die Handfläche auf den Bildschirm legen bzw. einen Zurück-Swipe auslösen. Notieren, ob die App dabei wirklich beendet wird (dann korrekterweise Icon rot) oder nur der Bildschirm abschaltet (dann sollte Icon grün bleiben) — siehe Design-Spec, Fehlerbehandlung.

- [ ] **Step 6: Grauer Zustand**

App-Daten löschen oder auf einem frischen Testgerät installieren, Icon-Sichtbarkeit einschalten, ohne die Watch-App je geöffnet zu haben. Erwartet: Icon grau, Tap navigiert zu den Einstellungen statt die Watch-App zu öffnen.

- [ ] **Step 7: Ergebnis festhalten**

Falls Abweichungen von den Erwartungen auftreten (insbesondere bei Schritt 4 oder 5), das Ergebnis in `CLAUDE.md` unter "Garmin Watch Integration" ergänzen — nach demselben Muster wie die bereits dort dokumentierten, durch echte Geräte-Tests gefundenen Erkenntnisse.
