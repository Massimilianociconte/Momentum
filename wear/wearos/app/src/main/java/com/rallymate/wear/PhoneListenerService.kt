package com.rallymate.wear

import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

internal const val SCORING_PROTOCOL_VERSION = 2
internal const val STAR_POINT_CAPABILITY = "star_point_v1"

/**
 * Format schema v3: this build can score a deciding set without tie-break.
 * Additive token — an older peer simply never advertises it, so the phone
 * gate fails closed instead of degrading the format silently.
 */
internal const val DECIDING_SET_CAPABILITY = "deciding_set_no_tiebreak_v1"

internal fun scoringPongPayload(nonce: String, kind: String): JSONObject =
    JSONObject()
        .put("nonce", nonce)
        .put("kind", kind)
        .put("scoringProtocolVersion", SCORING_PROTOCOL_VERSION)
        .put(
            "scoringCapabilities",
            JSONArray().put(STAR_POINT_CAPABILITY).put(DECIDING_SET_CAPABILITY),
        )

internal enum class StartMatchDeliveryDecision {
    APPLY,
    IDEMPOTENT,
    STALE,
}

internal fun startMatchDeliveryDecision(
    incomingDispatchedAtMs: Long,
    incomingMatchId: String,
    lastDispatchedAtMs: Long,
    lastMatchId: String?,
): StartMatchDeliveryDecision {
    if (lastDispatchedAtMs > 0 && incomingDispatchedAtMs <= 0) {
        return StartMatchDeliveryDecision.STALE
    }
    if (incomingDispatchedAtMs < lastDispatchedAtMs) {
        return StartMatchDeliveryDecision.STALE
    }
    if (
        incomingDispatchedAtMs > 0 &&
        incomingDispatchedAtMs == lastDispatchedAtMs &&
        incomingMatchId == lastMatchId
    ) {
        return StartMatchDeliveryDecision.IDEMPOTENT
    }
    return StartMatchDeliveryDecision.APPLY
}

/**
 * Riceve `startMatch` dal telefono anche ad app chiusa (PRD C1 punto 7:
 * "Avvia su telefono o invia al watch").
 */
class PhoneListenerService : WearableListenerService() {

    companion object {
        const val ACTION_TEAM_VISUAL_UPDATED =
            "com.rallymate.wear.TEAM_VISUAL_UPDATED"
        const val ACTION_PROFILE_IMAGE_UPDATED =
            "com.rallymate.wear.PROFILE_IMAGE_UPDATED"
        const val EXTRA_MATCH_ID = "matchId"
        const val ACTION_RESUMABLE_UPDATED =
            "com.rallymate.wear.RESUMABLE_UPDATED"
        private const val START_DELIVERY_PREFERENCES =
            "rallymate_start_match_delivery"
        private const val LAST_START_DISPATCHED_AT_MS =
            "last_start_dispatched_at_ms"
        private const val LAST_START_MATCH_ID = "last_start_match_id"
    }

    override fun onMessageReceived(event: MessageEvent) {
        when (event.path) {
            SyncPaths.EVENTS_ACK,
            SyncPaths.EVENTS_ACK_V2,
            -> acknowledgeEvents(event)
            SyncPaths.START_MATCH,
            SyncPaths.START_MATCH_V2,
            -> handleStartMatchPayload(event.data)
            SyncPaths.STATE_RESPONSE,
            SyncPaths.STATE_RESPONSE_V2,
            -> handleStateResponse(event)
            SyncPaths.LIFECYCLE,
            SyncPaths.LIFECYCLE_V2,
            -> handleLifecyclePayload(event.data)
            SyncPaths.PING, SyncPaths.TEST_POINT -> acknowledgeTest(event)
        }
    }

    private fun handleStateResponse(event: MessageEvent) {
        try {
            // Recovery: il telefono ha risposto con il log completo. A Star
            // Point response on the legacy path is ignored fail-closed.
            val json = JSONObject(String(event.data))
            val matchId = json.getString("matchId")
            val events = MatchEvent.listFromJson(json.getString("events"))
            val store = LocalMatchStore(this)
            val format = store.loadFormat(matchId) ?: return
            if (event.path != SyncPaths.scoringTransport(format).stateResponse) {
                return
            }
            if (events.isNotEmpty()) {
                val remoteIds = events.map { it.eventId }.toSet()
                val localTail = store.loadEvents(matchId).filter {
                    it.eventId !in remoteIds
                }
                store.saveMatch(matchId, format, events + localTail)
            }
        } catch (_: Exception) {
            // Recovery is best-effort; keep the local watch log intact.
        }
    }

    /** Latest snapshot of resumable matches. Merged, never blindly replaced. */
    private fun handleResumablePayload(raw: ByteArray) {
        try {
            val store = LocalMatchStore(this)
            val snapshot = WearResumableSnapshot.fromPayload(JSONObject(String(raw)))
            store.mergeResumableSnapshot(snapshot)
            broadcastResumableChanged()
        } catch (_: Exception) {
            // A malformed snapshot must never drop the local list.
        }
    }

    /**
     * Durable lifecycle change with the full journal attached, so a match paused
     * on the phone can be resumed here with no connection at all.
     * Idempotent: the Data Layer may redeliver the same payload.
     */
    private fun handleLifecyclePayload(raw: ByteArray) {
        try {
            val json = JSONObject(String(raw))
            val lifecycle = WearMatchLifecycle.fromPayload(json) ?: return
            val store = LocalMatchStore(this)
            val declaredScope = lifecycle.authorityScope?.let {
                WearSnapshotAuthorityScope.fromWire(it) ?: return
            }
            val wireSummary = json.optString("summary").takeIf { it.isNotBlank() }
                ?.let {
                    runCatching {
                        WearResumableMatch.fromJson(JSONObject(it))
                    }.getOrNull()
                }
            val knownFormats = listOfNotNull(
                lifecycle.format,
                wireSummary?.format,
                store.loadFormat(lifecycle.matchId),
            )
            val inferredScopes = knownFormats.map {
                if (it.gameScoringMode == GameScoringMode.STAR_POINT) {
                    WearSnapshotAuthorityScope.STAR_POINT
                } else {
                    WearSnapshotAuthorityScope.NON_STAR_POINT
                }
            }
            if (declaredScope != null && inferredScopes.any { it != declaredScope }) {
                return
            }
            val lifecycleScope = declaredScope
                ?: inferredScopes.firstOrNull()
            if (!store.acceptLifecycleAuthority(
                    source = lifecycle.authoritySource,
                    scope = lifecycleScope,
                    version = lifecycle.authorityVersion,
                )
            ) {
                return
            }
            if (!store.markLifecycleApplied(lifecycle.idempotencyKey)) return
            val known = store.stateVersion(lifecycle.matchId)
            // A lower version never overwrites a newer local state, but a
            // terminal status always wins so a match cannot be reopened.
            if (lifecycle.stateVersion < known && !lifecycle.status.isTerminal) return
            store.saveStateVersion(lifecycle.matchId, lifecycle.stateVersion)

            if (lifecycle.events.isNotEmpty()) {
                val format = lifecycle.format
                    ?: store.loadFormat(lifecycle.matchId)
                    ?: MatchFormat()
                val merged = mergeStartMatchEvents(
                    existing = store.loadEvents(lifecycle.matchId),
                    incoming = lifecycle.events,
                )
                // Never hijack the match currently open on this watch.
                store.saveJournal(lifecycle.matchId, format, merged)
            }
            val summary = wireSummary ?: buildSummary(store, lifecycle)
            if (summary != null) store.applyLocalMatchUpdate(summary)
            broadcastResumableChanged()
        } catch (_: Exception) {
            // Never let a malformed lifecycle payload corrupt local state.
        }
    }

    private fun buildSummary(
        store: LocalMatchStore,
        lifecycle: WearMatchLifecycle,
    ): WearResumableMatch? {
        val format = store.loadFormat(lifecycle.matchId) ?: return null
        val events = store.loadEvents(lifecycle.matchId)
        val engine = ScoringEngine(matchId = lifecycle.matchId, format = format)
        if (events.isNotEmpty()) engine.loadEvents(events)
        val state = engine.state
        val visual = store.loadTeamVisual(lifecycle.matchId)
        return WearResumableMatch(
            matchId = lifecycle.matchId,
            status = lifecycle.status,
            stateVersion = maxOf(lifecycle.stateVersion, events.size),
            updatedAtMs = if (lifecycle.timestampMs > 0) {
                lifecycle.timestampMs
            } else {
                events.lastOrNull()?.timestampMs ?: 0
            },
            pausedAtMs = if (lifecycle.status == WearMatchStatus.PAUSED) {
                events.lastOrNull { it.type == EventType.MATCH_PAUSED }?.timestampMs
            } else {
                null
            },
            teamLabel = visual.teamName,
            scoreLine = "${state.pointsLabel(TeamId.A)}-${state.pointsLabel(TeamId.B)}",
            setsLabel = "${state.setsA}-${state.setsB}",
            gamesLabel = "${state.gamesA}-${state.gamesB}",
            format = format,
            sourceDevice = "PHONE",
            eventCount = events.size,
            journalAvailable = events.isNotEmpty(),
        )
    }

    private fun broadcastResumableChanged() {
        sendBroadcast(
            android.content.Intent(ACTION_RESUMABLE_UPDATED)
                .setPackage(packageName)
        )
    }

    private fun handleStartMatchPayload(raw: ByteArray) {
        try {
            val json = JSONObject(String(raw))
            val matchId = json.getString("matchId")
            val dispatchedAtMs = json.optLong("startDispatchedAtMs", 0L)
            val deliveryPreferences = getSharedPreferences(
                START_DELIVERY_PREFERENCES,
                MODE_PRIVATE,
            )
            when (
                startMatchDeliveryDecision(
                    incomingDispatchedAtMs = dispatchedAtMs,
                    incomingMatchId = matchId,
                    lastDispatchedAtMs = deliveryPreferences.getLong(
                        LAST_START_DISPATCHED_AT_MS,
                        0L,
                    ),
                    lastMatchId = deliveryPreferences.getString(
                        LAST_START_MATCH_ID,
                        null,
                    ),
                )
            ) {
                StartMatchDeliveryDecision.STALE,
                StartMatchDeliveryDecision.IDEMPOTENT,
                -> return
                StartMatchDeliveryDecision.APPLY -> Unit
            }
            val format = MatchFormat.fromJson(
                JSONObject(json.getString("format"))
            )
            val store = LocalMatchStore(this)
            // MessageClient and Data Layer may redeliver the same START_MATCH.
            // Never replace the durable watch journal with an empty phone payload.
            val incomingEvents = json.optString("events")
                .takeIf { it.isNotBlank() }
                ?.let { MatchEvent.listFromJson(it) }
                .orEmpty()
            val mergedEvents = mergeStartMatchEvents(
                existing = store.loadEvents(matchId),
                incoming = incomingEvents,
            )
            store.saveMatch(matchId, format, mergedEvents)
            val teamNamesJson = json.optJSONArray("teamNames")
            val teamNames = if (teamNamesJson == null) emptyList() else {
                (0 until teamNamesJson.length()).mapNotNull { index ->
                    teamNamesJson.optString(index).takeIf { it.isNotBlank() }
                }
            }
            store.saveAccountContext(
                WearAccountContext(
                    sourceUserId = json.optString("sourceUserId")
                        .takeIf { it.isNotBlank() },
                    premiumEnabled = json.optBoolean("premiumEnabled", false),
                    assistantEnabled = json.optBoolean("assistantEnabled", false),
                    teamNames = teamNames,
                    defaultTeamName = json.optString(
                        "defaultTeamName",
                        json.optString("teamName"),
                    ),
                ),
            )
            val credentialStore = WearAssistantCredentialStore(this)
            if (json.optBoolean("assistantEnabled", false)) {
                val credentials = WearAssistantCredentials(
                    endpoint = json.optString("assistantEndpoint"),
                    publishableKey = json.optString("assistantPublishableKey"),
                    accessToken = json.optString("assistantAccessToken"),
                    expiresAtMs = json.optLong("assistantExpiresAtMs"),
                )
                credentialStore.save(credentials)
            } else {
                credentialStore.clear()
            }
            store.saveDuoTeam(
                matchId,
                json.optString("duoTeam").takeIf { it.isNotBlank() }
                    ?.let { runCatching { TeamId.fromWire(it) }.getOrNull() },
            )
            // Absent on payloads from an older phone build: the stored default
            // TEAM_A then matches what that phone's engine assumed.
            json.optString("firstServer").takeIf { it.isNotBlank() }
                ?.let { runCatching { TeamId.fromWire(it) }.getOrNull() }
                ?.let { store.saveFirstServer(matchId, it) }
            val version = json.optInt("teamImageVersion", 0)
            val existing = store.loadTeamVisual(matchId)
            val expected = json.optBoolean("teamImageExpected", false)
            store.saveTeamVisual(
                matchId,
                TeamVisual(
                    teamName = json.optString("teamName").take(80),
                    style = json.optString("teamScoringStyle", "AUTO"),
                    imageVersion = version,
                    imageExpected = expected,
                    imagePath = existing.imagePath.takeIf {
                        expected && existing.imageVersion == version
                    },
                ),
            )
            deliveryPreferences.edit()
                .putLong(LAST_START_DISPATCHED_AT_MS, dispatchedAtMs)
                .putString(LAST_START_MATCH_ID, matchId)
                .apply()
            startActivity(
                MainActivityLaunchPolicy.applyTo(
                    Intent(this, MainActivity::class.java)
                        .putExtra("matchId", matchId)
                )
            )
        } catch (_: Exception) {
            // A malformed phone payload should not kill the wearable service.
        }
    }

    private fun acknowledgeEvents(event: MessageEvent) {
        try {
            val json = JSONObject(String(event.data))
            val matchId = json.getString("matchId")
            val store = LocalMatchStore(this)
            val format = store.loadFormat(matchId) ?: return
            if (event.path != SyncPaths.scoringTransport(format).eventsAck) {
                // In particular, never let a legacy phone ACK a Star Point
                // journal it could only have interpreted as Advantage.
                return
            }
            val rows = json.getJSONArray("eventIds")
            val eventIds = buildSet {
                for (index in 0 until minOf(rows.length(), 2_000)) {
                    rows.optString(index)
                        .takeIf { it.isNotBlank() && it.length <= 128 }
                        ?.let(::add)
                }
            }
            if (eventIds.isEmpty()) return
            // Commit the ACK on-watch even if no UI process is waiting.  A
            // duplicate or out-of-order ACK is harmless because marking is by
            // immutable eventId.
            store.markSynced(matchId, eventIds)
            EventAckRegistry.acknowledge(matchId, eventIds, event.path)
        } catch (_: Exception) {
            // Malformed ACKs never remove events from the durable journal.
        }
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        try {
            dataEvents
                .filter { it.type == DataEvent.TYPE_CHANGED }
                .map { it.dataItem }
                .filter {
                    it.uri.path?.startsWith(SyncPaths.TEAM_IMAGE) == true ||
                        it.uri.path?.startsWith(SyncPaths.PROFILE_IMAGE) == true ||
                        it.uri.path == SyncPaths.WORKOUT_DETECTION_PREFERENCES ||
                        SyncPaths.isStartMatch(it.uri.path) ||
                        SyncPaths.isResumable(it.uri.path) ||
                        SyncPaths.isLifecycle(it.uri.path)
                }
                .forEach { item ->
                    val data = DataMapItem.fromDataItem(item).dataMap
                    if (SyncPaths.isStartMatch(item.uri.path)) {
                        val payload = data.getByteArray("payload") ?: return@forEach
                        handleStartMatchPayload(payload)
                        return@forEach
                    }
                    if (SyncPaths.isResumable(item.uri.path)) {
                        val payload = data.getByteArray("payload") ?: return@forEach
                        handleResumablePayload(payload)
                        return@forEach
                    }
                    if (SyncPaths.isLifecycle(item.uri.path)) {
                        val payload = data.getByteArray("payload") ?: return@forEach
                        handleLifecyclePayload(payload)
                        return@forEach
                    }
                    if (item.uri.path == SyncPaths.WORKOUT_DETECTION_PREFERENCES) {
                        val preferences = WorkoutDetectionPreferences(
                            mode = WorkoutDetectionMode.fromWire(data.getString("mode")),
                            racketSportsOnly = data.getBoolean("racketSportsOnly", true),
                            onlyWhenWorn = data.getBoolean("onlyWhenWorn", false),
                        )
                        WorkoutDetectionManager.applyPreferences(this, preferences)
                        return@forEach
                    }
                    if (item.uri.path?.startsWith(SyncPaths.PROFILE_IMAGE) == true) {
                        receiveProfileImage(data)
                        return@forEach
                    }
                    val matchId = data.getString("matchId")?.takeIf { it.isNotBlank() }
                        ?: return@forEach
                    val style = data.getString("style") ?: "AUTO"
                    val teamName = data.getString("teamName") ?: ""
                    val version = data.getInt("version")
                    if (!data.getBoolean("hasImage")) {
                        clearTeamImage(matchId)
                        saveTeamVisual(matchId, teamName, style, version, null)
                        return@forEach
                    }
                    val asset = data.getAsset("image") ?: return@forEach
                    Wearable.getDataClient(this).getFdForAsset(asset)
                        .addOnSuccessListener { response ->
                            val input = response.inputStream ?: return@addOnSuccessListener
                            val directory = File(filesDir, "team_images").apply { mkdirs() }
                            val safeMatch = safePathComponent(matchId)
                            val destination = File(directory, "${safeMatch}_${version}.jpg")
                            val temporary = File(directory, ".${destination.name}.tmp")
                            val saved = runCatching {
                                input.use { source ->
                                    temporary.outputStream().use { target ->
                                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                                        var total = 0L
                                        while (true) {
                                            val read = source.read(buffer)
                                            if (read < 0) break
                                            total += read
                                            require(total <= 2L * 1024L * 1024L)
                                            target.write(buffer, 0, read)
                                        }
                                        require(total > 0)
                                    }
                                }
                                require(isValidWatchImage(temporary))
                                directory.listFiles()
                                    ?.filter {
                                        it.name.startsWith("${safeMatch}_") &&
                                            it != destination && it != temporary
                                    }
                                    ?.forEach(File::delete)
                                destination.delete()
                                require(temporary.renameTo(destination))
                                destination.absolutePath
                            }.getOrNull()
                            if (saved == null) temporary.delete()
                            else saveTeamVisual(matchId, teamName, style, version, saved)
                        }
                }
        } finally {
            dataEvents.release()
        }
    }

    private fun receiveProfileImage(data: com.google.android.gms.wearable.DataMap) {
        val store = LocalMatchStore(this)
        val version = data.getInt("version")
        if (!data.getBoolean("hasImage")) {
            File(filesDir, "profile_images").deleteRecursively()
            store.saveProfileImage(null, 0)
            sendBroadcast(Intent(ACTION_PROFILE_IMAGE_UPDATED).setPackage(packageName))
            return
        }
        val asset = data.getAsset("image") ?: return
        Wearable.getDataClient(this).getFdForAsset(asset)
            .addOnSuccessListener { response ->
                val input = response.inputStream ?: return@addOnSuccessListener
                val directory = File(filesDir, "profile_images").apply { mkdirs() }
                val destination = File(directory, "avatar_${version.coerceAtLeast(0)}.jpg")
                val temporary = File(directory, ".avatar.tmp")
                val saved = runCatching {
                    input.use { source ->
                        temporary.outputStream().use { target ->
                            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                            var total = 0L
                            while (true) {
                                val read = source.read(buffer)
                                if (read < 0) break
                                total += read
                                require(total <= 2L * 1024L * 1024L)
                                target.write(buffer, 0, read)
                            }
                            require(total > 0)
                        }
                    }
                    require(isValidWatchImage(temporary))
                    directory.listFiles()
                        ?.filter { it != temporary && it != destination }
                        ?.forEach(File::delete)
                    destination.delete()
                    require(temporary.renameTo(destination))
                    destination.absolutePath
                }.getOrNull()
                if (saved == null) {
                    temporary.delete()
                } else {
                    store.saveProfileImage(saved, version)
                    sendBroadcast(
                        Intent(ACTION_PROFILE_IMAGE_UPDATED).setPackage(packageName),
                    )
                }
            }
    }

    private fun saveTeamVisual(
        matchId: String,
        teamName: String,
        style: String,
        version: Int,
        imagePath: String?,
    ) {
        LocalMatchStore(this).saveTeamVisual(
            matchId,
            TeamVisual(
                teamName = teamName.take(80),
                style = style,
                imageVersion = version.coerceAtLeast(0),
                imageExpected = imagePath != null,
                imagePath = imagePath,
            ),
        )
        sendBroadcast(
            Intent(ACTION_TEAM_VISUAL_UPDATED)
                .setPackage(packageName)
                .putExtra(EXTRA_MATCH_ID, matchId)
        )
    }

    private fun clearTeamImage(matchId: String) {
        val safeMatch = safePathComponent(matchId)
        File(filesDir, "team_images").listFiles()
            ?.filter { it.name.startsWith("${safeMatch}_") }
            ?.forEach(File::delete)
    }

    private fun safePathComponent(value: String): String = value
        .replace(Regex("[^A-Za-z0-9_-]"), "_")
        .take(96)

    private fun acknowledgeTest(event: MessageEvent) {
        val nonce = runCatching {
            JSONObject(String(event.data)).getString("nonce")
        }.getOrNull() ?: return
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as? Vibrator
        }
        val duration = if (event.path == SyncPaths.TEST_POINT) 180L else 70L
        vibrator?.vibrate(
            VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE)
        )
        Wearable.getMessageClient(this).sendMessage(
            event.sourceNodeId,
            SyncPaths.PONG,
            scoringPongPayload(nonce, event.path).toString().toByteArray(),
        )
    }
}

private fun isValidWatchImage(file: File): Boolean {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.absolutePath, bounds)
    return bounds.outWidth in 1..4096 && bounds.outHeight in 1..4096
}
