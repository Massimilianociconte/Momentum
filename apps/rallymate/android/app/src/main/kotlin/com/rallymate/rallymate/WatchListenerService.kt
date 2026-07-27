package com.rallymate.rallymate

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONArray
import org.json.JSONObject

internal enum class BackgroundScoringMessageKind {
    EVENTS,
    REQUEST_STATE,
}

/**
 * Pure routing decision shared by the background receiver and its unit tests.
 *
 * The path is not trusted on its own: [acceptsWatchEventsPath] and
 * [acceptsRequestStatePath] also validate the canonical format for that lane.
 * This keeps a queued Star Point journal off the legacy path and prevents a
 * malformed/non-Star payload from entering the v2 lane.
 */
internal data class BackgroundScoringRoute(
    val kind: BackgroundScoringMessageKind,
    val replyPath: String,
)

internal fun backgroundScoringRoute(
    path: String,
    formatJson: String?,
): BackgroundScoringRoute? {
    if (acceptsWatchEventsPath(path, formatJson)) {
        return eventsAckPathFor(path)?.let {
            BackgroundScoringRoute(BackgroundScoringMessageKind.EVENTS, it)
        }
    }
    if (acceptsRequestStatePath(path, formatJson)) {
        return stateResponsePathFor(path)?.let {
            BackgroundScoringRoute(BackgroundScoringMessageKind.REQUEST_STATE, it)
        }
    }
    return null
}

/**
 * An ACK is valid only after [WatchEventQueue.enqueueEvents] has durably
 * committed the batch and returned its immutable event ids.
 */
internal fun acknowledgementPathAfterCommit(
    route: BackgroundScoringRoute,
    committedEventIds: Set<String>?,
): String? =
    route.replyPath.takeIf {
        route.kind == BackgroundScoringMessageKind.EVENTS &&
            !committedEventIds.isNullOrEmpty()
    }

/**
 * Receives Wear OS messages even when MainActivity is not in foreground.
 *
 * Events are queued locally and imported by Flutter on the next app startup or
 * resume. This preserves watch-originated scoring instead of dropping messages
 * when the phone app is closed.
 */
class WatchListenerService : WearableListenerService() {

    override fun onMessageReceived(event: MessageEvent) {
        when (event.path) {
            SCORING_EVENTS_V1_PATH,
            SCORING_EVENTS_V2_PATH,
            -> queueEvents(event)
            SCORING_REQUEST_STATE_V1_PATH,
            SCORING_REQUEST_STATE_V2_PATH,
            -> sendEmptyStateResponse(event)
        }
    }

    private fun queueEvents(event: MessageEvent) {
        try {
            val json = JSONObject(String(event.data))
            val matchId = json.optString("matchId").takeIf { it.isNotBlank() }
                ?: return
            val format = json.optString("format").takeIf { it.isNotBlank() }
                ?: return
            val route = backgroundScoringRoute(event.path, format)
                ?.takeIf { it.kind == BackgroundScoringMessageKind.EVENTS }
                ?: return
            val eventIds = WatchEventQueue.enqueueEvents(
                context = this,
                matchId = matchId,
                events = json.getString("events"),
                format = format,
            )
            val ackPath = acknowledgementPathAfterCommit(route, eventIds)
            if (ackPath != null) {
                sendEventsAck(
                    nodeId = event.sourceNodeId,
                    matchId = matchId,
                    eventIds = eventIds.orEmpty(),
                    path = ackPath,
                )
            }
        } catch (_: Exception) {
            // Ignore malformed wearable payloads; scoring data is validated on merge.
        }
    }

    private fun sendEventsAck(
        nodeId: String,
        matchId: String,
        eventIds: Set<String>,
        path: String,
    ) {
        val payload = JSONObject()
            .put("matchId", matchId)
            .put("eventIds", JSONArray(eventIds.toList()))
            .toString()
            .toByteArray()
        Wearable.getMessageClient(this)
            .sendMessage(nodeId, path, payload)
    }

    private fun sendEmptyStateResponse(event: MessageEvent) {
        try {
            val json = JSONObject(String(event.data))
            val matchId = json.optString("matchId").takeIf { it.isNotBlank() }
                ?: return
            val format = json.optString("format").takeIf { it.isNotBlank() }
            val route = backgroundScoringRoute(event.path, format)
                ?.takeIf { it.kind == BackgroundScoringMessageKind.REQUEST_STATE }
                ?: return
            val payload = JSONObject()
                .put("matchId", matchId)
                .put("events", "[]")
                .apply {
                    // Keep the requested lane explicit for diagnostics and for
                    // future receivers that validate response metadata too.
                    if (format != null) put("format", format)
                }
            Wearable.getMessageClient(this)
                .sendMessage(
                    event.sourceNodeId,
                    route.replyPath,
                    payload.toString().toByteArray(),
                )
        } catch (_: Exception) {
            // State recovery is best-effort when the phone app is not running.
        }
    }
}
