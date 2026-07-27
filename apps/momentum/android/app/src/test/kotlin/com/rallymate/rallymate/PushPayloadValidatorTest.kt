package com.rallymate.rallymate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PushPayloadValidatorTest {
    @Test
    fun `accepts only routed RallyMate deep links`() {
        assertEquals(
            "rallymate://match/8a9b/duo",
            PushPayloadValidator.deepLink("rallymate://match/8a9b/duo"),
        )
        assertEquals(
            "rallymate://friends",
            PushPayloadValidator.deepLink("rallymate://friends"),
        )
        assertNull(PushPayloadValidator.deepLink("https://evil.example/path"))
        assertNull(PushPayloadValidator.deepLink("rallymate://unknown/path"))
        assertNull(PushPayloadValidator.deepLink("rallymate://user@friends/path"))
        assertNull(PushPayloadValidator.deepLink("rallymate://friends/path#fragment"))
    }

    @Test
    fun `normalizes bounded notification content`() {
        assertEquals("Invito RallyMate", PushPayloadValidator.text(" Invito\nRallyMate ", 80))
        assertEquals("friend_request", PushPayloadValidator.category("FRIEND REQUEST"))
        assertNull(PushPayloadValidator.identifier("not valid !"))
        assertEquals("friend:123", PushPayloadValidator.identifier("friend:123"))
    }

    @Test
    fun `rejects oversized provider data`() {
        assertNull(PushPayloadValidator.payload("x".repeat(4097)))
        assertNull(PushPayloadValidator.deepLink("rallymate://friends/" + "x".repeat(500)))
    }
}
