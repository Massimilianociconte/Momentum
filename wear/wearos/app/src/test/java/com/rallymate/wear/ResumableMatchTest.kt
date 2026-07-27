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
        format: MatchFormat = MatchFormat.ADVANTAGE_BO3,
        sourceDevice: String = "PHONE",
    ) = WearResumableMatch(
        matchId = id,
        status = status,
        stateVersion = version,
        updatedAtMs = updatedAt,
        format = format,
        sourceDevice = sourceDevice,
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
    fun `authoritative star clear removes stale phone entry but preserves pending tail`() {
        val stored = WearResumableSnapshot(
            matches = listOf(
                entry(
                    "stale-star",
                    WearMatchStatus.PAUSED,
                    format = MatchFormat.STAR_POINT_BO3,
                ),
                entry(
                    "pending-star",
                    WearMatchStatus.PAUSED,
                    format = MatchFormat.STAR_POINT_BO3,
                ),
                entry("classic", WearMatchStatus.PAUSED),
            ),
        )
        val cleared = stored.merging(
            WearResumableSnapshot(
                authoritative = true,
                authoritySource = "PHONE",
                authorityScope = WearSnapshotAuthorityScope.STAR_POINT.wire,
                authorityVersion = 20,
            ),
            protectedMatchIds = setOf("pending-star"),
        )

        assertNull(cleared.match("stale-star"))
        assertNotNull(cleared.match("pending-star"))
        assertNotNull(cleared.match("classic"))
        assertEquals(
            20L,
            cleared.authorityVersions[WearSnapshotAuthorityScope.STAR_POINT.wire],
        )
    }

    @Test
    fun `older reconnect snapshot cannot resurrect star after newer clear`() {
        val initial = WearResumableSnapshot(
            matches = listOf(
                entry(
                    "star",
                    WearMatchStatus.PAUSED,
                    format = MatchFormat.STAR_POINT_BO3,
                ),
            ),
        )
        val cleared = initial.merging(
            WearResumableSnapshot(
                authoritative = true,
                authoritySource = "PHONE",
                authorityScope = WearSnapshotAuthorityScope.STAR_POINT.wire,
                authorityVersion = 30,
            ),
        )
        val staleReconnect = cleared.merging(
            WearResumableSnapshot(
                matches = listOf(
                    entry(
                        "star",
                        WearMatchStatus.PAUSED,
                        format = MatchFormat.STAR_POINT_BO3,
                    ),
                ),
                authoritative = true,
                authoritySource = "PHONE",
                authorityScope = WearSnapshotAuthorityScope.STAR_POINT.wire,
                authorityVersion = 29,
            ),
        )

        assertNull(staleReconnect.match("star"))
    }

    @Test
    fun `lifecycle and snapshot clear converge in either delivery order`() {
        val star = entry(
            "star-lifecycle",
            WearMatchStatus.PAUSED,
            format = MatchFormat.STAR_POINT_BO3,
        )
        val clear = WearResumableSnapshot(
            authoritative = true,
            authoritySource = "PHONE",
            authorityScope = WearSnapshotAuthorityScope.STAR_POINT.wire,
            authorityVersion = 20,
        )

        val clearFirst = WearResumableSnapshot(matches = listOf(star)).merging(clear)
        assertNull(
            clearFirst.acceptingLifecycleAuthority(
                source = "PHONE",
                scope = WearSnapshotAuthorityScope.STAR_POINT,
                version = 19,
            ),
        )
        assertNull(
            clearFirst.acceptingLifecycleAuthority(
                source = null,
                scope = WearSnapshotAuthorityScope.STAR_POINT,
                version = 0,
            ),
        )
        assertNull(clearFirst.match(star.matchId))

        val lifecycleFirst = WearResumableSnapshot.EMPTY
            .acceptingLifecycleAuthority(
                source = "PHONE",
                scope = WearSnapshotAuthorityScope.STAR_POINT,
                version = 19,
            )!!
            .applying(star)
        assertNotNull(lifecycleFirst.match(star.matchId))
        assertNull(lifecycleFirst.merging(clear).match(star.matchId))
    }

    @Test
    fun `lifecycle newer than clear may reintroduce current phone state`() {
        val clear = WearResumableSnapshot(
            authoritative = true,
            authoritySource = "PHONE",
            authorityScope = WearSnapshotAuthorityScope.STAR_POINT.wire,
            authorityVersion = 20,
        )
        val cleared = WearResumableSnapshot.EMPTY.merging(clear)
        val accepted = cleared.acceptingLifecycleAuthority(
            source = "PHONE",
            scope = WearSnapshotAuthorityScope.STAR_POINT,
            version = 21,
        )
        assertNotNull(accepted)
        val updated = accepted!!.applying(
            entry(
                "new-star",
                WearMatchStatus.PAUSED,
                format = MatchFormat.STAR_POINT_BO3,
            )
        )
        assertNotNull(updated.match("new-star"))
    }

    @Test
    fun `scoped snapshots converge independently in either delivery order`() {
        val classic = entry("classic", WearMatchStatus.PAUSED)
        val star = entry(
            "star",
            WearMatchStatus.PAUSED,
            format = MatchFormat.STAR_POINT_BO3,
        )
        val legacy = WearResumableSnapshot(
            matches = listOf(classic),
            authoritative = true,
            authoritySource = "PHONE",
            authorityScope = WearSnapshotAuthorityScope.NON_STAR_POINT.wire,
            authorityVersion = 40,
        )
        val v2 = WearResumableSnapshot(
            matches = listOf(classic, star),
            authoritative = true,
            authoritySource = "PHONE",
            authorityScope = WearSnapshotAuthorityScope.STAR_POINT.wire,
            authorityVersion = 40,
        )

        val legacyThenV2 = WearResumableSnapshot.EMPTY.merging(legacy).merging(v2)
        val v2ThenLegacy = WearResumableSnapshot.EMPTY.merging(v2).merging(legacy)
        assertEquals(
            setOf("classic", "star"),
            legacyThenV2.matches.mapTo(mutableSetOf()) { it.matchId },
        )
        assertEquals(
            setOf("classic", "star"),
            v2ThenLegacy.matches.mapTo(mutableSetOf()) { it.matchId },
        )

        val roundTrip = WearResumableSnapshot.fromJson(v2ThenLegacy.toJson())
        assertEquals(
            40L,
            roundTrip.authorityVersions[
                WearSnapshotAuthorityScope.NON_STAR_POINT.wire
            ],
        )
        assertEquals(
            40L,
            roundTrip.authorityVersions[
                WearSnapshotAuthorityScope.STAR_POINT.wire
            ],
        )
    }

    @Test
    fun `v2 full payload cannot resurrect row owned by non star scope`() {
        val classic = entry("deleted-classic", WearMatchStatus.PAUSED)
        val star = entry(
            "current-star",
            WearMatchStatus.PAUSED,
            format = MatchFormat.STAR_POINT_BO3,
        )
        val nonStarClear = WearResumableSnapshot(
            authoritative = true,
            authoritySource = "PHONE",
            authorityScope = WearSnapshotAuthorityScope.NON_STAR_POINT.wire,
            authorityVersion = 50,
        )
        val v2Full = WearResumableSnapshot(
            activeMatchId = classic.matchId,
            matches = listOf(classic, star),
            authoritative = true,
            authoritySource = "PHONE",
            authorityScope = WearSnapshotAuthorityScope.STAR_POINT.wire,
            authorityVersion = 50,
        )

        val clearThenV2 = WearResumableSnapshot.EMPTY
            .merging(nonStarClear)
            .merging(v2Full)
        val v2ThenClear = WearResumableSnapshot.EMPTY
            .merging(v2Full)
            .merging(nonStarClear)

        assertEquals(setOf(star.matchId), clearThenV2.matches.map { it.matchId }.toSet())
        assertEquals(setOf(star.matchId), v2ThenClear.matches.map { it.matchId }.toSet())
        assertNull(clearThenV2.activeMatchId)
        assertNull(v2ThenClear.activeMatchId)
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
    fun `star point survives lifecycle journal replay and offline resume`() {
        val format = MatchFormat.STAR_POINT_BO3
        val engine = ScoringEngine(matchId = "star-resume", format = format)
        engine.start()
        repeat(3) {
            engine.addPoint(TeamId.A)
            engine.addPoint(TeamId.B)
        }
        engine.addPoint(TeamId.A)
        engine.addPoint(TeamId.B)
        engine.addPoint(TeamId.B)
        engine.addPoint(TeamId.A)
        assertTrue(engine.state.starPointActive)
        engine.pause()

        val journal = engine.allEvents
        val payload = JSONObject()
            .put("matchId", "star-resume")
            .put("action", "PAUSED")
            .put("stateVersion", journal.size)
            .put("format", format.toJson().toString())
            .put("events", MatchEvent.listToJson(journal))
        val lifecycle = WearMatchLifecycle.fromPayload(payload)

        assertNotNull(lifecycle)
        assertEquals(GameScoringMode.STAR_POINT, lifecycle!!.format?.gameScoringMode)
        val replayed = ScoringEngine(
            matchId = lifecycle.matchId,
            format = lifecycle.format!!,
        )
        replayed.loadEvents(lifecycle.events)
        assertTrue(replayed.state.paused)
        assertEquals(3, replayed.state.deuceNumber)
        assertTrue(replayed.state.starPointActive)

        replayed.resume()
        assertFalse(replayed.state.paused)
        assertTrue(replayed.state.starPointActive)
        replayed.addPoint(TeamId.B)
        assertEquals(1, replayed.state.gamesB)
    }

    @Test
    fun `an unknown match id yields no lifecycle`() {
        assertNull(WearMatchLifecycle.fromPayload(JSONObject().put("action", "PAUSED")))
    }
}
