package com.rallymate.wear

import android.content.Intent

/**
 * Every non-Activity entry point must converge on the launcher's one task.
 *
 * START_MATCH intentionally arrives twice (durable Data Item + live Message).
 * Combined with MainActivity's `singleTask` launch mode and default affinity,
 * these flags route both deliveries to the existing instance via onNewIntent
 * instead of leaving duplicate cards in Wear OS Recents.
 */
internal object MainActivityLaunchPolicy {
    const val EXTERNAL_ENTRY_FLAGS: Int =
        Intent.FLAG_ACTIVITY_NEW_TASK or
            Intent.FLAG_ACTIVITY_CLEAR_TOP or
            Intent.FLAG_ACTIVITY_SINGLE_TOP

    fun applyTo(intent: Intent): Intent = intent.addFlags(EXTERNAL_ENTRY_FLAGS)
}
