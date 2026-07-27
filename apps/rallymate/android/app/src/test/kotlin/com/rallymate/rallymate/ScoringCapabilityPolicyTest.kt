package com.rallymate.rallymate

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ScoringCapabilityPolicyTest {

    private fun format(
        mode: String,
        schemaVersion: Int = 2,
    ): String = JSONObject()
        .put("formatSchemaVersion", schemaVersion)
        .put("gameScoringMode", mode)
        .put("goldenPoint", mode == "GOLDEN_POINT")
        .toString()

    @Test
    fun allInstalledLegacyNodesMustAdvertiseScoringV2() {
        assertTrue(
            allLegacyScoringNodesSupportV2(
                legacyNodeIds = setOf("watch-a", "watch-b"),
                scoringV2NodeIds = setOf("watch-a", "watch-b"),
            )
        )
    }

    @Test
    fun mixedV1AndV2NodesFailClosed() {
        assertFalse(
            allLegacyScoringNodesSupportV2(
                legacyNodeIds = setOf("watch-v1", "watch-v2"),
                scoringV2NodeIds = setOf("watch-v2"),
            )
        )
    }

    @Test
    fun missingLegacyCompanionFailsClosed() {
        assertFalse(
            allLegacyScoringNodesSupportV2(
                legacyNodeIds = emptySet(),
                scoringV2NodeIds = setOf("orphan-v2"),
            )
        )
    }

    @Test
    fun startMatchPublicationClearsTheOppositeProtocolSlot() {
        assertEquals(
            "/rallymate/v2/start_match",
            oppositeStartMatchPath("/rallymate/start_match"),
        )
        assertEquals(
            "/rallymate/start_match",
            oppositeStartMatchPath("/rallymate/v2/start_match"),
        )
        assertNull(oppositeStartMatchPath("/rallymate/lifecycle"))
    }

    @Test
    fun startDispatchClockStaysMonotonicAcrossClockRollback() {
        assertEquals(101L, nextMonotonicDispatchAtMs(100L, 90L))
        assertEquals(150L, nextMonotonicDispatchAtMs(101L, 150L))
    }

    @Test
    fun onlyAuthenticatedEmptyAuthoritativeSnapshotMayBypassV2Capability() {
        assertTrue(
            permitsCapabilitylessScoringV2SnapshotClear(
                path = "/rallymate/v2/resumable",
                requestedClear = true,
                authoritative = true,
                authoritySource = "PHONE",
                authorityScope = "STAR_POINT",
                authorityVersion = 42,
                matchCount = 0,
            )
        )
        assertFalse(
            permitsCapabilitylessScoringV2SnapshotClear(
                path = "/rallymate/v2/resumable",
                requestedClear = true,
                authoritative = true,
                authoritySource = "PHONE",
                authorityScope = "STAR_POINT",
                authorityVersion = 42,
                matchCount = 1,
            )
        )
        assertFalse(
            permitsCapabilitylessScoringV2SnapshotClear(
                path = "/rallymate/v2/resumable",
                requestedClear = true,
                authoritative = false,
                authoritySource = "PHONE",
                authorityScope = "STAR_POINT",
                authorityVersion = 42,
                matchCount = 0,
            )
        )
    }

    @Test
    fun starPointEventsAreAcceptedOnlyOnCanonicalV2Path() {
        val star = format("STAR_POINT")

        assertFalse(acceptsWatchEventsPath(SCORING_EVENTS_V1_PATH, star))
        assertTrue(acceptsWatchEventsPath(SCORING_EVENTS_V2_PATH, star))
        assertFalse(
            acceptsWatchEventsPath(
                SCORING_EVENTS_V2_PATH,
                format("STAR_POINT", schemaVersion = 1),
            )
        )
        assertFalse(
            acceptsWatchEventsPath(
                SCORING_EVENTS_V2_PATH,
                JSONObject()
                    .put("formatSchemaVersion", 2)
                    .put("goldenPoint", false)
                    .toString(),
            )
        )
        assertFalse(
            acceptsWatchEventsPath(
                SCORING_EVENTS_V2_PATH,
                JSONObject(star).put("goldenPoint", true).toString(),
            )
        )
        assertFalse(
            acceptsWatchEventsPath(
                SCORING_EVENTS_V2_PATH,
                JSONObject(star).put("formatSchemaVersion", 2.5).toString(),
            )
        )
        // A watch on a newer build declares a higher schema and only adds
        // fields: it must not be rejected as a legacy payload.
        assertTrue(
            acceptsWatchEventsPath(
                SCORING_EVENTS_V2_PATH,
                JSONObject(star).put("formatSchemaVersion", 3).toString(),
            )
        )
        assertFalse(
            acceptsWatchEventsPath(
                SCORING_EVENTS_V2_PATH,
                JSONObject(star)
                    .put("formatSchemaVersion", 4_294_967_298L)
                    .toString(),
            )
        )
    }

    @Test
    fun advantageAndGoldenEventsRemainOnLegacyPath() {
        for (mode in listOf("ADVANTAGE", "GOLDEN_POINT")) {
            val payload = format(mode)
            assertTrue(acceptsWatchEventsPath(SCORING_EVENTS_V1_PATH, payload))
            assertFalse(acceptsWatchEventsPath(SCORING_EVENTS_V2_PATH, payload))
        }
        assertFalse(
            acceptsWatchEventsPath(
                SCORING_EVENTS_V1_PATH,
                JSONObject(format("ADVANTAGE"))
                    .put("goldenPoint", true)
                    .toString(),
            )
        )
        val preV2Format = JSONObject().put("goldenPoint", false).toString()
        assertTrue(acceptsWatchEventsPath(SCORING_EVENTS_V1_PATH, preV2Format))
        assertFalse(acceptsWatchEventsPath(SCORING_EVENTS_V2_PATH, preV2Format))
    }

    @Test
    fun eventAckAlwaysUsesTheSameProtocolLaneAsAcceptedEvents() {
        assertEquals(
            SCORING_EVENTS_ACK_V1_PATH,
            eventsAckPathFor(SCORING_EVENTS_V1_PATH),
        )
        assertEquals(
            SCORING_EVENTS_ACK_V2_PATH,
            eventsAckPathFor(SCORING_EVENTS_V2_PATH),
        )
        assertNull(eventsAckPathFor("/rallymate/v3/events"))
    }

    @Test
    fun starPointStateRecoveryNeverFallsBackToLegacyPath() {
        val star = format("STAR_POINT")
        assertFalse(acceptsRequestStatePath(SCORING_REQUEST_STATE_V1_PATH, star))
        assertTrue(acceptsRequestStatePath(SCORING_REQUEST_STATE_V2_PATH, star))
        assertEquals(
            SCORING_STATE_RESPONSE_V2_PATH,
            stateResponsePathFor(SCORING_REQUEST_STATE_V2_PATH),
        )

        // Pre-v2 watches sent only matchId and remain compatible on v1.
        assertTrue(acceptsRequestStatePath(SCORING_REQUEST_STATE_V1_PATH, null))
        assertFalse(acceptsRequestStatePath(SCORING_REQUEST_STATE_V2_PATH, null))
        assertEquals(
            SCORING_STATE_RESPONSE_V1_PATH,
            stateResponsePathFor(SCORING_REQUEST_STATE_V1_PATH),
        )
    }
}
