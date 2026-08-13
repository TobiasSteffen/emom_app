package com.example.emom_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.emom_app/garmin"
    private val eventChannelName = "com.example.emom_app/garmin_events"
    private var currentEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = GarminBridge(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWatchConnected" -> bridge.isWatchConnected { connected -> result.success(connected) }
                "openWatchApp" -> bridge.openWatchApp { status -> result.success(status) }
                "sendStateSnapshot" -> {
                    @Suppress("UNCHECKED_CAST")
                    val payload = call.arguments as Map<String, Any?>
                    bridge.sendStateSnapshot(payload) { status -> result.success(status) }
                }
                "retryEventRegistration" -> {
                    // registerAppEventListener() ist idempotent (siehe GarminBridge) --
                    // dauerhafte Dart-Abonnenten (Task 6/7) sorgen dafuer, dass der
                    // native EventChannel.onListen nur einmal pro Prozess feuert,
                    // deshalb dieser explizite Retry-Pfad bei App-Resume. Ist die
                    // Registrierung schon erfolgreich (appEventListenerRegistered)
                    // oder laeuft gerade (registrationInFlight), ist der Aufruf ein
                    // reines No-Op (siehe GarminBridge.registerAppEventListener) --
                    // er greift nur nach einer zuvor endgueltig aufgegebenen
                    // Registrierung (REGISTER_MAX_ATTEMPTS erschoepft).
                    currentEventSink?.let { sink ->
                        bridge.registerAppEventListener { payload -> sink.success(payload) }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    currentEventSink = events
                    bridge.registerAppEventListener { payload -> events.success(payload) }
                }

                // registerAppEventListener() registriert bei der Connect-IQ-SDK nur
                // einmal pro Prozess (siehe GarminBridge) -- onCancel loest deshalb
                // kein SDK-Unregister aus, sondern nur bridge.unregisterAppEventListener(),
                // damit spaetere Events nicht an diesen bereits geschlossenen EventSink
                // weitergereicht werden.
                override fun onCancel(arguments: Any?) {
                    currentEventSink = null
                    bridge.unregisterAppEventListener()
                }
            }
        )
    }
}
