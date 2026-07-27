package com.rallymate.wear

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.health.services.client.HealthServices
import androidx.health.services.client.PassiveListenerService
import androidx.health.services.client.data.ExerciseInfo
import androidx.health.services.client.data.ExerciseTrackedStatus
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.PassiveListenerConfig
import androidx.health.services.client.data.UserActivityInfo
import androidx.health.services.client.data.UserActivityState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch

enum class WorkoutDetectionMode {
    OFF,
    ASK,
    QUICK_START;

    companion object {
        fun fromWire(value: String?): WorkoutDetectionMode =
            entries.firstOrNull { it.name == value } ?: OFF
    }
}

data class WorkoutDetectionPreferences(
    val mode: WorkoutDetectionMode = WorkoutDetectionMode.OFF,
    val racketSportsOnly: Boolean = true,
    // Reserved in the shared contract. No undocumented worn-state heuristic
    // is used by the current implementation.
    val onlyWhenWorn: Boolean = false,
) {
    val enabled: Boolean get() = mode != WorkoutDetectionMode.OFF
}

data class DetectedWorkout(
    val exerciseTypeId: Int,
    val exerciseTypeName: String,
    val startedAtMs: Long,
) {
    val fingerprint: String get() = "$exerciseTypeId:$startedAtMs"

    val displayName: String
        get() = when (exerciseTypeName) {
            ExerciseType.TENNIS.name -> "Tennis"
            ExerciseType.BADMINTON.name -> "Badminton"
            ExerciseType.RACQUETBALL.name -> "Racquetball"
            ExerciseType.SQUASH.name -> "Squash"
            ExerciseType.TABLE_TENNIS.name -> "Tennistavolo"
            else -> "Allenamento"
        }
}

object WorkoutDetectionPolicy {
    private val racketTypes = setOf(
        ExerciseType.TENNIS.name,
        ExerciseType.BADMINTON.name,
        ExerciseType.RACQUETBALL.name,
        ExerciseType.SQUASH.name,
        ExerciseType.TABLE_TENNIS.name,
    )

    fun shouldPrompt(
        preferences: WorkoutDetectionPreferences,
        trackedStatus: Int,
        exerciseTypeName: String,
        fingerprint: String,
        ignoredFingerprint: String?,
        activeRallyMateMatch: Boolean,
    ): Boolean {
        if (!preferences.enabled || activeRallyMateMatch) return false
        if (trackedStatus != ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS) return false
        if (fingerprint == ignoredFingerprint) return false
        return !preferences.racketSportsOnly || exerciseTypeName in racketTypes
    }
}

class WorkoutDetectionStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun savePreferences(value: WorkoutDetectionPreferences) {
        prefs.edit()
            .putString(KEY_MODE, value.mode.name)
            .putBoolean(KEY_RACKET_ONLY, value.racketSportsOnly)
            .putBoolean(KEY_WORN_ONLY, value.onlyWhenWorn)
            .apply()
    }

    fun loadPreferences(): WorkoutDetectionPreferences =
        WorkoutDetectionPreferences(
            mode = WorkoutDetectionMode.fromWire(prefs.getString(KEY_MODE, null)),
            racketSportsOnly = prefs.getBoolean(KEY_RACKET_ONLY, true),
            onlyWhenWorn = prefs.getBoolean(KEY_WORN_ONLY, false),
        )

    fun savePending(candidate: DetectedWorkout): Boolean {
        if (prefs.getString(KEY_LAST_HANDLED, null) == candidate.fingerprint) return false
        prefs.edit()
            .putInt(KEY_PENDING_TYPE_ID, candidate.exerciseTypeId)
            .putString(KEY_PENDING_TYPE_NAME, candidate.exerciseTypeName)
            .putLong(KEY_PENDING_STARTED_AT, candidate.startedAtMs)
            .putString(KEY_LAST_HANDLED, candidate.fingerprint)
            .apply()
        return true
    }

    fun pending(): DetectedWorkout? {
        val startedAt = prefs.getLong(KEY_PENDING_STARTED_AT, 0L)
        val name = prefs.getString(KEY_PENDING_TYPE_NAME, null)
        if (startedAt <= 0L || name.isNullOrBlank()) return null
        return DetectedWorkout(
            exerciseTypeId = prefs.getInt(KEY_PENDING_TYPE_ID, ExerciseType.UNKNOWN.id),
            exerciseTypeName = name,
            startedAtMs = startedAt,
        )
    }

    fun clearPending() {
        prefs.edit()
            .remove(KEY_PENDING_TYPE_ID)
            .remove(KEY_PENDING_TYPE_NAME)
            .remove(KEY_PENDING_STARTED_AT)
            .apply()
    }

    fun ignore(candidate: DetectedWorkout?) {
        prefs.edit().apply {
            candidate?.let { putString(KEY_IGNORED_FINGERPRINT, it.fingerprint) }
            remove(KEY_PENDING_TYPE_ID)
            remove(KEY_PENDING_TYPE_NAME)
            remove(KEY_PENDING_STARTED_AT)
        }.apply()
    }

    fun ignoredFingerprint(): String? =
        prefs.getString(KEY_IGNORED_FINGERPRINT, null)

    fun saveRegistrationStatus(status: String) {
        prefs.edit().putString(KEY_REGISTRATION_STATUS, status).apply()
    }

    fun registrationStatus(): String =
        prefs.getString(KEY_REGISTRATION_STATUS, "DISABLED") ?: "DISABLED"

    companion object {
        private const val PREFS = "rallymate_workout_detection"
        private const val KEY_MODE = "mode"
        private const val KEY_RACKET_ONLY = "racket_only"
        private const val KEY_WORN_ONLY = "worn_only"
        private const val KEY_PENDING_TYPE_ID = "pending_type_id"
        private const val KEY_PENDING_TYPE_NAME = "pending_type_name"
        private const val KEY_PENDING_STARTED_AT = "pending_started_at"
        private const val KEY_LAST_HANDLED = "last_handled_fingerprint"
        private const val KEY_IGNORED_FINGERPRINT = "ignored_fingerprint"
        private const val KEY_REGISTRATION_STATUS = "registration_status"
    }
}

object WorkoutDetectionIntents {
    const val ACTION_QUICK_START = "com.rallymate.wear.action.DETECTED_QUICK_START"
    const val ACTION_CONFIGURE = "com.rallymate.wear.action.DETECTED_CONFIGURE"
    const val ACTION_IGNORE = "com.rallymate.wear.action.DETECTED_IGNORE"
}

object WorkoutDetectionManager {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun applyPreferences(context: Context, preferences: WorkoutDetectionPreferences) {
        val appContext = context.applicationContext
        WorkoutDetectionStore(appContext).savePreferences(preferences)
        ensureRegistration(appContext, inspectCurrentExercise = false)
    }

    fun ensureRegistration(context: Context, inspectCurrentExercise: Boolean = true) {
        val appContext = context.applicationContext
        val store = WorkoutDetectionStore(appContext)
        val preferences = store.loadPreferences()
        val client = HealthServices.getClient(appContext).passiveMonitoringClient
        if (!preferences.enabled) {
            scope.launch {
                runCatching { client.clearPassiveListenerServiceAsync().await() }
                store.saveRegistrationStatus("DISABLED")
            }
            return
        }
        if (!hasActivityRecognitionPermission(appContext)) {
            store.saveRegistrationStatus("PERMISSION_REQUIRED")
            return
        }
        scope.launch {
            runCatching {
                val capabilities = client.getCapabilitiesAsync().await()
                check(
                    UserActivityState.USER_ACTIVITY_EXERCISE in
                        capabilities.supportedUserActivityStates
                )
                val config = PassiveListenerConfig.builder()
                    .setShouldUserActivityInfoBeRequested(true)
                    .build()
                client.setPassiveListenerServiceAsync(
                    RacketWorkoutDetectionService::class.java,
                    config,
                ).await()
                store.saveRegistrationStatus("READY")
                if (inspectCurrentExercise) inspectCurrentExercise(appContext)
            }.onFailure {
                store.saveRegistrationStatus("UNAVAILABLE")
            }
        }
    }

    private suspend fun inspectCurrentExercise(context: Context) {
        val info = runCatching {
            HealthServices.getClient(context).exerciseClient
                .getCurrentExerciseInfoAsync().await()
        }.getOrNull() ?: return
        processExerciseInfo(context, info, System.currentTimeMillis())
    }

    fun processUserActivity(context: Context, info: UserActivityInfo) {
        if (info.userActivityState != UserActivityState.USER_ACTIVITY_EXERCISE) return
        val exerciseInfo = info.exerciseInfo ?: return
        processExerciseInfo(context, exerciseInfo, info.stateChangeTime.toEpochMilli())
    }

    fun processExerciseInfo(context: Context, info: ExerciseInfo, startedAtMs: Long) {
        val appContext = context.applicationContext
        val candidate = DetectedWorkout(
            exerciseTypeId = info.exerciseType.id,
            exerciseTypeName = info.exerciseType.name,
            startedAtMs = startedAtMs.coerceAtLeast(1L),
        )
        val store = WorkoutDetectionStore(appContext)
        val shouldPrompt = WorkoutDetectionPolicy.shouldPrompt(
            preferences = store.loadPreferences(),
            trackedStatus = info.exerciseTrackedStatus,
            exerciseTypeName = candidate.exerciseTypeName,
            fingerprint = candidate.fingerprint,
            ignoredFingerprint = store.ignoredFingerprint(),
            activeRallyMateMatch = LocalMatchStore(appContext).activeMatchId() != null,
        )
        if (!shouldPrompt || !store.savePending(candidate)) return
        WorkoutDetectionNotification.show(appContext, candidate)
    }

    fun hasActivityRecognitionPermission(context: Context): Boolean =
        ActivityCompat.checkSelfPermission(
            context,
            Manifest.permission.ACTIVITY_RECOGNITION,
        ) == PackageManager.PERMISSION_GRANTED
}

class RacketWorkoutDetectionService : PassiveListenerService() {
    override fun onUserActivityInfoReceived(info: UserActivityInfo) {
        WorkoutDetectionManager.processUserActivity(this, info)
    }

    override fun onPermissionLost() {
        WorkoutDetectionStore(this).saveRegistrationStatus("PERMISSION_REQUIRED")
    }
}

class WorkoutDetectionActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != WorkoutDetectionIntents.ACTION_IGNORE) return
        val store = WorkoutDetectionStore(context)
        store.ignore(store.pending())
        NotificationManagerCompat.from(context).cancel(
            WorkoutDetectionNotification.NOTIFICATION_ID,
        )
    }
}

object WorkoutDetectionNotification {
    const val NOTIFICATION_ID = 91
    private const val CHANNEL_ID = "rallymate_workout_detection"

    fun show(context: Context, candidate: DetectedWorkout) {
        if (!notificationsAllowed(context)) return
        createChannel(context)
        val configureIntent = PendingIntent.getActivity(
            context,
            910,
            MainActivityLaunchPolicy.applyTo(
                Intent(context, MainActivity::class.java)
                    .setAction(WorkoutDetectionIntents.ACTION_CONFIGURE)
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val quickStartIntent = PendingIntent.getActivity(
            context,
            911,
            MainActivityLaunchPolicy.applyTo(
                Intent(context, MainActivity::class.java)
                    .setAction(WorkoutDetectionIntents.ACTION_QUICK_START)
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val ignoreIntent = PendingIntent.getBroadcast(
            context,
            912,
            Intent(context, WorkoutDetectionActionReceiver::class.java)
                .setAction(WorkoutDetectionIntents.ACTION_IGNORE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val preferences = WorkoutDetectionStore(context).loadPreferences()
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_rally_ongoing)
            .setContentTitle("${candidate.displayName} rilevato")
            .setContentText("Vuoi iniziare una partita su Momentum?")
            .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setContentIntent(
                if (preferences.mode == WorkoutDetectionMode.QUICK_START) {
                    quickStartIntent
                } else {
                    configureIntent
                },
            )
            .addAction(0, "Avvio rapido", quickStartIntent)
            .addAction(0, "Configura", configureIntent)
            .addAction(0, "Ignora", ignoreIntent)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Permission can be revoked between notificationsAllowed() and notify().
        }
    }

    private fun createChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Allenamenti rilevati",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Prompt opzionali per avviare una partita Momentum."
            setShowBadge(false)
        }
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun notificationsAllowed(context: Context): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
    }
}
