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

data class MatchFormat(
    val id: String = "GOLDEN_BO3",
    val name: String = "Golden point — meglio di 3",
    val setsToWin: Int = 2,
    val gamesPerSet: Int = 6,
    val goldenPoint: Boolean = true,
    val tieBreakAtGamesAll: Boolean = true,
    val tieBreakPoints: Int = 7,
    val superTieBreakDecider: Boolean = false,
    val superTieBreakPoints: Int = 10,
    val freePlay: Boolean = false,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id); put("name", name)
        put("setsToWin", setsToWin); put("gamesPerSet", gamesPerSet)
        put("goldenPoint", goldenPoint)
        put("tieBreakAtGamesAll", tieBreakAtGamesAll)
        put("tieBreakPoints", tieBreakPoints)
        put("superTieBreakDecider", superTieBreakDecider)
        put("superTieBreakPoints", superTieBreakPoints)
        put("freePlay", freePlay)
    }

    companion object {
        fun fromJson(j: JSONObject) = MatchFormat(
            id = j.optString("id", "GOLDEN_BO3"),
            name = j.optString("name", "Custom"),
            setsToWin = j.optInt("setsToWin", 2),
            gamesPerSet = j.optInt("gamesPerSet", 6),
            goldenPoint = j.optBoolean("goldenPoint", true),
            tieBreakAtGamesAll = j.optBoolean("tieBreakAtGamesAll", true),
            tieBreakPoints = j.optInt("tieBreakPoints", 7),
            superTieBreakDecider = j.optBoolean("superTieBreakDecider", false),
            superTieBreakPoints = j.optInt("superTieBreakPoints", 10),
            freePlay = j.optBoolean("freePlay", false),
        )

        val GOLDEN_BO3 = MatchFormat()
        val ADVANTAGE_BO3 = MatchFormat(
            id = "ADV_BO3",
            name = "Vantaggi - meglio di 3",
            goldenPoint = false,
        )
        val SUPER_TIE_BREAK = MatchFormat(
            id = "SUPER_TB_BO3",
            name = "Super tie-break al terzo",
            superTieBreakDecider = true,
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
            ADVANTAGE_BO3,
            SUPER_TIE_BREAK,
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
    val pointsA: Int,
    val pointsB: Int,
    val advantage: TeamId?,
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
    fun pointsLabel(team: TeamId): String {
        val labels = arrayOf("0", "15", "30", "40")
        if (advantage != null) return if (advantage == team) "AD" else "40"
        val v = if (team == TeamId.A) pointsA else pointsB
        return labels[v.coerceIn(0, 3)]
    }

    fun pointSituation(
        goldenPoint: Boolean,
        teamALabel: String = "NOI",
        teamBLabel: String = "LORO",
    ): String? {
        if (inTieBreak || inSuperTieBreak) return null
        advantage?.let {
            val label = if (it == TeamId.A) teamALabel else teamBLabel
            return "VANTAGGIO $label · GAME POINT"
        }
        if (pointsA < 3 || pointsB < 3) return null
        return if (goldenPoint) {
            "40 PARI · PUNTO DECISIVO"
        } else {
            "40 PARI · VANTAGGI"
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

        private fun gamePoint(team: TeamId): List<Transition> {
            var gameWon = false
            if (f.goldenPoint) {
                if (team == TeamId.A) pA++ else pB++
                gameWon = pA >= 4 || pB >= 4
            } else if (pA == 4 && pB == 3) {
                if (team == TeamId.A) gameWon = true else { pA = 3; pB = 3 }
            } else if (pB == 4 && pA == 3) {
                if (team == TeamId.B) gameWon = true else { pA = 3; pB = 3 }
            } else if (pA == 3 && pB == 3) {
                if (team == TeamId.A) pA = 4 else pB = 4
            } else {
                if (team == TeamId.A) pA++ else pB++
                gameWon = (pA >= 4 && pA - pB >= 2) ||
                    (pB >= 4 && pB - pA >= 2)
            }
            if (!gameWon) return listOf(Transition.POINT)

            val gWinner = if (pA > pB) TeamId.A else TeamId.B
            pA = 0; pB = 0
            if (gWinner == TeamId.A) gA++ else gB++
            serving = serving.opponent

            val out = mutableListOf(Transition.POINT, Transition.GAME_WON)
            if ((gA + gB) % 2 == 1) { sidePending = true; out.add(Transition.SIDE_CHANGE) }

            val lg = if (gWinner == TeamId.A) gA else gB
            val og = if (gWinner == TeamId.A) gB else gA
            if (lg >= f.gamesPerSet && lg - og >= 2) {
                out.addAll(completeSet(gWinner, tb = false)); return out
            }
            if (f.tieBreakAtGamesAll && gA == f.gamesPerSet && gB == f.gamesPerSet) {
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
            gA = 0; gB = 0; pA = 0; pB = 0
            if (inTb) serving = tbFirstServer.opponent
            inTb = false; tbA = 0; tbB = 0
            sidePending = true

            val out = mutableListOf(Transition.SET_WON, Transition.SIDE_CHANGE)
            val winSets = if (setWinner == TeamId.A) sA else sB
            if (winSets >= f.setsToWin) {
                completed = true; winner = setWinner
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
            completed = true; winner = stbWinner
            return listOf(Transition.SET_WON, Transition.MATCH_WON)
        }

        fun applyEdit(p: JSONObject) {
            pA = p.optInt("pointsA", pA).coerceIn(0, 4)
            pB = p.optInt("pointsB", pB).coerceIn(0, 4)
            gA = p.optInt("gamesA", gA).coerceIn(0, f.gamesPerSet + 1)
            gB = p.optInt("gamesB", gB).coerceIn(0, f.gamesPerSet + 1)
            if (inTb || inStb) {
                tbA = p.optInt("tieBreakA", tbA)
                tbB = p.optInt("tieBreakB", tbB)
            }
        }

        fun snapshot(): MatchState {
            var adv: TeamId? = null
            if (!f.goldenPoint) {
                if (pA == 4 && pB == 3) adv = TeamId.A
                if (pB == 4 && pA == 3) adv = TeamId.B
            }
            return MatchState(
                completed = completed,
                paused = paused,
                pointsA = pA.coerceIn(0, 3),
                pointsB = pB.coerceIn(0, 3),
                advantage = adv,
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
