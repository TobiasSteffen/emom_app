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

                // Kein Abmelden beim Connect-IQ-SDK -- registerForAppEvents()
                // bleibt bewusst fuer die Prozesslaufzeit der App bestehen
                // (GarminBridge.registerAppEventListener() ist idempotent,
                // siehe dort). onCancel() stoppt hier nur das Weiterleiten an
                // den jetzt geschlossenen EventSink, damit spaetere SDK-Events
                // nicht gegen einen veralteten Sink aufgerufen werden; ein
                // spaeteres onListen() (z.B. wenn garminProvider nach
                // Dispose neu aufgebaut wird) haengt per
                // registerAppEventListener() einfach einen neuen Sink ein,
                // ohne die SDK-Registrierung zu wiederholen.
                override fun onCancel(arguments: Any?) {
                    bridge.unregisterAppEventListener()
                }
            }
        )
    }
}
