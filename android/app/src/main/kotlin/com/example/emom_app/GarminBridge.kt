package com.example.emom_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import com.garmin.android.connectiq.exception.InvalidStateException
import com.garmin.android.connectiq.exception.ServiceUnavailableException

private const val TAG = "GarminBridge"
private const val REGISTER_MAX_ATTEMPTS = 5
private const val REGISTER_RETRY_DELAY_MS = 2000L

class GarminBridge(private val context: Context) {

    // Application-ID aus garmin_watch_app/manifest.xml
    private val watchAppId = "ddb356dd-6f3c-4f7a-bb62-3664460edba8"

    private val connectIQ: ConnectIQ = ConnectIQ.getInstance(context, ConnectIQ.IQConnectType.WIRELESS)

    // Die SDK vertraegt kein wiederholtes/ueberlappendes initialize() pro Aufruf --
    // einmal initialisieren, danach den bereit-Zustand fuer alle Aufrufe wiederverwenden.
    private var sdkReady = false
    private var initializing = false
    private val pendingCallbacks = mutableListOf<(Boolean) -> Unit>()

    private fun ensureSdkReady(onResult: (Boolean) -> Unit) {
        if (sdkReady) {
            onResult(true)
            return
        }
        pendingCallbacks.add(onResult)
        if (initializing) return
        initializing = true
        connectIQ.initialize(context, true, object : ConnectIQ.ConnectIQListener {
            override fun onSdkReady() {
                sdkReady = true
                initializing = false
                val callbacks = pendingCallbacks.toList()
                pendingCallbacks.clear()
                callbacks.forEach { it(true) }
            }
            override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
                Log.w(TAG, "Connect IQ SDK initialize failed: $status")
                sdkReady = false
                initializing = false
                val callbacks = pendingCallbacks.toList()
                pendingCallbacks.clear()
                callbacks.forEach { it(false) }
            }
            override fun onSdkShutDown() {
                sdkReady = false
            }
        })
    }

    fun isWatchConnected(callback: (Boolean) -> Unit) {
        ensureSdkReady { ready ->
            if (!ready) {
                callback(false)
                return@ensureSdkReady
            }
            val devices = connectIQ.connectedDevices
            callback(devices != null && devices.isNotEmpty())
        }
    }

    fun openWatchApp(callback: (String) -> Unit) {
        ensureSdkReady { ready ->
            if (!ready) {
                callback("error")
                return@ensureSdkReady
            }
            try {
                val devices = connectIQ.connectedDevices
                val device: IQDevice? = devices?.firstOrNull()
                if (device == null) {
                    callback("no_device")
                    return@ensureSdkReady
                }
                connectIQ.getApplicationInfo(watchAppId, device, object : ConnectIQ.IQApplicationInfoListener {
                    override fun onApplicationInfoReceived(app: IQApp) {
                        try {
                            connectIQ.openApplication(device, app) { _, _, status ->
                                callback(status.name)
                            }
                        } catch (e: InvalidStateException) {
                            Log.e(TAG, "openApplication failed", e)
                            callback("error")
                        } catch (e: ServiceUnavailableException) {
                            Log.e(TAG, "openApplication failed", e)
                            callback("error")
                        }
                    }
                    override fun onApplicationNotInstalled(applicationId: String) {
                        callback("not_installed")
                    }
                })
            } catch (e: InvalidStateException) {
                Log.e(TAG, "getApplicationInfo failed", e)
                callback("error")
            } catch (e: ServiceUnavailableException) {
                Log.e(TAG, "getApplicationInfo failed", e)
                callback("error")
            }
        }
    }

    // Die SDK vertraegt auch registerForAppEvents() nur einmal pro Prozess --
    // registerAppEventListener() kann beliebig oft aufgerufen werden (jedes
    // EventChannel.onListen auf Dart-Seite loest einen Aufruf aus, siehe
    // MainActivity.kt), aber connectIQ.registerForAppEvents() selbst darf nur
    // beim allerersten erfolgreichen Durchlauf passieren. Weitere Aufrufe
    // tauschen nur noch currentOnEvent aus.
    private var appEventListenerRegistered = false
    private var registrationInFlight = false
    private var currentOnEvent: ((String) -> Unit)? = null

    fun registerAppEventListener(onEvent: (String) -> Unit) {
        currentOnEvent = onEvent
        if (appEventListenerRegistered || registrationInFlight) return
        registrationInFlight = true
        ensureSdkReady { ready ->
            if (!ready) {
                registrationInFlight = false
                Log.w(TAG, "registerAppEventListener: SDK nicht bereit, Registrierung abgebrochen")
                return@ensureSdkReady
            }
            attemptRegisterAppEventListener(attempt = 1)
        }
    }

    // Meldet nicht beim Connect-IQ-SDK ab (registerForAppEvents() bleibt fuer
    // die Prozesslaufzeit bestehen, siehe oben) -- stoppt nur das Weiterleiten
    // an einen inzwischen geschlossenen/veralteten EventSink.
    fun unregisterAppEventListener() {
        currentOnEvent = null
    }

    private fun attemptRegisterAppEventListener(attempt: Int) {
        val devices = connectIQ.connectedDevices
        val device: IQDevice? = devices?.firstOrNull()
        if (device == null) {
            if (attempt >= REGISTER_MAX_ATTEMPTS) {
                registrationInFlight = false
                Log.w(TAG, "registerAppEventListener: kein Geraet nach $attempt Versuchen, gebe auf")
                return
            }
            Handler(Looper.getMainLooper()).postDelayed({
                attemptRegisterAppEventListener(attempt + 1)
            }, REGISTER_RETRY_DELAY_MS)
            return
        }
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
                                currentOnEvent?.invoke(payload)
                            }
                        })
                        appEventListenerRegistered = true
                        registrationInFlight = false
                        Log.i(TAG, "registerAppEventListener: erfolgreich registriert")
                    } catch (e: InvalidStateException) {
                        registrationInFlight = false
                        Log.e(TAG, "registerForAppEvents failed", e)
                    } catch (e: ServiceUnavailableException) {
                        registrationInFlight = false
                        Log.e(TAG, "registerForAppEvents failed", e)
                    }
                }
                override fun onApplicationNotInstalled(applicationId: String) {
                    registrationInFlight = false
                    Log.w(TAG, "App-Event-Registrierung: Watch-App nicht installiert")
                }
            })
        } catch (e: InvalidStateException) {
            registrationInFlight = false
            Log.e(TAG, "getApplicationInfo failed", e)
        } catch (e: ServiceUnavailableException) {
            registrationInFlight = false
            Log.e(TAG, "getApplicationInfo failed", e)
        }
    }
}
