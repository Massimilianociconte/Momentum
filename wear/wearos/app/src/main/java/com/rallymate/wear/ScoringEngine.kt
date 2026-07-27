/**
 * Kotlin port of the rally_core padel scoring engine.
 *
 * MUST stay semantically identical to packages/rally_core (Dart) and the
 * Swift port (watchOS). The JSON wire format is the sync contract:
 * see rally_core/lib/src/model/match_event.dart.
 */
package com.rallymate.wear

import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

enum class TeamId(val wire: String) {
    A("TEAM_A"), B("TEAM_B");

    val opponent: TeamId get() = if (this == A) B else A

    companion object {
        fun fromWire(w: String) = entries.first { it.wire == w }
    }
}

enum class EventType(val wire: String) {
    MATCH_STARTED("MATCH_STARTED"),
    POINT_TEAM_A("POINT_TEAM_A"),
    POINT_TEAM_B("POINT_TEAM_B"),
    UNDO("UNDO"),
    GAME_COMPLETED("GAME_COMPLETED"),
    SET_COMPLETED("SET_COMPLETED"),
    SIDE_CHANGE("SIDE_CHANGE"),
    MATCH_PAUSED("MATCH_PAUSED"),
    MATCH_RESUMED("MATCH_RESUMED"),
    MATCH_COMPLETED("MATCH_COMPLETED"),
    SCORE_EDITED("SCORE_EDITED"),

    // Duo Mode session lifecycle (audit-only on replay).
    DEVICE_JOINED_MATCH("DEVICE_JOINED_MATCH"),
    DEVICE_LEFT_MATCH("DEVICE_LEFT_MATCH"),
    TEAM_CONFIRMED("TEAM_CONFIRMED");

    companion object {
        fun fromWire(w: String) = entries.first { it.wire == w }

        /** Tolerant variant: unknown future event types are skipped, not fatal. */
        fun fromWireOrNull(w: String) = entries.firstOrNull { it.wire == w }
    }
}

/**
 * Game rule used at 40-40.
 *
 * The wire value is deliberately explicit: two booleans (`goldenPoint` and
 * `starPoint`) could describe impossible combinations and make offline replay
 * diverge across app versions.
 */
enum class GameScoringMode(val wire: String) {
    ADVANTAGE("ADVANTAGE"),
    STAR_POINT("STAR_POINT"),
    GOLDEN_POINT("GOLDEN_POINT");

    companion object {
        fun fromWireOrNull(value: String?): GameScoringMode? =
            entries.firstOrNull { it.wire == value }

        fun fromLegacyGoldenPoint(goldenPoint: Boolean): GameScoringMode =
            if (goldenPoint) GOLDEN_POINT else ADVANTAGE
    }
}

data class MatchFormat(
    val id: String = "GOLDEN_BO3",
    val name: String = "Golden point — meglio di 3",
    val formatSchemaVersion: Int = CURRENT_SCHEMA_VERSION,
    val setsToWin: Int = 2,
    val gamesPerSet: Int = 6,
    val gameScoringMode: GameScoringMode = GameScoringMode.GOLDEN_POINT,
    val tieBreakAtGamesAll: Boolean = true,
    val tieBreakPoints: Int = 7,
    /**
     * FIP Rule 1, Option 1.4: when false the deciding set is played to two
     * games of margin instead of a tie-break.
     */
    val tieBreakInDecidingSet: Boolean = true,
    val superTieBreakDecider: Boolean = false,
    val superTieBreakPoints: Int = 10,
    val freePlay: Boolean = false,
) {
    /** Legacy source compatibility while callers migrate to [gameScoringMode]. */
    val goldenPoint: Boolean
        get() = gameScoringMode == GameScoringMode.GOLDEN_POINT

    fun toJson(): JSONObject = JSONObject().apply {
        put("formatSchemaVersion", CURRENT_SCHEMA_VERSION)
        put("id", id); put("name", name)
        put("setsToWin", setsToWin); put("gamesPerSet", gamesPerSet)
        put("gameScoringMode", gameScoringMode.wire)
        // Kept during the v1 → v2 rollout for old phone/watch readers.
        put("goldenPoint", goldenPoint)
        put("tieBreakAtGamesAll", tieBreakAtGamesAll)
        put("tieBreakPoints", tieBreakPoints)
        put("tieBreakInDecidingSet", tieBreakInDecidingSet)
        put("superTieBreakDecider", superTieBreakDecider)
        put("superTieBreakPoints", superTieBreakPoints)
        put("freePlay", freePlay)
    }

    companion object {
        /** v3 adds [MatchFormat.tieBreakInDecidingSet]. */
        const val CURRENT_SCHEMA_VERSION = 3

        fun fromJson(j: JSONObject): MatchFormat {
            val gameScoringMode = GameScoringMode.fromWireOrNull(
                j.optString("gameScoringMode").takeIf { it.isNotBlank() },
            ) ?: GameScoringMode.fromWireOrNull(
                // Temporary compatibility with pre-canonical schema-v2 builds.
                j.optString("mode").takeIf { it.isNotBlank() },
            ) ?: if (j.has("goldenPoint")) {
                GameScoringMode.fromLegacyGoldenPoint(
                    j.optBoolean("goldenPoint", true),
                )
            } else {
                // Preserve the historical default when both v1 and v2 fields
                // are absent. Known ids make recovery deterministic.
                when (j.optString("id")) {
                    "ADV_BO3" -> GameScoringMode.ADVANTAGE
                    "STAR_POINT_BO3" -> GameScoringMode.STAR_POINT
                    else -> GameScoringMode.GOLDEN_POINT
                }
            }
            return MatchFormat(
                id = j.optString("id", "GOLDEN_BO3"),
                name = j.optString("name", "Custom"),
                // Decoded formats are normalized before persistence/re-emission.
                formatSchemaVersion = CURRENT_SCHEMA_VERSION,
                setsToWin = j.optInt("setsToWin", 2),
                gamesPerSet = j.optInt("gamesPerSet", 6),
                gameScoringMode = gameScoringMode,
                tieBreakAtGamesAll = j.optBoolean("tieBreakAtGamesAll", true),
                tieBreakPoints = j.optInt("tieBreakPoints", 7),
                // Absent in v1/v2 payloads: those always had a deciding tie-break.
                tieBreakInDecidingSet = j.optBoolean("tieBreakInDecidingSet", true),
                superTieBreakDecider = j.optBoolean("superTieBreakDecider", false),
                superTieBreakPoints = j.optInt("superTieBreakPoints", 10),
                freePlay = j.optBoolean("freePlay", false),
            )
        }

        val GOLDEN_BO3 = MatchFormat()
        val STAR_POINT_BO3 = MatchFormat(
            id = "STAR_POINT_BO3",
            name = "Star Point FIP 2026 — meglio di 3",
            gameScoringMode = GameScoringMode.STAR_POINT,
        )
        val ADVANTAGE_BO3 = MatchFormat(
            id = "ADV_BO3",
            name = "Vantaggi - meglio di 3",
            gameScoringMode = GameScoringMode.ADVANTAGE,
        )
        val SUPER_TIE_BREAK = MatchFormat(
            id = "SUPER_TB_BO3",
            name = "Super tie-break al terzo",
            superTieBreakDecider = true,
        )
        val MATCH_TB7_BO3 = MatchFormat(
            id = "MATCH_TB7_BO3",
            name = "Tie-break decisivo a 7",
            superTieBreakDecider = true,
            superTieBreakPoints = 7,
        )
        val MINI_SET_BO3 = MatchFormat(
            id = "MINI_SET_BO3",
            name = "Mini-set a 4 game",
            gamesPerSet = 4,
        )
        val ADV_NO_TB_THIRD_BO3 = MatchFormat(
            id = "ADV_NO_TB_THIRD_BO3",
            name = "Terzo set senza tie-break",
            gameScoringMode = GameScoringMode.ADVANTAGE,
            tieBreakInDecidingSet = false,
        )
        val SINGLE_SET = MatchFormat(
            id = "SINGLE_SET",
            name = "Partita secca - 1 set",
            setsToWin = 1,
        )
        val TRAINING = MatchFormat(
            id = "TRAINING",
            name = "Allenamento libero",
            setsToWin = 1,
            freePlay = true,
        )
        val PRESETS = listOf(
            GOLDEN_BO3,
            STAR_POINT_BO3,
            ADVANTAGE_BO3,
            SUPER_TIE_BREAK,
            MATCH_TB7_BO3,
            MINI_SET_BO3,
            // ADV_NO_TB_THIRD_BO3 is deliberately absent: a watch-authored
            // match travels to the phone without a capability handshake, and a
            // phone on the previous build would replay the deciding set with a
            // tie-break. The format is selectable on the phone, which gates the
            // dispatch on `deciding_set_no_tiebreak_v1`.
            SINGLE_SET,
            TRAINING,
        )
    }
}

data class MatchEvent(
    val eventId: String,
    val matchId: String,
    val timestampMs: Long,
    val type: EventType,
    val teamId: TeamId? = null,
    val scoreBefore: String? = null,
    val scoreAfter: String? = null,
    val sourceDevice: String = "WEAR_OS",
    val sourceMethod: String = "TAP",
    val synced: Boolean = false,
    val payload: JSONObject? = null,
    val sourceUserId: String? = null,
    val sourceTeamId: TeamId? = null,
    val duoMode: Boolean = false,
    val createdLocallyAtMs: Long? = null,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("eventId", eventId)
        put("matchId", matchId)
        put("ts", timestampMs)
        put("type", type.wire)
        teamId?.let { put("teamId", it.wire) }
        scoreBefore?.let { put("scoreBefore", it) }
        scoreAfter?.let { put("scoreAfter", it) }
        put("sourceDevice", sourceDevice)
        put("sourceMethod", sourceMethod)
        put("synced", synced)
        payload?.let { put("payload", it) }
        sourceUserId?.let { put("sourceUserId", it) }
        sourceTeamId?.let { put("sourceTeamId", it.wire) }
        if (duoMode) put("duo", true)
        createdLocallyAtMs?.let { put("createdLocallyAt", it) }
    }

    companion object {
        fun fromJson(j: JSONObject): MatchEvent? {
            val type = EventType.fromWireOrNull(j.getString("type")) ?: return null
            return MatchEvent(
                eventId = j.getString("eventId"),
                matchId = j.getString("matchId"),
                timestampMs = j.getLong("ts"),
                type = type,
                teamId = if (j.has("teamId")) TeamId.fromWire(j.getString("teamId")) else null,
                scoreBefore = j.optNullableString("scoreBefore"),
                scoreAfter = j.optNullableString("scoreAfter"),
                sourceDevice = j.optString("sourceDevice", "WEAR_OS"),
                sourceMethod = j.optString("sourceMethod", "TAP"),
                synced = j.optBoolean("synced", false),
                payload = j.optJSONObject("payload"),
                sourceUserId = j.optNullableString("sourceUserId"),
                sourceTeamId = j.optNullableString("sourceTeamId")
                    ?.let { runCatching { TeamId.fromWire(it) }.getOrNull() },
                duoMode = j.optBoolean("duo", false),
                createdLocallyAtMs = if (j.has("createdLocallyAt")) {
                    j.optLong("createdLocallyAt")
                } else {
                    null
                },
            )
        }

        fun listToJson(events: List<MatchEvent>): String {
            val arr = JSONArray()
            events.forEach { arr.put(it.toJson()) }
            return arr.toString()
        }

        fun listFromJson(json: String): List<MatchEvent> {
            val arr = JSONArray(json)
            return (0 until arr.length()).mapNotNull { fromJson(arr.getJSONObject(it)) }
        }
    }
}

private fun JSONObject.optNullableString(name: String): String? =
    if (has(name) && !isNull(name)) getString(name) else null

data class SetResult(
    val gamesA: Int,
    val gamesB: Int,
    val tieBreakA: Int? = null,
    val tieBreakB: Int? = null,
    val isSuperTieBreak: Boolean = false,
)

enum class Transition { POINT, GAME_WON, SET_WON, MATCH_WON, SIDE_CHANGE, UNDONE }

data class MatchState(
    val completed: Boolean,
    val paused: Boolean,
    val scoringMode: GameScoringMode,
    val pointsA: Int,
    val pointsB: Int,
    val advantage: TeamId?,
    /** 0 before deuce; 1/2 are the two advantage cycles; 3 is Star Point. */
    val deuceNumber: Int,
    val gamesA: Int,
    val gamesB: Int,
    val setsA: Int,
    val setsB: Int,
    val completedSets: List<SetResult>,
    val servingTeam: TeamId,
    val inTieBreak: Boolean,
    val inSuperTieBreak: Boolean,
    val tieBreakA: Int,
    val tieBreakB: Int,
    val freePlayA: Int,
    val freePlayB: Int,
    val sideChangePending: Boolean,
    val winner: TeamId?,
) {
    val starPointActive: Boolean
        get() = scoringMode == GameScoringMode.STAR_POINT &&
            deuceNumber == 3 &&
            advantage == null &&
            pointsA >= 3 &&
            pointsB >= 3 &&
            !inTieBreak &&
            !inSuperTieBreak

    fun pointsLabel(team: TeamId): String {
        val labels = arrayOf("0", "15", "30", "40")
        if (advantage != null) return if (advantage == team) "AD" else "40"
        val v = if (team == TeamId.A) pointsA else pointsB
        return labels[v.coerceIn(0, 3)]
    }

    fun pointSituation(
        teamALabel: String = "NOI",
        teamBLabel: String = "LORO",
    ): String? {
        if (inTieBreak || inSuperTieBreak) return null
        advantage?.let {
            val label = if (it == TeamId.A) teamALabel else teamBLabel
            return if (scoringMode == GameScoringMode.STAR_POINT) {
                "AD ${deuceNumber.coerceIn(1, 2)} · VANTAGGIO $label"
            } else {
                "VANTAGGIO $label · GAME POINT"
            }
        }
        if (pointsA < 3 || pointsB < 3) return null
        return when (scoringMode) {
            GameScoringMode.GOLDEN_POINT -> "40 PARI · PUNTO DECISIVO"
            GameScoringMode.ADVANTAGE -> "40 PARI · VANTAGGI"
            GameScoringMode.STAR_POINT -> when (deuceNumber.coerceIn(1, 3)) {
                1 -> "DEUCE 1 · VANTAGGI"
                2 -> "DEUCE 2 · VANTAGGI"
                else -> "STAR POINT"
            }
        }
    }

    fun pointSituationHint(): String? =
        if (starPointActive) "La coppia in risposta sceglie il lato" else null

    fun pointSituationAccessibility(
        teamALabel: String = "NOI",
        teamBLabel: String = "LORO",
    ): String? {
        if (starPointActive) {
            return "Star Point. Punto decisivo. La coppia in risposta sceglie il lato."
        }
        val situation = pointSituation(teamALabel, teamBLabel) ?: return null
        return if (
            scoringMode == GameScoringMode.STAR_POINT &&
            advantage != null
        ) {
            "$situation. Ciclo ${deuceNumber.coerceIn(1, 2)} di 2."
        } else {
            situation
        }
    }
}

class ScoringEngine(
    private val matchId: String,
    private val format: MatchFormat,
    private val firstServer: TeamId = TeamId.A,
    private val sourceUserId: String? = null,
    private val assignedTeam: TeamId? = null,
    private val duoMode: Boolean = false,
    private val clock: () -> Long = { System.currentTimeMillis() },
    private val idGen: () -> String = { UUID.randomUUID().toString() },
) {
    private val events = mutableListOf<MatchEvent>()
    var state: MatchState = replay().first
        private set

    val allEvents: List<MatchEvent> get() = events.toList()

    val canUndo: Boolean
        get() {
            val resolution = resolveUndos()
            events.forEachIndexed { i, event ->
                if (i in resolution.cancelled || i in resolution.ignored) {
                    return@forEachIndexed
                }
                when (event.type) {
                    EventType.POINT_TEAM_A,
                    EventType.POINT_TEAM_B,
                    EventType.SCORE_EDITED,
                    -> return true
                    else -> {}
                }
            }
            return false
        }

    /** Duo Mode: whether a team-scoped undo would cancel anything. */
    fun canUndoTeam(team: TeamId): Boolean {
        val resolution = resolveUndos()
        val wanted = if (team == TeamId.A) EventType.POINT_TEAM_A else EventType.POINT_TEAM_B
        for (i in events.indices.reversed()) {
            if (i in resolution.cancelled || i in resolution.ignored) continue
            if (events[i].type == wanted) return true
        }
        return false
    }

    fun loadEvents(persisted: List<MatchEvent>) {
        events.clear()
        events.addAll(persisted)
        state = replay().first
    }

    fun start(): List<MatchEvent> {
        if (events.any { it.type == EventType.MATCH_STARTED }) return emptyList()
        val e = make(EventType.MATCH_STARTED)
        events.add(e)
        state = replay().first
        return listOf(e)
    }

    /** Returns (new events, transitions). */
    fun addPoint(team: TeamId, method: String = "TAP"): Pair<List<MatchEvent>, List<Transition>> {
        if (state.completed || state.paused) return emptyList<MatchEvent>() to emptyList()
        val point = make(
            if (team == TeamId.A) EventType.POINT_TEAM_A else EventType.POINT_TEAM_B,
            teamId = team,
            method = method,
        )
        events.add(point)
        val (newState, transitions) = replay()
        state = newState

        val derived = mutableListOf<MatchEvent>()
        fun derive(t: EventType) {
            val d = make(t, teamId = team, method = "AUTO")
            derived.add(d); events.add(d)
        }
        if (Transition.GAME_WON in transitions) derive(EventType.GAME_COMPLETED)
        if (Transition.SET_WON in transitions) derive(EventType.SET_COMPLETED)
        if (Transition.SIDE_CHANGE in transitions) derive(EventType.SIDE_CHANGE)
        if (Transition.MATCH_WON in transitions) derive(EventType.MATCH_COMPLETED)
        return (listOf(point) + derived) to transitions
    }

    /**
     * [team] (Duo Mode): l'UNDO annulla solo l'ultimo punto di quel team,
     * così i log dei due device convergono anche se interlacciati in ordini
     * diversi. Senza [team]: undo globale classico.
     */
    fun undo(team: TeamId? = null): Pair<List<MatchEvent>, List<Transition>> {
        if (state.paused) return emptyList<MatchEvent>() to emptyList()
        if (if (team == null) !canUndo else !canUndoTeam(team)) {
            return emptyList<MatchEvent>() to emptyList()
        }
        val e = make(EventType.UNDO, teamId = team)
        events.add(e)
        state = replay().first
        return listOf(e) to listOf(Transition.UNDONE)
    }

    fun pause(): List<MatchEvent> {
        if (state.completed || state.paused) return emptyList()
        val event = make(EventType.MATCH_PAUSED)
        events.add(event)
        state = replay().first
        return listOf(event)
    }

    fun resume(): List<MatchEvent> {
        if (state.completed || !state.paused) return emptyList()
        val event = make(EventType.MATCH_RESUMED)
        events.add(event)
        state = replay().first
        return listOf(event)
    }

    fun finish(winner: TeamId? = null): List<MatchEvent> {
        if (state.completed) return emptyList()
        val event = make(
            EventType.MATCH_COMPLETED,
            teamId = winner,
            method = "MANUAL_EDIT",
        )
        events.add(event)
        state = replay().first
        return listOf(event)
    }

    private fun make(
        type: EventType,
        teamId: TeamId? = null,
        method: String = "TAP",
    ): MatchEvent {
        val now = clock()
        return MatchEvent(
            eventId = idGen(),
            matchId = matchId,
            timestampMs = now,
            type = type,
            teamId = teamId,
            sourceMethod = method,
            sourceUserId = sourceUserId,
            sourceTeamId = assignedTeam,
            duoMode = duoMode,
            createdLocallyAtMs = if (duoMode) now else null,
        )
    }

    // ------------------------------------------------------------- replay

    private enum class ReplayLifecycle { CREATED, IN_PROGRESS, PAUSED, COMPLETED }

    private data class UndoResolution(
        val cancelled: Set<Int>,
        val ignored: Set<Int>,
    )

    /**
     * Pass 1 of replay resolves UNDOs and lifecycle-invalid events. An UNDO
     * carrying a teamId cancels only the most recent active point of that team.
     */
    private fun resolveUndos(): UndoResolution {
        val cancelled = mutableSetOf<Int>()
        val ignored = mutableSetOf<Int>()
        val stack = ArrayDeque<Int>()
        var lifecycle = ReplayLifecycle.CREATED
        var manuallyCompleted = false
        events.forEachIndexed { i, e ->
            when (e.type) {
                EventType.MATCH_STARTED -> if (lifecycle == ReplayLifecycle.CREATED) {
                    lifecycle = ReplayLifecycle.IN_PROGRESS
                }
                EventType.MATCH_PAUSED -> if (lifecycle == ReplayLifecycle.IN_PROGRESS) {
                    lifecycle = ReplayLifecycle.PAUSED
                }
                EventType.MATCH_RESUMED -> if (lifecycle == ReplayLifecycle.PAUSED) {
                    lifecycle = ReplayLifecycle.IN_PROGRESS
                }
                EventType.POINT_TEAM_A, EventType.POINT_TEAM_B -> {
                    if (lifecycle == ReplayLifecycle.PAUSED ||
                        lifecycle == ReplayLifecycle.COMPLETED
                    ) {
                        ignored.add(i)
                        return@forEachIndexed
                    }
                    if (lifecycle == ReplayLifecycle.CREATED) {
                        lifecycle = ReplayLifecycle.IN_PROGRESS
                    }
                    stack.addLast(i)
                }
                EventType.SCORE_EDITED -> {
                    if (lifecycle == ReplayLifecycle.PAUSED ||
                        lifecycle == ReplayLifecycle.COMPLETED
                    ) {
                        ignored.add(i)
                        return@forEachIndexed
                    }
                    stack.addLast(i)
                }
                EventType.MATCH_COMPLETED -> {
                    lifecycle = ReplayLifecycle.COMPLETED
                    if (e.sourceMethod == "MANUAL_EDIT") manuallyCompleted = true
                }
                EventType.UNDO -> {
                    if (lifecycle == ReplayLifecycle.PAUSED) {
                        ignored.add(i)
                        return@forEachIndexed
                    }
                    val team = e.teamId
                    var didCancel = false
                    if (team == null) {
                        if (stack.isNotEmpty()) {
                            cancelled.add(stack.removeLast())
                            didCancel = true
                        }
                    } else {
                        val wanted = if (team == TeamId.A) {
                            EventType.POINT_TEAM_A
                        } else {
                            EventType.POINT_TEAM_B
                        }
                        val idx = stack.indexOfLast { events[it].type == wanted }
                        if (idx >= 0) {
                            cancelled.add(stack[idx])
                            stack.removeAt(idx)
                            didCancel = true
                        }
                    }
                    // Undoing the point which produced an automatic completion
                    // reopens the match. Explicit manual completion remains final.
                    if (didCancel &&
                        lifecycle == ReplayLifecycle.COMPLETED &&
                        !manuallyCompleted
                    ) {
                        lifecycle = ReplayLifecycle.IN_PROGRESS
                    }
                }
                else -> {}
            }
        }
        return UndoResolution(cancelled, ignored)
    }

    private fun replay(): Pair<MatchState, List<Transition>> {
        val resolution = resolveUndos()

        val w = Working(format, firstServer)
        var last = emptyList<Transition>()
        events.forEachIndexed { i, e ->
            if (i in resolution.cancelled || i in resolution.ignored) return@forEachIndexed
            when (e.type) {
                EventType.MATCH_STARTED -> w.started = true
                EventType.MATCH_PAUSED -> if (!w.completed) w.paused = true
                EventType.MATCH_RESUMED -> if (!w.completed && w.paused) w.paused = false
                EventType.POINT_TEAM_A -> if (!w.completed && !w.paused) {
                    last = w.applyPoint(TeamId.A)
                }
                EventType.POINT_TEAM_B -> if (!w.completed && !w.paused) {
                    last = w.applyPoint(TeamId.B)
                }
                EventType.SCORE_EDITED -> if (!w.completed && !w.paused) {
                    e.payload?.let { w.applyEdit(it); last = emptyList() }
                }
                EventType.MATCH_COMPLETED ->
                    if (e.sourceMethod == "MANUAL_EDIT" && !w.completed) {
                        w.completed = true
                        w.winner = e.teamId ?: w.leading()
                        last = listOf(Transition.MATCH_WON)
                    }
                else -> {}
            }
        }
        return w.snapshot() to last
    }

    private class Working(val f: MatchFormat, firstServer: TeamId) {
        var started = false
        var paused = false
        var completed = false
        var pA = 0; var pB = 0
        var deuceNumber = 0
        var gA = 0; var gB = 0
        var sA = 0; var sB = 0
        val sets = mutableListOf<SetResult>()
        var serving = firstServer
        var inTb = false; var inStb = false
        var tbA = 0; var tbB = 0
        var tbFirstServer = TeamId.A
        var freeA = 0; var freeB = 0
        var sidePending = false
        var winner: TeamId? = null

        fun leading(): TeamId? = when {
            f.freePlay -> if (freeA == freeB) null else if (freeA > freeB) TeamId.A else TeamId.B
            sA != sB -> if (sA > sB) TeamId.A else TeamId.B
            gA != gB -> if (gA > gB) TeamId.A else TeamId.B
            else -> null
        }

        fun currentServer(): TeamId {
            if (!inTb && !inStb) return serving
            val idx = tbA + tbB
            if (idx == 0) return tbFirstServer
            val block = (idx - 1) / 2
            return if (block % 2 == 0) tbFirstServer.opponent else tbFirstServer
        }

        fun applyPoint(team: TeamId): List<Transition> {
            sidePending = false
            if (f.freePlay) {
                if (team == TeamId.A) freeA++ else freeB++
                return listOf(Transition.POINT)
            }
            return if (inTb || inStb) tieBreakPoint(team) else gamePoint(team)
        }

        /** The set in play is the last one the match can have. */
        private val inDecidingSet: Boolean
            get() = sA == f.setsToWin - 1 && sB == f.setsToWin - 1

        /**
         * Whether gamesPerSet-all opens a tie-break in the set being played.
         * FIP Rule 1, Option 1.4 allows the deciding set to be played out.
         */
        private val tieBreakAvailable: Boolean
            get() = f.tieBreakAtGamesAll && (f.tieBreakInDecidingSet || !inDecidingSet)

        private fun gamePoint(team: TeamId): List<Transition> {
            var gameWinner: TeamId? = null
            when (f.gameScoringMode) {
                GameScoringMode.GOLDEN_POINT -> {
                    if (team == TeamId.A) pA++ else pB++
                    if (pA >= 4 || pB >= 4) gameWinner = team
                }
                GameScoringMode.ADVANTAGE,
                GameScoringMode.STAR_POINT,
                -> when {
                    pA == 4 && pB == 3 -> {
                        if (team == TeamId.A) {
                            gameWinner = TeamId.A
                        } else {
                            pA = 3
                            pB = 3
                            if (f.gameScoringMode == GameScoringMode.STAR_POINT) {
                                deuceNumber = (deuceNumber + 1).coerceIn(1, 3)
                            }
                        }
                    }
                    pB == 4 && pA == 3 -> {
                        if (team == TeamId.B) {
                            gameWinner = TeamId.B
                        } else {
                            pA = 3
                            pB = 3
                            if (f.gameScoringMode == GameScoringMode.STAR_POINT) {
                                deuceNumber = (deuceNumber + 1).coerceIn(1, 3)
                            }
                        }
                    }
                    pA == 3 && pB == 3 -> {
                        if (
                            f.gameScoringMode == GameScoringMode.STAR_POINT &&
                            deuceNumber >= 3
                        ) {
                            gameWinner = team
                        } else if (team == TeamId.A) {
                            pA = 4
                        } else {
                            pB = 4
                        }
                    }
                    else -> {
                        if (team == TeamId.A) pA++ else pB++
                        if (
                            (pA >= 4 && pA - pB >= 2) ||
                            (pB >= 4 && pB - pA >= 2)
                        ) {
                            gameWinner = team
                        }
                    }
                }
            }
            if (
                gameWinner == null &&
                f.gameScoringMode == GameScoringMode.STAR_POINT &&
                pA == 3 &&
                pB == 3 &&
                deuceNumber == 0
            ) {
                deuceNumber = 1
            }
            if (gameWinner == null) return listOf(Transition.POINT)

            val gWinner = gameWinner
            pA = 0; pB = 0; deuceNumber = 0
            if (gWinner == TeamId.A) gA++ else gB++
            serving = serving.opponent

            val out = mutableListOf(Transition.POINT, Transition.GAME_WON)

            // Set won outright? completeSet owns the end-of-set change of ends,
            // which follows the same odd-total rule applied below to mid-set
            // games.
            val lg = if (gWinner == TeamId.A) gA else gB
            val og = if (gWinner == TeamId.A) gB else gA
            if (lg >= f.gamesPerSet && lg - og >= 2) {
                out.addAll(completeSet(gWinner, tb = false)); return out
            }

            if ((gA + gB) % 2 == 1) { sidePending = true; out.add(Transition.SIDE_CHANGE) }
            // No tie-break in a deciding set played to two games of margin.
            if (tieBreakAvailable && gA == f.gamesPerSet && gB == f.gamesPerSet) {
                inTb = true; tbA = 0; tbB = 0; tbFirstServer = serving
            }
            return out
        }

        private fun tieBreakPoint(team: TeamId): List<Transition> {
            if (team == TeamId.A) tbA++ else tbB++
            val target = if (inStb) f.superTieBreakPoints else f.tieBreakPoints
            val out = mutableListOf(Transition.POINT)
            val leader = if (tbA > tbB) TeamId.A else TeamId.B
            val lead = kotlin.math.abs(tbA - tbB)
            val maxPts = maxOf(tbA, tbB)
            if (maxPts >= target && lead >= 2) {
                if (inStb) out.addAll(completeSuperTb(leader))
                else { out.add(Transition.GAME_WON); out.addAll(completeSet(leader, tb = true)) }
                return out
            }
            val total = tbA + tbB
            if (total > 0 && total % 6 == 0) {
                sidePending = true; out.add(Transition.SIDE_CHANGE)
            }
            return out
        }

        private fun completeSet(setWinner: TeamId, tb: Boolean): List<Transition> {
            sets.add(
                if (tb) SetResult(
                    gamesA = if (setWinner == TeamId.A) f.gamesPerSet + 1 else f.gamesPerSet,
                    gamesB = if (setWinner == TeamId.B) f.gamesPerSet + 1 else f.gamesPerSet,
                    tieBreakA = tbA, tieBreakB = tbB,
                ) else SetResult(gA, gB)
            )
            if (setWinner == TeamId.A) sA++ else sB++
            // Captured before the reset below: the games actually played in the
            // set that just finished.
            val setTotalGames = if (tb) f.gamesPerSet * 2 + 1 else gA + gB
            gA = 0; gB = 0; pA = 0; pB = 0; deuceNumber = 0
            if (inTb) serving = tbFirstServer.opponent
            inTb = false; tbA = 0; tbB = 0

            // FIP Rules of Padel (Rule 11 — Change of ends): teams change ends
            // at the end of every odd game, and at the end of a set only when
            // the set's total number of games is odd. After an even set (6-0,
            // 6-2, 6-4) the change is deferred to the end of the first game of
            // the next set, which the per-game odd rule in gamePoint already
            // produces. A set won on a tie-break is 7-6 = 13 games, so it
            // always changes ends.
            val changeEnds = setTotalGames % 2 == 1
            sidePending = changeEnds

            val out = mutableListOf(Transition.SET_WON)
            if (changeEnds) out.add(Transition.SIDE_CHANGE)
            val winSets = if (setWinner == TeamId.A) sA else sB
            if (winSets >= f.setsToWin) {
                completed = true; winner = setWinner
                // The match is over: there is no next game to change ends for.
                sidePending = false
                out.add(Transition.MATCH_WON)
                return out
            }
            if (f.superTieBreakDecider && sA == f.setsToWin - 1 && sB == f.setsToWin - 1) {
                inStb = true; tbA = 0; tbB = 0; tbFirstServer = serving
            }
            return out
        }

        private fun completeSuperTb(stbWinner: TeamId): List<Transition> {
            sets.add(
                SetResult(
                    gamesA = if (stbWinner == TeamId.A) 1 else 0,
                    gamesB = if (stbWinner == TeamId.B) 1 else 0,
                    tieBreakA = tbA, tieBreakB = tbB, isSuperTieBreak = true,
                )
            )
            if (stbWinner == TeamId.A) sA++ else sB++
            inStb = false
            deuceNumber = 0
            completed = true; winner = stbWinner
            return listOf(Transition.SET_WON, Transition.MATCH_WON)
        }

        fun applyEdit(p: JSONObject) {
            pA = p.optInt("pointsA", pA).coerceIn(0, 4)
            pB = p.optInt("pointsB", pB).coerceIn(0, 4)
            // A deciding set without tie-break has no gamesPerSet+1 ceiling
            // (8-6, 9-7, ...), so the bound follows the set in play.
            val maxGames = if (tieBreakAvailable) f.gamesPerSet + 1 else f.gamesPerSet * 4
            gA = p.optInt("gamesA", gA).coerceIn(0, maxGames)
            gB = p.optInt("gamesB", gB).coerceIn(0, maxGames)

            if (
                f.freePlay ||
                inTb ||
                inStb ||
                f.gameScoringMode == GameScoringMode.GOLDEN_POINT
            ) {
                pA = pA.coerceIn(0, 3)
                pB = pB.coerceIn(0, 3)
                deuceNumber = 0
            } else {
                // AD is valid only as 4-3 or 3-4. Normalize corrupted/legacy
                // absolute edits before replaying subsequent points.
                if (pA == 4 && pB == 4) {
                    pA = 3
                    pB = 3
                } else {
                    if (pA == 4 && pB != 3) pA = 3
                    if (pB == 4 && pA != 3) pB = 3
                }

                val inDeucePhase =
                    (pA == 3 && pB == 3) ||
                        (pA == 4 && pB == 3) ||
                        (pB == 4 && pA == 3)
                deuceNumber = if (
                    f.gameScoringMode == GameScoringMode.STAR_POINT &&
                    inDeucePhase
                ) {
                    // Legacy SCORE_EDITED carried no phase: always restart
                    // from deuce 1 rather than inheriting replay state.
                    p.optInt("deuceNumber", 1).coerceIn(1, 3).let { requested ->
                        if ((pA == 4 || pB == 4) && requested == 3) 2 else requested
                    }
                } else {
                    0
                }
            }
            if (inTb || inStb) {
                tbA = p.optInt("tieBreakA", tbA)
                tbB = p.optInt("tieBreakB", tbB)
            }
        }

        fun snapshot(): MatchState {
            var adv: TeamId? = null
            if (f.gameScoringMode != GameScoringMode.GOLDEN_POINT) {
                if (pA == 4 && pB == 3) adv = TeamId.A
                if (pB == 4 && pA == 3) adv = TeamId.B
            }
            return MatchState(
                completed = completed,
                paused = paused,
                scoringMode = f.gameScoringMode,
                pointsA = pA.coerceIn(0, 3),
                pointsB = pB.coerceIn(0, 3),
                advantage = adv,
                deuceNumber = deuceNumber.coerceIn(0, 3),
                gamesA = gA, gamesB = gB,
                setsA = sA, setsB = sB,
                completedSets = sets.toList(),
                servingTeam = currentServer(),
                inTieBreak = inTb, inSuperTieBreak = inStb,
                tieBreakA = tbA, tieBreakB = tbB,
                freePlayA = freeA, freePlayB = freeB,
                sideChangePending = sidePending,
                winner = winner,
            )
        }
    }
}
