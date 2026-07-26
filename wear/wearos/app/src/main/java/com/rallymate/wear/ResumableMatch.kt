package com.rallymate.wear

import org.json.JSONArray
import org.json.JSONObject

/** Lifecycle status shared with the phone, mirroring `MatchStatus` in rally_core. */
enum class WearMatchStatus(val wire: String) {
    CREATED("CREATED"),
    IN_PROGRESS("IN_PROGRESS"),
    PAUSED("PAUSED"),
    COMPLETED("COMPLETED"),
    ABANDONED("ABANDONED"),
    ;

    val isResumable: Boolean
        get() = this == IN_PROGRESS || this == PAUSED || this == CREATED

    val isTerminal: Boolean
        get() = this == COMPLETED || this == ABANDONED

    companion object {
        fun fromWire(value: String?): WearMatchStatus =
            entries.firstOrNull { it.wire == value } ?: IN_PROGRESS
    }
}

/**
 * One entry of the resumable-match snapshot published by the phone.
 * Carries only what the watch needs to show the match; the event journal is
 * delivered separately so a resume works with no connection.
 */
data class WearResumableMatch(
    val matchId: String,
    val status: WearMatchStatus,
    val stateVersion: Int = 0,
    val updatedAtMs: Long = 0,
    val pausedAtMs: Long? = null,
    val teamLabel: String = "",
    val scoreLine: String = "",
    val setsLabel: String = "",
    val gamesLabel: String = "",
    val format: MatchFormat = MatchFormat(),
    val sourceDevice: String = "PHONE",
    val eventCount: Int = 0,
    val journalAvailable: Boolean = false,
) {
    val scoreSummary: String
        get() = listOf(
            if (setsLabel.isBlank()) "" else "Set $setsLabel",
            if (gamesLabel.isBlank()) "" else "Game $gamesLabel",
            scoreLine,
        ).filter { it.isNotBlank() }.joinToString(" · ")

    fun toJson(): JSONObject = JSONObject()
        .put("matchId", matchId)
        .put("status", status.wire)
        .put("stateVersion", stateVersion)
        .put("updatedAtMs", updatedAtMs)
        .put("teamLabel", teamLabel)
        .put("scoreLine", scoreLine)
        .put("setsLabel", setsLabel)
        .put("gamesLabel", gamesLabel)
        .put("format", format.toJson())
        .put("sourceDevice", sourceDevice)
        .put("eventCount", eventCount)
        .put("journalAvailable", journalAvailable)
        .apply { pausedAtMs?.let { put("pausedAtMs", it) } }

    companion object {
        fun fromJson(json: JSONObject): WearResumableMatch? {
            val matchId = json.optString("matchId").takeIf { it.isNotBlank() }
                ?: return null
            val formatValue = json.opt("format")
            val format = when (formatValue) {
                is JSONObject -> MatchFormat.fromJson(formatValue)
                is String -> runCatching {
                    MatchFormat.fromJson(JSONObject(formatValue))
                }.getOrDefault(MatchFormat())
                else -> MatchFormat()
            }
            return WearResumableMatch(
                matchId = matchId,
                status = WearMatchStatus.fromWire(json.optString("status")),
                stateVersion = json.optInt("stateVersion", 0),
                updatedAtMs = json.optLong("updatedAtMs", 0),
                pausedAtMs = if (json.isNull("pausedAtMs")) {
                    null
                } else {
                    json.optLong("pausedAtMs").takeIf { it > 0 }
                },
                teamLabel = json.optString("teamLabel"),
                scoreLine = json.optString("scoreLine"),
                setsLabel = json.optString("setsLabel"),
                gamesLabel = json.optString("gamesLabel"),
                format = format,
                sourceDevice = json.optString("sourceDevice", "PHONE"),
                eventCount = json.optInt("eventCount", 0),
                journalAvailable = json.optBoolean("journalAvailable", false),
            )
        }

        fun listFromJson(json: String): List<WearResumableMatch> = runCatching {
            val array = JSONArray(json)
            (0 until array.length()).mapNotNull { index ->
                array.optJSONObject(index)?.let(::fromJson)
            }
        }.getOrDefault(emptyList())

        fun listToJson(items: List<WearResumableMatch>): String {
            val array = JSONArray()
            items.forEach { array.put(it.toJson()) }
            return array.toString()
        }
    }
}

/** Snapshot published through the "latest state" channel (a Data Item). */
data class WearResumableSnapshot(
    val stateVersion: Int = 0,
    val lastUpdatedAtMs: Long = 0,
    val activeMatchId: String? = null,
    val matches: List<WearResumableMatch> = emptyList(),
) {
    fun match(matchId: String): WearResumableMatch? =
        matches.firstOrNull { it.matchId == matchId }

    /** Entries the watch may offer for resume, most recent first. */
    val resumable: List<WearResumableMatch>
        get() = matches.filter { it.status.isResumable }
            .sortedByDescending { it.updatedAtMs }

    /**
     * Deterministic merge, identical to the watchOS rules:
     * a terminal status always wins; otherwise the higher `stateVersion`;
     * equal versions keep the most recently updated entry.
     */
    fun merging(incoming: WearResumableSnapshot): WearResumableSnapshot {
        val byId = matches.associateBy { it.matchId }.toMutableMap()
        for (candidate in incoming.matches) {
            val existing = byId[candidate.matchId]
            byId[candidate.matchId] = if (existing == null) {
                candidate
            } else {
                winner(existing, candidate)
            }
        }
        val newerIncoming = incoming.stateVersion >= stateVersion
        return WearResumableSnapshot(
            stateVersion = maxOf(stateVersion, incoming.stateVersion),
            lastUpdatedAtMs = maxOf(lastUpdatedAtMs, incoming.lastUpdatedAtMs),
            activeMatchId = if (newerIncoming) incoming.activeMatchId else activeMatchId,
            matches = byId.values.sortedByDescending { it.updatedAtMs },
        )
    }

    fun applying(update: WearResumableMatch): WearResumableSnapshot = merging(
        WearResumableSnapshot(
            stateVersion = stateVersion,
            lastUpdatedAtMs = update.updatedAtMs,
            activeMatchId = activeMatchId,
            matches = listOf(update),
        )
    )

    fun toJson(): String = JSONObject()
        .put("stateVersion", stateVersion)
        .put("lastUpdatedAtMs", lastUpdatedAtMs)
        .put("matches", JSONArray(WearResumableMatch.listToJson(matches)))
        .apply { activeMatchId?.let { put("activeMatchId", it) } }
        .toString()

    companion object {
        val EMPTY = WearResumableSnapshot()

        fun winner(
            existing: WearResumableMatch,
            incoming: WearResumableMatch,
        ): WearResumableMatch {
            if (existing.status.isTerminal && !incoming.status.isTerminal) return existing
            if (incoming.status.isTerminal && !existing.status.isTerminal) return incoming
            if (incoming.stateVersion > existing.stateVersion) return incoming
            if (incoming.stateVersion < existing.stateVersion) return existing
            return if (incoming.updatedAtMs >= existing.updatedAtMs) incoming else existing
        }

        fun fromJson(json: String): WearResumableSnapshot = runCatching {
            val root = JSONObject(json)
            WearResumableSnapshot(
                stateVersion = root.optInt("stateVersion", 0),
                lastUpdatedAtMs = root.optLong("lastUpdatedAtMs", 0),
                activeMatchId = root.optString("activeMatchId")
                    .takeIf { it.isNotBlank() },
                matches = WearResumableMatch.listFromJson(
                    root.optJSONArray("matches")?.toString() ?: "[]"
                ),
            )
        }.getOrDefault(EMPTY)

        /** Decodes the wire payload sent by the phone. */
        fun fromPayload(json: JSONObject): WearResumableSnapshot =
            WearResumableSnapshot(
                stateVersion = json.optInt("stateVersion", 0),
                lastUpdatedAtMs = json.optLong("lastUpdatedAtMs", 0),
                activeMatchId = json.optString("activeMatchId")
                    .takeIf { it.isNotBlank() },
                matches = WearResumableMatch.listFromJson(
                    json.optString("matches", "[]")
                ),
            )
    }
}

/** Durable lifecycle change delivered by the phone. */
data class WearMatchLifecycle(
    val matchId: String,
    val action: String,
    val status: WearMatchStatus,
    val stateVersion: Int,
    val idempotencyKey: String,
    val timestampMs: Long,
    val format: MatchFormat?,
    val events: List<MatchEvent>,
) {
    companion object {
        fun fromPayload(json: JSONObject): WearMatchLifecycle? {
            val matchId = json.optString("matchId").takeIf { it.isNotBlank() }
                ?: return null
            val action = json.optString("action").uppercase()
            val statusWire = json.optString("status").takeIf { it.isNotBlank() }
                ?: when (action) {
                    "PAUSED" -> WearMatchStatus.PAUSED.wire
                    "COMPLETED" -> WearMatchStatus.COMPLETED.wire
                    "ABANDONED" -> WearMatchStatus.ABANDONED.wire
                    else -> WearMatchStatus.IN_PROGRESS.wire
                }
            val stateVersion = json.optInt("stateVersion", 0)
            return WearMatchLifecycle(
                matchId = matchId,
                action = action,
                status = WearMatchStatus.fromWire(statusWire),
                stateVersion = stateVersion,
                // A missing key must not disable dedup: derive a stable one.
                idempotencyKey = json.optString("idempotencyKey")
                    .takeIf { it.isNotBlank() }
                    ?: "$matchId#$action#$stateVersion",
                timestampMs = json.optLong("ts", 0),
                format = json.optString("format").takeIf { it.isNotBlank() }
                    ?.let { runCatching { MatchFormat.fromJson(JSONObject(it)) }.getOrNull() },
                events = json.optString("events").takeIf { it.isNotBlank() }
                    ?.let { MatchEvent.listFromJson(it) }
                    .orEmpty(),
            )
        }
    }
}
