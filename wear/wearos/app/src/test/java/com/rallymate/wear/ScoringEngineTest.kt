package com.rallymate.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.json.JSONObject
import java.util.UUID
import kotlinx.coroutines.runBlocking

/**
 * Parità semantica con il test suite Dart di rally_core.
 */
class ScoringEngineTest {

    @Test
    fun defaultEventIds_areCanonicalUniqueUuidV4() {
        val engine = ScoringEngine("uuid-match", MatchFormat())
        val ids = engine.start().map { it.eventId } +
            engine.addPoint(TeamId.A).first.map { it.eventId }

        assertEquals(ids.size, ids.toSet().size)
        ids.forEach { value ->
            val uuid = UUID.fromString(value)
            assertEquals(4, uuid.version())
            assertEquals(2, uuid.variant())
            assertEquals(value.lowercase(), value)
        }
    }

    private fun engine(format: MatchFormat = MatchFormat()): ScoringEngine {
        var t = 0L
        var i = 0
        return ScoringEngine("m1", format, clock = { ++t }, idGen = { "e${i++}" })
    }

    private fun winGame(e: ScoringEngine, team: TeamId) {
        val games = if (team == TeamId.A) e.state.gamesA else e.state.gamesB
        val sets = if (team == TeamId.A) e.state.setsA else e.state.setsB
        while (!e.state.completed) {
            e.addPoint(team)
            val g = if (team == TeamId.A) e.state.gamesA else e.state.gamesB
            val s = if (team == TeamId.A) e.state.setsA else e.state.setsB
            if (g > games || s > sets || e.state.completed) return
        }
    }

    private fun winSet(e: ScoringEngine, team: TeamId) {
        val sets = if (team == TeamId.A) e.state.setsA else e.state.setsB
        while (!e.state.completed) {
            winGame(e, team)
            val s = if (team == TeamId.A) e.state.setsA else e.state.setsB
            if (s > sets || e.state.completed) return
        }
    }

    /** Like [winGame] but returns the transitions of the game-winning point. */
    private fun playGame(e: ScoringEngine, team: TeamId): List<Transition> {
        val games = if (team == TeamId.A) e.state.gamesA else e.state.gamesB
        val sets = if (team == TeamId.A) e.state.setsA else e.state.setsB
        while (true) {
            val transitions = e.addPoint(team).second
            val g = if (team == TeamId.A) e.state.gamesA else e.state.gamesB
            val s = if (team == TeamId.A) e.state.setsA else e.state.setsB
            if (g > games || s > sets || e.state.completed) return transitions
        }
    }

    private fun reachStarPoint(e: ScoringEngine) {
        repeat(3) {
            e.addPoint(TeamId.A)
            e.addPoint(TeamId.B)
        }
        assertEquals(1, e.state.deuceNumber)
        assertEquals("DEUCE 1 · VANTAGGI", e.state.pointSituation())

        e.addPoint(TeamId.A)
        assertEquals("AD 1 · VANTAGGIO NOI", e.state.pointSituation())
        e.addPoint(TeamId.B)
        assertEquals(2, e.state.deuceNumber)
        assertEquals("DEUCE 2 · VANTAGGI", e.state.pointSituation())

        e.addPoint(TeamId.B)
        assertEquals("AD 2 · VANTAGGIO LORO", e.state.pointSituation())
        e.addPoint(TeamId.A)
        assertEquals(3, e.state.deuceNumber)
        assertTrue(e.state.starPointActive)
        assertEquals("STAR POINT", e.state.pointSituation())
    }

    @Test
    fun matchFormatV3_roundTripAndLegacyFallbackAreDeterministic() {
        val encoded = MatchFormat.STAR_POINT_BO3.toJson()
        assertEquals(3, encoded.getInt("formatSchemaVersion"))
        assertEquals("STAR_POINT", encoded.getString("gameScoringMode"))
        assertFalse(encoded.has("schemaVersion"))
        assertFalse(encoded.has("mode"))
        assertFalse(encoded.getBoolean("goldenPoint"))
        assertEquals(
            MatchFormat.STAR_POINT_BO3,
            MatchFormat.fromJson(encoded),
        )
        assertEquals(
            MatchFormat.CURRENT_SCHEMA_VERSION,
            MatchFormat.fromJson(encoded).formatSchemaVersion,
        )

        val legacyGolden = MatchFormat.fromJson(
            JSONObject()
                .put("id", "LEGACY_GOLDEN")
                .put("goldenPoint", true),
        )
        val legacyAdvantage = MatchFormat.fromJson(
            JSONObject()
                .put("id", "LEGACY_ADV")
                .put("goldenPoint", false),
        )
        assertEquals(GameScoringMode.GOLDEN_POINT, legacyGolden.gameScoringMode)
        assertEquals(GameScoringMode.ADVANTAGE, legacyAdvantage.gameScoringMode)

        val canonicalV2WinsOverLegacy = MatchFormat.fromJson(
            JSONObject()
                .put("id", "STAR_POINT_BO3")
                .put("formatSchemaVersion", 2)
                .put("gameScoringMode", "STAR_POINT")
                .put("mode", "GOLDEN_POINT")
                .put("goldenPoint", true),
        )
        assertEquals(
            GameScoringMode.STAR_POINT,
            canonicalV2WinsOverLegacy.gameScoringMode,
        )
        val transientAliasFallback = MatchFormat.fromJson(
            JSONObject()
                .put("id", "STAR_POINT_BO3")
                .put("schemaVersion", 2)
                .put("mode", "STAR_POINT")
                .put("goldenPoint", true),
        )
        assertEquals(
            GameScoringMode.STAR_POINT,
            transientAliasFallback.gameScoringMode,
        )
        assertEquals(GameScoringMode.GOLDEN_POINT, MatchFormat().gameScoringMode)
        assertEquals(MatchFormat.GOLDEN_BO3, MatchFormat.PRESETS.first())
        assertTrue(MatchFormat.STAR_POINT_BO3 in MatchFormat.PRESETS)
    }

    @Test
    fun goldenPoint_fourPointsWinGame() {
        val e = engine().also { it.start() }
        repeat(3) { e.addPoint(TeamId.A) }
        assertEquals("40", e.state.pointsLabel(TeamId.A))
        e.addPoint(TeamId.A)
        assertEquals(1, e.state.gamesA)
    }

    @Test
    fun goldenPoint_deuceNextPointWins() {
        val e = engine().also { it.start() }
        repeat(3) { e.addPoint(TeamId.A); e.addPoint(TeamId.B) }
        assertEquals(
            "40 PARI · PUNTO DECISIVO",
            e.state.pointSituation(),
        )
        e.addPoint(TeamId.B)
        assertEquals(1, e.state.gamesB)
    }

    @Test
    fun advantage_deuceAdGame() {
        val e = engine(
            MatchFormat(
                id = "ADV_BO3",
                gameScoringMode = GameScoringMode.ADVANTAGE,
            ),
        )
            .also { it.start() }
        repeat(3) { e.addPoint(TeamId.A); e.addPoint(TeamId.B) }
        assertEquals(0, e.state.deuceNumber)
        assertEquals(
            "40 PARI · VANTAGGI",
            e.state.pointSituation(),
        )
        e.addPoint(TeamId.A) // AD A
        assertEquals("AD", e.state.pointsLabel(TeamId.A))
        assertEquals(
            "VANTAGGIO CASA · GAME POINT",
            e.state.pointSituation(
                teamALabel = "CASA",
                teamBLabel = "OSPITI",
            ),
        )
        e.addPoint(TeamId.B) // deuce
        assertEquals("40", e.state.pointsLabel(TeamId.A))
        assertEquals(
            "40 PARI · VANTAGGI",
            e.state.pointSituation(),
        )
        e.addPoint(TeamId.B)
        e.addPoint(TeamId.B)
        assertEquals(1, e.state.gamesB)
    }

    @Test
    fun advantage_alternatesThroughDeuceAndUndoRestoresDeuce() {
        val e = engine(
            MatchFormat(
                id = "ADV_BO3",
                gameScoringMode = GameScoringMode.ADVANTAGE,
            ),
        )
            .also { it.start() }
        repeat(3) { e.addPoint(TeamId.A); e.addPoint(TeamId.B) }

        e.addPoint(TeamId.A)
        assertEquals("AD", e.state.pointsLabel(TeamId.A))
        assertEquals("40", e.state.pointsLabel(TeamId.B))

        e.addPoint(TeamId.B)
        assertEquals("40", e.state.pointsLabel(TeamId.A))
        assertEquals("40", e.state.pointsLabel(TeamId.B))

        e.addPoint(TeamId.B)
        assertEquals("40", e.state.pointsLabel(TeamId.A))
        assertEquals("AD", e.state.pointsLabel(TeamId.B))

        e.addPoint(TeamId.A)
        assertEquals("40", e.state.pointsLabel(TeamId.A))
        assertEquals("40", e.state.pointsLabel(TeamId.B))

        e.addPoint(TeamId.A)
        assertEquals("AD", e.state.pointsLabel(TeamId.A))
        e.undo()
        assertEquals("40", e.state.pointsLabel(TeamId.A))
        assertEquals("40", e.state.pointsLabel(TeamId.B))
    }

    @Test
    fun starPoint_twoAdvantageCyclesThenNextPointWins() {
        val e = engine(MatchFormat.STAR_POINT_BO3).also { it.start() }
        reachStarPoint(e)

        assertEquals(
            "La coppia in risposta sceglie il lato",
            e.state.pointSituationHint(),
        )
        assertEquals(
            "Star Point. Punto decisivo. La coppia in risposta sceglie il lato.",
            e.state.pointSituationAccessibility(),
        )
        e.addPoint(TeamId.B)
        assertEquals(1, e.state.gamesB)
        assertEquals(0, e.state.deuceNumber)
        assertFalse(e.state.starPointActive)
    }

    @Test
    fun starPoint_advantageCanStillBeConvertedBeforeThirdDeuce() {
        val e = engine(MatchFormat.STAR_POINT_BO3).also { it.start() }
        repeat(3) {
            e.addPoint(TeamId.A)
            e.addPoint(TeamId.B)
        }
        e.addPoint(TeamId.A)
        e.addPoint(TeamId.A)

        assertEquals(1, e.state.gamesA)
        assertEquals(0, e.state.deuceNumber)
    }

    @Test
    fun starPoint_undoAcrossThirdDeuceAndGameRebuildsExactState() {
        val e = engine(MatchFormat.STAR_POINT_BO3).also { it.start() }
        reachStarPoint(e)

        e.undo()
        assertEquals(2, e.state.deuceNumber)
        assertEquals(TeamId.B, e.state.advantage)
        assertEquals("AD 2 · VANTAGGIO LORO", e.state.pointSituation())

        // Reapply the cancelled return-to-deuce as a fresh event.
        e.addPoint(TeamId.A)
        assertTrue(e.state.starPointActive)
        e.addPoint(TeamId.A)
        assertEquals(1, e.state.gamesA)

        e.undo()
        assertEquals(0, e.state.gamesA)
        assertEquals(3, e.state.deuceNumber)
        assertTrue(e.state.starPointActive)
        assertEquals("STAR POINT", e.state.pointSituation())
    }

    @Test
    fun starPoint_journalReplayPreservesThirdDeuce() {
        val e = engine(MatchFormat.STAR_POINT_BO3).also { it.start() }
        reachStarPoint(e)

        val replayed = engine(MatchFormat.STAR_POINT_BO3)
        replayed.loadEvents(
            MatchEvent.listFromJson(MatchEvent.listToJson(e.allEvents)),
        )
        assertEquals(e.state, replayed.state)
        assertEquals(3, replayed.state.deuceNumber)
        assertTrue(replayed.state.starPointActive)
    }

    @Test
    fun scoreEditResetsOrExplicitlyRestoresStarPointContext() {
        val e = engine(MatchFormat.STAR_POINT_BO3).also { it.start() }
        reachStarPoint(e)
        val resetEdit = MatchEvent(
            eventId = "edit-reset",
            matchId = "m1",
            timestampMs = 100,
            type = EventType.SCORE_EDITED,
            payload = JSONObject()
                .put("pointsA", 3)
                .put("pointsB", 3)
                .put("gamesA", 0)
                .put("gamesB", 0),
        )
        e.loadEvents(e.allEvents + resetEdit)
        assertEquals(1, e.state.deuceNumber)
        assertFalse(e.state.starPointActive)

        val restoreEdit = resetEdit.copy(
            eventId = "edit-restore",
            timestampMs = 101,
            payload = JSONObject()
                .put("pointsA", 3)
                .put("pointsB", 3)
                .put("gamesA", 0)
                .put("gamesB", 0)
                .put("deuceNumber", 3),
        )
        e.loadEvents(e.allEvents + restoreEdit)
        assertEquals(3, e.state.deuceNumber)
        assertTrue(e.state.starPointActive)
    }

    @Test
    fun tieBreak_at66_winBy2_recorded76() {
        val e = engine().also { it.start() }
        repeat(6) { winGame(e, TeamId.A); winGame(e, TeamId.B) }
        assertTrue(e.state.inTieBreak)
        repeat(6) { e.addPoint(TeamId.A); e.addPoint(TeamId.B) }
        e.addPoint(TeamId.A)
        assertTrue(e.state.inTieBreak) // 7-6, serve 2 di scarto
        e.addPoint(TeamId.A) // 8-6
        assertEquals(1, e.state.setsA)
        val set = e.state.completedSets.single()
        assertEquals(7, set.gamesA)
        assertEquals(6, set.gamesB)
        assertEquals(8, set.tieBreakA)
    }

    @Test
    fun superTieBreak_decidesThirdSet() {
        val e = engine(MatchFormat(id = "STB", superTieBreakDecider = true))
            .also { it.start() }
        winSet(e, TeamId.A)
        winSet(e, TeamId.B)
        assertTrue(e.state.inSuperTieBreak)
        repeat(10) { e.addPoint(TeamId.A) }
        assertTrue(e.state.completed)
        assertEquals(TeamId.A, e.state.winner)
        assertTrue(e.state.completedSets.last().isSuperTieBreak)
    }

    @Test
    fun undo_acrossGameBoundary() {
        val e = engine().also { it.start() }
        winGame(e, TeamId.A)
        assertEquals(1, e.state.gamesA)
        e.undo()
        assertEquals(0, e.state.gamesA)
        assertEquals("40", e.state.pointsLabel(TeamId.A))
    }

    @Test
    fun undo_reopensCompletedMatch() {
        val e = engine(MatchFormat(id = "SINGLE", setsToWin = 1))
            .also { it.start() }
        winSet(e, TeamId.A)
        assertTrue(e.state.completed)
        e.undo()
        assertFalse(e.state.completed)
    }

    @Test
    fun jsonRoundTrip_preservesState() {
        val e = engine().also { it.start() }
        winGame(e, TeamId.A)
        e.addPoint(TeamId.B)
        e.undo()
        val json = MatchEvent.listToJson(e.allEvents)
        val rebuilt = engine()
        rebuilt.loadEvents(MatchEvent.listFromJson(json))
        assertEquals(e.state, rebuilt.state)
    }

    @Test
    fun repeatedStartMerge_preservesJournalAndAppendsOnlyLocalTail() {
        val e = engine().also { it.start() }
        e.addPoint(TeamId.A)
        e.addPoint(TeamId.B)
        val existing = e.allEvents

        assertEquals(existing, mergeStartMatchEvents(existing, emptyList()))

        val remotePrefix = existing.take(2)
        val merged = mergeStartMatchEvents(existing, remotePrefix)
        assertEquals(existing.map { it.eventId }, merged.map { it.eventId })
        assertEquals(merged.size, merged.map { it.eventId }.toSet().size)
    }

    @Test
    fun applicationAck_isMatchScopedAndAcceptsOnlyAcknowledgedIds() = runBlocking {
        val waiter = EventAckRegistry.register(
            "match-a",
            setOf("e1", "e2"),
            SyncPaths.EVENTS_ACK,
        )

        EventAckRegistry.acknowledge(
            "match-b",
            setOf("e1", "e2"),
            SyncPaths.EVENTS_ACK,
        )
        assertFalse(waiter.result.isCompleted)

        EventAckRegistry.acknowledge(
            "match-a",
            setOf("old", "e2"),
            SyncPaths.EVENTS_ACK,
        )
        assertEquals(setOf("e2"), waiter.result.await())

        // Duplicate/out-of-order ACKs have no effect on an already completed
        // waiter and can never acknowledge a different event implicitly.
        EventAckRegistry.acknowledge(
            "match-a",
            setOf("e1"),
            SyncPaths.EVENTS_ACK,
        )
        assertEquals(setOf("e2"), waiter.result.await())
    }

    @Test
    fun serveRotation_alternatesEachGame() {
        val e = engine().also { it.start() }
        assertEquals(TeamId.A, e.state.servingTeam)
        winGame(e, TeamId.A)
        assertEquals(TeamId.B, e.state.servingTeam)
    }

    @Test
    fun freePlay_countsRallyPoints() {
        val e = engine(MatchFormat(id = "TRAINING", setsToWin = 1, freePlay = true))
            .also { it.start() }
        e.addPoint(TeamId.A); e.addPoint(TeamId.A); e.addPoint(TeamId.B)
        assertEquals(2, e.state.freePlayA)
        assertEquals(1, e.state.freePlayB)
        assertFalse(e.state.completed)
    }

    @Test
    fun pauseResumeAndManualFinish_areReplayable() {
        val e = engine(MatchFormat.TRAINING).also { it.start() }
        e.addPoint(TeamId.A)
        assertEquals(listOf(EventType.MATCH_PAUSED), e.pause().map { it.type })
        assertTrue(e.state.paused)
        assertTrue(e.pause().isEmpty())
        assertEquals(listOf(EventType.MATCH_RESUMED), e.resume().map { it.type })
        assertFalse(e.state.paused)
        assertEquals(listOf(EventType.MATCH_COMPLETED), e.finish(TeamId.A).map { it.type })
        assertTrue(e.state.completed)
        assertEquals(TeamId.A, e.state.winner)

        val replayed = engine(MatchFormat.TRAINING)
        replayed.loadEvents(MatchEvent.listFromJson(MatchEvent.listToJson(e.allEvents)))
        assertEquals(e.state, replayed.state)
    }

    @Test
    fun pausedMutations_areNoOpsLiveAndOnReplay() {
        val live = engine().also { it.start() }
        live.addPoint(TeamId.A)
        live.pause()
        val eventCount = live.allEvents.size
        assertTrue(live.addPoint(TeamId.B).first.isEmpty())
        assertTrue(live.undo().first.isEmpty())
        assertEquals(eventCount, live.allEvents.size)

        fun event(
            id: String,
            timestamp: Long,
            type: EventType,
            team: TeamId? = null,
            payload: org.json.JSONObject? = null,
        ) = MatchEvent(
            eventId = id,
            matchId = "paused-replay",
            timestampMs = timestamp,
            type = type,
            teamId = team,
            payload = payload,
        )

        val replayed = engine().also {
            it.loadEvents(
                listOf(
                    event("start", 1, EventType.MATCH_STARTED),
                    event("point-a", 2, EventType.POINT_TEAM_A, TeamId.A),
                    event("pause", 3, EventType.MATCH_PAUSED),
                    event("paused-point", 4, EventType.POINT_TEAM_B, TeamId.B),
                    event("paused-undo", 5, EventType.UNDO),
                    event(
                        "paused-edit",
                        6,
                        EventType.SCORE_EDITED,
                        payload = org.json.JSONObject()
                            .put("pointsA", 3)
                            .put("pointsB", 0)
                            .put("gamesA", 4)
                            .put("gamesB", 0),
                    ),
                    event("resume", 7, EventType.MATCH_RESUMED),
                    event("point-b", 8, EventType.POINT_TEAM_B, TeamId.B),
                    event("valid-undo", 9, EventType.UNDO),
                ),
            )
        }
        assertFalse(replayed.state.paused)
        assertEquals("15", replayed.state.pointsLabel(TeamId.A))
        assertEquals("0", replayed.state.pointsLabel(TeamId.B))
        assertEquals(0, replayed.state.gamesA)
    }

    @Test
    fun completedReplay_blocksLatePointAndScoreEdit() {
        val replayed = engine(MatchFormat.TRAINING).also {
            it.loadEvents(
                listOf(
                    MatchEvent("start", "done", 1, EventType.MATCH_STARTED),
                    MatchEvent(
                        "point-a", "done", 2, EventType.POINT_TEAM_A,
                        teamId = TeamId.A,
                    ),
                    MatchEvent(
                        "finish", "done", 3, EventType.MATCH_COMPLETED,
                        teamId = TeamId.A,
                        sourceMethod = "MANUAL_EDIT",
                    ),
                    MatchEvent(
                        "late-point", "done", 4, EventType.POINT_TEAM_B,
                        teamId = TeamId.B,
                    ),
                    MatchEvent(
                        "late-edit", "done", 5, EventType.SCORE_EDITED,
                        payload = org.json.JSONObject()
                            .put("pointsA", 0)
                            .put("pointsB", 0)
                            .put("gamesA", 4)
                            .put("gamesB", 3),
                    ),
                ),
            )
        }
        assertTrue(replayed.state.completed)
        assertEquals(1, replayed.state.freePlayA)
        assertEquals(0, replayed.state.freePlayB)
        assertEquals(0, replayed.state.gamesA)
    }

    @Test
    fun duoAttribution_survivesJsonRoundTrip() {
        val e = ScoringEngine(
            matchId = "duo-1",
            format = MatchFormat.ADVANTAGE_BO3,
            sourceUserId = "user-1",
            assignedTeam = TeamId.B,
            duoMode = true,
            clock = { 99L },
            idGen = { "event-1" },
        )
        val event = e.start().single()
        assertEquals("user-1", event.sourceUserId)
        assertEquals(TeamId.B, event.sourceTeamId)
        assertTrue(event.duoMode)
        assertEquals(99L, event.createdLocallyAtMs)
        assertEquals(
            event,
            MatchEvent.listFromJson(MatchEvent.listToJson(listOf(event))).single(),
        )
    }

    // ------------------------------------------------------------ Duo Mode

    @Test
    fun duo_teamUndoCancelsOnlyOwnTeamPoint() {
        val e = engine().also { it.start() }
        e.addPoint(TeamId.A)
        e.addPoint(TeamId.B)
        assertTrue(e.canUndoTeam(TeamId.A))
        e.undo(TeamId.A)
        assertEquals("0", e.state.pointsLabel(TeamId.A))
        assertEquals("15", e.state.pointsLabel(TeamId.B))
        assertFalse(e.canUndoTeam(TeamId.A))
        assertTrue(e.canUndoTeam(TeamId.B))
    }

    @Test
    fun duo_teamUndoWithNoOwnPointIsNoOp() {
        val e = engine().also { it.start() }
        e.addPoint(TeamId.A)
        val (events, _) = e.undo(TeamId.B)
        assertTrue(events.isEmpty())
        assertEquals("15", e.state.pointsLabel(TeamId.A))
    }

    // FIP Rules of Padel, Rule 11 (Change of ends): every odd game, and at the
    // end of a set only when that set's total number of games is odd.

    @Test
    fun changeOfEnds_setWonSixFour_doesNotChangeEnds() {
        val e = engine().also { it.start() }
        repeat(4) {
            playGame(e, TeamId.A)
            playGame(e, TeamId.B)
        }
        playGame(e, TeamId.A)
        val transitions = playGame(e, TeamId.A) // 6-4 → set
        assertTrue(Transition.SET_WON in transitions)
        assertFalse(Transition.SIDE_CHANGE in transitions)
        assertFalse(e.state.sideChangePending)
    }

    @Test
    fun changeOfEnds_deferredChangeHappensAfterFirstGameOfNextSet() {
        val e = engine().also { it.start() }
        repeat(4) {
            playGame(e, TeamId.A)
            playGame(e, TeamId.B)
        }
        playGame(e, TeamId.A)
        playGame(e, TeamId.A) // 6-4, no change of ends yet
        val transitions = playGame(e, TeamId.B) // first game of set 2
        assertTrue(Transition.SIDE_CHANGE in transitions)
        assertTrue(e.state.sideChangePending)
    }

    @Test
    fun changeOfEnds_setWonSixThree_changesEnds() {
        val e = engine().also { it.start() }
        repeat(3) {
            playGame(e, TeamId.A)
            playGame(e, TeamId.B)
        }
        playGame(e, TeamId.A)
        playGame(e, TeamId.A)
        val transitions = playGame(e, TeamId.A) // 6-3 → set
        assertTrue(Transition.SET_WON in transitions)
        assertTrue(Transition.SIDE_CHANGE in transitions)
        assertTrue(e.state.sideChangePending)
    }

    @Test
    fun changeOfEnds_setWonSixLove_doesNotChangeEnds() {
        val e = engine().also { it.start() }
        repeat(5) { playGame(e, TeamId.A) }
        val transitions = playGame(e, TeamId.A) // 6-0 → set
        assertFalse(Transition.SIDE_CHANGE in transitions)
        assertFalse(e.state.sideChangePending)
    }

    @Test
    fun changeOfEnds_setWonOnTieBreak_changesEnds() {
        val e = engine().also { it.start() }
        repeat(6) {
            playGame(e, TeamId.A)
            playGame(e, TeamId.B)
        }
        assertTrue(e.state.inTieBreak)
        var transitions: List<Transition> = emptyList()
        repeat(7) { transitions = e.addPoint(TeamId.A).second }
        assertTrue(Transition.SET_WON in transitions)
        assertTrue(Transition.SIDE_CHANGE in transitions)
        assertTrue(e.state.sideChangePending)
    }

    @Test
    fun changeOfEnds_matchWinningSet_leavesNoPendingChange() {
        val e = engine().also { it.start() }
        winSet(e, TeamId.A)
        repeat(3) {
            playGame(e, TeamId.A)
            playGame(e, TeamId.B)
        }
        playGame(e, TeamId.A)
        playGame(e, TeamId.A)
        val transitions = playGame(e, TeamId.A) // 6-3 → set and match
        assertTrue(Transition.MATCH_WON in transitions)
        assertTrue(e.state.completed)
        assertFalse(e.state.sideChangePending)
    }

    @Test
    fun duo_lifecycleEventsAreAuditOnlyOnReplay() {
        val e = engine().also { it.start() }
        e.addPoint(TeamId.A)
        val log = e.allEvents + MatchEvent(
            eventId = "j1",
            matchId = "m1",
            timestampMs = 99,
            type = EventType.TEAM_CONFIRMED,
            teamId = TeamId.B,
        )
        val replayed = engine().also { it.loadEvents(log) }
        assertEquals("15", replayed.state.pointsLabel(TeamId.A))
        assertFalse(replayed.state.completed)
    }
}
