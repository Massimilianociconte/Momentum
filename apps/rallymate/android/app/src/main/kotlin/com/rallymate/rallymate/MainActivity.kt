package com.rallymate.rallymate

import android.content.pm.ApplicationInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.Asset
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Phone-side bridge Wear OS ⇄ Flutter (canale "com.rallymate/watch").
 *
 * Percorsi Data Layer (contratto condiviso con wear/wearos e wear/watchos):
 *  - /rallymate/start_match    phone → watch
 *  - /rallymate/events         watch → phone
 *  - /rallymate/request_state  watch → phone (risposta su state_response)
 *  - /rallymate/state_response phone → watch
 */
class MainActivity : FlutterFragmentActivity(), MessageClient.OnMessageReceivedListener {

    private companion object {
        const val CHANNEL = "com.rallymate/watch"
        const val PATH_START_MATCH = "/rallymate/start_match"
        /** Upper bound for the journal carried by a durable Data Item. */
        const val MAX_DURABLE_JOURNAL_BYTES = 24 * 1024
        const val PATH_RESUMABLE = "/rallymate/resumable"
        const val PATH_LIFECYCLE = "/rallymate/lifecycle"
        const val PATH_EVENTS = "/rallymate/events"
        const val PATH_EVENTS_ACK = "/rallymate/events_ack"
        const val PATH_REQUEST_STATE = "/rallymate/request_state"
        const val PATH_STATE_RESPONSE = "/rallymate/state_response"
        const val PATH_PING = "/rallymate/ping"
        const val PATH_TEST_POINT = "/rallymate/test_point"
        const val PATH_PONG = "/rallymate/pong"
        const val PATH_TEAM_IMAGE = "/rallymate/team_image"
        const val PATH_PROFILE_IMAGE = "/rallymate/profile_image"
        const val PATH_WORKOUT_DETECTION_PREFERENCES =
            "/rallymate/workout_detection_preferences"
        const val CAPABILITY_SCORING = "rallymate_scoring"
        const val EXTRA_GARMIN_TETHERED = "rallymate_garmin_tethered"
        const val EXTRA_GARMIN_SMOKE_TEST = "rallymate_garmin_smoke_test"
    }

    private var channel: MethodChannel? = null
    private var notificationBridge: NotificationBridge? = null
    private var healthConnectBridge: HealthConnectBridge? = null
    private var garminBridge: GarminConnectIqBridge? = null
    private var bleHeartRateBridge: BleHeartRateBridge? = null
    private val pendingTests = ConcurrentHashMap<String, MethodChannel.Result>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationBridge = NotificationBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        healthConnectBridge = HealthConnectBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        garminBridge = GarminConnectIqBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
            useTetheredTransport = isDebuggable() &&
                intent.getBooleanExtra(EXTRA_GARMIN_TETHERED, false),
            runTetheredSmokeTest = isDebuggable() &&
                intent.getBooleanExtra(EXTRA_GARMIN_SMOKE_TEST, false),
        )
        bleHeartRateBridge = BleHeartRateBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        )
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> queryStatus(result)
                "refreshStatus" -> queryStatus(result)
                "testConnection" -> sendWatchTest(PATH_PING, result)
                "testPoint" -> sendWatchTest(PATH_TEST_POINT, result)
                "drainEvents" -> {
                    val pending = WatchEventQueue.pending(this)
                    if (pending == null) {
                        result.error(
                            "queue_corrupt",
                            "Coda Wear non leggibile; i dati restano sul telefono",
                            null,
                        )
                    } else {
                        result.success(pending)
                    }
                }
                "replaceQueuedEvents" -> {
                    val pendingJson = call.argument<String>("pendingJson")
                    if (pendingJson == null) {
                        result.error("bad_args", "pendingJson richiesto", null)
                    } else {
                        result.success(WatchEventQueue.replace(this, pendingJson))
                    }
                }
                "syncProfileImage" -> {
                    putProfileImage(
                        imagePath = call.argument<String>("path"),
                        version = call.argument<Int>("version") ?: 0,
                        result = result,
                    )
                }
                "updateWorkoutDetectionPreferences" -> {
                    putWorkoutDetectionPreferences(
                        mode = call.argument<String>("mode") ?: "OFF",
                        racketSportsOnly =
                            call.argument<Boolean>("racketSportsOnly") ?: true,
                        onlyWhenWorn =
                            call.argument<Boolean>("onlyWhenWorn") ?: false,
                        result = result,
                    )
                }
                "startMatch" -> {
                    val matchId = call.argument<String>("matchId")
                    val format = call.argument<String>("format")
                    // Phone event journal for mid-match handoff (JSON array string).
                    val events = call.argument<String>("events") ?: "[]"
                    // Duo Mode: team assegnato al watch (opzionale).
                    val duoTeam = call.argument<String>("duoTeam")
                    val teamName = call.argument<String>("teamName")
                    val teamImagePath = call.argument<String>("teamImagePath")
                    val teamImageVersion = call.argument<Int>("teamImageVersion") ?: 0
                    val teamScoringStyle =
                        call.argument<String>("teamScoringStyle") ?: "AUTO"
                    val sourceUserId = call.argument<String>("sourceUserId")
                    val premiumEnabled = call.argument<Boolean>("premiumEnabled") ?: false
                    val assistantEnabled = call.argument<Boolean>("assistantEnabled") ?: false
                    val assistantEndpoint = call.argument<String>("assistantEndpoint")
                    val assistantAccessToken = call.argument<String>("assistantAccessToken")
                    val assistantPublishableKey = call.argument<String>("assistantPublishableKey")
                    val assistantExpiresAtMs = call.argument<Number>("assistantExpiresAtMs")
                        ?.toLong()
                    val teamNames = call.argument<List<String>>("teamNames").orEmpty()
                        .filter { it.isNotBlank() }
                        .take(12)
                    val defaultTeamName = call.argument<String>("defaultTeamName")
                    if (matchId == null || format == null) {
                        result.error("bad_args", "matchId/format richiesti", null)
                    } else {
                        putTeamVisual(
                            matchId = matchId,
                            imagePath = teamImagePath,
                            version = teamImageVersion,
                            style = teamScoringStyle,
                            teamName = teamName.orEmpty(),
                        ) { imageAvailable ->
                            sendToWatch(
                                PATH_START_MATCH,
                                JSONObject()
                                    .put("matchId", matchId)
                                    .put("format", format)
                                    .put("events", events)
                                    .put("teamName", teamName.orEmpty())
                                    .put("teamImageVersion", teamImageVersion)
                                    .put("teamScoringStyle", teamScoringStyle)
                                    .put("teamImageExpected", imageAvailable)
                                    .put("premiumEnabled", premiumEnabled)
                                    .put("assistantEnabled", assistantEnabled)
                                    .put("teamNames", org.json.JSONArray(teamNames))
                                    .apply {
                                        sourceUserId?.takeIf { it.isNotBlank() }
                                            ?.let { put("sourceUserId", it) }
                                        defaultTeamName?.let { put("defaultTeamName", it) }
                                        if (assistantEnabled) {
                                            assistantEndpoint?.let { put("assistantEndpoint", it) }
                                            assistantAccessToken?.let { put("assistantAccessToken", it) }
                                            assistantPublishableKey?.let {
                                                put("assistantPublishableKey", it)
                                            }
                                            assistantExpiresAtMs?.let {
                                                put("assistantExpiresAtMs", it)
                                            }
                                        }
                                    }
                                    .apply { duoTeam?.let { put("duoTeam", it) } }
                                    .toString()
                                    .toByteArray(),
                                result,
                            )
                        }
                    }
                }
                "matchLifecycle" -> {
                    // Durable pause/resume/complete: the journal travels with
                    // the payload so the watch can resume with no connection.
                    val matchId = call.argument<String>("matchId")
                    val action = call.argument<String>("action")
                    if (matchId.isNullOrBlank() || action.isNullOrBlank()) {
                        result.error("bad_args", "matchId/action richiesti", null)
                    } else {
                        val payload = JSONObject()
                            .put("matchId", matchId)
                            .put("action", action)
                            .put("schemaVersion", 1)
                            .put("stateVersion", call.argument<Int>("stateVersion") ?: 0)
                            .put(
                                "idempotencyKey",
                                call.argument<String>("idempotencyKey")
                                    ?: UUID.randomUUID().toString(),
                            )
                            .put(
                                "ts",
                                call.argument<Number>("ts")?.toLong()
                                    ?: System.currentTimeMillis(),
                            )
                            .apply {
                                call.argument<String>("status")?.let { put("status", it) }
                                call.argument<String>("format")?.let { put("format", it) }
                                // A very long journal is dropped, never
                                // truncated: a partial journal would replay to
                                // the wrong score. The watch pulls it with
                                // REQUEST_STATE instead.
                                call.argument<String>("events")?.let {
                                    if (it.toByteArray().size <= MAX_DURABLE_JOURNAL_BYTES) {
                                        put("events", it)
                                    } else {
                                        put("journalTruncated", true)
                                    }
                                }
                                call.argument<String>("summary")?.let { put("summary", it) }
                            }
                        sendDurableToWatch(
                            PATH_LIFECYCLE,
                            payload.toString().toByteArray(),
                            result,
                        )
                    }
                }
                "publishResumableMatches" -> {
                    // Latest-state channel: a Data Item always holds the most
                    // recent snapshot and is delivered when the watch reconnects.
                    val payload = JSONObject()
                        .put("schemaVersion", 1)
                        .put("matches", call.argument<String>("matches") ?: "[]")
                        .put("stateVersion", call.argument<Int>("stateVersion") ?: 0)
                        .put(
                            "lastUpdatedAtMs",
                            call.argument<Number>("lastUpdatedAtMs")?.toLong()
                                ?: System.currentTimeMillis(),
                        )
                        .apply {
                            call.argument<String>("activeMatchId")
                                ?.takeIf { it.isNotBlank() }
                                ?.let { put("activeMatchId", it) }
                        }
                    putResumableSnapshot(payload.toString().toByteArray(), result)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        notificationBridge?.dispose()
        notificationBridge = null
        bleHeartRateBridge?.dispose()
        bleHeartRateBridge = null
        garminBridge?.dispose()
        garminBridge = null
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        notificationBridge?.onNewIntent(intent)
    }

    private fun isDebuggable(): Boolean =
        applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (bleHeartRateBridge?.onRequestPermissionsResult(requestCode, grantResults) == true) {
            return
        }
        if (notificationBridge?.onRequestPermissionsResult(requestCode, grantResults) == true) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onResume() {
        super.onResume()
        Wearable.getMessageClient(this).addListener(this)
        notifyConnection()
    }

    override fun onPause() {
        Wearable.getMessageClient(this).removeListener(this)
        super.onPause()
    }

    override fun onMessageReceived(event: MessageEvent) {
        when (event.path) {
            PATH_PONG -> handlePong(event)
            PATH_EVENTS -> handleWatchEvents(event)
            PATH_REQUEST_STATE -> {
                val matchId = try {
                    JSONObject(String(event.data)).getString("matchId")
                } catch (_: Exception) {
                    return
                }
                val sourceNode = event.sourceNodeId
                runOnUiThread {
                    channel?.invokeMethod(
                        "requestState",
                        mapOf("matchId" to matchId),
                        object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                val payload = JSONObject()
                                    .put("matchId", matchId)
                                    .put("events", result as? String ?: "[]")
                                Wearable.getMessageClient(this@MainActivity)
                                    .sendMessage(
                                        sourceNode,
                                        PATH_STATE_RESPONSE,
                                        payload.toString().toByteArray(),
                                    )
                            }

                            override fun error(
                                code: String, msg: String?, details: Any?
                            ) = Unit

                            override fun notImplemented() = Unit
                        },
                    )
                }
            }
        }
    }

    private fun handlePong(event: MessageEvent) {
        val nonce = runCatching {
            JSONObject(String(event.data)).getString("nonce")
        }.getOrNull() ?: return
        mainHandler.post {
            pendingTests.remove(nonce)?.success(true)
            notifyConnection()
        }
    }

    private fun handleWatchEvents(event: MessageEvent) {
        val json = try {
            JSONObject(String(event.data))
        } catch (_: Exception) {
            return
        }
        val args = try {
            mutableMapOf<String, Any>(
                "matchId" to json.getString("matchId"),
                "events" to json.getString("events"),
            )
        } catch (_: Exception) {
            return
        }
        json.optString("format").takeIf { it.isNotBlank() }?.let {
            args["format"] = it
        }

        val ch = channel
        if (ch == null) {
            queueRawWatchPayload(json, event.sourceNodeId)
            return
        }

        runOnUiThread {
            ch.invokeMethod(
                "events",
                args,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (result == true) {
                            sendEventsAck(
                                event.sourceNodeId,
                                args.getValue("matchId") as String,
                                WatchEventQueue.eventIds(args.getValue("events") as String),
                            )
                        } else {
                            queueRawWatchPayload(json, event.sourceNodeId)
                        }
                    }

                    override fun error(code: String, msg: String?, details: Any?) {
                        queueRawWatchPayload(json, event.sourceNodeId)
                    }

                    override fun notImplemented() {
                        queueRawWatchPayload(json, event.sourceNodeId)
                    }
                },
            )
        }
    }

    private fun queueRawWatchPayload(json: JSONObject, sourceNodeId: String) {
        try {
            val matchId = json.getString("matchId")
            val eventIds = WatchEventQueue.enqueueEvents(
                context = this,
                matchId = matchId,
                events = json.getString("events"),
                format = json.optString("format").takeIf { it.isNotBlank() },
            )
            if (!eventIds.isNullOrEmpty()) {
                sendEventsAck(sourceNodeId, matchId, eventIds)
            }
        } catch (_: Exception) {
            // Malformed watch payloads should never crash the phone app.
        }
    }

    private fun sendEventsAck(nodeId: String, matchId: String, eventIds: Set<String>) {
        if (eventIds.isEmpty()) return
        val payload = JSONObject()
            .put("matchId", matchId)
            .put("eventIds", JSONArray(eventIds.toList()))
            .toString()
            .toByteArray()
        Wearable.getMessageClient(this)
            .sendMessage(nodeId, PATH_EVENTS_ACK, payload)
    }

    private fun queryStatus(result: MethodChannel.Result) {
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                Wearable.getCapabilityClient(this)
                    .getCapability(CAPABILITY_SCORING, CapabilityClient.FILTER_ALL)
                    .addOnSuccessListener { capability ->
                        Wearable.getCapabilityClient(this)
                            .getCapability(
                                CAPABILITY_SCORING,
                                CapabilityClient.FILTER_REACHABLE,
                            )
                            .addOnSuccessListener { reachable ->
                                val readyNode = reachable.nodes.firstOrNull { it.isNearby }
                                    ?: reachable.nodes.firstOrNull()
                                val knownNode = readyNode
                                    ?: capability.nodes.firstOrNull { it.isNearby }
                                    ?: capability.nodes.firstOrNull()
                                val installed = capability.nodes.isNotEmpty()
                                val isReachable = reachable.nodes.isNotEmpty()
                                result.success(
                                    statusPayload(
                                        paired = nodes.isNotEmpty() || installed,
                                        installed = installed,
                                        reachable = isReachable,
                                        deviceName = knownNode?.displayName.orEmpty(),
                                    )
                                )
                            }
                            .addOnFailureListener {
                                result.success(
                                    statusPayload(
                                        paired = nodes.isNotEmpty(),
                                        installed = false,
                                        reachable = false,
                                    )
                                )
                            }
                    }
                    .addOnFailureListener {
                        result.success(
                            statusPayload(
                                paired = nodes.isNotEmpty(),
                                installed = false,
                                reachable = false,
                            )
                        )
                    }
            }
            .addOnFailureListener {
                result.success(statusPayload(false, false, false))
            }
    }

    private fun statusPayload(
        paired: Boolean,
        installed: Boolean,
        reachable: Boolean,
        deviceName: String = "",
    ): Map<String, Any> = mapOf(
        "supported" to true,
        "paired" to paired,
        "companionInstalled" to installed,
        "reachable" to reachable,
        // Connected means the companion can receive durable Data Layer payloads,
        // not only an interactive nearby node for MessageClient.
        "connected" to (paired && installed),
        "permissionsComplete" to true,
        "platform" to "Wear OS",
        "deviceName" to deviceName,
        "status" to when {
            reachable -> "READY"
            !paired -> "NOT_PAIRED"
            !installed -> "COMPANION_MISSING"
            else -> "NOT_REACHABLE"
        },
        "capabilities" to listOf(
            "scoring", "duo", "offline", "haptics", "voice", "workout", "alwaysOn"
        ),
    )

    private fun notifyConnection() {
        // Paired/installed must use FILTER_ALL; reachable alone falsely reports
        // companion missing when the watch is only wrist-down.
        Wearable.getCapabilityClient(this)
            .getCapability(CAPABILITY_SCORING, CapabilityClient.FILTER_ALL)
            .addOnSuccessListener { allNodes ->
                Wearable.getCapabilityClient(this)
                    .getCapability(
                        CAPABILITY_SCORING,
                        CapabilityClient.FILTER_REACHABLE,
                    )
                    .addOnSuccessListener { reachableNodes ->
                        val paired = allNodes.nodes.isNotEmpty()
                        val installed = allNodes.nodes.isNotEmpty()
                        val reachable = reachableNodes.nodes.isNotEmpty()
                        val node = reachableNodes.nodes.firstOrNull { it.isNearby }
                            ?: reachableNodes.nodes.firstOrNull()
                            ?: allNodes.nodes.firstOrNull()
                        channel?.invokeMethod(
                            "connectionChanged",
                            statusPayload(
                                paired = paired,
                                installed = installed,
                                reachable = reachable,
                                deviceName = node?.displayName.orEmpty(),
                            ),
                        )
                    }
                    .addOnFailureListener {
                        val node = allNodes.nodes.firstOrNull()
                        channel?.invokeMethod(
                            "connectionChanged",
                            statusPayload(
                                paired = allNodes.nodes.isNotEmpty(),
                                installed = allNodes.nodes.isNotEmpty(),
                                reachable = false,
                                deviceName = node?.displayName.orEmpty(),
                            ),
                        )
                    }
            }
    }

    private fun sendWatchTest(path: String, result: MethodChannel.Result) {
        val nonce = UUID.randomUUID().toString()
        pendingTests[nonce] = result
        mainHandler.postDelayed({
            pendingTests.remove(nonce)?.success(false)
        }, 6_000)
        val payload = JSONObject().put("nonce", nonce).toString().toByteArray()
        Wearable.getCapabilityClient(this)
            .getCapability(CAPABILITY_SCORING, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { capability ->
                val node = capability.nodes.firstOrNull { it.isNearby }
                    ?: capability.nodes.firstOrNull()
                if (node == null) {
                    pendingTests.remove(nonce)?.success(false)
                    return@addOnSuccessListener
                }
                Wearable.getMessageClient(this)
                    .sendMessage(node.id, path, payload)
                    .addOnFailureListener {
                        pendingTests.remove(nonce)?.success(false)
                    }
            }
            .addOnFailureListener {
                pendingTests.remove(nonce)?.success(false)
            }
    }

    private fun sendToWatch(
        path: String,
        data: ByteArray,
        result: MethodChannel.Result,
    ) {
        // Durable Data Layer copy first (mirrors iOS transferUserInfo) so a
        // suspended companion still receives START_MATCH when it wakes.
        // Strip short-lived assistant secrets from the durable copy.
        if (path == PATH_START_MATCH) {
            val durable = stripAssistantSecrets(data)
            val request = PutDataMapRequest.create(PATH_START_MATCH).apply {
                dataMap.putByteArray("payload", durable)
                dataMap.putLong("updatedAt", System.currentTimeMillis())
            }
            Wearable.getDataClient(this)
                .putDataItem(request.asPutDataRequest().setUrgent())
                .addOnSuccessListener {
                    deliverWatchMessage(path, data, durableOk = true, result)
                }
                .addOnFailureListener {
                    // No durable handoff — only succeed if live message lands.
                    deliverWatchMessage(path, data, durableOk = false, result)
                }
            return
        }
        deliverWatchMessage(path, data, durableOk = false, result)
    }

    /// Reliable delivery: a Data Item is queued by the Data Layer and reaches
    /// the watch even when the companion is not running, then a live message is
    /// attempted for immediacy.
    private fun sendDurableToWatch(
        path: String,
        data: ByteArray,
        result: MethodChannel.Result,
    ) {
        val request = PutDataMapRequest.create(path).apply {
            dataMap.putByteArray("payload", data)
            dataMap.putLong("updatedAt", System.currentTimeMillis())
        }
        Wearable.getDataClient(this)
            .putDataItem(request.asPutDataRequest().setUrgent())
            .addOnSuccessListener {
                deliverWatchMessage(path, data, durableOk = true, result)
            }
            .addOnFailureListener {
                deliverWatchMessage(path, data, durableOk = false, result)
            }
    }

    /// Snapshot channel: one Data Item that always carries the latest state.
    private fun putResumableSnapshot(
        data: ByteArray,
        result: MethodChannel.Result,
    ) {
        val request = PutDataMapRequest.create(PATH_RESUMABLE).apply {
            dataMap.putByteArray("payload", data)
            dataMap.putLong("updatedAt", System.currentTimeMillis())
        }
        Wearable.getDataClient(this)
            .putDataItem(request.asPutDataRequest().setUrgent())
            .addOnSuccessListener { mainHandler.post { result.success(true) } }
            .addOnFailureListener { mainHandler.post { result.success(false) } }
    }

    private fun deliverWatchMessage(
        path: String,
        data: ByteArray,
        durableOk: Boolean,
        result: MethodChannel.Result,
    ) {
        Wearable.getCapabilityClient(this)
            .getCapability(CAPABILITY_SCORING, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { capability ->
                val node = capability.nodes.firstOrNull { it.isNearby }
                    ?: capability.nodes.firstOrNull()
                if (node == null) {
                    mainHandler.post { result.success(durableOk) }
                    return@addOnSuccessListener
                }
                Wearable.getMessageClient(this)
                    .sendMessage(node.id, path, data)
                    .addOnSuccessListener { mainHandler.post { result.success(true) } }
                    .addOnFailureListener {
                        mainHandler.post { result.success(durableOk) }
                    }
            }
            .addOnFailureListener {
                mainHandler.post { result.success(durableOk) }
            }
    }

    /** Durable queue must not hold access tokens longer than a live message. */
    private fun stripAssistantSecrets(data: ByteArray): ByteArray = try {
        val json = JSONObject(String(data, Charsets.UTF_8))
        json.remove("assistantAccessToken")
        json.remove("assistantPublishableKey")
        json.remove("assistantEndpoint")
        json.remove("assistantExpiresAtMs")
        json.toString().toByteArray(Charsets.UTF_8)
    } catch (_: Exception) {
        data
    }

    private fun putTeamVisual(
        matchId: String,
        imagePath: String?,
        version: Int,
        style: String,
        teamName: String,
        completion: (Boolean) -> Unit,
    ) {
        Thread {
            val image = imagePath
                ?.takeIf { style != "COLOR" }
                ?.let(::File)
                ?.takeIf { file ->
                    file.isFile && file.length() in 1..(2L * 1024L * 1024L) &&
                        file.extension.lowercase() in setOf("jpg", "jpeg", "png", "webp")
                }
            val bytes = runCatching { image?.readBytes() }.getOrNull()
            val request = PutDataMapRequest.create(
                "$PATH_TEAM_IMAGE/${safePathComponent(matchId)}"
            ).apply {
                dataMap.putString("matchId", matchId)
                dataMap.putInt("version", version.coerceAtLeast(0))
                dataMap.putString("style", style)
                dataMap.putString("teamName", teamName.take(80))
                dataMap.putLong("updatedAt", System.currentTimeMillis())
                dataMap.putBoolean("hasImage", bytes != null)
                if (bytes != null) dataMap.putAsset("image", Asset.createFromBytes(bytes))
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(this).putDataItem(request)
                .addOnSuccessListener { completion(bytes != null) }
                .addOnFailureListener { completion(false) }
        }.start()
    }

    private fun putProfileImage(
        imagePath: String?,
        version: Int,
        result: MethodChannel.Result,
    ) {
        Thread {
            val image = imagePath
                ?.let(::File)
                ?.takeIf { file ->
                    file.isFile && file.length() in 1..(2L * 1024L * 1024L) &&
                        file.extension.lowercase() in setOf("jpg", "jpeg", "png", "webp")
                }
            val bytes = runCatching { image?.readBytes() }.getOrNull()
            val request = PutDataMapRequest.create(PATH_PROFILE_IMAGE).apply {
                dataMap.putInt("version", version.coerceAtLeast(0))
                dataMap.putLong("updatedAt", System.currentTimeMillis())
                dataMap.putBoolean("hasImage", bytes != null)
                if (bytes != null) dataMap.putAsset("image", Asset.createFromBytes(bytes))
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(this).putDataItem(request)
                .addOnSuccessListener { mainHandler.post { result.success(true) } }
                .addOnFailureListener { mainHandler.post { result.success(false) } }
        }.start()
    }

    private fun putWorkoutDetectionPreferences(
        mode: String,
        racketSportsOnly: Boolean,
        onlyWhenWorn: Boolean,
        result: MethodChannel.Result,
    ) {
        val safeMode = mode.takeIf { it in setOf("OFF", "ASK", "QUICK_START") }
            ?: "OFF"
        val request = PutDataMapRequest.create(
            PATH_WORKOUT_DETECTION_PREFERENCES
        ).apply {
            dataMap.putInt("schemaVersion", 1)
            dataMap.putString("mode", safeMode)
            dataMap.putBoolean("racketSportsOnly", racketSportsOnly)
            // Stored for forward compatibility; the current wearable runtime
            // deliberately does not infer worn state from undocumented APIs.
            dataMap.putBoolean("onlyWhenWorn", onlyWhenWorn)
            dataMap.putLong("updatedAt", System.currentTimeMillis())
        }.asPutDataRequest()
        Wearable.getDataClient(this).putDataItem(request)
            .addOnSuccessListener { mainHandler.post { result.success(true) } }
            .addOnFailureListener { mainHandler.post { result.success(false) } }
    }

    private fun safePathComponent(value: String): String = value
        .replace(Regex("[^A-Za-z0-9_-]"), "_")
        .take(96)
}
