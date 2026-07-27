package com.rallymate.rallymate

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BackgroundScoringRoutingTest {

    private fun format(
        mode: String,
        schemaVersion: Int = 2,
        goldenPoint: Boolean = mode == "GOLDEN_POINT",
    ): String = JSONObject()
        .put("formatSchemaVersion", schemaVersion)
        .put("gameScoringMode", mode)
        .put("goldenPoint", goldenPoint)
        .toString()

    @Test
    fun backgroundStarPointV2UsesMatchingAckAndStateResponsePaths() {
        val starPoint = format("STAR_POINT")

        assertEquals(
            BackgroundScoringRoute(
                kind = BackgroundScoringMessageKind.EVENTS,
                replyPath = SCORING_EVENTS_ACK_V2_PATH,
            ),
            backgroundScoringRoute(SCORING_EVENTS_V2_PATH, starPoint),
        )
        assertEquals(
            BackgroundScoringRoute(
                kind = BackgroundScoringMessageKind.REQUEST_STATE,
                replyPath = SCORING_STATE_RESPONSE_V2_PATH,
            ),
            backgroundScoringRoute(SCORING_REQUEST_STATE_V2_PATH, starPoint),
        )
    }

    @Test
    fun backgroundReceiverRejectsStarPointOnLegacyPaths() {
        val starPoint = format("STAR_POINT")

        assertNull(backgroundScoringRoute(SCORING_EVENTS_V1_PATH, starPoint))
        assertNull(backgroundScoringRoute(SCORING_REQUEST_STATE_V1_PATH, starPoint))
    }

    @Test
    fun backgroundReceiverRejectsNonStarAndMalformedPayloadsOnV2Paths() {
        val advantage = format("ADVANTAGE")
        val malformedStarPoint = format(
            mode = "STAR_POINT",
            schemaVersion = 1,
        )
        val incoherentStarPoint = format(
            mode = "STAR_POINT",
            goldenPoint = true,
        )

        for (payload in listOf(advantage, malformedStarPoint, incoherentStarPoint, "{")) {
            assertNull(backgroundScoringRoute(SCORING_EVENTS_V2_PATH, payload))
            assertNull(backgroundScoringRoute(SCORING_REQUEST_STATE_V2_PATH, payload))
        }
        assertNull(backgroundScoringRoute(SCORING_EVENTS_V2_PATH, null))
        assertNull(backgroundScoringRoute(SCORING_REQUEST_STATE_V2_PATH, null))
    }

    @Test
    fun eventAckIsExposedOnlyAfterDurableQueueCommit() {
        val route = requireNotNull(
            backgroundScoringRoute(
                SCORING_EVENTS_V2_PATH,
                format("STAR_POINT"),
            )
        )

        assertNull(acknowledgementPathAfterCommit(route, null))
        assertNull(acknowledgementPathAfterCommit(route, emptySet()))
        assertEquals(
            SCORING_EVENTS_ACK_V2_PATH,
            acknowledgementPathAfterCommit(route, setOf("event-1")),
        )
    }

    @Test
    fun legacyBackgroundRecoveryWithoutFormatRemainsCompatible() {
        assertEquals(
            BackgroundScoringRoute(
                kind = BackgroundScoringMessageKind.REQUEST_STATE,
                replyPath = SCORING_STATE_RESPONSE_V1_PATH,
            ),
            backgroundScoringRoute(SCORING_REQUEST_STATE_V1_PATH, null),
        )
    }
}
