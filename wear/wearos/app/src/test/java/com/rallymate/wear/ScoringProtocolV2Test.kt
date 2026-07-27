package com.rallymate.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScoringProtocolV2Test {

    @Test
    fun pongAdvertisesStarPointProtocolCapability() {
        val payload = scoringPongPayload(
            nonce = "nonce-1",
            kind = SyncPaths.PING,
        )

        assertEquals("nonce-1", payload.getString("nonce"))
        assertEquals(SyncPaths.PING, payload.getString("kind"))
        assertEquals(2, payload.getInt("scoringProtocolVersion"))
        assertEquals(
            "star_point_v1",
            payload.getJSONArray("scoringCapabilities").getString(0),
        )
    }

    @Test
    fun versionedPathsAreDistinctAndRecognizedAlongsideLegacyPaths() {
        assertFalse(SyncPaths.START_MATCH == SyncPaths.START_MATCH_V2)
        assertFalse(SyncPaths.RESUMABLE == SyncPaths.RESUMABLE_V2)
        assertFalse(SyncPaths.LIFECYCLE == SyncPaths.LIFECYCLE_V2)
        assertFalse(SyncPaths.EVENTS == SyncPaths.EVENTS_V2)
        assertFalse(SyncPaths.EVENTS_ACK == SyncPaths.EVENTS_ACK_V2)
        assertFalse(SyncPaths.REQUEST_STATE == SyncPaths.REQUEST_STATE_V2)
        assertFalse(SyncPaths.STATE_RESPONSE == SyncPaths.STATE_RESPONSE_V2)

        assertTrue(SyncPaths.isStartMatch(SyncPaths.START_MATCH))
        assertTrue(SyncPaths.isStartMatch(SyncPaths.START_MATCH_V2))
        assertTrue(SyncPaths.isResumable(SyncPaths.RESUMABLE))
        assertTrue(SyncPaths.isResumable(SyncPaths.RESUMABLE_V2))
        assertTrue(SyncPaths.isLifecycle(SyncPaths.LIFECYCLE))
        assertTrue(SyncPaths.isLifecycle(SyncPaths.LIFECYCLE_V2))
    }

    @Test
    fun starPointOutboundAndEveryRetryStayOnV2Lane() {
        val attempts = List(4) {
            SyncPaths.scoringTransport(MatchFormat.STAR_POINT_BO3)
        }

        assertTrue(attempts.all { it.events == SyncPaths.EVENTS_V2 })
        assertTrue(attempts.all { it.eventsAck == SyncPaths.EVENTS_ACK_V2 })
        assertTrue(attempts.all { it.requestState == SyncPaths.REQUEST_STATE_V2 })
        assertTrue(attempts.all { it.stateResponse == SyncPaths.STATE_RESPONSE_V2 })
        assertFalse(attempts.any { it.events == SyncPaths.EVENTS })
    }

    @Test
    fun advantageAndGoldenPointRemainOnLegacyLane() {
        for (format in listOf(MatchFormat.ADVANTAGE_BO3, MatchFormat.GOLDEN_BO3)) {
            val transport = SyncPaths.scoringTransport(format)
            assertEquals(SyncPaths.EVENTS, transport.events)
            assertEquals(SyncPaths.EVENTS_ACK, transport.eventsAck)
            assertEquals(SyncPaths.REQUEST_STATE, transport.requestState)
            assertEquals(SyncPaths.STATE_RESPONSE, transport.stateResponse)
        }
    }

    @Test
    fun legacyAckCannotCommitPendingStarPointRetry() {
        val waiter = EventAckRegistry.register(
            matchId = "star-pending",
            expectedIds = setOf("event-star"),
            expectedAckPath = SyncPaths.EVENTS_ACK_V2,
        )

        EventAckRegistry.acknowledge(
            matchId = "star-pending",
            eventIds = setOf("event-star"),
            ackPath = SyncPaths.EVENTS_ACK,
        )
        assertFalse(waiter.result.isCompleted)

        EventAckRegistry.acknowledge(
            matchId = "star-pending",
            eventIds = setOf("event-star"),
            ackPath = SyncPaths.EVENTS_ACK_V2,
        )
        assertTrue(waiter.result.isCompleted)
    }

    @Test
    fun newerStartMatchWinsRegardlessOfPersistentPathRedeliveryOrder() {
        assertEquals(
            StartMatchDeliveryDecision.APPLY,
            startMatchDeliveryDecision(
                incomingDispatchedAtMs = 20,
                incomingMatchId = "new-match",
                lastDispatchedAtMs = 10,
                lastMatchId = "old-match",
            ),
        )
        assertEquals(
            StartMatchDeliveryDecision.STALE,
            startMatchDeliveryDecision(
                incomingDispatchedAtMs = 10,
                incomingMatchId = "old-match",
                lastDispatchedAtMs = 20,
                lastMatchId = "new-match",
            ),
        )
    }

    @Test
    fun liveAndDurableCopiesOfSameStartAreIdempotent() {
        assertEquals(
            StartMatchDeliveryDecision.IDEMPOTENT,
            startMatchDeliveryDecision(
                incomingDispatchedAtMs = 20,
                incomingMatchId = "same-match",
                lastDispatchedAtMs = 20,
                lastMatchId = "same-match",
            ),
        )
    }

    @Test
    fun legacyStartCannotOverwriteAnAcceptedVersionedStart() {
        assertEquals(
            StartMatchDeliveryDecision.STALE,
            startMatchDeliveryDecision(
                incomingDispatchedAtMs = 0,
                incomingMatchId = "legacy-stale",
                lastDispatchedAtMs = 20,
                lastMatchId = "new-match",
            ),
        )
        assertEquals(
            StartMatchDeliveryDecision.APPLY,
            startMatchDeliveryDecision(
                incomingDispatchedAtMs = 0,
                incomingMatchId = "legacy-first-install",
                lastDispatchedAtMs = 0,
                lastMatchId = null,
            ),
        )
        assertEquals(
            StartMatchDeliveryDecision.APPLY,
            startMatchDeliveryDecision(
                incomingDispatchedAtMs = 0,
                incomingMatchId = "legacy-resend",
                lastDispatchedAtMs = 0,
                lastMatchId = "legacy-resend",
            ),
        )
    }
}
