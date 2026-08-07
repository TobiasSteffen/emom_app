package com.example.emom_app

import android.content.Context
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import com.garmin.android.connectiq.exception.InvalidStateException
import com.garmin.android.connectiq.exception.ServiceUnavailableException

class GarminBridge(private val context: Context) {

    // Application-ID aus garmin_watch_app/manifest.xml (kommt aus einem spaeteren Task, noch nicht vorhanden) eintragen:
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
