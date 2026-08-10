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

                // registerAppEventListener() registriert bei der Connect-IQ-SDK nur
                // einmal pro Prozess (siehe GarminBridge) -- onCancel loest deshalb
                // kein SDK-Unregister aus, sondern nur bridge.unregisterAppEventListener(),
                // damit spaetere Events nicht an diesen bereits geschlossenen EventSink
                // weitergereicht werden.
                override fun onCancel(arguments: Any?) {
                    bridge.unregisterAppEventListener()
                }
            }
        )
    }
}
