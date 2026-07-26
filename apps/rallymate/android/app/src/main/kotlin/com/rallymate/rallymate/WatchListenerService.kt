package com.rallymate.rallymate

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONArray
import org.json.JSONObject

/**
 * Receives Wear OS messages even when MainActivity is not in foreground.
 *
 * Events are queued locally and imported by Flutter on the next app startup or
 * resume. This preserves watch-originated scoring instead of dropping messages
 * when the phone app is closed.
 */
class WatchListenerService : WearableListenerService() {

    private companion object {
        const val PATH_EVENTS = "/rallymate/events"
        const val PATH_EVENTS_ACK = "/rallymate/events_ack"
        const val PATH_REQUEST_STATE = "/rallymate/request_state"
        const val PATH_STATE_RESPONSE = "/rallymate/state_response"
    }

    override fun onMessageReceived(event: MessageEvent) {
        when (event.path) {
            PATH_EVENTS -> queueEvents(event)
            PATH_REQUEST_STATE -> sendEmptyStateResponse(event)
        }
    }

    private fun queueEvents(event: MessageEvent) {
        try {
            val json = JSONObject(String(event.data))
            val matchId = json.getString("matchId")
            val eventIds = WatchEventQueue.enqueueEvents(
                context = this,
                matchId = matchId,
                events = json.getString("events"),
                format = json.optString("format").takeIf { it.isNotBlank() },
            )
            if (!eventIds.isNullOrEmpty()) {
                sendEventsAck(event.sourceNodeId, matchId, eventIds)
            }
        } catch (_: Exception) {
            // Ignore malformed wearable payloads; scoring data is validated on merge.
        }
    }

    private fun sendEventsAck(nodeId: String, matchId: String, eventIds: Set<String>) {
        val payload = JSONObject()
            .put("matchId", matchId)
            .put("eventIds", JSONArray(eventIds.toList()))
            .toString()
            .toByteArray()
        Wearable.getMessageClient(this)
            .sendMessage(nodeId, PATH_EVENTS_ACK, payload)
    }

    private fun sendEmptyStateResponse(event: MessageEvent) {
        try {
            val json = JSONObject(String(event.data))
            val matchId = json.getString("matchId")
            val payload = JSONObject()
                .put("matchId", matchId)
                .put("events", "[]")
            Wearable.getMessageClient(this)
                .sendMessage(
                    event.sourceNodeId,
                    PATH_STATE_RESPONSE,
                    payload.toString().toByteArray(),
                )
        } catch (_: Exception) {
            // State recovery is best-effort when the phone app is not running.
        }
    }
}
