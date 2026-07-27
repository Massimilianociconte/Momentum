package com.rallymate.wear

/**
 * Owner of the health recording for a match.
 *
 * Health Services allows a single owner of the exercise session per device
 * (`ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS` when another app holds it), so
 * the user picks the owner up front exactly like on watchOS.
 */
enum class WearHealthRecordingMode(val wire: String) {
    RALLYMATE_MANAGED("RALLYMATE_MANAGED"),
    EXTERNAL_MANAGED("EXTERNAL_MANAGED"),
    DISABLED("DISABLED"),
    ;

    val title: String
        get() = when (this) {
            RALLYMATE_MANAGED -> "Registra con Momentum"
            EXTERNAL_MANAGED -> "Uso un'altra app"
            DISABLED -> "Non registrare"
        }

    val subtitle: String
        get() = when (this) {
            RALLYMATE_MANAGED -> "Momentum apre e chiude l'unico allenamento."
            EXTERNAL_MANAGED -> "Solo punteggio, workout gestito dall'altra app."
            DISABLED -> "Nessun dato salute."
        }

    val shortLabel: String
        get() = when (this) {
            RALLYMATE_MANAGED -> "Momentum"
            EXTERNAL_MANAGED -> "App esterna"
            DISABLED -> "Off"
        }

    companion object {
        const val EXCLUSIVITY_NOTE =
            "Non avviare due allenamenti insieme: il watch ne tiene attivo uno solo."

        fun fromWire(value: String?): WearHealthRecordingMode =
            entries.firstOrNull { it.wire == value } ?: RALLYMATE_MANAGED
    }
}

enum class WearRecordingState(val wire: String) {
    IDLE("idle"),
    PREPARING("preparing"),
    RUNNING("running"),
    PAUSED("paused"),
    STOPPING("stopping"),
    SAVED("saved"),
    FAILED("failed"),
    EXTERNAL_OWNED("externalOwned"),
    DISABLED("disabled"),
    ;

    val ownsSession: Boolean
        get() = this == PREPARING || this == RUNNING || this == PAUSED || this == STOPPING

    val isTerminal: Boolean
        get() = this == SAVED || this == FAILED || this == EXTERNAL_OWNED || this == DISABLED

    companion object {
        fun fromWire(value: String?): WearRecordingState =
            entries.firstOrNull { it.wire == value } ?: IDLE
    }
}

enum class WearRecordingReason {
    MATCH_STARTED,
    USER_RETRY,
    SESSION_RUNNING,
    USER_PAUSED,
    USER_RESUMED,
    MATCH_FINISHED,
    SESSION_ENDED,
    EXERCISE_SAVED,
    RECOVERED,
    /** `ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS`, or an ownership loss. */
    OWNED_BY_OTHER_APP,
    SESSION_FAILED,
    PERMISSION_DENIED,
    SERVICE_UNAVAILABLE,
    USER_CHOICE_EXTERNAL,
    USER_CHOICE_DISABLED,
    DUPLICATE_START_IGNORED,
    AUTO_RESTART_SUPPRESSED,
}

data class WearWorkoutSegment(
    val startedAtMs: Long,
    val endedAtMs: Long? = null,
    val saved: Boolean = false,
    val endReason: String? = null,
) {
    val isOpen: Boolean get() = endedAtMs == null

    fun encode(): String =
        "$startedAtMs|${endedAtMs ?: ""}|${if (saved) 1 else 0}|${endReason.orEmpty()}"

    companion object {
        fun decode(value: String): WearWorkoutSegment? {
            val parts = value.split('|')
            if (parts.size < 3) return null
            val start = parts[0].toLongOrNull() ?: return null
            return WearWorkoutSegment(
                startedAtMs = start,
                endedAtMs = parts[1].toLongOrNull(),
                saved = parts[2] == "1",
                endReason = parts.getOrNull(3)?.takeIf { it.isNotBlank() },
            )
        }
    }
}

data class WearRecordingTransition(
    val from: WearRecordingState,
    val to: WearRecordingState,
    val reason: WearRecordingReason,
    val atMs: Long,
    val errorCode: Int? = null,
) {
    /** Structured, privacy-safe log line: no health values, no identifiers. */
    fun logLine(matchToken: String): String =
        "$atMs $matchToken ${from.wire}->${to.wire} $reason" +
            (errorCode?.let { " err=$it" } ?: "")
}

enum class WearRecordingCompleteness { COMPLETE, PARTIAL, EXTERNAL, NONE, PENDING }

data class WearHealthDataQuality(
    val completeness: WearRecordingCompleteness,
    val matchDurationMs: Long,
    val recordedDurationMs: Long,
    val segmentCount: Int,
) {
    val coverage: Double
        get() = if (matchDurationMs <= 0) 0.0
        else (recordedDurationMs.toDouble() / matchDurationMs).coerceIn(0.0, 1.0)

    val isPartial: Boolean get() = completeness == WearRecordingCompleteness.PARTIAL

    val label: String
        get() = when (completeness) {
            WearRecordingCompleteness.COMPLETE -> "Dati salute completi"
            WearRecordingCompleteness.PARTIAL -> "Dati salute parziali"
            WearRecordingCompleteness.EXTERNAL -> "Registrato da app esterna"
            WearRecordingCompleteness.NONE -> "Nessun dato salute"
            WearRecordingCompleteness.PENDING -> "Registrazione in corso"
        }

    val detail: String
        get() {
            val recorded = minutes(recordedDurationMs)
            val match = minutes(matchDurationMs)
            return when (completeness) {
                WearRecordingCompleteness.COMPLETE -> "Allenamento $recorded su partita $match."
                WearRecordingCompleteness.PARTIAL ->
                    "Registrati $recorded su $match di partita" +
                        if (segmentCount > 1) " in $segmentCount segmenti." else "."
                WearRecordingCompleteness.EXTERNAL ->
                    "Collega l'allenamento dall'app salute: partita $match."
                WearRecordingCompleteness.NONE -> "Solo punteggio. Durata partita $match."
                WearRecordingCompleteness.PENDING -> "Allenamento ancora attivo."
            }
        }

    private fun minutes(ms: Long): String = "${Math.round(ms / 60_000.0)} min"
}

/**
 * Single-owner recording state machine, mirroring the watchOS one so both
 * platforms refuse duplicate starts and never auto-restart after an
 * interruption. Pure Kotlin: fully unit-testable on the JVM.
 */
class WearRecordingStateMachine(mode: WearHealthRecordingMode = WearHealthRecordingMode.RALLYMATE_MANAGED) {

    var mode: WearHealthRecordingMode = mode
        private set
    var state: WearRecordingState = initialState(mode)
        private set
    var acceptedStarts: Int = 0
        private set
    var refusedStarts: Int = 0
        private set
    var lastReason: WearRecordingReason? = null
        private set
    var lastErrorCode: Int? = null
        private set

    private val _segments = mutableListOf<WearWorkoutSegment>()
    val segments: List<WearWorkoutSegment> get() = _segments.toList()

    sealed interface StartDecision {
        data object Start : StartDecision
        data class Rejected(val reason: WearRecordingReason) : StartDecision
    }

    data class StartResult(
        val decision: StartDecision,
        val transition: WearRecordingTransition?,
    )

    fun reset(mode: WearHealthRecordingMode) {
        this.mode = mode
        state = initialState(mode)
        _segments.clear()
        acceptedStarts = 0
        refusedStarts = 0
        lastReason = null
        lastErrorCode = null
    }

    fun restore(segments: List<WearWorkoutSegment>, state: WearRecordingState) {
        _segments.clear()
        _segments += segments
        this.state = state
    }

    /** The only gate allowed to call `ExerciseClient.startExerciseAsync`. */
    fun requestStart(atMs: Long, userInitiated: Boolean = false): StartResult {
        when (mode) {
            WearHealthRecordingMode.DISABLED ->
                return refuse(
                    WearRecordingReason.USER_CHOICE_DISABLED,
                    WearRecordingState.DISABLED,
                    atMs,
                )
            WearHealthRecordingMode.EXTERNAL_MANAGED ->
                return refuse(
                    WearRecordingReason.USER_CHOICE_EXTERNAL,
                    WearRecordingState.EXTERNAL_OWNED,
                    atMs,
                )
            WearHealthRecordingMode.RALLYMATE_MANAGED -> Unit
        }
        if (state.ownsSession) {
            return refuse(WearRecordingReason.DUPLICATE_START_IGNORED, state, atMs)
        }
        if (state.isTerminal && !userInitiated) {
            return refuse(WearRecordingReason.AUTO_RESTART_SUPPRESSED, state, atMs)
        }
        acceptedStarts += 1
        val reason = if (userInitiated) {
            WearRecordingReason.USER_RETRY
        } else {
            WearRecordingReason.MATCH_STARTED
        }
        return StartResult(
            StartDecision.Start,
            transition(WearRecordingState.PREPARING, reason, atMs),
        )
    }

    fun onExerciseStarted(atMs: Long): WearRecordingTransition? {
        if (state != WearRecordingState.PREPARING) return null
        _segments += WearWorkoutSegment(startedAtMs = atMs)
        return transition(
            WearRecordingState.RUNNING,
            WearRecordingReason.SESSION_RUNNING,
            atMs,
        )
    }

    fun onRecovered(startedAtMs: Long, atMs: Long, paused: Boolean): WearRecordingTransition? {
        if (state != WearRecordingState.IDLE &&
            state != WearRecordingState.PREPARING &&
            !state.isTerminal
        ) {
            return null
        }
        if (state != WearRecordingState.PREPARING) acceptedStarts += 1
        if (_segments.lastOrNull()?.isOpen != true) {
            _segments += WearWorkoutSegment(startedAtMs = startedAtMs)
        }
        val target = if (paused) WearRecordingState.PAUSED else WearRecordingState.RUNNING
        return transition(target, WearRecordingReason.RECOVERED, atMs)
    }

    /** Another app owns the exercise: expected condition, never a retry loop. */
    fun onOwnedByOtherApp(atMs: Long): WearRecordingTransition? {
        if (state == WearRecordingState.EXTERNAL_OWNED) return null
        closeOpenSegment(atMs, WearRecordingReason.OWNED_BY_OTHER_APP, saved = true)
        return transition(
            WearRecordingState.EXTERNAL_OWNED,
            WearRecordingReason.OWNED_BY_OTHER_APP,
            atMs,
        )
    }

    fun onPaused(atMs: Long): WearRecordingTransition? {
        if (state != WearRecordingState.RUNNING) return null
        return transition(WearRecordingState.PAUSED, WearRecordingReason.USER_PAUSED, atMs)
    }

    fun onResumed(atMs: Long): WearRecordingTransition? {
        if (state != WearRecordingState.PAUSED) return null
        return transition(WearRecordingState.RUNNING, WearRecordingReason.USER_RESUMED, atMs)
    }

    fun onStopRequested(atMs: Long, reason: WearRecordingReason): WearRecordingTransition? {
        if (!state.ownsSession) return null
        return transition(WearRecordingState.STOPPING, reason, atMs)
    }

    fun onExerciseEnded(atMs: Long, saved: Boolean = true): WearRecordingTransition? {
        if (!state.ownsSession) return null
        closeOpenSegment(atMs, WearRecordingReason.SESSION_ENDED, saved = saved)
        return transition(
            if (saved) WearRecordingState.SAVED else WearRecordingState.FAILED,
            if (saved) WearRecordingReason.EXERCISE_SAVED else WearRecordingReason.SESSION_FAILED,
            atMs,
        )
    }

    fun onFailure(atMs: Long, reason: WearRecordingReason, errorCode: Int? = null): WearRecordingTransition? {
        if (state.isTerminal) return null
        closeOpenSegment(atMs, reason, saved = _segments.lastOrNull()?.isOpen == true)
        return transition(WearRecordingState.FAILED, reason, atMs, errorCode)
    }

    /** Non-overlapping saved recording inside the match window. */
    fun recordedDurationMs(matchStartMs: Long, matchEndMs: Long?, nowMs: Long): Long {
        val upper = matchEndMs ?: nowMs
        val ranges = _segments
            .filter { it.saved }
            .mapNotNull {
                val start = maxOf(it.startedAtMs, matchStartMs)
                val end = minOf(it.endedAtMs ?: nowMs, upper)
                if (end > start) start to end else null
            }
            .sortedBy { it.first }

        var total = 0L
        var current: Pair<Long, Long>? = null
        for (range in ranges) {
            val open = current
            if (open == null) {
                current = range
                continue
            }
            current = if (range.first <= open.second) {
                // Overlapping segments merge; they are never summed twice.
                open.first to maxOf(open.second, range.second)
            } else {
                total += open.second - open.first
                range
            }
        }
        current?.let { total += it.second - it.first }
        return total
    }

    fun quality(
        matchStartMs: Long,
        matchEndMs: Long?,
        nowMs: Long,
        completeCoverage: Double = 0.9,
    ): WearHealthDataQuality {
        val matchDuration = maxOf(0L, (matchEndMs ?: nowMs) - matchStartMs)
        val saved = _segments.filter { it.saved }
        val recorded = recordedDurationMs(matchStartMs, matchEndMs, nowMs)
        val completeness = when {
            mode == WearHealthRecordingMode.DISABLED -> WearRecordingCompleteness.NONE
            mode == WearHealthRecordingMode.EXTERNAL_MANAGED -> WearRecordingCompleteness.EXTERNAL
            state.ownsSession && matchEndMs == null -> WearRecordingCompleteness.PENDING
            saved.isEmpty() || recorded <= 0 ->
                if (state == WearRecordingState.EXTERNAL_OWNED) {
                    WearRecordingCompleteness.EXTERNAL
                } else {
                    WearRecordingCompleteness.NONE
                }
            saved.size == 1 && matchDuration > 0 &&
                recorded.toDouble() / matchDuration >= completeCoverage ->
                WearRecordingCompleteness.COMPLETE
            else -> WearRecordingCompleteness.PARTIAL
        }
        return WearHealthDataQuality(completeness, matchDuration, recorded, saved.size)
    }

    private fun refuse(
        reason: WearRecordingReason,
        target: WearRecordingState,
        atMs: Long,
    ): StartResult {
        refusedStarts += 1
        val logged = if (state == target) {
            WearRecordingTransition(state, target, reason, atMs)
        } else {
            transition(target, reason, atMs)
        }
        lastReason = reason
        return StartResult(StartDecision.Rejected(reason), logged)
    }

    private fun transition(
        target: WearRecordingState,
        reason: WearRecordingReason,
        atMs: Long,
        errorCode: Int? = null,
    ): WearRecordingTransition {
        val record = WearRecordingTransition(state, target, reason, atMs, errorCode)
        state = target
        lastReason = reason
        if (errorCode != null) lastErrorCode = errorCode
        return record
    }

    private fun closeOpenSegment(atMs: Long, reason: WearRecordingReason, saved: Boolean) {
        val index = _segments.lastIndex
        if (index < 0 || !_segments[index].isOpen) return
        _segments[index] = _segments[index].copy(
            endedAtMs = maxOf(_segments[index].startedAtMs, atMs),
            saved = saved,
            endReason = reason.name,
        )
    }

    private fun initialState(mode: WearHealthRecordingMode) = when (mode) {
        WearHealthRecordingMode.RALLYMATE_MANAGED -> WearRecordingState.IDLE
        WearHealthRecordingMode.EXTERNAL_MANAGED -> WearRecordingState.EXTERNAL_OWNED
        WearHealthRecordingMode.DISABLED -> WearRecordingState.DISABLED
    }
}

/** Opaque, non-reversible short token so logs correlate without identifiers. */
fun wearMatchToken(matchId: String): String {
    if (matchId.isEmpty()) return "-"
    var hash = -0x340d631b7bdddcdbL // FNV-1a 64-bit offset basis
    for (byte in matchId.toByteArray()) {
        hash = hash xor (byte.toLong() and 0xff)
        hash *= 0x100000001b3L
    }
    return "m%08x".format(hash.toInt())
}
