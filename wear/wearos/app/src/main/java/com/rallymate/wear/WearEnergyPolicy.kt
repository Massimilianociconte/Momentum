package com.rallymate.wear

/**
 * Work that affects scoring stays synchronous and local. These limits only
 * coalesce radio, disk and image work that does not need frame-level updates.
 */
object WearEnergyPolicy {
    const val SYNC_DEBOUNCE_MS = 180L
    const val NODE_CACHE_MS = 120_000L
    const val MAX_IMAGE_PIXELS = 256
    const val INITIAL_DISCOVERY_BACKOFF_MS = 2_000L
    const val MAX_DISCOVERY_BACKOFF_MS = 30_000L

    fun nextDiscoveryBackoff(currentMs: Long): Long =
        (currentMs * 2).coerceAtMost(MAX_DISCOVERY_BACKOFF_MS)
}
