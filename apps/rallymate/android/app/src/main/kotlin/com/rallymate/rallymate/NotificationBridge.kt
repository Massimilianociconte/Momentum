package com.rallymate.rallymate

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class NotificationBridge(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
) {
    private companion object {
        const val CHANNEL = "com.rallymate/notifications"
        const val REQ_POST_NOTIFICATIONS = 4517
        const val REGISTRATION_TIMEOUT_MS = 15_000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    // FCM registration touches FirebaseMessaging.setAutoInitEnabled/register,
    // which internally block on Tasks.await (fetchFid). Running that on the
    // platform main thread throws IllegalStateException("Must not be called on
    // the main application thread") and stalls app startup, so all Firebase
    // interaction is dispatched to this single background thread.
    private val registrationExecutor = Executors.newSingleThreadExecutor()
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingRemoteTokenResult: MethodChannel.Result? = null
    private var pendingInitialDeepLink: String? =
        RallyNotifications.deepLinkFromIntent(activity.intent)
    private val channel = MethodChannel(messenger, CHANNEL)
    private val registrationTimeout = Runnable {
        val pending = pendingRemoteTokenResult ?: return@Runnable
        pendingRemoteTokenResult = null
        pending.error(
            "token_unavailable",
            "FCM registration timed out",
            null,
        )
    }
    private val tokenListener: (String) -> Unit = { installationId ->
        val payload = remoteTokenPayload(installationId)
        pendingRemoteTokenResult?.let { pending ->
            pendingRemoteTokenResult = null
            mainHandler.removeCallbacks(registrationTimeout)
            pending.success(payload)
        }
        channel.invokeMethod("remoteTokenChanged", payload)
    }

    init {
        RemotePushRegistrationEvents.attach(tokenListener)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(RallyNotifications.status(activity))
                "requestPermission" -> requestPermission(result)
                "registerRemote" -> registerRemote(result)
                "unregisterRemote" -> unregisterRemote(result)
                "initialNotification" -> {
                    result.success(pendingInitialDeepLink)
                    pendingInitialDeepLink = null
                }
                "show" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("bad_args", "Missing notification payload", null)
                    } else {
                        result.success(RallyNotifications.post(activity, args))
                    }
                }
                "schedule" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("bad_args", "Missing notification payload", null)
                    } else {
                        result.success(RallyNotifications.schedule(activity, args))
                    }
                }
                "cancel" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("bad_args", "id required", null)
                    } else {
                        RallyNotifications.cancel(activity, id)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onNewIntent(intent: Intent) {
        val deepLink = RallyNotifications.deepLinkFromIntent(intent) ?: return
        pendingInitialDeepLink = deepLink
        channel.invokeMethod("notificationOpened", deepLink)
    }

    fun dispose() {
        RemotePushRegistrationEvents.detach(tokenListener)
        channel.setMethodCallHandler(null)
        pendingPermissionResult = null
        pendingRemoteTokenResult = null
        mainHandler.removeCallbacks(registrationTimeout)
        registrationExecutor.shutdown()
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        _grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQ_POST_NOTIFICATIONS) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        result.success(RallyNotifications.status(activity))
        return true
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(RallyNotifications.status(activity))
            return
        }
        if (ActivityCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(RallyNotifications.status(activity))
            return
        }
        if (pendingPermissionResult != null) {
            result.error("busy", "Notification permission request already pending", null)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQ_POST_NOTIFICATIONS,
        )
    }

    private fun registerRemote(result: MethodChannel.Result) {
        if (RallyNotifications.status(activity)["granted"] != true) {
            result.error("permission_required", "Notification permission required", null)
            return
        }
        if (FirebaseApp.getApps(activity).isEmpty()) {
            result.error("firebase_not_configured", "Firebase client configuration missing", null)
            return
        }
        if (pendingRemoteTokenResult != null) {
            result.error("busy", "Push token registration already pending", null)
            return
        }
        pendingRemoteTokenResult = result
        mainHandler.postDelayed(registrationTimeout, REGISTRATION_TIMEOUT_MS)
        // Dispatch off the main thread: setAutoInitEnabled(true) synchronously
        // triggers startSyncIfNecessary -> fetchFid -> Tasks.await, which is
        // illegal on the main thread. The success path returns via
        // RemotePushRegistrationEvents (already marshalled to main).
        registrationExecutor.execute {
            try {
                val messaging = FirebaseMessaging.getInstance()
                if (!messaging.isAutoInitEnabled) {
                    messaging.setAutoInitEnabled(true)
                }
                messaging.register()
                    .addOnFailureListener { error ->
                        failRegistration(error.localizedMessage)
                    }
            } catch (t: Throwable) {
                failRegistration(t.localizedMessage ?: "FCM registration failed")
            }
        }
    }

    private fun failRegistration(message: String?) {
        mainHandler.post {
            val pending = pendingRemoteTokenResult ?: return@post
            pendingRemoteTokenResult = null
            mainHandler.removeCallbacks(registrationTimeout)
            pending.error("token_unavailable", message, null)
        }
    }

    private fun unregisterRemote(result: MethodChannel.Result) {
        pendingRemoteTokenResult?.error(
            "registration_cancelled",
            "FCM registration cancelled",
            null,
        )
        pendingRemoteTokenResult = null
        mainHandler.removeCallbacks(registrationTimeout)
        if (FirebaseApp.getApps(activity).isEmpty()) {
            result.success(null)
            return
        }
        val messaging = FirebaseMessaging.getInstance()
        messaging.setAutoInitEnabled(false)
        messaging.unregister()
            .addOnCompleteListener { result.success(null) }
    }

    private fun remoteTokenPayload(token: String): Map<String, String> = mapOf(
        "token" to token,
        "platform" to "ANDROID",
        "transport" to "FCM",
        "environment" to "PRODUCTION",
    )
}

object RallyNotifications {
    private const val CHANNEL_ID = "padelandia_status"
    private const val CHANNEL_NAME = "Momentum"
    private const val WORK_PREFIX = "rallymate_notification_"

    fun status(context: Context): Map<String, Any> {
        val manager = NotificationManagerCompat.from(context)
        val runtimeGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        val enabled = manager.areNotificationsEnabled() && runtimeGranted
        return mapOf(
            "status" to if (enabled) "granted" else "denied",
            "granted" to enabled,
            "canRequest" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !runtimeGranted),
        )
    }

    fun schedule(context: Context, args: Map<*, *>): Boolean {
        val id = args["id"] as? String ?: return false
        val scheduledAtMs = (args["scheduledAtMs"] as? Number)?.toLong() ?: return false
        val delayMs = (scheduledAtMs - System.currentTimeMillis()).coerceAtLeast(0L)
        val data = Data.Builder()
            .putString("id", id)
            .putString("title", args["title"] as? String ?: "")
            .putString("body", args["body"] as? String ?: "")
            .putString("category", args["category"] as? String ?: "reminder")
            .putString("payload", args["payload"] as? String)
            .build()
        val request = OneTimeWorkRequestBuilder<RallyNotificationWorker>()
            .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
            .setInputData(data)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            WORK_PREFIX + id,
            ExistingWorkPolicy.REPLACE,
            request,
        )
        return true
    }

    fun cancel(context: Context, id: String) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_PREFIX + id)
        NotificationManagerCompat.from(context).cancel(notificationId(id))
    }

    @SuppressLint("MissingPermission")
    fun post(context: Context, args: Map<*, *>): Boolean {
        if (status(context)["granted"] != true) return false
        val id = args["id"] as? String ?: return false
        val title = args["title"] as? String ?: return false
        val body = args["body"] as? String ?: ""
        val category = args["category"] as? String ?: "status"
        val deepLink = PushPayloadValidator.deepLink(args["deep_link"] as? String)
            ?: PushPayloadValidator.deepLink(args["payload"] as? String)
        ensureChannel(context)

        val launch = Intent(context, MainActivity::class.java).apply {
            action = if (deepLink != null) Intent.ACTION_VIEW else Intent.ACTION_MAIN
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            deepLink?.let {
                data = Uri.parse(it)
                putExtra("notification_deep_link", it)
            }
            putExtra("notification_id", id)
            putExtra("notification_category", category)
            (args["payload"] as? String)?.let { putExtra("notification_payload", it) }
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId("open_$id"),
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_rallymate)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .addAction(R.drawable.ic_stat_rallymate, "Apri Momentum", pendingIntent)
            .setAutoCancel(true)
            .setCategory(nativeCategory(category))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        NotificationManagerCompat.from(context).notify(notificationId(id), notification)
        return true
    }

    fun deepLinkFromIntent(intent: Intent?): String? =
        PushPayloadValidator.deepLink(intent?.dataString)
            ?: PushPayloadValidator.deepLink(intent?.getStringExtra("notification_deep_link"))
            ?: PushPayloadValidator.deepLink(intent?.getStringExtra("notification_payload"))

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        runCatching { manager.deleteNotificationChannel("rallymate_status") }
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Aggiornamenti partita, allenamento e riepiloghi Momentum"
            },
        )
    }

    private fun nativeCategory(category: String): String = when (category) {
        "match", "training", "recap" -> NotificationCompat.CATEGORY_STATUS
        "reminder" -> NotificationCompat.CATEGORY_REMINDER
        else -> NotificationCompat.CATEGORY_STATUS
    }

    private fun notificationId(id: String): Int = id.hashCode() and 0x7fffffff
}
