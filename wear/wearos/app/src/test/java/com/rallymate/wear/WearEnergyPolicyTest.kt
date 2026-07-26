package com.rallymate.wear

import org.junit.Assert.assertEquals
import org.junit.Test

class WearEnergyPolicyTest {
    @Test
    fun discoveryBackoffGrowsAndCaps() {
        var delay = WearEnergyPolicy.INITIAL_DISCOVERY_BACKOFF_MS
        delay = WearEnergyPolicy.nextDiscoveryBackoff(delay)
        assertEquals(4_000L, delay)
        repeat(8) { delay = WearEnergyPolicy.nextDiscoveryBackoff(delay) }
        assertEquals(WearEnergyPolicy.MAX_DISCOVERY_BACKOFF_MS, delay)
    }
}
