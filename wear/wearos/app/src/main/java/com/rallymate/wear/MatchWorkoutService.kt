package com.rallymate.wear

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseTrackedStatus
import androidx.health.services.client.data.ExerciseUpdate
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch

/**
 * Owns at most one Health Services exercise for the active match.
 *
 * Health Services allows a single owner: `OTHER_APP_IN_PROGRESS` means another
 * app holds it, which is an expected condition. RallyMate then scores only and
 * never retries in a loop; the persisted recording state is what stops callers
 * from asking again.
 */
class MatchWorkoutService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val exerciseClient by lazy { HealthServices.getClient(this).exerciseClient }
    private val store by lazy { LocalMatchStore(this) }
    private var machine = WearRecordingStateMachine()
    private var activeMatchId = ""
    private var startInFlight = false

    private val callback = object : ExerciseUpdateCallback {
        override fun onRegistered() = Unit

        override fun onRegistrationFailed(throwable: Throwable) {
            apply(machine.onFailure(now(), WearRecordingReason.SERVICE_UNAVAILABLE))
            refreshNotification("Metriche allenamento non disponibili")
        }

        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            if (update.exerciseStateInfo.state.isEnded) {
                apply(machine.onExerciseEnded(now(), saved = true))
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) = Unit

        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) = Unit
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopWorkout()
            ACTION_PAUSE -> pauseWorkout()
            ACTION_RESUME -> resumeWorkout()
            else -> {
                if (!canStartHealthForegroundService(this)) {
                    apply(machine.onFailure(now(), WearRecordingReason.PERMISSION_DENIED))
                    stopSelf()
                    return START_NOT_STICKY
                }
                val requestedMatchId = intent?.getStringExtra(EXTRA_MATCH_ID)
                    .orEmpty()
                    .ifBlank { savedMatchId() }
                if (requestedMatchId.isBlank()) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                startWorkout(
                    requestedMatchId,
                    userInitiated = intent?.getBooleanExtra(EXTRA_USER_INITIATED, false) == true,
                )
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        runCatching { exerciseClient.clearUpdateCallbackAsync(callback) }
        scope.cancel()
        super.onDestroy()
    }

    private fun adopt(matchId: String) {
        val mode = store.loadHealthRecordingMode(matchId)
        if (matchId != activeMatchId || mode != machine.mode) {
            activeMatchId = matchId
            machine.reset(mode)
            machine.restore(
                store.loadWorkoutSegments(matchId),
                store.loadRecordingState(matchId),
            )
        }
    }

    private fun startWorkout(matchId: String, userInitiated: Boolean) {
        adopt(matchId)
        if (startInFlight) return

        val result = machine.requestStart(now(), userInitiated)
        result.transition?.let(::log)
        if (result.decision !is WearRecordingStateMachine.StartDecision.Start) {
            persist()
            if (!machine.state.ownsSession) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            return
        }

        startInFlight = true
        store.setActiveWorkoutMatch(matchId)
        persist()
        try {
            startForeground(NOTIFICATION_ID, buildNotification("Partita in corso"))
        } catch (_: SecurityException) {
            startInFlight = false
            apply(machine.onFailure(now(), WearRecordingReason.PERMISSION_DENIED))
            stopSelf()
            return
        }

        scope.launch {
            runCatching {
                val current = exerciseClient.getCurrentExerciseInfoAsync().await()
                when (current.exerciseTrackedStatus) {
                    ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS -> {
                        // Expected: never replace another app's exercise.
                        apply(machine.onOwnedByOtherApp(now()))
                        releaseWithoutEndingExercise()
                        return@launch
                    }
                    ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS -> {
                        exerciseClient.setUpdateCallback(callback)
                        apply(machine.onRecovered(now(), now(), paused = false))
                        refreshNotification("Allenamento ripristinato")
                        return@launch
                    }
                    ExerciseTrackedStatus.UNKNOWN -> {
                        // Ownership cannot be proven: stay out.
                        apply(machine.onOwnedByOtherApp(now()))
                        releaseWithoutEndingExercise()
                        return@launch
                    }
                }
                exerciseClient.setUpdateCallback(callback)
                val capabilities = exerciseClient.getCapabilitiesAsync().await()
                // Health Services has no padel exercise type; TENNIS is the
                // documented racket sport. PADDLING is a water sport.
                val exerciseType = when {
                    ExerciseType.TENNIS in capabilities.supportedExerciseTypes ->
                        ExerciseType.TENNIS
                    ExerciseType.WORKOUT in capabilities.supportedExerciseTypes ->
                        ExerciseType.WORKOUT
                    else -> capabilities.supportedExerciseTypes.firstOrNull() ?: ExerciseType.WORKOUT
                }
                val supported = capabilities
                    .getExerciseTypeCapabilities(exerciseType)
                    .supportedDataTypes
                val dataTypes = mutableSetOf<DataType<*, *>>()
                if (hasBodySensorPermission() && DataType.HEART_RATE_BPM in supported) {
                    dataTypes += DataType.HEART_RATE_BPM
                }
                if (DataType.CALORIES_TOTAL in supported) dataTypes += DataType.CALORIES_TOTAL
                val config = ExerciseConfig(
                    exerciseType = exerciseType,
                    dataTypes = dataTypes,
                    isAutoPauseAndResumeEnabled = false,
                    isGpsEnabled = false,
                )
                exerciseClient.startExerciseAsync(config).await()
                apply(machine.onExerciseStarted(now()))
                refreshNotification("Allenamento attivo")
            }.onFailure {
                apply(machine.onFailure(now(), WearRecordingReason.SESSION_FAILED))
                refreshNotification("Allenamento non avviato")
            }
            startInFlight = false
        }
    }

    /** Leaves the other app's exercise untouched and gives up ownership. */
    private fun releaseWithoutEndingExercise() {
        store.clearActiveWorkoutMatch()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopWorkout() {
        val matchId = savedMatchId().ifBlank { activeMatchId }
        if (matchId.isNotBlank()) adopt(matchId)
        if (!machine.state.ownsSession) {
            persist()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        apply(machine.onStopRequested(now(), WearRecordingReason.MATCH_FINISHED))
        scope.launch {
            val ended = runCatching { exerciseClient.endExerciseAsync().await() }.isSuccess
            runCatching { exerciseClient.clearUpdateCallbackAsync(callback).await() }
            // Idempotent: the update callback may have closed it already.
            apply(machine.onExerciseEnded(now(), saved = ended))
            store.clearActiveWorkoutMatch()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun pauseWorkout() {
        if (!machine.state.ownsSession) return
        scope.launch {
            runCatching { exerciseClient.pauseExerciseAsync().await() }
                .onSuccess {
                    apply(machine.onPaused(now()))
                    refreshNotification("Partita in pausa")
                }
        }
    }

    private fun resumeWorkout() {
        if (machine.state != WearRecordingState.PAUSED) return
        scope.launch {
            runCatching { exerciseClient.resumeExerciseAsync().await() }
                .onSuccess {
                    apply(machine.onResumed(now()))
                    refreshNotification("Allenamento attivo")
                }
        }
    }

    private fun apply(transition: WearRecordingTransition?) {
        transition?.let(::log)
        persist()
    }

    private fun persist() {
        if (activeMatchId.isBlank()) return
        store.saveWorkoutSegments(activeMatchId, machine.segments)
        store.saveRecordingState(activeMatchId, machine.state)
    }

    private fun log(transition: WearRecordingTransition) {
        Log.i(LOG_TAG, transition.logLine(wearMatchToken(activeMatchId)))
    }

    private fun now(): Long = System.currentTimeMillis()

    private fun savedMatchId(): String = store.activeWorkoutMatch()

    private fun buildNotification(text: String): android.app.Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            MainActivityLaunchPolicy.applyTo(
                Intent(this, MainActivity::class.java)
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Momentum")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_rally_ongoing)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)

        val ongoingActivity = OngoingActivity.Builder(
            applicationContext,
            NOTIFICATION_ID,
            notificationBuilder,
        )
            .setStaticIcon(R.drawable.ic_rally_ongoing)
            .setTouchIntent(pendingIntent)
            .setStatus(
                Status.Builder()
                    .addTemplate("#type# #time#")
                    .addPart("type", Status.TextPart("Padel"))
                    .addPart("time", Status.StopwatchPart(SystemClock.elapsedRealtime()))
                    .build(),
            )
            .build()
        ongoingActivity.apply(applicationContext)
        return notificationBuilder.build()
    }

    private fun refreshNotification(text: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Partita Momentum",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Sessione workout e always-on durante una partita."
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun hasBodySensorPermission(): Boolean =
        ActivityCompat.checkSelfPermission(this, Manifest.permission.BODY_SENSORS) ==
            PackageManager.PERMISSION_GRANTED

    companion object {
        private const val CHANNEL_ID = "rallymate_match_workout"
        private const val LOG_TAG = "RallyMateWorkout"
        private const val NOTIFICATION_ID = 72
        private const val ACTION_START = "com.rallymate.wear.action.START_WORKOUT"
        private const val ACTION_STOP = "com.rallymate.wear.action.STOP_WORKOUT"
        private const val ACTION_PAUSE = "com.rallymate.wear.action.PAUSE_WORKOUT"
        private const val ACTION_RESUME = "com.rallymate.wear.action.RESUME_WORKOUT"
        private const val EXTRA_MATCH_ID = "matchId"
        private const val EXTRA_USER_INITIATED = "userInitiated"

        fun canStartHealthForegroundService(context: Context): Boolean {
            val hasActivityRecognition =
                ActivityCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACTIVITY_RECOGNITION,
                ) == PackageManager.PERMISSION_GRANTED
            val hasBodySensors =
                ActivityCompat.checkSelfPermission(context, Manifest.permission.BODY_SENSORS) ==
                    PackageManager.PERMISSION_GRANTED
            return hasActivityRecognition || hasBodySensors
        }

        fun start(context: Context, matchId: String, userInitiated: Boolean = false) {
            if (!canStartHealthForegroundService(context)) return
            val intent = Intent(context, MatchWorkoutService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_MATCH_ID, matchId)
                .putExtra(EXTRA_USER_INITIATED, userInitiated)
            runCatching {
                context.startForegroundService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, MatchWorkoutService::class.java)
                .setAction(ACTION_STOP)
            runCatching {
                context.startService(intent)
            }
        }

        fun pause(context: Context) {
            sendAction(context, ACTION_PAUSE)
        }

        fun resume(context: Context) {
            sendAction(context, ACTION_RESUME)
        }

        private fun sendAction(context: Context, action: String) {
            val intent = Intent(context, MatchWorkoutService::class.java).setAction(action)
            runCatching { context.startService(intent) }
        }
    }
}
