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

enum class WearSnapshotAuthorityScope(val wire: String) {
    NON_STAR_POINT("NON_STAR_POINT"),
    STAR_POINT("STAR_POINT"),
    ;

    fun owns(match: WearResumableMatch): Boolean =
        (match.format.gameScoringMode == GameScoringMode.STAR_POINT) ==
            (this == STAR_POINT)

    companion object {
        fun fromWire(value: String?): WearSnapshotAuthorityScope? =
            entries.firstOrNull { it.wire == value }
    }
}

/** Snapshot published through the "latest state" channel (a Data Item). */
data class WearResumableSnapshot(
    val stateVersion: Int = 0,
    val lastUpdatedAtMs: Long = 0,
    val activeMatchId: String? = null,
    val matches: List<WearResumableMatch> = emptyList(),
    val authoritative: Boolean = false,
    val authoritySource: String? = null,
    val authorityScope: String? = null,
    val authorityVersion: Long = 0,
    val authorityVersions: Map<String, Long> = emptyMap(),
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
    fun merging(
        incoming: WearResumableSnapshot,
        protectedMatchIds: Set<String> = emptySet(),
    ): WearResumableSnapshot {
        val declaresAuthority =
            incoming.authoritative ||
                incoming.authoritySource != null ||
                incoming.authorityScope != null ||
                incoming.authorityVersion > 0
        val incomingScope = WearSnapshotAuthorityScope.fromWire(
            incoming.authorityScope,
        ).takeIf {
            incoming.authoritative &&
                incoming.authoritySource == "PHONE" &&
                incoming.authorityVersion > 0
        }
        // Partial or unknown authority metadata must not silently fall back to
        // legacy additive merge semantics.
        if (declaresAuthority && incomingScope == null) return this
        val knownAuthorityVersions = authorityVersions.toMutableMap()
        val knownGlobalVersion = authorityVersions.values.maxOrNull() ?: 0L
        if (incomingScope != null) {
            val knownVersion = knownAuthorityVersions[incomingScope.wire] ?: 0L
            // A delayed Data Item must never resurrect a match removed by a
            // newer authoritative clear.
            if (incoming.authorityVersion < knownVersion) return this
        }

        val byId = matches.associateBy { it.matchId }.toMutableMap()
        if (incomingScope != null) {
            val incomingIds = incoming.matches
                .filter(incomingScope::owns)
                .mapTo(mutableSetOf()) { it.matchId }
            byId.entries.removeAll { (matchId, match) ->
                match.sourceDevice == "PHONE" &&
                    incomingScope.owns(match) &&
                    matchId !in incomingIds &&
                    matchId !in protectedMatchIds
            }
            knownAuthorityVersions[incomingScope.wire] = incoming.authorityVersion
        }
        val incomingCandidates = if (incomingScope == null) {
            incoming.matches
        } else {
            // The v2 wire payload intentionally contains the full list, but
            // its STAR_POINT authority owns only Star Point rows. The legacy
            // slot independently owns every other scoring mode.
            incoming.matches.filter(incomingScope::owns)
        }
        for (candidate in incomingCandidates) {
            val existing = byId[candidate.matchId]
            byId[candidate.matchId] = if (existing == null) {
                candidate
            } else {
                winner(existing, candidate)
            }
        }
        val newerIncoming = incoming.stateVersion >= stateVersion
        val mergedActiveMatchId = if (incomingScope == null) {
            if (newerIncoming) incoming.activeMatchId else activeMatchId
        } else {
            val incomingActive = incoming.activeMatchId?.takeIf { activeId ->
                incoming.matches.any {
                    it.matchId == activeId && incomingScope.owns(it)
                }
            }
            val currentActive = activeMatchId
            val currentActiveOwned = currentActive != null &&
                matches.any {
                    it.matchId == currentActive && incomingScope.owns(it)
                }
            when {
                incomingActive != null &&
                    incoming.authorityVersion >= knownGlobalVersion -> incomingActive
                currentActiveOwned && currentActive !in protectedMatchIds -> null
                currentActive != null && byId.containsKey(currentActive) -> currentActive
                else -> null
            }
        }
        return WearResumableSnapshot(
            stateVersion = maxOf(stateVersion, incoming.stateVersion),
            lastUpdatedAtMs = maxOf(lastUpdatedAtMs, incoming.lastUpdatedAtMs),
            activeMatchId = mergedActiveMatchId,
            matches = byId.values.sortedByDescending { it.updatedAtMs },
            authoritative = incoming.authoritative,
            authoritySource = incoming.authoritySource,
            authorityScope = incoming.authorityScope,
            authorityVersion = incoming.authorityVersion,
            authorityVersions = knownAuthorityVersions,
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

    /**
     * Records a lifecycle generation without applying snapshot absence rules.
     * Returns null when a delayed lifecycle is older than the authoritative
     * snapshot already accepted for the same scoring scope.
     */
    fun acceptingLifecycleAuthority(
        source: String?,
        scope: WearSnapshotAuthorityScope?,
        version: Long,
    ): WearResumableSnapshot? {
        if (scope == null) {
            return takeIf { source == null && version <= 0 }
        }
        val known = authorityVersions[scope.wire] ?: 0L
        if (source == null && version <= 0) return takeIf { known == 0L }
        if (source != "PHONE" || version <= 0 || version < known) return null
        if (version == known) return this
        return copy(
            authorityVersions = authorityVersions + (scope.wire to version),
        )
    }

    fun toJson(): String = JSONObject()
        .put("stateVersion", stateVersion)
        .put("lastUpdatedAtMs", lastUpdatedAtMs)
        .put("matches", JSONArray(WearResumableMatch.listToJson(matches)))
        .apply {
            activeMatchId?.let { put("activeMatchId", it) }
            if (authoritative) put("authoritative", true)
            authoritySource?.let { put("authoritySource", it) }
            authorityScope?.let { put("authorityScope", it) }
            if (authorityVersion > 0) put("authorityVersion", authorityVersion)
            if (authorityVersions.isNotEmpty()) {
                put(
                    "authorityVersions",
                    JSONObject().apply {
                        authorityVersions.forEach { (scope, version) ->
                            put(scope, version)
                        }
                    },
                )
            }
        }
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
                authoritative = root.optBoolean("authoritative", false),
                authoritySource = root.optString("authoritySource")
                    .takeIf { it.isNotBlank() },
                authorityScope = root.optString("authorityScope")
                    .takeIf { it.isNotBlank() },
                authorityVersion = root.optLong("authorityVersion", 0),
                authorityVersions = authorityVersionsFrom(root),
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
                authoritative = json.optBoolean("authoritative", false),
                authoritySource = json.optString("authoritySource")
                    .takeIf { it.isNotBlank() },
                authorityScope = json.optString("authorityScope")
                    .takeIf { it.isNotBlank() },
                authorityVersion = json.optLong("authorityVersion", 0),
            )

        private fun authorityVersionsFrom(root: JSONObject): Map<String, Long> {
            val json = root.optJSONObject("authorityVersions") ?: return emptyMap()
            return buildMap {
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val value = json.optLong(key, 0)
                    if (value > 0) put(key, value)
                }
            }
        }
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
    val authoritySource: String? = null,
    val authorityScope: String? = null,
    val authorityVersion: Long = 0,
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
                authoritySource = json.optString("authoritySource")
                    .takeIf { it.isNotBlank() },
                authorityScope = json.optString("authorityScope")
                    .takeIf { it.isNotBlank() },
                authorityVersion = json.optLong("authorityVersion", 0),
            )
        }
    }
}
