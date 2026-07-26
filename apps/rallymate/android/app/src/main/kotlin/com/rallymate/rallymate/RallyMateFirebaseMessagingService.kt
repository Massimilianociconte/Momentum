package com.rallymate.rallymate

import android.os.Handler
import android.os.Looper
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

internal object RemotePushRegistrationEvents {
    @Volatile
    private var listener: ((String) -> Unit)? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(value: (String) -> Unit) {
        listener = value
    }

    fun detach(value: (String) -> Unit) {
        if (listener === value) listener = null
    }

    fun publish(token: String) {
        val safeToken = token.trim().takeIf {
            it.length in 20..4096 && it.none(Char::isWhitespace)
        } ?: return
        mainHandler.post { listener?.invoke(safeToken) }
    }
}

class RallyMateFirebaseMessagingService : FirebaseMessagingService() {
    override fun onRegistered(installationId: String) {
        super.onRegistered(installationId)
        RemotePushRegistrationEvents.publish(installationId)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val id = PushPayloadValidator.identifier(data["notification_id"])
            ?: PushPayloadValidator.identifier(message.messageId)
            ?: return
        val title = PushPayloadValidator.text(data["title"], 80) ?: return
        val body = PushPayloadValidator.text(data["body"], 220).orEmpty()
        val args = mutableMapOf<String, Any?>(
            "id" to id,
            "title" to title,
            "body" to body,
            "category" to PushPayloadValidator.category(data["kind"]),
        )
        PushPayloadValidator.deepLink(data["deep_link"])?.let {
            args["deep_link"] = it
        }
        PushPayloadValidator.payload(data["payload"])?.let {
            args["payload"] = it
        }
        RallyNotifications.post(applicationContext, args)
    }
}
