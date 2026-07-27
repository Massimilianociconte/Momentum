package com.rallymate.rallymate

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.time.ZoneId
import java.util.UUID
import java.util.concurrent.Executors

/** Native Garmin Connect IQ companion bridge.
 *
 * Garmin identifiers are kept on-device. Flutter receives a local native id
 * only for subsequent SDK calls and a hashed public id for display/storage.
 * Incoming parcels are durably queued before Dart is notified.
 */
class GarminConnectIqBridge(
    private val context: Context,
    messenger: BinaryMessenger,
    useTetheredTransport: Boolean = false,
    private val runTetheredSmokeTest: Boolean = false,
) : ConnectIQ.ConnectIQListener,
    ConnectIQ.IQDeviceEventListener,
    ConnectIQ.IQApplicationEventListener {

    private companion object {
        const val CHANNEL = "com.rallymate/provider_wearables"
        const val APP_ID = "5735e52b850f42c887082915700c92ad"
        const val GARMIN_CONNECT_PACKAGE = "com.garmin.android.apps.connectmobile"
        const val PREFS = "rallymate_garmin_bridge"
        const val QUEUE_KEY = "pending_messages"
        const val MAX_QUEUE_ENTRIES = 128
        const val MAX_TETHERED_DISCOVERY_ATTEMPTS = 12
        const val TETHERED_DISCOVERY_DELAY_MS = 1_000L
        const val LOG_TAG = "RallyMateGarmin"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val tetheredExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "rallymate-garmin-tethered")
    }
    private val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val connectType = if (useTetheredTransport) {
        ConnectIQ.IQConnectType.TETHERED
    } else {
        ConnectIQ.IQConnectType.WIRELESS
    }
    private val connectIQ = ConnectIQ.getInstance(context, connectType)
    private val registeredApps = mutableMapOf<Long, IQApp>()
    private var sdkReady = false
    private var sdkInitializing = false
    private var sdkError: String? = null
    private val pendingInitialization = mutableListOf<MethodChannel.Result>()
    private var tetheredDiscoveryAttempts = 0
    private var tetheredProbeInFlight = false
    private var tetheredPingInFlight = false
    private var tetheredSmokePassed = false
    private val tetheredDiscovery = object : Runnable {
        override fun run() {
            if (!sdkReady || connectType != ConnectIQ.IQConnectType.TETHERED) return
            tetheredDiscoveryAttempts += 1
            val devices = knownDevices()
            devices.forEach { device ->
                runCatching { connectIQ.registerForDeviceEvents(device, this@GarminConnectIqBridge) }
            }
            val connected = devices.firstOrNull { device ->
                runCatching { connectIQ.getDeviceStatus(device) }
                    .getOrDefault(IQDevice.IQDeviceStatus.UNKNOWN) ==
                    IQDevice.IQDeviceStatus.CONNECTED
            }
            if (connected != null) {
                Log.i(LOG_TAG, "Tethered discovery found a connected simulator")
                channel.invokeMethod("garminStatusChanged", statusPayload())
                if (!runTetheredSmokeTest) return
                probeTetheredDevice(connected)
            } else if (tetheredDiscoveryAttempts == 1) {
                Log.i(LOG_TAG, "Tethered discovery is waiting for the simulator socket")
            }
            if ((!runTetheredSmokeTest || !tetheredSmokePassed) &&
                tetheredDiscoveryAttempts < MAX_TETHERED_DISCOVERY_ATTEMPTS
            ) {
                mainHandler.postDelayed(this, TETHERED_DISCOVERY_DELAY_MS)
            } else if (runTetheredSmokeTest && !tetheredSmokePassed) {
                Log.w(LOG_TAG, "Tethered smoke test timed out before PING/PONG completed")
            } else if (connected == null) {
                Log.w(LOG_TAG, "Tethered discovery timed out before the simulator connected")
            }
        }
    }

    init {
        channel.setMethodCallHandler(::handle)
        initializeSdk(null)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "providerLocalTimeZone" -> result.success(ZoneId.systemDefault().id)
            "garminInitialize" -> initializeSdk(result)
            "garminStatus" -> result.success(statusPayload())
            "garminDevices" -> result.success(devicePayloads())
            "garminRegisterDevice" -> registerDevice(call, result)
            "garminSend" -> send(call, result)
            "garminOpenStore" -> openStore(result)
            "garminOpenCompanionStore" -> openCompanionStore(result)
            "garminDrainMessages" -> result.success(readQueue())
            "garminAcknowledgeMessages" -> acknowledgeMessages(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initializeSdk(result: MethodChannel.Result?) {
        if (sdkReady) {
            result?.success(statusPayload())
            return
        }
        result?.let(pendingInitialization::add)
        if (sdkInitializing) return
        sdkInitializing = true
        runCatching { connectIQ.initialize(context, false, this) }
            .onFailure { completeInitialization(it.javaClass.simpleName) }
    }

    override fun onSdkReady() {
        sdkReady = true
        sdkError = null
        Log.i(LOG_TAG, "Connect IQ SDK ready (${connectType.name})")
        completeInitialization(null)
        mainHandler.post { channel.invokeMethod("garminStatusChanged", statusPayload()) }
        if (connectType == ConnectIQ.IQConnectType.TETHERED) {
            tetheredDiscoveryAttempts = 0
            mainHandler.removeCallbacks(tetheredDiscovery)
            mainHandler.post(tetheredDiscovery)
        }
    }

    override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
        sdkReady = false
        Log.w(LOG_TAG, "Connect IQ initialization failed: ${status.name}")
        completeInitialization(status.name)
        mainHandler.post { channel.invokeMethod("garminStatusChanged", statusPayload()) }
    }

    override fun onSdkShutDown() {
        sdkReady = false
        sdkError = "SDK_SHUT_DOWN"
    }

    private fun completeInitialization(error: String?) {
        sdkInitializing = false
        sdkError = error
        val payload = statusPayload()
        val callbacks = pendingInitialization.toList()
        pendingInitialization.clear()
        callbacks.forEach { it.success(payload) }
    }

    private fun statusPayload(): Map<String, Any?> = mapOf(
        "provider" to "GARMIN_CONNECT_IQ",
        "transport" to connectType.name,
        "sdkReady" to sdkReady,
        "companionInstalled" to isPackageInstalled(GARMIN_CONNECT_PACKAGE),
        "error" to sdkError,
        "devices" to devicePayloads(),
        "pendingMessages" to readQueue().size,
    )

    private fun devicePayloads(): List<Map<String, Any?>> {
        if (!sdkReady) return emptyList()
        return knownDevices()
            .map { device ->
                val status = runCatching { connectIQ.getDeviceStatus(device) }
                    .getOrDefault(IQDevice.IQDeviceStatus.UNKNOWN)
                mapOf(
                    "nativeId" to device.deviceIdentifier.toString(),
                    "deviceId" to hashIdentifier(device.deviceIdentifier.toString()),
                    "name" to device.friendlyName.orEmpty(),
                    "status" to status.name,
                    "appRegistered" to registeredApps.containsKey(device.deviceIdentifier),
                )
            }
    }

    private fun knownDevices(): List<IQDevice> =
        runCatching { connectIQ.knownDevices }.getOrDefault(emptyList())

    private fun probeTetheredDevice(device: IQDevice) {
        val existing = registeredApps[device.deviceIdentifier]
        if (existing != null) {
            sendTetheredPing(device, existing)
            return
        }
        if (tetheredProbeInFlight) return
        tetheredProbeInFlight = true
        runCatching { connectIQ.registerForDeviceEvents(device, this) }
        runCatching {
            connectIQ.getApplicationInfo(
                APP_ID,
                device,
                object : ConnectIQ.IQApplicationInfoListener {
                    override fun onApplicationInfoReceived(app: IQApp) {
                        tetheredProbeInFlight = false
                        registeredApps[device.deviceIdentifier] = app
                        runCatching {
                            connectIQ.registerForAppEvents(
                                device,
                                app,
                                this@GarminConnectIqBridge,
                            )
                        }
                        Log.i(LOG_TAG, "Tethered RallyMate app registered")
                        sendTetheredPing(device, app)
                    }

                    override fun onApplicationNotInstalled(applicationId: String) {
                        tetheredProbeInFlight = false
                        Log.w(LOG_TAG, "Tethered RallyMate app is not installed in the simulator")
                    }
                },
            )
        }.onFailure {
            tetheredProbeInFlight = false
            Log.w(LOG_TAG, "Tethered app probe failed", it)
        }
    }

    private fun sendTetheredPing(device: IQDevice, app: IQApp) {
        if (tetheredPingInFlight || tetheredSmokePassed) return
        tetheredPingInFlight = true
        executeTransportSend {
            runCatching {
                connectIQ.sendMessage(device, app, mapOf("type" to "PING")) { _, _, status ->
                    tetheredPingInFlight = false
                    Log.i(LOG_TAG, "Tethered PING transport status: ${status.name}")
                }
            }.onFailure {
                tetheredPingInFlight = false
                Log.w(LOG_TAG, "Tethered PING failed", it)
            }
        }
    }

    private fun executeTransportSend(action: () -> Unit) {
        if (connectType == ConnectIQ.IQConnectType.TETHERED) {
            tetheredExecutor.execute(action)
        } else {
            action()
        }
    }

    private fun registerDevice(call: MethodCall, result: MethodChannel.Result) {
        val device = findDevice(call.argument<String>("nativeId"))
        if (device == null) {
            result.error("device_not_found", "Il Garmin selezionato non e disponibile", null)
            return
        }
        runCatching { connectIQ.registerForDeviceEvents(device, this) }
            .onFailure {
                result.error("registration_failed", it.javaClass.simpleName, null)
                return
            }
        runCatching {
            connectIQ.getApplicationInfo(
                APP_ID,
                device,
                object : ConnectIQ.IQApplicationInfoListener {
                    override fun onApplicationInfoReceived(app: IQApp) {
                        registeredApps[device.deviceIdentifier] = app
                        runCatching { connectIQ.registerForAppEvents(device, app, this@GarminConnectIqBridge) }
                        mainHandler.post {
                            result.success(
                                mapOf(
                                    "registered" to true,
                                    "appInstalled" to true,
                                    "version" to app.version(),
                                    "device" to devicePayload(device),
                                )
                            )
                        }
                    }

                    override fun onApplicationNotInstalled(applicationId: String) {
                        mainHandler.post {
                            result.success(
                                mapOf(
                                    "registered" to true,
                                    "appInstalled" to false,
                                    "device" to devicePayload(device),
                                )
                            )
                        }
                    }
                },
            )
        }.onFailure {
            result.error("app_status_failed", it.javaClass.simpleName, null)
        }
    }

    private fun send(call: MethodCall, result: MethodChannel.Result) {
        val device = findDevice(call.argument<String>("nativeId"))
        val app = device?.let { registeredApps[it.deviceIdentifier] }
        val payload = call.argument<Map<String, Any?>>("payload")
        if (device == null || app == null || payload == null) {
            result.error("not_ready", "Registra prima il dispositivo Garmin", null)
            return
        }
        executeTransportSend {
            runCatching {
                connectIQ.sendMessage(device, app, payload) { _, _, status ->
                    mainHandler.post {
                        result.success(status == ConnectIQ.IQMessageStatus.SUCCESS)
                    }
                }
            }.onFailure {
                mainHandler.post {
                    result.error("send_failed", it.javaClass.simpleName, null)
                }
            }
        }
    }

    private fun openStore(result: MethodChannel.Result) {
        val opened = runCatching { connectIQ.openStore(APP_ID) }.getOrDefault(false)
        result.success(opened)
    }

    private fun openCompanionStore(result: MethodChannel.Result) {
        val market = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=$GARMIN_CONNECT_PACKAGE"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val web = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("https://play.google.com/store/apps/details?id=$GARMIN_CONNECT_PACKAGE"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val opened = runCatching { context.startActivity(market); true }
            .getOrElse { runCatching { context.startActivity(web); true }.getOrDefault(false) }
        result.success(opened)
    }

    override fun onDeviceStatusChanged(device: IQDevice, status: IQDevice.IQDeviceStatus) {
        if (connectType == ConnectIQ.IQConnectType.TETHERED &&
            status == IQDevice.IQDeviceStatus.CONNECTED
        ) {
            tetheredDiscoveryAttempts = 0
            mainHandler.removeCallbacks(tetheredDiscovery)
            mainHandler.post {
                Log.i(LOG_TAG, "Tethered simulator reported CONNECTED")
                channel.invokeMethod("garminStatusChanged", statusPayload())
                if (runTetheredSmokeTest) {
                    probeTetheredDevice(device)
                    mainHandler.postDelayed(
                        tetheredDiscovery,
                        TETHERED_DISCOVERY_DELAY_MS,
                    )
                }
            }
        }
        mainHandler.post {
            channel.invokeMethod(
                "garminDeviceChanged",
                devicePayload(device) + ("status" to status.name),
            )
        }
    }

    override fun onMessageReceived(
        device: IQDevice,
        app: IQApp,
        messageData: MutableList<Any>,
        status: ConnectIQ.IQMessageStatus,
    ) {
        if (status != ConnectIQ.IQMessageStatus.SUCCESS || messageData.isEmpty()) return
        val payload: Any? = if (messageData.size == 1) messageData.first() else messageData
        if (runTetheredSmokeTest && messageType(payload) == "PONG") {
            tetheredSmokePassed = true
            mainHandler.removeCallbacks(tetheredDiscovery)
            Log.i(LOG_TAG, "Tethered PING/PONG smoke test passed")
        }
        val queued = enqueue(device, payload) ?: return
        mainHandler.post { channel.invokeMethod("garminMessage", queued) }
    }

    private fun messageType(payload: Any?): String? = when (payload) {
        is Map<*, *> -> payload["type"]?.toString()
        is List<*> -> payload.firstNotNullOfOrNull(::messageType)
        else -> null
    }

    private fun enqueue(device: IQDevice, payload: Any?): Map<String, Any?>? {
        synchronized(preferences) {
            val queue = parseQueue() ?: return null
            val payloadJson = toJson(payload)
            val fingerprint = hashIdentifier(payloadJson.toString())
            for (index in 0 until queue.length()) {
                val existing = queue.optJSONObject(index) ?: continue
                if (existing.optString("fingerprint") == fingerprint) {
                    return jsonObjectToMap(existing)
                }
            }
            if (queue.length() >= MAX_QUEUE_ENTRIES) {
                Log.e(LOG_TAG, "Native Garmin queue full; watch event remains unacknowledged")
                return null
            }
            val entry = JSONObject()
                .put("queueId", UUID.randomUUID().toString())
                .put("nativeId", device.deviceIdentifier.toString())
                .put("deviceId", hashIdentifier(device.deviceIdentifier.toString()))
                .put("deviceName", device.friendlyName.orEmpty())
                .put("receivedAtMs", System.currentTimeMillis())
                .put("fingerprint", fingerprint)
                .put("payload", payloadJson)
            queue.put(entry)
            if (!preferences.edit().putString(QUEUE_KEY, queue.toString()).commit()) {
                Log.e(LOG_TAG, "Unable to persist native Garmin queue")
                return null
            }
            return jsonObjectToMap(entry)
        }
    }

    private fun readQueue(): List<Map<String, Any?>> = synchronized(preferences) {
        val queue = parseQueue() ?: return@synchronized emptyList()
        (0 until queue.length()).mapNotNull { queue.optJSONObject(it)?.let(::jsonObjectToMap) }
    }

    private fun parseQueue(): JSONArray? = runCatching {
        JSONArray(preferences.getString(QUEUE_KEY, "[]"))
    }.onFailure {
        Log.e(LOG_TAG, "Native Garmin queue is unreadable; preserving raw data", it)
    }.getOrNull()

    private fun acknowledgeMessages(call: MethodCall, result: MethodChannel.Result) {
        val ids = call.argument<List<String>>("queueIds").orEmpty().toSet()
        if (ids.isEmpty()) {
            result.success(false)
            return
        }
        synchronized(preferences) {
            val existing = parseQueue()
            if (existing == null) {
                result.success(false)
                return
            }
            val remaining = JSONArray()
            for (index in 0 until existing.length()) {
                val item = existing.optJSONObject(index) ?: continue
                if (item.optString("queueId") !in ids) remaining.put(item)
            }
            val persisted = preferences.edit()
                .putString(QUEUE_KEY, remaining.toString())
                .commit()
            result.success(persisted)
            return
        }
    }

    private fun devicePayload(device: IQDevice): Map<String, Any?> = mapOf(
        "nativeId" to device.deviceIdentifier.toString(),
        "deviceId" to hashIdentifier(device.deviceIdentifier.toString()),
        "name" to device.friendlyName.orEmpty(),
        "status" to runCatching { connectIQ.getDeviceStatus(device).name }.getOrDefault("UNKNOWN"),
    )

    private fun findDevice(nativeId: String?): IQDevice? {
        val parsed = nativeId?.toLongOrNull() ?: return null
        if (!sdkReady) return null
        return runCatching { connectIQ.knownDevices.firstOrNull { it.deviceIdentifier == parsed } }
            .getOrNull()
    }

    private fun isPackageInstalled(packageName: String): Boolean = runCatching {
        context.packageManager.getPackageInfo(packageName, 0)
        true
    }.getOrDefault(false)

    private fun hashIdentifier(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray())
        .take(12)
        .joinToString("") { "%02x".format(it) }

    private fun toJson(value: Any?): Any = when (value) {
        null -> JSONObject.NULL
        is Map<*, *> -> JSONObject().apply {
            value.forEach { (key, nested) -> if (key is String) put(key, toJson(nested)) }
        }
        is Iterable<*> -> JSONArray().apply { value.forEach { put(toJson(it)) } }
        is Array<*> -> JSONArray().apply { value.forEach { put(toJson(it)) } }
        is Number, is Boolean, is String -> value
        else -> value.toString()
    }

    private fun jsonObjectToMap(value: JSONObject): Map<String, Any?> = value.keys().asSequence()
        .associateWith { key -> jsonToDart(value.opt(key)) }

    private fun jsonToDart(value: Any?): Any? = when (value) {
        JSONObject.NULL -> null
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> (0 until value.length()).map { jsonToDart(value.opt(it)) }
        else -> value
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        mainHandler.removeCallbacks(tetheredDiscovery)
        tetheredExecutor.shutdownNow()
        if (!sdkReady) return
        runCatching { connectIQ.unregisterAllForEvents() }
        runCatching { connectIQ.shutdown(context) }
        sdkReady = false
    }
}
