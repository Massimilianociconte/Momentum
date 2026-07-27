package com.rallymate.rallymate

import android.content.pm.ApplicationInfo
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.Asset
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

internal fun allLegacyScoringNodesSupportV2(
    legacyNodeIds: Set<String>,
    scoringV2NodeIds: Set<String>,
): Boolean = legacyNodeIds.isNotEmpty() && scoringV2NodeIds.containsAll(legacyNodeIds)

internal fun oppositeStartMatchPath(path: String): String? = when (path) {
    "/rallymate/start_match" -> "/rallymate/v2/start_match"
    "/rallymate/v2/start_match" -> "/rallymate/start_match"
    else -> null
}

internal fun nextMonotonicDispatchAtMs(previous: Long, wallClock: Long): Long =
    maxOf(wallClock, previous + 1)

internal const val SCORING_EVENTS_V1_PATH = "/rallymate/events"
internal const val SCORING_EVENTS_V2_PATH = "/rallymate/v2/events"
internal const val SCORING_EVENTS_ACK_V1_PATH = "/rallymate/events_ack"
internal const val SCORING_EVENTS_ACK_V2_PATH = "/rallymate/v2/events_ack"
internal const val SCORING_REQUEST_STATE_V1_PATH = "/rallymate/request_state"
internal const val SCORING_REQUEST_STATE_V2_PATH = "/rallymate/v2/request_state"
internal const val SCORING_STATE_RESPONSE_V1_PATH = "/rallymate/state_response"
internal const val SCORING_STATE_RESPONSE_V2_PATH = "/rallymate/v2/state_response"

internal enum class ScoringPayloadLane {
    LEGACY,
    STAR_POINT_V2,
    INVALID,
}

/**
 * Resolves the scoring lane without tolerant fallback. Star Point is valid
 * only as canonical schema-v2; otherwise an old phone could read
 * `goldenPoint=false` and silently replay it as Advantage.
 */
/**
 * Upper bound for a plausible declared schema: anything larger is a malformed
 * or hostile payload, not a future build.
 */
internal const val MAX_SUPPORTED_FORMAT_SCHEMA_VERSION = 1000.0

internal fun scoringPayloadLane(formatJson: String?): ScoringPayloadLane {
    if (formatJson.isNullOrBlank()) return ScoringPayloadLane.INVALID
    return runCatching {
        val format = JSONObject(formatJson)
        val legacyGoldenPoint = format.opt("goldenPoint")
        val schemaVersion = (format.opt("formatSchemaVersion") as? Number)
            ?.toDouble()
        // Schema 2 is the first that can represent Star Point at all, and
        // later schemas only add fields, so pinning the exact number would
        // reject a watch on a newer build. The value must still be a plain
        // integer inside a sane range: fractional or runaway versions stay
        // rejected as malformed.
        val isCanonicalV2 =
            schemaVersion != null &&
                schemaVersion.isFinite() &&
                schemaVersion >= 2.0 &&
                schemaVersion <= MAX_SUPPORTED_FORMAT_SCHEMA_VERSION &&
                schemaVersion == kotlin.math.floor(schemaVersion)
        when (format.optString("gameScoringMode").takeIf { it.isNotBlank() }) {
            "STAR_POINT" -> if (
                isCanonicalV2 &&
                legacyGoldenPoint == false
            ) {
                ScoringPayloadLane.STAR_POINT_V2
            } else {
                ScoringPayloadLane.INVALID
            }
            "ADVANTAGE" -> if (legacyGoldenPoint == false) {
                ScoringPayloadLane.LEGACY
            } else {
                ScoringPayloadLane.INVALID
            }
            "GOLDEN_POINT" -> if (legacyGoldenPoint == true) {
                ScoringPayloadLane.LEGACY
            } else {
                ScoringPayloadLane.INVALID
            }
            null -> if (legacyGoldenPoint is Boolean) {
                ScoringPayloadLane.LEGACY
            } else {
                ScoringPayloadLane.INVALID
            }
            else -> ScoringPayloadLane.INVALID
        }
    }.getOrDefault(ScoringPayloadLane.INVALID)
}

internal fun acceptsWatchEventsPath(path: String, formatJson: String?): Boolean =
    when (scoringPayloadLane(formatJson)) {
        ScoringPayloadLane.LEGACY -> path == SCORING_EVENTS_V1_PATH
        ScoringPayloadLane.STAR_POINT_V2 -> path == SCORING_EVENTS_V2_PATH
        ScoringPayloadLane.INVALID -> false
    }

internal fun eventsAckPathFor(eventsPath: String): String? = when (eventsPath) {
    SCORING_EVENTS_V1_PATH -> SCORING_EVENTS_ACK_V1_PATH
    SCORING_EVENTS_V2_PATH -> SCORING_EVENTS_ACK_V2_PATH
    else -> null
}

internal fun acceptsRequestStatePath(path: String, formatJson: String?): Boolean {
    // Legacy watches sent only matchId. Preserve that v1 recovery contract;
    // the v2 lane always requires explicit canonical Star Point metadata.
    if (path == SCORING_REQUEST_STATE_V1_PATH && formatJson.isNullOrBlank()) {
        return true
    }
    return when (scoringPayloadLane(formatJson)) {
        ScoringPayloadLane.LEGACY -> path == SCORING_REQUEST_STATE_V1_PATH
        ScoringPayloadLane.STAR_POINT_V2 -> path == SCORING_REQUEST_STATE_V2_PATH
        ScoringPayloadLane.INVALID -> false
    }
}

internal fun stateResponsePathFor(requestPath: String): String? = when (requestPath) {
    SCORING_REQUEST_STATE_V1_PATH -> SCORING_STATE_RESPONSE_V1_PATH
    SCORING_REQUEST_STATE_V2_PATH -> SCORING_STATE_RESPONSE_V2_PATH
    else -> null
}

internal fun permitsCapabilitylessScoringV2SnapshotClear(
    path: String,
    requestedClear: Boolean,
    authoritative: Boolean,
    authoritySource: String?,
    authorityScope: String?,
    authorityVersion: Long,
    matchCount: Int,
): Boolean =
    path == "/rallymate/v2/resumable" &&
        requestedClear &&
        authoritative &&
        authoritySource == "PHONE" &&
        authorityScope == "STAR_POINT" &&
        authorityVersion > 0 &&
        matchCount == 0

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
        const val PATH_START_MATCH_V2 = "/rallymate/v2/start_match"
        /** Upper bound for the journal carried by a durable Data Item. */
        const val MAX_DURABLE_JOURNAL_BYTES = 24 * 1024
        const val PATH_RESUMABLE = "/rallymate/resumable"
        const val PATH_RESUMABLE_V2 = "/rallymate/v2/resumable"
        const val PATH_LIFECYCLE = "/rallymate/lifecycle"
        const val PATH_LIFECYCLE_V2 = "/rallymate/v2/lifecycle"
        const val PATH_EVENTS = SCORING_EVENTS_V1_PATH
        const val PATH_EVENTS_V2 = SCORING_EVENTS_V2_PATH
        const val PATH_EVENTS_ACK = SCORING_EVENTS_ACK_V1_PATH
        const val PATH_EVENTS_ACK_V2 = SCORING_EVENTS_ACK_V2_PATH
        const val PATH_REQUEST_STATE = SCORING_REQUEST_STATE_V1_PATH
        const val PATH_REQUEST_STATE_V2 = SCORING_REQUEST_STATE_V2_PATH
        const val PATH_STATE_RESPONSE = SCORING_STATE_RESPONSE_V1_PATH
        const val PATH_STATE_RESPONSE_V2 = SCORING_STATE_RESPONSE_V2_PATH
        const val PATH_PING = "/rallymate/ping"
        const val PATH_TEST_POINT = "/rallymate/test_point"
        const val PATH_PONG = "/rallymate/pong"
        const val PATH_TEAM_IMAGE = "/rallymate/team_image"
        const val PATH_PROFILE_IMAGE = "/rallymate/profile_image"
        const val PATH_WORKOUT_DETECTION_PREFERENCES =
            "/rallymate/workout_detection_preferences"
        const val CAPABILITY_SCORING = "rallymate_scoring"
        const val CAPABILITY_SCORING_V2 = "rallymate_scoring_v2"

        /**
         * Format schema v3: the companion understands
         * MatchFormat.tieBreakInDecidingSet. Older companions never declare it,
         * so the deciding-set format stays blocked instead of degrading.
         */
        const val CAPABILITY_SCORING_V3 = "rallymate_scoring_v3"
        const val START_DISPATCH_PREFERENCES = "rallymate_start_dispatch"
        const val LAST_START_DISPATCHED_AT_MS = "last_start_dispatched_at_ms"
        const val EXTRA_GARMIN_TETHERED = "rallymate_garmin_tethered"
        const val EXTRA_GARMIN_SMOKE_TEST = "rallymate_garmin_smoke_test"
        /** Health Connect: richiesta rationale/privacy dichiarata nel manifest. */
        const val ACTION_HC_RATIONALE = "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"
        const val ACTION_VIEW_PERMISSION_USAGE = "android.intent.action.VIEW_PERMISSION_USAGE"
    }

    private var channel: MethodChannel? = null
    private var notificationBridge: NotificationBridge? = null
    private var healthConnectBridge: HealthConnectBridge? = null
    private var garminBridge: GarminConnectIqBridge? = null
    private var bleHeartRateBridge: BleHeartRateBridge? = null
    private val pendingTests = ConcurrentHashMap<String, MethodChannel.Result>()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Synchronized
    private fun nextStartDispatchAtMs(): Long {
        val preferences = getSharedPreferences(
            START_DISPATCH_PREFERENCES,
            MODE_PRIVATE,
        )
        val next = nextMonotonicDispatchAtMs(
            previous = preferences.getLong(LAST_START_DISPATCHED_AT_MS, 0L),
            wallClock = System.currentTimeMillis(),
        )
        // Persist synchronously: a process restart or clock rollback must not
        // produce a START_MATCH older than the watch has already accepted.
        preferences.edit().putLong(LAST_START_DISPATCHED_AT_MS, next).commit()
        return next
    }

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
        // Apertura via foglio permessi Health Connect: Flutter mostrerà la
        // schermata Privacy e dati (rationale d'uso dei dati salute).
        if (isHealthRationaleIntent(intent)) {
            healthConnectBridge?.onRationaleIntent()
        }
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
                    // Serving rotation of this match (FIP Rule 4). Absent on
                    // payloads from an older phone build, where the engine
                    // default TEAM_A applies.
                    val firstServer = call.argument<String>("firstServer")
                        ?.takeIf { it == "TEAM_A" || it == "TEAM_B" }
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
                                if (isStarPointFormat(format)) {
                                    PATH_START_MATCH_V2
                                } else {
                                    PATH_START_MATCH
                                },
                                JSONObject()
                                    .put("matchId", matchId)
                                    .put("format", format)
                                    .put("events", events)
                                    .put("startDispatchedAtMs", nextStartDispatchAtMs())
                                    .put("teamName", teamName.orEmpty())
                                    .put("teamImageVersion", teamImageVersion)
                                    .put("teamScoringStyle", teamScoringStyle)
                                    .put("teamImageExpected", imageAvailable)
                                    .apply {
                                        firstServer?.let { put("firstServer", it) }
                                    }
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
                        val format = call.argument<String>("format")
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
                                format?.let { put("format", it) }
                                call.argument<String>("authoritySource")
                                    ?.let { put("authoritySource", it) }
                                call.argument<String>("authorityScope")
                                    ?.let { put("authorityScope", it) }
                                call.argument<Number>("authorityVersion")
                                    ?.toLong()
                                    ?.takeIf { it > 0 }
                                    ?.let { put("authorityVersion", it) }
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
                            if (isStarPointFormat(format)) {
                                PATH_LIFECYCLE_V2
                            } else {
                                PATH_LIFECYCLE
                            },
                            payload.toString().toByteArray(),
                            result,
                        )
                    }
                }
                "publishResumableMatches" -> {
                    // Latest-state channel: a Data Item always holds the most
                    // recent snapshot and is delivered when the watch reconnects.
                    val matchesJson = call.argument<String>("matches") ?: "[]"
                    val authoritative = call.argument<Boolean>("authoritative") == true
                    val authoritySource = call.argument<String>("authoritySource")
                    val authorityScope = call.argument<String>("authorityScope")
                    val authorityVersion = call.argument<Number>("authorityVersion")
                        ?.toLong() ?: 0L
                    val payload = JSONObject()
                        .put("schemaVersion", 1)
                        .put("matches", matchesJson)
                        .put("stateVersion", call.argument<Int>("stateVersion") ?: 0)
                        .put(
                            "lastUpdatedAtMs",
                            call.argument<Number>("lastUpdatedAtMs")?.toLong()
                                ?: System.currentTimeMillis(),
                        )
                        .apply {
                            if (authoritative) put("authoritative", true)
                            authoritySource?.let { put("authoritySource", it) }
                            authorityScope?.let { put("authorityScope", it) }
                            if (authorityVersion > 0) {
                                put("authorityVersion", authorityVersion)
                            }
                            call.argument<String>("activeMatchId")
                                ?.takeIf { it.isNotBlank() }
                                ?.let { put("activeMatchId", it) }
                        }
                    val path = if (
                        call.argument<Boolean>("requiresScoringV2") == true
                    ) {
                        PATH_RESUMABLE_V2
                    } else {
                        PATH_RESUMABLE
                    }
                    val matchCount = runCatching {
                        JSONArray(matchesJson).length()
                    }.getOrDefault(-1)
                    val allowCapabilitylessClear =
                        permitsCapabilitylessScoringV2SnapshotClear(
                            path = path,
                            requestedClear =
                                call.argument<Boolean>("clearScoringV2Slot") == true,
                            authoritative = authoritative,
                            authoritySource = authoritySource,
                            authorityScope = authorityScope,
                            authorityVersion = authorityVersion,
                            matchCount = matchCount,
                        )
                    putResumableSnapshot(
                        path,
                        payload.toString().toByteArray(),
                        result,
                        allowCapabilitylessClear = allowCapabilitylessClear,
                    )
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
        if (isHealthRationaleIntent(intent)) {
            healthConnectBridge?.onRationaleIntent()
        }
    }

    private fun isHealthRationaleIntent(intent: Intent?): Boolean =
        intent?.action == ACTION_HC_RATIONALE ||
            intent?.action == ACTION_VIEW_PERMISSION_USAGE

    private fun isStarPointFormat(formatJson: String?): Boolean {
        if (formatJson.isNullOrBlank()) return false
        return runCatching {
            val format = JSONObject(formatJson)
            format.optString("gameScoringMode", format.optString("mode")) == "STAR_POINT"
        }.getOrDefault(false)
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
            PATH_EVENTS,
            PATH_EVENTS_V2,
            -> handleWatchEvents(event)
            PATH_REQUEST_STATE,
            PATH_REQUEST_STATE_V2,
            -> {
                val request = try {
                    JSONObject(String(event.data))
                } catch (_: Exception) {
                    return
                }
                val matchId = request.optString("matchId").takeIf { it.isNotBlank() }
                    ?: return
                val formatJson = request.optString("format").takeIf { it.isNotBlank() }
                if (!acceptsRequestStatePath(event.path, formatJson)) return
                val responsePath = stateResponsePathFor(event.path) ?: return
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
                                        responsePath,
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
        val formatJson = json.optString("format").takeIf { it.isNotBlank() }
            ?: return
        if (!acceptsWatchEventsPath(event.path, formatJson)) return
        val ackPath = eventsAckPathFor(event.path) ?: return
        val args = try {
            mutableMapOf<String, Any>(
                "matchId" to json.getString("matchId"),
                "events" to json.getString("events"),
            )
        } catch (_: Exception) {
            return
        }
        args["format"] = formatJson

        val ch = channel
        if (ch == null) {
            queueRawWatchPayload(json, event.sourceNodeId, ackPath)
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
                                ackPath,
                            )
                        } else {
                            queueRawWatchPayload(json, event.sourceNodeId, ackPath)
                        }
                    }

                    override fun error(code: String, msg: String?, details: Any?) {
                        queueRawWatchPayload(json, event.sourceNodeId, ackPath)
                    }

                    override fun notImplemented() {
                        queueRawWatchPayload(json, event.sourceNodeId, ackPath)
                    }
                },
            )
        }
    }

    private fun queueRawWatchPayload(
        json: JSONObject,
        sourceNodeId: String,
        ackPath: String,
    ) {
        try {
            val matchId = json.getString("matchId")
            val eventIds = WatchEventQueue.enqueueEvents(
                context = this,
                matchId = matchId,
                events = json.getString("events"),
                format = json.optString("format").takeIf { it.isNotBlank() },
            )
            if (!eventIds.isNullOrEmpty()) {
                sendEventsAck(sourceNodeId, matchId, eventIds, ackPath)
            }
        } catch (_: Exception) {
            // Malformed watch payloads should never crash the phone app.
        }
    }

    private fun sendEventsAck(
        nodeId: String,
        matchId: String,
        eventIds: Set<String>,
        path: String,
    ) {
        if (eventIds.isEmpty()) return
        val payload = JSONObject()
            .put("matchId", matchId)
            .put("eventIds", JSONArray(eventIds.toList()))
            .toString()
            .toByteArray()
        Wearable.getMessageClient(this)
            .sendMessage(nodeId, path, payload)
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
                                val scoringNodeIds =
                                    capability.nodes.mapTo(mutableSetOf()) { it.id }
                                resolveStarPointCapability(
                                    scoringNodeIds,
                                ) { supported ->
                                    resolveDecidingSetCapability(
                                        scoringNodeIds,
                                    ) { decidingSet ->
                                        result.success(
                                            statusPayload(
                                                paired = nodes.isNotEmpty() || installed,
                                                installed = installed,
                                                reachable = isReachable,
                                                deviceName = knownNode?.displayName.orEmpty(),
                                                starPointCapable = supported,
                                                decidingSetCapable = decidingSet,
                                                scoringCapabilityProbed = true,
                                            )
                                        )
                                    }
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
        starPointCapable: Boolean = false,
        decidingSetCapable: Boolean = false,
        scoringCapabilityProbed: Boolean = false,
    ): Map<String, Any> {
        val capabilities = mutableListOf(
            "scoring", "duo", "offline", "haptics", "voice", "workout", "alwaysOn"
        )
        if (starPointCapable) capabilities += "star_point_v1"
        if (decidingSetCapable) capabilities += "deciding_set_no_tiebreak_v1"
        return mapOf(
            "supported" to true,
            "paired" to paired,
            "companionInstalled" to installed,
            "reachable" to reachable,
            // Connected means the companion can receive durable Data Layer
            // payloads, not only an interactive nearby node for MessageClient.
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
            "capabilities" to capabilities,
            "scoringProtocolVersion" to if (starPointCapable) 2 else 1,
            "scoringCapabilityProbed" to scoringCapabilityProbed,
        )
    }

    private fun resolveStarPointCapability(
        legacyNodeIds: Set<String>,
        result: (Boolean) -> Unit,
    ) {
        resolveScoringCapability(CAPABILITY_SCORING_V2, legacyNodeIds, result)
    }

    private fun resolveDecidingSetCapability(
        legacyNodeIds: Set<String>,
        result: (Boolean) -> Unit,
    ) {
        resolveScoringCapability(CAPABILITY_SCORING_V3, legacyNodeIds, result)
    }

    /**
     * True only when EVERY node that declares the legacy scoring capability
     * also declares [capabilityName]: a mixed fleet must fail closed, since a
     * single stale companion would score the match differently.
     */
    private fun resolveScoringCapability(
        capabilityName: String,
        legacyNodeIds: Set<String>,
        result: (Boolean) -> Unit,
    ) {
        if (legacyNodeIds.isEmpty()) {
            result(false)
            return
        }
        Wearable.getCapabilityClient(this)
            .getCapability(capabilityName, CapabilityClient.FILTER_ALL)
            .addOnSuccessListener { capability ->
                result(
                    allLegacyScoringNodesSupportV2(
                        legacyNodeIds = legacyNodeIds,
                        scoringV2NodeIds =
                            capability.nodes.mapTo(mutableSetOf()) { it.id },
                    )
                )
            }
            .addOnFailureListener { result(false) }
    }

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
                        val scoringNodeIds =
                            allNodes.nodes.mapTo(mutableSetOf()) { it.id }
                        resolveStarPointCapability(scoringNodeIds) { supported ->
                            resolveDecidingSetCapability(
                                scoringNodeIds,
                            ) { decidingSet ->
                                channel?.invokeMethod(
                                    "connectionChanged",
                                    statusPayload(
                                        paired = paired,
                                        installed = installed,
                                        reachable = reachable,
                                        deviceName = node?.displayName.orEmpty(),
                                        starPointCapable = supported,
                                        decidingSetCapable = decidingSet,
                                        scoringCapabilityProbed = true,
                                    ),
                                )
                            }
                        }
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
        withScoringV2Authorization(path, result) {
            // Durable Data Layer copy first (mirrors iOS transferUserInfo) so a
            // suspended companion still receives START_MATCH when it wakes.
            // Strip short-lived assistant secrets from the durable copy.
            if (path == PATH_START_MATCH || path == PATH_START_MATCH_V2) {
                val durable = stripAssistantSecrets(data)
                val request = PutDataMapRequest.create(path).apply {
                    dataMap.putByteArray("payload", durable)
                    dataMap.putLong("updatedAt", System.currentTimeMillis())
                }
                val dataClient = Wearable.getDataClient(this)
                val putCurrent: () -> Unit = {
                    dataClient
                        .putDataItem(request.asPutDataRequest().setUrgent())
                        .addOnSuccessListener {
                            deliverWatchMessage(path, data, durableOk = true, result)
                        }
                        .addOnFailureListener {
                            // No durable handoff — only succeed if live message lands.
                            deliverWatchMessage(path, data, durableOk = false, result)
                        }
                }
                val obsoletePath = oppositeStartMatchPath(path)
                if (obsoletePath == null) {
                    putCurrent()
                } else {
                    val obsoleteUri = Uri.Builder()
                        .scheme(PutDataRequest.WEAR_URI_SCHEME)
                        .path(obsoletePath)
                        .build()
                    // START_MATCH has one authoritative slot. Remove the other
                    // protocol path before publishing so reconnect cannot replay
                    // an older match from a previous scoring format.
                    dataClient.deleteDataItems(obsoleteUri)
                        .addOnCompleteListener { putCurrent() }
                }
                return@withScoringV2Authorization
            }
            deliverWatchMessage(path, data, durableOk = false, result)
        }
    }

    /// Reliable delivery: a Data Item is queued by the Data Layer and reaches
    /// the watch even when the companion is not running, then a live message is
    /// attempted for immediacy.
    private fun sendDurableToWatch(
        path: String,
        data: ByteArray,
        result: MethodChannel.Result,
    ) {
        withScoringV2Authorization(path, result) {
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
    }

    /// Snapshot channel: one Data Item that always carries the latest state.
    private fun putResumableSnapshot(
        path: String,
        data: ByteArray,
        result: MethodChannel.Result,
        allowCapabilitylessClear: Boolean = false,
    ) {
        val publish: () -> Unit = {
            val request = PutDataMapRequest.create(path).apply {
                dataMap.putByteArray("payload", data)
                dataMap.putLong("updatedAt", System.currentTimeMillis())
            }
            Wearable.getDataClient(this)
                .putDataItem(request.asPutDataRequest().setUrgent())
                .addOnSuccessListener { mainHandler.post { result.success(true) } }
                .addOnFailureListener { mainHandler.post { result.success(false) } }
        }
        if (allowCapabilitylessClear) {
            publish()
        } else {
            withScoringV2Authorization(path, result, publish)
        }
    }

    private fun withScoringV2Authorization(
        path: String,
        result: MethodChannel.Result,
        authorized: () -> Unit,
    ) {
        if (!isScoringV2Path(path)) {
            authorized()
            return
        }
        Wearable.getCapabilityClient(this)
            .getCapability(CAPABILITY_SCORING, CapabilityClient.FILTER_ALL)
            .addOnSuccessListener { legacy ->
                resolveStarPointCapability(
                    legacy.nodes.mapTo(mutableSetOf()) { it.id },
                ) { supported ->
                    if (supported) {
                        authorized()
                    } else {
                        mainHandler.post { result.success(false) }
                    }
                }
            }
            .addOnFailureListener {
                mainHandler.post { result.success(false) }
            }
    }

    private fun isScoringV2Path(path: String): Boolean =
        path.startsWith("/rallymate/v2/")

    private fun deliverWatchMessage(
        path: String,
        data: ByteArray,
        durableOk: Boolean,
        result: MethodChannel.Result,
    ) {
        val capabilityName = if (isScoringV2Path(path)) {
            CAPABILITY_SCORING_V2
        } else {
            CAPABILITY_SCORING
        }
        Wearable.getCapabilityClient(this)
            .getCapability(capabilityName, CapabilityClient.FILTER_REACHABLE)
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
