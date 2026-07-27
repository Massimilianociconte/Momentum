package com.rallymate.wear

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class WearAssistantCredentials(
    val endpoint: String,
    val publishableKey: String,
    val accessToken: String,
    val expiresAtMs: Long,
) {
    val usable: Boolean
        get() = endpoint.startsWith("https://") && publishableKey.isNotBlank() &&
            accessToken.isNotBlank() && expiresAtMs > System.currentTimeMillis() + 30_000
}

data class WearAssistantReply(
    val answer: String? = null,
    val sources: List<String> = emptyList(),
    val error: String? = null,
)

/** Short-lived Supabase session encrypted with a non-exportable Android Keystore key. */
class WearAssistantCredentialStore(context: Context) {
    private val prefs = context.getSharedPreferences("rallymate_assistant", Context.MODE_PRIVATE)

    fun save(value: WearAssistantCredentials) {
        if (!value.usable) {
            clear()
            return
        }
        runCatching {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey())
            val plaintext = JSONObject()
                .put("endpoint", value.endpoint)
                .put("publishableKey", value.publishableKey)
                .put("accessToken", value.accessToken)
                .put("expiresAtMs", value.expiresAtMs)
                .toString()
                .toByteArray(Charsets.UTF_8)
            val ciphertext = cipher.doFinal(plaintext)
            prefs.edit()
                .putString("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                .putString("payload", Base64.encodeToString(ciphertext, Base64.NO_WRAP))
                .commit()
        }.onFailure { clear() }
    }

    fun load(): WearAssistantCredentials? = runCatching {
        val iv = Base64.decode(prefs.getString("iv", null), Base64.NO_WRAP)
        val payload = Base64.decode(prefs.getString("payload", null), Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
        val json = JSONObject(String(cipher.doFinal(payload), Charsets.UTF_8))
        WearAssistantCredentials(
            endpoint = json.getString("endpoint"),
            publishableKey = json.getString("publishableKey"),
            accessToken = json.getString("accessToken"),
            expiresAtMs = json.getLong("expiresAtMs"),
        ).takeIf(WearAssistantCredentials::usable)
    }.getOrNull()

    fun clear() {
        prefs.edit().clear().apply()
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            .apply {
                init(
                    KeyGenParameterSpec.Builder(
                        KEY_ALIAS,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                    )
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setUserAuthenticationRequired(false)
                        .build(),
                )
            }
            .generateKey()
    }

    private companion object {
        const val KEY_ALIAS = "rallymate_watch_assistant_session"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}

class WearAssistantClient(
    private val credentials: WearAssistantCredentialStore,
) {
    suspend fun ask(
        question: String,
        matchId: String?,
        matchContext: String?,
    ): WearAssistantReply = withContext(Dispatchers.IO) {
        val credential = credentials.load()
            ?: return@withContext WearAssistantReply(
                error = "Apri Momentum sul telefono per attivare Pallino.",
            )
        val trimmed = question.trim().take(800)
        if (trimmed.isEmpty()) return@withContext WearAssistantReply(error = "Domanda vuota.")
        runCatching {
            val body = JSONObject()
                .put("question", trimmed)
                .put("mode", if (matchId == null) "RULES" else "LIVE_MATCH")
                .put("surface", "watch")
                .put("matchContext", matchContext.orEmpty().take(1_200))
                .apply { matchId?.let { put("matchId", it) } }
                .toString()
            val connection = (URL(credential.endpoint).openConnection() as HttpURLConnection)
                .apply {
                    requestMethod = "POST"
                    connectTimeout = 12_000
                    readTimeout = 38_000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Authorization", "Bearer ${credential.accessToken}")
                    setRequestProperty("apikey", credential.publishableKey)
                }
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val response = JSONObject(stream?.bufferedReader()?.use { it.readText() }.orEmpty())
            if (status !in 200..299) {
                return@runCatching WearAssistantReply(
                    error = errorMessage(response.optString("error"), status),
                )
            }
            val answer = response.optString("answer").trim()
            val sourceRows = response.optJSONArray("sources")
            val sources = if (sourceRows == null) emptyList() else {
                (0 until sourceRows.length()).mapNotNull { index ->
                    sourceRows.optJSONObject(index)?.optString("title")?.takeIf(String::isNotBlank)
                }.take(3)
            }
            WearAssistantReply(
                answer = answer.takeIf(String::isNotBlank),
                sources = sources,
                error = if (answer.isBlank()) "Risposta non disponibile." else null,
            )
        }.getOrElse {
            WearAssistantReply(error = "Nessuna rete. Usa le FAQ locali.")
        }
    }

    internal fun errorMessage(code: String, status: Int): String = when (code) {
        "plan_required", "assistant_disabled" -> "Pallino richiede il piano Pro."
        "daily_limit", "live_limit" -> "Limite domande raggiunto."
        "unauthorized" -> "Sessione scaduta. Avvicina il telefono."
        else -> if (status == 401) {
            "Sessione scaduta. Avvicina il telefono."
        } else {
            "Pallino non disponibile."
        }
    }
}
