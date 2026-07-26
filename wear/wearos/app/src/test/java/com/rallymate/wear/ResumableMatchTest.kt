package com.rallymate.wear

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Wear OS mirror of the cross-device pause/resume rules: deterministic merge,
 * idempotent lifecycle, no stale overwrite, score rebuilt from the journal.
 */
class ResumableMatchTest {

    private fun entry(
        id: String,
        status: WearMatchStatus,
        version: Int = 0,
        updatedAt: Long = 0,
    ) = WearResumableMatch(
        matchId = id,
        status = status,
        stateVersion = version,
        updatedAtMs = updatedAt,
    )

    @Test
    fun `completed always wins over paused and in progress`() {
        val paused = entry("m1", WearMatchStatus.PAUSED, version = 9, updatedAt = 200)
        val completed = entry("m1", WearMatchStatus.COMPLETED, version = 3, updatedAt = 100)
        assertEquals(
            WearMatchStatus.COMPLETED,
            WearResumableSnapshot.winner(paused, completed).status,
        )
        assertEquals(
            WearMatchStatus.COMPLETED,
            WearResumableSnapshot.winner(completed, paused).status,
        )
    }

    @Test
    fun `a newer version is never overwritten by an older one`() {
        val newer = entry("m1", WearMatchStatus.IN_PROGRESS, version = 12, updatedAt = 50)
        val older = entry("m1", WearMatchStatus.PAUSED, version = 4, updatedAt = 100)
        val snapshot = WearResumableSnapshot(matches = listOf(newer)).applying(older)
        assertEquals(12, snapshot.match("m1")?.stateVersion)
        assertEquals(WearMatchStatus.IN_PROGRESS, snapshot.match("m1")?.status)
    }

    @Test
    fun `resumable entries are ordered by last activity`() {
        val snapshot = WearResumableSnapshot(
            matches = listOf(
                entry("old", WearMatchStatus.PAUSED, updatedAt = 10),
                entry("new", WearMatchStatus.PAUSED, updatedAt = 90),
                entry("done", WearMatchStatus.COMPLETED, updatedAt = 99),
            ),
        )
        assertEquals(listOf("new", "old"), snapshot.resumable.map { it.matchId })
    }

    @Test
    fun `a snapshot survives a json round trip`() {
        val snapshot = WearResumableSnapshot(
            stateVersion = 3,
            lastUpdatedAtMs = 1_700_000_000_000,
            activeMatchId = "m2",
            matches = listOf(
                WearResumableMatch(
                    matchId = "m1",
                    status = WearMatchStatus.PAUSED,
                    stateVersion = 31,
                    updatedAtMs = 1_700_000_000_000,
                    pausedAtMs = 1_700_000_000_000,
                    teamLabel = "Noi",
                    scoreLine = "40-30",
                    setsLabel = "0-0",
                    gamesLabel = "4-1",
                    eventCount = 31,
                    journalAvailable = true,
                ),
            ),
        )
        val decoded = WearResumableSnapshot.fromJson(snapshot.toJson())
        assertEquals("m2", decoded.activeMatchId)
        assertEquals(1, decoded.matches.size)
        assertEquals("4-1", decoded.match("m1")?.gamesLabel)
        assertEquals(WearMatchStatus.PAUSED, decoded.match("m1")?.status)
        assertTrue(decoded.match("m1")!!.journalAvailable)
    }

    @Test
    fun `the wire payload decodes into a snapshot`() {
        val matches = WearResumableMatch.listToJson(
            listOf(entry("m1", WearMatchStatus.PAUSED, version = 7, updatedAt = 42)),
        )
        val payload = JSONObject()
            .put("stateVersion", 7)
            .put("lastUpdatedAtMs", 42L)
            .put("matches", matches)
        val snapshot = WearResumableSnapshot.fromPayload(payload)
        assertEquals(1, snapshot.matches.size)
        assertEquals(7, snapshot.stateVersion)
        assertNull(snapshot.activeMatchId)
    }

    @Test
    fun `a lifecycle payload without a key still dedups deterministically`() {
        val payload = JSONObject()
            .put("matchId", "m1")
            .put("action", "paused")
            .put("stateVersion", 7)
        val lifecycle = WearMatchLifecycle.fromPayload(payload)
        assertNotNull(lifecycle)
        assertEquals(WearMatchStatus.PAUSED, lifecycle!!.status)
        assertEquals("m1#PAUSED#7", lifecycle.idempotencyKey)
    }

    @Test
    fun `a lifecycle payload carries the journal so the watch can resume offline`() {
        val format = MatchFormat.ADVANTAGE_BO3
        val engine = ScoringEngine(matchId = "m1", format = format)
        engine.start()
        repeat(4) { engine.addPoint(TeamId.A, "TAP") }
        val journal = engine.allEvents
        val payload = JSONObject()
            .put("matchId", "m1")
            .put("action", "PAUSED")
            .put("stateVersion", journal.size)
            .put("format", format.toJson().toString())
            .put("events", MatchEvent.listToJson(journal))

        val lifecycle = WearMatchLifecycle.fromPayload(payload)
        assertNotNull(lifecycle)
        assertEquals(journal.size, lifecycle!!.events.size)
        assertEquals(format.id, lifecycle.format?.id)

        // Replaying the delivered journal rebuilds the exact score.
        val replayed = ScoringEngine(matchId = "m1", format = format)
        replayed.loadEvents(lifecycle.events)
        assertEquals(1, replayed.state.gamesA)
        assertFalse(replayed.state.completed)
    }

    @Test
    fun `an unknown match id yields no lifecycle`() {
        assertNull(WearMatchLifecycle.fromPayload(JSONObject().put("action", "PAUSED")))
    }
}
