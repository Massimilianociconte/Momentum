package com.rallymate.rallymate

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class HealthConnectBridge(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
) {
    private companion object {
        const val CHANNEL = "com.rallymate/health_connect"
        const val PROVIDER_PACKAGE = "com.google.android.apps.healthdata"
        /** After this, a pending permission request is considered orphaned. */
        const val STALE_REQUEST_MS = 3 * 60 * 1000L
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    /** Core metrics required for match association and the fitness today card. */
    private val corePermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
    )
    /** Optional enrichments; denial must not block steps/HR/calories. */
    private val optionalPermissions = setOf(
        HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
    )
    private val permissions = corePermissions + optionalPermissions
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPermissionAtMs: Long = 0L
    private val permissionLauncher = activity.registerForActivityResult(
        PermissionController.createRequestPermissionResultContract(),
    ) { granted ->
        val result = pendingPermissionResult ?: return@registerForActivityResult
        pendingPermissionResult = null
        pendingPermissionAtMs = 0L
        result.success(statusPayload(granted))
    }

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> status(result)
                "requestPermissions" -> requestPermissions(result)
                "readSummary" -> readSummary(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun status(result: MethodChannel.Result) {
        scope.launch {
            result.success(statusPayload(grantedPermissions()))
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (sdkStatus() != HealthConnectClient.SDK_AVAILABLE) {
            result.success(statusPayload(emptySet()))
            return
        }
        val pending = pendingPermissionResult
        if (pending != null) {
            // A pending result can be orphaned when the activity is recreated
            // while the system sheet is up: its callback then finds no result
            // to complete and the Dart future never resolves. Never let that
            // wedge the bridge forever — supersede a stale request instead of
            // refusing every later one.
            if (System.currentTimeMillis() - pendingPermissionAtMs < STALE_REQUEST_MS) {
                result.error("busy", "Health Connect permission request already pending", null)
                return
            }
            pendingPermissionResult = null
            runCatching { pending.success(statusPayload(emptySet())) }
        }
        pendingPermissionResult = result
        pendingPermissionAtMs = System.currentTimeMillis()
        permissionLauncher.launch(permissions)
    }

    private fun readSummary(call: MethodCall, result: MethodChannel.Result) {
        val startMs = (call.argument<Number>("startMs"))?.toLong()
        val endMs = (call.argument<Number>("endMs"))?.toLong()
        if (startMs == null || endMs == null || startMs >= endMs) {
            result.error("bad_args", "startMs and endMs required", null)
            return
        }
        val requestedRange = Duration.between(
            Instant.ofEpochMilli(startMs),
            Instant.ofEpochMilli(endMs),
        )
        if (requestedRange > Duration.ofDays(7)) {
            result.error("range_too_large", "Health summary range cannot exceed 7 days", null)
            return
        }

        scope.launch {
            try {
                val granted = grantedPermissions()
                // Partial grants: require at least one core metric, not HRV/sleep.
                if (granted.intersect(corePermissions).isEmpty()) {
                    result.error("permission_denied", "Health Connect permissions missing", null)
                    return@launch
                }
                val payload = withContext(Dispatchers.IO) {
                    readSummaryPayload(
                        Instant.ofEpochMilli(startMs),
                        Instant.ofEpochMilli(endMs),
                        granted,
                    )
                }
                result.success(payload)
            } catch (e: Exception) {
                result.error("health_connect_error", e.message, null)
            }
        }
    }

    private suspend fun readSummaryPayload(
        start: Instant,
        end: Instant,
        granted: Set<String>,
    ): Map<String, Any?> {
        val client = HealthConnectClient.getOrCreate(activity, PROVIDER_PACKAGE)
        val range = TimeRangeFilter.between(start, end)
        val stepsPerm = HealthPermission.getReadPermission(StepsRecord::class)
        val caloriesPerm = HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class)
        val heartPerm = HealthPermission.getReadPermission(HeartRateRecord::class)
        val exercisePerm = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        val sleepPerm = HealthPermission.getReadPermission(SleepSessionRecord::class)
        val hrvPerm = HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class)

        // Aggregate only metrics the user actually granted to avoid HC errors.
        val metrics = buildSet {
            if (granted.contains(stepsPerm)) add(StepsRecord.COUNT_TOTAL)
            if (granted.contains(caloriesPerm)) {
                add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
            }
            if (granted.contains(heartPerm)) add(HeartRateRecord.BPM_AVG)
            if (granted.contains(exercisePerm)) {
                add(ExerciseSessionRecord.EXERCISE_DURATION_TOTAL)
            }
            if (granted.contains(sleepPerm)) {
                add(SleepSessionRecord.SLEEP_DURATION_TOTAL)
            }
        }

        val aggregate = if (metrics.isNotEmpty()) {
            client.aggregate(
                AggregateRequest(
                    metrics = metrics,
                    timeRangeFilter = range,
                ),
            )
        } else {
            null
        }

        val steps = if (granted.contains(stepsPerm)) {
            aggregate?.get(StepsRecord.COUNT_TOTAL) ?: 0L
        } else {
            0L
        }
        val calories = if (granted.contains(caloriesPerm)) {
            aggregate?.get(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
                ?.inKilocalories ?: 0.0
        } else {
            0.0
        }
        val averageHeartRate = if (granted.contains(heartPerm)) {
            aggregate?.get(HeartRateRecord.BPM_AVG)?.toDouble()
        } else {
            null
        }
        val exerciseMinutes = if (granted.contains(exercisePerm)) {
            aggregate?.get(ExerciseSessionRecord.EXERCISE_DURATION_TOTAL)
                ?.toMinutes()?.toInt() ?: 0
        } else {
            0
        }
        val sleepMinutes = if (granted.contains(sleepPerm)) {
            aggregate?.get(SleepSessionRecord.SLEEP_DURATION_TOTAL)
                ?.toMinutes()?.toInt() ?: 0
        } else {
            0
        }

        // HRV is optional; skip entirely when permission denied.
        val hrvRecords = if (granted.contains(hrvPerm)) {
            client.readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateVariabilityRmssdRecord::class,
                    timeRangeFilter = range,
                    ascendingOrder = false,
                    pageSize = 500,
                ),
            ).records
        } else {
            emptyList()
        }
        val averageHrv = hrvRecords
            .map { it.heartRateVariabilityMillis }
            .takeIf { it.isNotEmpty() }
            ?.average()

        val metricNames = buildList {
            if (steps > 0) add("STEPS")
            if (calories > 0) add("ACTIVE_ENERGY")
            if (averageHeartRate != null) add("HEART_RATE")
            if (exerciseMinutes > 0) add("EXERCISE_MINUTES")
            if (sleepMinutes > 0) add("SLEEP")
            if (averageHrv != null) add("HRV")
        }
        val sourceRows = linkedMapOf<String, MutableMap<String, Any?>>()
        fun addSource(
            packageName: String,
            manufacturer: String = "",
            model: String = "",
            metrics: Collection<String> = metricNames,
        ) {
            val key = "$packageName|$manufacturer|$model"
            val row = sourceRows.getOrPut(key) {
                mutableMapOf(
                    "sourceApplication" to applicationLabel(packageName),
                    "sourceBundleId" to packageName,
                    "sourceDevice" to manufacturer,
                    "sourceModel" to model,
                    "metrics" to mutableSetOf<String>(),
                )
            }
            @Suppress("UNCHECKED_CAST")
            (row["metrics"] as MutableSet<String>).addAll(metrics)
        }
        aggregate?.dataOrigins?.forEach { addSource(it.packageName) }
        hrvRecords.forEach { record ->
            val metadata = record.metadata
            addSource(
                packageName = metadata.dataOrigin.packageName,
                manufacturer = metadata.device?.manufacturer.orEmpty(),
                model = metadata.device?.model.orEmpty(),
                metrics = listOf("HRV"),
            )
        }

        return mapOf(
            "startMs" to start.toEpochMilli(),
            "endMs" to end.toEpochMilli(),
            "steps" to steps,
            "activeCaloriesKcal" to calories,
            "averageHeartRateBpm" to averageHeartRate,
            "exerciseMinutes" to exerciseMinutes,
            "heartRateVariabilityMs" to averageHrv,
            "heartRateVariabilityMethod" to "RMSSD",
            "sleepMinutes" to sleepMinutes,
            "sources" to sourceRows.values.map { row ->
                row.mapValues { (_, value) ->
                    if (value is Set<*>) value.toList() else value
                }
            },
        )
    }

    private fun applicationLabel(packageName: String): String = runCatching {
        val info = activity.packageManager.getApplicationInfo(packageName, 0)
        activity.packageManager.getApplicationLabel(info).toString()
    }.getOrDefault(packageName)

    private suspend fun grantedPermissions(): Set<String> {
        if (sdkStatus() != HealthConnectClient.SDK_AVAILABLE) return emptySet()
        return HealthConnectClient.getOrCreate(activity, PROVIDER_PACKAGE)
            .permissionController
            .getGrantedPermissions()
    }

    private fun statusPayload(granted: Set<String>): Map<String, Any?> {
        val status = sdkStatus()
        val available = status == HealthConnectClient.SDK_AVAILABLE
        val coreGranted = available && granted.containsAll(corePermissions)
        val anyCore = available && granted.intersect(corePermissions).isNotEmpty()
        return mapOf(
            "available" to available,
            // "granted" means usable for match/fitness (all core metrics).
            "granted" to coreGranted,
            "partial" to (anyCore && !coreGranted),
            "grantedPermissions" to granted.toList(),
            "availability" to when (status) {
                HealthConnectClient.SDK_AVAILABLE -> "available"
                HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "updateRequired"
                HealthConnectClient.SDK_UNAVAILABLE -> "unavailable"
                else -> "unknown"
            },
            "providerPackage" to PROVIDER_PACKAGE,
        )
    }

    private fun sdkStatus(): Int =
        HealthConnectClient.getSdkStatus(activity, PROVIDER_PACKAGE)
}
