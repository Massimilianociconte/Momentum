/**
 * Data Layer sync verso il telefono (PRD 9.2).
 *
 * Percorsi messaggi (contratto condiviso con l'app Flutter/Android):
 *  - /rallymate/start_match   phone → watch  {matchId, format}
 *  - /rallymate/events        watch → phone  {matchId, events[]}
 *  - /rallymate/request_state watch → phone  {matchId} → risposta con log
 *
 * Offline-first: gli eventi vengono SEMPRE salvati in locale
 * (SharedPreferences, "salvataggio temporaneo offline" PRD 6.1) e
 * marcati synced solo dopo l'ack del telefono. Il flush è idempotente
 * grazie agli eventId univoci.
 */
package com.rallymate.wear

import android.annotation.SuppressLint
import android.content.Context
import android.os.SystemClock
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONObject

object SyncPaths {
    const val START_MATCH = "/rallymate/start_match"
    const val EVENTS = "/rallymate/events"
    const val EVENTS_ACK = "/rallymate/events_ack"
    const val REQUEST_STATE = "/rallymate/request_state"
    const val STATE_RESPONSE = "/rallymate/state_response"
    const val PING = "/rallymate/ping"
    const val TEST_POINT = "/rallymate/test_point"
    const val PONG = "/rallymate/pong"
    const val TEAM_IMAGE = "/rallymate/team_image"
    const val PROFILE_IMAGE = "/rallymate/profile_image"
    const val WORKOUT_DETECTION_PREFERENCES =
        "/rallymate/workout_detection_preferences"
    /** Latest snapshot of resumable matches (Data Item). */
    const val RESUMABLE = "/rallymate/resumable"
    /** Durable per-match lifecycle change (Data Item + live message). */
    const val LIFECYCLE = "/rallymate/lifecycle"
}

internal class PendingEventAck(
    val matchId: String,
    val expectedIds: Set<String>,
) {
    val result = CompletableDeferred<Set<String>>()
}

/**
 * Process-local rendezvous for application-level acknowledgements.  The
 * listener also commits ACKs directly to [LocalMatchStore], so a process death
 * or a late ACK remains crash-safe and the next retry is idempotent.
 */
internal object EventAckRegistry {
    private val lock = Any()
    private val waiters = mutableSetOf<PendingEventAck>()

    fun register(matchId: String, expectedIds: Set<String>): PendingEventAck =
        PendingEventAck(matchId, expectedIds).also { waiter ->
            synchronized(lock) { waiters += waiter }
        }

    fun cancel(waiter: PendingEventAck) {
        synchronized(lock) { waiters -= waiter }
        waiter.result.cancel()
    }

    fun acknowledge(matchId: String, eventIds: Set<String>) {
        if (eventIds.isEmpty()) return
        val completed = mutableListOf<Pair<PendingEventAck, Set<String>>>()
        synchronized(lock) {
            val iterator = waiters.iterator()
            while (iterator.hasNext()) {
                val waiter = iterator.next()
                if (waiter.matchId != matchId) continue
                val acknowledged = waiter.expectedIds.intersect(eventIds)
                if (acknowledged.isEmpty()) continue
                iterator.remove()
                completed += waiter to acknowledged
            }
        }
        completed.forEach { (waiter, acknowledged) ->
            waiter.result.complete(acknowledged)
        }
    }
}

data class TeamVisual(
    val teamName: String = "",
    val style: String = "AUTO",
    val imageVersion: Int = 0,
    val imageExpected: Boolean = false,
    val imagePath: String? = null,
)

data class WearAccountContext(
    val sourceUserId: String? = null,
    val premiumEnabled: Boolean = false,
    val assistantEnabled: Boolean = false,
    val teamNames: List<String> = emptyList(),
    val defaultTeamName: String = "",
)

/** Idempotent START_MATCH merge: remote order first, then unsent local tail. */
internal fun mergeStartMatchEvents(
    existing: List<MatchEvent>,
    incoming: List<MatchEvent>,
): List<MatchEvent> {
    if (incoming.isEmpty()) return existing
    if (existing.isEmpty()) return incoming
    val incomingIds = incoming.map { it.eventId }.toSet()
    return incoming + existing.filter { it.eventId !in incomingIds }
}

@SuppressLint("ApplySharedPref")
class LocalMatchStore(context: Context) {
    private val prefs =
        context.getSharedPreferences("rallymate_match", Context.MODE_PRIVATE)

    fun saveMatch(matchId: String, format: MatchFormat, events: List<MatchEvent>) {
        saveJournal(matchId, format, events)
        prefs.edit().putString("active_match_id", matchId).commit()
    }

    /**
     * Stores the journal of any match **without** making it the active one.
     * A pause that happened on the phone must never hijack the match being
     * played on this watch.
     */
    fun saveJournal(matchId: String, format: MatchFormat, events: List<MatchEvent>) {
        if (matchId.isBlank()) return
        val alreadySynced = loadEvents(matchId)
            .filter { it.synced }
            .map { it.eventId }
            .toSet()
        val merged = events.map {
            if (it.synced || it.eventId in alreadySynced) it.copy(synced = true) else it
        }
        val known = prefs.getStringSet("known_match_ids", emptySet()).orEmpty().toMutableSet()
        known.add(matchId)
        prefs.edit()
            .putString("format_$matchId", format.toJson().toString())
            .putString("events_$matchId", MatchEvent.listToJson(merged))
            .putStringSet("known_match_ids", known)
            .commit()
    }

    fun activeMatchId(): String? = prefs.getString("active_match_id", null)

    fun setActiveMatch(matchId: String) {
        prefs.edit().putString("active_match_id", matchId).commit()
    }

    fun saveLastFormat(format: MatchFormat) {
        prefs.edit().putString("last_match_format", format.toJson().toString()).commit()
    }

    fun loadLastFormat(): MatchFormat = prefs.getString("last_match_format", null)
        ?.let { runCatching { MatchFormat.fromJson(JSONObject(it)) }.getOrNull() }
        ?: MatchFormat.GOLDEN_BO3

    fun savePlayerRole(role: String) {
        prefs.edit().putString("last_player_role", role).commit()
    }

    fun loadPlayerRole(): String = prefs.getString("last_player_role", "FLEX") ?: "FLEX"

    fun markIncomplete(matchId: String) {
        prefs.edit()
            .putString("last_incomplete_match_id", matchId)
            .remove("active_match_id")
            .commit()
    }

    fun lastIncompleteMatchId(): String? =
        prefs.getString("last_incomplete_match_id", null)

    fun clearIncomplete(expectedMatchId: String? = null) {
        if (expectedMatchId != null && lastIncompleteMatchId() != expectedMatchId) return
        prefs.edit().remove("last_incomplete_match_id").commit()
    }

    fun saveAccountContext(context: WearAccountContext) {
        prefs.edit().putString(
            "account_context",
            JSONObject().apply {
                context.sourceUserId?.let { put("sourceUserId", it) }
                put("premiumEnabled", context.premiumEnabled)
                put("assistantEnabled", context.assistantEnabled)
                put("teamNames", org.json.JSONArray(context.teamNames.take(12)))
                put("defaultTeamName", context.defaultTeamName)
            }.toString(),
        ).commit()
    }

    fun loadAccountContext(): WearAccountContext = runCatching {
        val value = JSONObject(prefs.getString("account_context", "{}").orEmpty())
        val names = value.optJSONArray("teamNames")
        WearAccountContext(
            sourceUserId = value.optString("sourceUserId").takeIf { it.isNotBlank() },
            premiumEnabled = value.optBoolean("premiumEnabled", false),
            assistantEnabled = value.optBoolean("assistantEnabled", false),
            teamNames = if (names == null) emptyList() else {
                (0 until names.length()).mapNotNull { names.optString(it).takeIf(String::isNotBlank) }
            },
            defaultTeamName = value.optString("defaultTeamName"),
        )
    }.getOrDefault(WearAccountContext())

    fun saveProfileImage(path: String?, version: Int) {
        prefs.edit().apply {
            if (path.isNullOrBlank()) {
                remove("profile_image_path")
                remove("profile_image_version")
            } else {
                putString("profile_image_path", path)
                putInt("profile_image_version", version.coerceAtLeast(0))
            }
        }.commit()
    }

    fun loadProfileImagePath(): String? = prefs
        .getString("profile_image_path", null)
        ?.takeIf { java.io.File(it).isFile }

    /** Duo Mode: team assegnato a questo watch per la partita (o null). */
    fun saveDuoTeam(matchId: String, team: TeamId?) {
        prefs.edit().apply {
            if (team == null) remove("duo_team_$matchId")
            else putString("duo_team_$matchId", team.wire)
        }.commit()
    }

    fun loadDuoTeam(matchId: String): TeamId? =
        prefs.getString("duo_team_$matchId", null)?.let {
            try {
                TeamId.fromWire(it)
            } catch (_: Exception) {
                null
            }
        }

    fun markExternalWorkoutMatch(matchId: String, external: Boolean) {
        prefs.edit().apply {
            if (external) putBoolean("external_workout_$matchId", true)
            else remove("external_workout_$matchId")
        }.commit()
    }

    fun isExternalWorkoutMatch(matchId: String): Boolean =
        loadHealthRecordingMode(matchId) != WearHealthRecordingMode.RALLYMATE_MANAGED

    // --- Health recording ownership -------------------------------------

    /** Sticky preference for the next match, editable on every new match. */
    fun saveDefaultHealthRecordingMode(mode: WearHealthRecordingMode) {
        prefs.edit().putString("health_recording_mode_default", mode.wire).commit()
    }

    fun loadDefaultHealthRecordingMode(): WearHealthRecordingMode =
        WearHealthRecordingMode.fromWire(
            prefs.getString("health_recording_mode_default", null)
        )

    /** Owner frozen for one match; changing the default never moves it. */
    fun saveHealthRecordingMode(matchId: String, mode: WearHealthRecordingMode) {
        if (matchId.isBlank()) return
        prefs.edit().putString("health_recording_mode_$matchId", mode.wire).commit()
    }

    fun loadHealthRecordingMode(matchId: String): WearHealthRecordingMode {
        prefs.getString("health_recording_mode_$matchId", null)?.let {
            return WearHealthRecordingMode.fromWire(it)
        }
        // Legacy flag written before the three-way choice existed.
        return if (prefs.getBoolean("external_workout_$matchId", false)) {
            WearHealthRecordingMode.EXTERNAL_MANAGED
        } else {
            WearHealthRecordingMode.RALLYMATE_MANAGED
        }
    }

    fun saveWorkoutSegments(matchId: String, segments: List<WearWorkoutSegment>) {
        if (matchId.isBlank()) return
        prefs.edit()
            .putStringSet(
                "workout_segments_$matchId",
                segments.map { it.encode() }.toSet(),
            )
            .commit()
    }

    fun loadWorkoutSegments(matchId: String): List<WearWorkoutSegment> =
        prefs.getStringSet("workout_segments_$matchId", emptySet())
            .orEmpty()
            .mapNotNull(WearWorkoutSegment::decode)
            .sortedBy { it.startedAtMs }

    /** Match the foreground workout service is currently bound to. */
    fun setActiveWorkoutMatch(matchId: String) {
        prefs.edit().putString("active_workout_match", matchId).commit()
    }

    fun activeWorkoutMatch(): String =
        prefs.getString("active_workout_match", "").orEmpty()

    fun clearActiveWorkoutMatch() {
        prefs.edit().remove("active_workout_match").commit()
    }

    // --- Resumable matches (phone ⇄ watch snapshot) ----------------------

    fun saveResumableSnapshot(snapshot: WearResumableSnapshot) {
        prefs.edit().putString("resumable_snapshot", snapshot.toJson()).commit()
    }

    fun loadResumableSnapshot(): WearResumableSnapshot =
        prefs.getString("resumable_snapshot", null)
            ?.let(WearResumableSnapshot::fromJson)
            ?: WearResumableSnapshot.EMPTY

    fun mergeResumableSnapshot(incoming: WearResumableSnapshot): WearResumableSnapshot {
        val merged = loadResumableSnapshot().merging(incoming)
        saveResumableSnapshot(merged)
        return merged
    }

    fun applyLocalMatchUpdate(update: WearResumableMatch): WearResumableSnapshot {
        val merged = loadResumableSnapshot().applying(update)
        saveResumableSnapshot(merged)
        return merged
    }

    /** Monotonic per-match version used to reject stale updates. */
    fun stateVersion(matchId: String): Int =
        prefs.getInt("state_version_$matchId", 0)

    fun saveStateVersion(matchId: String, version: Int) {
        if (matchId.isBlank() || version <= stateVersion(matchId)) return
        prefs.edit().putInt("state_version_$matchId", version).commit()
    }

    /**
     * Idempotency guard: the Data Layer may redeliver the same payload.
     * @return true the first time a key is seen, false on redelivery.
     */
    fun markLifecycleApplied(key: String, limit: Int = 64): Boolean {
        if (key.isBlank()) return true
        val raw = prefs.getString("applied_lifecycle_keys", "").orEmpty()
        val seen = raw.split('\n').filter { it.isNotBlank() }
        if (key in seen) return false
        val next = (seen + key).takeLast(limit)
        prefs.edit().putString("applied_lifecycle_keys", next.joinToString("\n")).commit()
        return true
    }

    fun knownMatchIds(): List<String> =
        prefs.getStringSet("known_match_ids", emptySet()).orEmpty().toList()

    fun saveRecordingState(matchId: String, state: WearRecordingState) {
        if (matchId.isBlank()) return
        prefs.edit().putString("recording_state_$matchId", state.wire).commit()
    }

    fun loadRecordingState(matchId: String): WearRecordingState =
        WearRecordingState.fromWire(prefs.getString("recording_state_$matchId", null))

    fun saveTeamVisual(matchId: String, visual: TeamVisual) {
        prefs.edit().apply {
            putString("team_name_$matchId", visual.teamName)
            putString("team_style_$matchId", visual.style)
            putInt("team_image_version_$matchId", visual.imageVersion)
            putBoolean("team_image_expected_$matchId", visual.imageExpected)
            if (visual.imagePath.isNullOrBlank()) remove("team_image_path_$matchId")
            else putString("team_image_path_$matchId", visual.imagePath)
        }.commit()
    }

    fun loadTeamVisual(matchId: String): TeamVisual {
        val path = prefs.getString("team_image_path_$matchId", null)
            ?.takeIf { java.io.File(it).isFile }
        return TeamVisual(
            teamName = prefs.getString("team_name_$matchId", "").orEmpty(),
            style = prefs.getString("team_style_$matchId", "AUTO") ?: "AUTO",
            imageVersion = prefs.getInt("team_image_version_$matchId", 0),
            imageExpected = prefs.getBoolean("team_image_expected_$matchId", false),
            imagePath = path,
        )
    }

    fun loadFormat(matchId: String): MatchFormat? =
        prefs.getString("format_$matchId", null)
            ?.let {
                try {
                    MatchFormat.fromJson(JSONObject(it))
                } catch (_: Exception) {
                    null
                }
            }

    fun loadEvents(matchId: String): List<MatchEvent> =
        prefs.getString("events_$matchId", null)
            ?.let {
                try {
                    MatchEvent.listFromJson(it)
                } catch (_: Exception) {
                    emptyList()
                }
            } ?: emptyList()

    fun pendingSyncCount(matchId: String): Int =
        loadEvents(matchId).count { !it.synced }

    fun pendingMatchIds(): List<String> =
        prefs.getStringSet("known_match_ids", emptySet()).orEmpty()
            .filter { pendingSyncCount(it) > 0 && loadFormat(it) != null }
            .sorted()

    fun markSynced(matchId: String, eventIds: Set<String>) {
        if (eventIds.isEmpty()) return
        val updated = loadEvents(matchId).map {
            if (it.eventId in eventIds) it.copy(synced = true) else it
        }
        prefs.edit()
            .putString("events_$matchId", MatchEvent.listToJson(updated))
            .commit()
    }

    fun clearActive(expectedMatchId: String? = null) {
        if (expectedMatchId != null && activeMatchId() != expectedMatchId) return
        prefs.edit().remove("active_match_id").commit()
    }
}

class PhoneSync(private val context: Context) {

    private var cachedNodeId: String? = null
    private var cachedNodeAtMs = 0L
    private var discoveryBackoffMs = WearEnergyPolicy.INITIAL_DISCOVERY_BACKOFF_MS
    private var nextDiscoveryAtMs = 0L

    /**
     * Push dell'intero log al telefono. Il completamento del transport non è
     * un commit: restituisce esclusivamente gli id confermati dal telefono
     * dopo il merge Dart o il commit della sua coda persistente.
     */
    suspend fun pushEvents(
        matchId: String,
        format: MatchFormat,
        events: List<MatchEvent>,
    ): Set<String> {
        val expectedIds = events.map { it.eventId }.filter { it.isNotBlank() }.toSet()
        if (expectedIds.isEmpty()) return emptySet()
        val waiter = EventAckRegistry.register(matchId, expectedIds)
        val delivered = send(SyncPaths.EVENTS, JSONObject().apply {
            put("matchId", matchId)
            put("format", format.toJson().toString())
            put("events", MatchEvent.listToJson(events))
        })
        if (!delivered) {
            EventAckRegistry.cancel(waiter)
            return emptySet()
        }
        val acknowledged = withTimeoutOrNull(EVENT_ACK_TIMEOUT_MS) {
            waiter.result.await()
        }
        if (acknowledged == null) EventAckRegistry.cancel(waiter)
        return acknowledged.orEmpty()
    }

    /**
     * Chiede al telefono il log completo della partita; la risposta arriva
     * in modo asincrono su STATE_RESPONSE (gestita da PhoneListenerService).
     */
    suspend fun requestState(matchId: String): Boolean =
        send(SyncPaths.REQUEST_STATE, JSONObject().put("matchId", matchId))

    private suspend fun send(path: String, json: JSONObject): Boolean {
        val payload = json.toString().toByteArray()
        val now = SystemClock.elapsedRealtime()
        val cached = cachedNodeId?.takeIf {
            now - cachedNodeAtMs <= WearEnergyPolicy.NODE_CACHE_MS
        }
        if (cached != null && sendToNode(cached, path, payload)) return true
        cachedNodeId = null

        if (now < nextDiscoveryAtMs) return false
        val phone = runCatching {
            val nodes = Wearable.getNodeClient(context).connectedNodes.await()
            nodes.firstOrNull { it.isNearby } ?: nodes.firstOrNull()
        }.getOrNull()
        if (phone == null) {
            nextDiscoveryAtMs = now + discoveryBackoffMs
            discoveryBackoffMs = WearEnergyPolicy.nextDiscoveryBackoff(discoveryBackoffMs)
            return false
        }

        cachedNodeId = phone.id
        cachedNodeAtMs = now
        nextDiscoveryAtMs = 0L
        discoveryBackoffMs = WearEnergyPolicy.INITIAL_DISCOVERY_BACKOFF_MS
        return sendToNode(phone.id, path, payload)
    }

    private suspend fun sendToNode(nodeId: String, path: String, payload: ByteArray): Boolean =
        runCatching {
            Wearable.getMessageClient(context).sendMessage(nodeId, path, payload).await()
        }.isSuccess

    private companion object {
        const val EVENT_ACK_TIMEOUT_MS = 6_000L
    }
}
