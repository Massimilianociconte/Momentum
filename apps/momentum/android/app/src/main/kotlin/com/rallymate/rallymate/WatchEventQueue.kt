package com.rallymate.rallymate

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Persistent handoff queue for watch events delivered while the Flutter engine
 * is not running. The Dart layer drains this queue on startup and performs the
 * idempotent DB merge.
 */
object WatchEventQueue {
    private const val PREFS = "rallymate_watch_queue"
    private const val KEY_PENDING_EVENTS = "pending_events"
    /** Hard cap: refuse new batches (no ACK) rather than unbounded SharedPreferences growth. */
    private const val MAX_BATCHES = 128
    private val lock = Any()
    private var lastDrainedIds: Set<String> = emptySet()

    /**
     * Durably queues a watch batch and returns the event ids that may be ACKed.
     * `null` means no durable commit happened, so the watch must retain/retry.
     */
    fun enqueueEvents(
        context: Context,
        matchId: String,
        events: String,
        format: String? = null,
    ): Set<String>? {
        val eventIds = eventIds(events)
        if (matchId.isBlank() || eventIds.isEmpty()) return null
        val item = JSONObject()
            .put("queueId", UUID.randomUUID().toString())
            .put("matchId", matchId)
            .put("events", events)
        if (!format.isNullOrBlank()) {
            item.put("format", format)
        }

        return synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val pending = try {
                JSONArray(prefs.getString(KEY_PENDING_EVENTS, "[]"))
            } catch (_: Exception) {
                // Preserve an unreadable queue for forensic/manual recovery. Do
                // not overwrite it and do not acknowledge the new watch batch.
                return@synchronized null
            }
            ensureQueueIds(pending)
            for (index in 0 until pending.length()) {
                val existing = pending.optJSONObject(index) ?: continue
                if (
                    existing.optString("matchId") == matchId &&
                    existing.optString("events") == events &&
                    existing.optString("format") == format.orEmpty()
                ) {
                    return@synchronized eventIds
                }
            }
            if (pending.length() >= MAX_BATCHES) {
                return@synchronized null
            }
            pending.put(item)
            val committed = prefs.edit()
                .putString(KEY_PENDING_EVENTS, pending.toString())
                .commit()
            eventIds.takeIf { committed }
        }
    }

    /**
     * Returns pending events without deleting them.
     *
     * Dart removes successfully imported items through [replace]. Keeping this
     * as peek-first makes app startup crash-safe: if Flutter dies mid-merge,
     * the queue is retried and repository inserts remain idempotent.
     */
    /**
     * Peek pending events. Returns `null` when storage is corrupt so Dart does
     * not treat the queue as empty and discard recovery.
     */
    fun pending(context: Context): String? {
        return synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING_EVENTS, null) ?: return@synchronized "[]"
            val snapshot = try {
                JSONArray(raw)
            } catch (_: Exception) {
                // Keep raw bytes; surface failure to Flutter (not empty success).
                return@synchronized null
            }
            val changed = ensureQueueIds(snapshot)
            if (changed && !prefs.edit()
                    .putString(KEY_PENDING_EVENTS, snapshot.toString())
                    .commit()
            ) {
                return@synchronized null
            }
            lastDrainedIds = queueIds(snapshot)
            snapshot.toString()
        }
    }

    /** Returns true when the replacement was durably committed. */
    fun replace(context: Context, pendingJson: String): Boolean {
        return synchronized(lock) {
            val replacement = try {
                JSONArray(pendingJson)
            } catch (_: Exception) {
                return@synchronized false
            }
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val current = try {
                JSONArray(prefs.getString(KEY_PENDING_EVENTS, "[]"))
            } catch (_: Exception) {
                return@synchronized false
            }
            ensureQueueIds(current)

            // `drainEvents` and `replaceQueuedEvents` are two method-channel
            // calls. Preserve batches committed between them instead of
            // overwriting those newly ACKed watch events with Dart's snapshot.
            val combined = JSONArray()
            val seen = mutableSetOf<String>()
            fun appendUnique(rows: JSONArray, include: (String) -> Boolean) {
                for (index in 0 until rows.length()) {
                    val item = rows.optJSONObject(index) ?: continue
                    val id = item.optString("queueId")
                    if (id.isBlank() || !include(id) || !seen.add(id)) continue
                    combined.put(item)
                }
            }
            appendUnique(replacement) { true }
            appendUnique(current) { it !in lastDrainedIds }

            val edit = prefs.edit()
            if (combined.length() == 0) {
                edit.remove(KEY_PENDING_EVENTS)
            } else {
                edit.putString(KEY_PENDING_EVENTS, combined.toString())
            }
            val committed = edit.commit()
            if (committed) lastDrainedIds = emptySet()
            committed
        }
    }

    fun eventIds(events: String): Set<String> = try {
        val rows = JSONArray(events)
        buildSet {
            for (index in 0 until rows.length()) {
                rows.optJSONObject(index)
                    ?.optString("eventId")
                    ?.takeIf { it.isNotBlank() && it.length <= 128 }
                    ?.let(::add)
            }
        }
    } catch (_: Exception) {
        emptySet()
    }

    private fun ensureQueueIds(rows: JSONArray): Boolean {
        var changed = false
        for (index in 0 until rows.length()) {
            val item = rows.optJSONObject(index) ?: continue
            if (item.optString("queueId").isBlank()) {
                item.put("queueId", UUID.randomUUID().toString())
                changed = true
            }
        }
        return changed
    }

    private fun queueIds(rows: JSONArray): Set<String> = buildSet {
        for (index in 0 until rows.length()) {
            rows.optJSONObject(index)
                ?.optString("queueId")
                ?.takeIf { it.isNotBlank() }
                ?.let(::add)
        }
    }
}
