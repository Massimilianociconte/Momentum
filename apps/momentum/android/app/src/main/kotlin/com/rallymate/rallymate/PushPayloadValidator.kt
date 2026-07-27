package com.rallymate.rallymate

import java.net.URI

internal object PushPayloadValidator {
    private val safeIdentifier = Regex("^[A-Za-z0-9:_-]{1,160}$")
    private val controlCharacters = Regex("[\\u0000-\\u001F\\u007F]")
    private val allowedHosts = setOf(
        "auth-callback",
        "coach",
        "devices",
        "friends",
        "invite",
        "match",
        "recap",
        "social",
        "teams",
        "training",
    )

    fun identifier(value: String?): String? = value
        ?.trim()
        ?.takeIf { safeIdentifier.matches(it) }

    fun text(value: String?, maxLength: Int): String? = value
        ?.replace(controlCharacters, " ")
        ?.replace(Regex("\\s+"), " ")
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?.take(maxLength)

    fun payload(value: String?): String? = value
        ?.trim()
        ?.takeIf { it.length <= 4096 }

    fun deepLink(value: String?): String? {
        val candidate = value?.trim()?.takeIf { it.length in 1..512 } ?: return null
        val uri = runCatching { URI(candidate) }.getOrNull() ?: return null
        if (uri.scheme?.lowercase() != "rallymate" || uri.isOpaque) return null
        if (uri.userInfo != null || uri.port != -1 || uri.fragment != null) return null
        if (uri.host?.lowercase() !in allowedHosts) return null
        return candidate
    }

    fun category(kind: String?): String = text(kind, 64)
        ?.lowercase()
        ?.replace(Regex("[^a-z0-9_-]"), "_")
        ?: "status"
}
