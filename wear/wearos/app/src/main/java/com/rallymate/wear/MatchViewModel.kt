package com.rallymate.wear

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * ViewModel della partita live su watch.
 * Ogni azione: engine → persistenza locale → best-effort sync telefono.
 */
class MatchViewModel(app: Application) : AndroidViewModel(app) {

    private val store = LocalMatchStore(app)
    private val sync = PhoneSync(app)
    private var engine: ScoringEngine? = null
    private var matchId: String = ""
    private var format: MatchFormat = MatchFormat()
    private var syncJob: Job? = null
    private var syncAgain = false
    private var persistedEventFingerprint = ""

    var state by mutableStateOf<MatchState?>(null)
        private set
    var blindMode by mutableStateOf(false)
    var synced by mutableStateOf(true)
        private set
    var teamName by mutableStateOf("")
        private set
    var teamScoringStyle by mutableStateOf("AUTO")
        private set
    var teamImagePath by mutableStateOf<String?>(null)
        private set
    var profileImagePath by mutableStateOf<String?>(null)
        private set
    var accountContext by mutableStateOf(WearAccountContext())
        private set
    var recoverableMatchId by mutableStateOf<String?>(null)
        private set
    var selectedRole by mutableStateOf("FLEX")
        private set
    var finishConfirmationRequested by mutableStateOf(false)
    var pendingDetectedWorkout by mutableStateOf(
        WorkoutDetectionStore(app).pending()
    )
        private set
    var workoutDetectionRegistrationStatus by mutableStateOf(
        WorkoutDetectionStore(app).registrationStatus()
    )
        private set

    /** Recording owner chosen for the active match. */
    var healthRecordingMode by mutableStateOf(WearHealthRecordingMode.RALLYMATE_MANAGED)
        private set
    var recordingState by mutableStateOf(WearRecordingState.IDLE)
        private set
    var healthQuality by mutableStateOf<WearHealthDataQuality?>(null)
        private set

    /** Matches the user may resume from this watch (ACTIVE + PAUSED). */
    var resumableMatches by mutableStateOf<List<WearResumableMatch>>(emptyList())
        private set

    /** Set when a resume is refused (completed elsewhere, journal missing). */
    var resumeBlockedMessage by mutableStateOf<String?>(null)

    val lastHealthRecordingMode: WearHealthRecordingMode
        get() = store.loadDefaultHealthRecordingMode()

    /** Duo Mode: team assegnato a QUESTO watch (null = scoring classico). */
    var duoTeam by mutableStateOf<TeamId?>(null)
        private set

    val canUndo: Boolean
        get() = duoTeam?.let { engine?.canUndoTeam(it) == true }
            ?: (engine?.canUndo == true)
    val isFreePlay: Boolean get() = format.freePlay
    val usesGoldenPoint: Boolean get() = format.goldenPoint
    val activeMatchId: String get() = matchId
    val activeFormat: MatchFormat get() = format
    val lastFormat: MatchFormat get() = store.loadLastFormat()
    val canScore: Boolean get() = state?.let { !it.completed && !it.paused } == true

    private val visualReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == PhoneListenerService.ACTION_PROFILE_IMAGE_UPDATED) {
                profileImagePath = store.loadProfileImagePath()
                return
            }
            if (intent?.action == PhoneListenerService.ACTION_RESUMABLE_UPDATED) {
                refreshResumableMatches()
                return
            }
            val updatedMatch = intent
                ?.getStringExtra(PhoneListenerService.EXTRA_MATCH_ID)
                ?: return
            if (updatedMatch == matchId) loadTeamVisual(updatedMatch)
        }
    }

    init {
        ContextCompat.registerReceiver(
            app,
            visualReceiver,
            IntentFilter().apply {
                addAction(PhoneListenerService.ACTION_TEAM_VISUAL_UPDATED)
                addAction(PhoneListenerService.ACTION_PROFILE_IMAGE_UPDATED)
                addAction(PhoneListenerService.ACTION_RESUMABLE_UPDATED)
            },
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        accountContext = store.loadAccountContext()
        profileImagePath = store.loadProfileImagePath()
        recoverableMatchId = store.lastIncompleteMatchId()
        selectedRole = store.loadPlayerRole()
        // 1. local database first, so the list is usable with no phone at all.
        refreshResumableMatches()
        restoreActiveMatch()
    }

    /** Riprende solo una partita attiva; la Home resta disponibile a riposo. */
    private fun restoreActiveMatch() {
        val active = store.activeMatchId()
        if (active != null) {
            val f = store.loadFormat(active) ?: MatchFormat()
            startMatch(active, f, store.loadEvents(active))
        }
    }

    fun newStandaloneMatch(format: MatchFormat = MatchFormat()) {
        val id = "mt_w_${UUID.randomUUID()}"
        startMatch(id, format, emptyList())
    }

    fun createStandaloneMatch(
        format: MatchFormat,
        role: String,
        selectedTeamName: String = "",
        externalWorkout: Boolean = false,
        recordingMode: WearHealthRecordingMode? = null,
    ): Boolean {
        if (state != null) return false
        selectedRole = role
        store.savePlayerRole(role)
        store.saveLastFormat(format)
        val id = "mt_w_${UUID.randomUUID()}"
        val mode = recordingMode
            ?: if (externalWorkout) {
                WearHealthRecordingMode.EXTERNAL_MANAGED
            } else {
                store.loadDefaultHealthRecordingMode()
            }
        store.saveDefaultHealthRecordingMode(mode)
        store.saveHealthRecordingMode(id, mode)
        store.saveTeamVisual(id, TeamVisual(teamName = selectedTeamName))
        startMatch(id, format, emptyList(), startWorkout = true)
        if (mode != WearHealthRecordingMode.RALLYMATE_MANAGED) clearPendingDetectedWorkout()
        return true
    }

    fun startMatch(
        id: String,
        f: MatchFormat,
        persisted: List<MatchEvent>,
        startWorkout: Boolean = false,
        /** True when resuming a match paused in an earlier session. */
        resumingSession: Boolean = false,
    ) {
        accountContext = store.loadAccountContext()
        profileImagePath = store.loadProfileImagePath()
        val effectiveEvents = mergeStartMatchEvents(
            existing = store.loadEvents(id),
            incoming = persisted,
        )
        matchId = id
        format = f
        duoTeam = store.loadDuoTeam(id)
        loadTeamVisual(id)
        val assignedTeam = store.loadDuoTeam(id)
        val e = ScoringEngine(
            matchId = id,
            format = f,
            sourceUserId = accountContext.sourceUserId,
            assignedTeam = assignedTeam,
            duoMode = assignedTeam != null,
        )
        if (effectiveEvents.isNotEmpty()) e.loadEvents(effectiveEvents) else e.start()
        engine = e
        state = e.state
        store.setActiveMatch(id)
        store.clearIncomplete(id)
        recoverableMatchId = store.lastIncompleteMatchId()
        blindMode = false
        // The owner of the recording is frozen for the whole match.
        healthRecordingMode = store.loadHealthRecordingMode(id)
        store.saveHealthRecordingMode(id, healthRecordingMode)
        refreshRecordingState()
        persistAndSync()
        if (state?.completed != true &&
            (startWorkout || shouldRestoreWorkout(effectiveEvents))
        ) {
            startWorkoutIfNeeded(userInitiated = resumingSession)
        }
        publishLocalStatus()
    }

    fun point(team: TeamId, blind: Boolean = false, method: String? = null) {
        val e = engine ?: return
        if (e.state.paused) return
        // Duo Mode: questo watch segna SOLO i punti del proprio team — è la
        // barriera anti-duplicazione tra i due smartwatch.
        duoTeam?.let { if (team != it) return }
        // Scoring never re-arms the exercise: it is opened once at match start
        // and closed once at match end.
        val source = method ?: if (blind) "BLIND_TAP" else "TAP"
        val (_, transitions) = e.addPoint(team, source)
        state = e.state
        haptics(transitions)
        persistAndSync()
        if (state?.completed == true) stopWorkout()
    }

    fun undo() {
        val e = engine ?: return
        if (e.state.paused) return
        // Duo Mode: undo team-scoped — annulla solo l'ultimo punto del
        // proprio team, mai gli eventi dell'altro (Duo Mode §10).
        val (_, transitions) = e.undo(duoTeam)
        state = e.state
        haptics(transitions)
        persistAndSync()
    }

    fun handleVoiceCommand(text: String): Boolean {
        return when (parseVoiceCommand(text)) {
            VoiceWatchCommand.POINT_US -> {
                point(duoTeam ?: TeamId.A, method = "VOICE")
                true
            }
            VoiceWatchCommand.POINT_THEM -> {
                if (duoTeam != null) return false
                point(TeamId.B, method = "VOICE")
                true
            }
            VoiceWatchCommand.UNDO -> {
                undo()
                true
            }
            VoiceWatchCommand.BLIND_MODE -> {
                blindMode = true
                true
            }
            VoiceWatchCommand.PAUSE -> {
                pause()
                true
            }
            VoiceWatchCommand.RESUME -> {
                resume()
                true
            }
            VoiceWatchCommand.FINISH -> {
                finishConfirmationRequested = true
                true
            }
            null -> false
        }
    }

    fun pause() {
        val e = engine ?: return
        if (e.pause().isEmpty()) return
        state = e.state
        persistAndSync()
        if (!store.isExternalWorkoutMatch(matchId)) {
            MatchWorkoutService.pause(getApplication())
        }
        publishLocalStatus()
        hapticSuccess()
    }

    fun resume() {
        val e = engine ?: return
        if (e.resume().isEmpty()) return
        state = e.state
        persistAndSync()
        if (!store.isExternalWorkoutMatch(matchId)) {
            MatchWorkoutService.resume(getApplication())
        }
        publishLocalStatus()
        hapticSuccess()
    }

    fun finishCurrentMatch() {
        val e = engine ?: return
        if (e.finish().isEmpty()) return
        state = e.state
        finishConfirmationRequested = false
        persistAndSync()
        publishLocalStatus()
        stopWorkout()
        hapticSuccess()
    }

    fun dismissCompletedMatch() {
        val completedId = matchId
        stopWorkout()
        store.clearActive(completedId)
        store.clearIncomplete(completedId)
        resetToHome()
    }

    fun abandonAsIncomplete() {
        val e = engine ?: return
        if (!e.state.paused) e.pause()
        state = e.state
        persistAndSync()
        val abandonedId = matchId
        store.markIncomplete(abandonedId)
        recoverableMatchId = abandonedId
        stopWorkout()
        resetToHome()
    }

    fun resumeIncompleteMatch() {
        val id = recoverableMatchId ?: return
        resumeMatch(id)
    }

    companion object {
        const val COMPLETED_ELSEWHERE =
            "Questa partita è già stata terminata su un altro dispositivo."
        const val NOT_SYNCHRONISED =
            "Partita non ancora sincronizzata su questo watch. Apri Padelandia sul telefono quando sono vicini."
    }

    /**
     * Rebuilds the list shown on the home screen from the local database merged
     * with the phone snapshot. Works with no connectivity at all.
     */
    fun refreshResumableMatches() {
        var snapshot = store.loadResumableSnapshot()
        for (id in store.knownMatchIds()) {
            if (snapshot.match(id) != null) continue
            val summary = localSummary(id) ?: continue
            snapshot = snapshot.applying(summary)
        }
        store.saveResumableSnapshot(snapshot)
        resumableMatches = snapshot.resumable.filter { it.matchId != matchId }
        recoverableMatchId = resumableMatches.firstOrNull()?.matchId
            ?: store.lastIncompleteMatchId()
    }

    /**
     * Resumes a match paused here or on the phone. A resume always opens a NEW
     * health segment, so the recording owner is asked again.
     */
    fun resumeMatch(id: String, recordingMode: WearHealthRecordingMode? = null) {
        if (id.isBlank()) return
        resumeBlockedMessage = null
        val snapshot = store.loadResumableSnapshot()
        val entry = snapshot.match(id)
        if (entry != null && entry.status.isTerminal) {
            resumeBlockedMessage = COMPLETED_ELSEWHERE
            return
        }
        val events = store.loadEvents(id)
        val storedFormat = store.loadFormat(id) ?: entry?.format
        if (storedFormat == null) {
            resumeBlockedMessage = NOT_SYNCHRONISED
            return
        }
        if (events.isEmpty() && (entry?.eventCount ?: 0) > 0) {
            // Resuming without the journal would restart from 0-0.
            resumeBlockedMessage = NOT_SYNCHRONISED
            return
        }
        recordingMode?.let {
            store.saveDefaultHealthRecordingMode(it)
            store.saveHealthRecordingMode(id, it)
        }
        startMatch(id, storedFormat, events, startWorkout = true, resumingSession = true)
        if (state?.paused == true) resume() else publishLocalStatus()
        store.clearIncomplete(id)
        refreshResumableMatches()
    }

    fun dismissResumeBlockedMessage() {
        resumeBlockedMessage = null
    }

    /** Publishes the status of the match owned by this watch into the list. */
    private fun publishLocalStatus() {
        if (matchId.isBlank()) return
        val summary = localSummary(matchId) ?: return
        store.applyLocalMatchUpdate(summary)
        refreshResumableMatches()
    }

    private fun localSummary(id: String): WearResumableMatch? {
        val storedFormat = store.loadFormat(id) ?: return null
        val events = store.loadEvents(id)
        val derived = if (id == matchId && state != null) {
            state
        } else if (events.isNotEmpty()) {
            ScoringEngine(matchId = id, format = storedFormat)
                .apply { loadEvents(events) }
                .state
        } else {
            null
        }
        val resolved = when {
            derived == null -> WearMatchStatus.CREATED
            derived.completed -> WearMatchStatus.COMPLETED
            derived.paused -> WearMatchStatus.PAUSED
            else -> WearMatchStatus.IN_PROGRESS
        }
        val visual = store.loadTeamVisual(id)
        return WearResumableMatch(
            matchId = id,
            status = resolved,
            // Version == journal length: every device derives the same number
            // from the same events, with no clock comparison.
            stateVersion = maxOf(store.stateVersion(id), events.size),
            updatedAtMs = events.lastOrNull()?.timestampMs ?: 0,
            pausedAtMs = if (resolved == WearMatchStatus.PAUSED) {
                events.lastOrNull { it.type == EventType.MATCH_PAUSED }?.timestampMs
            } else {
                null
            },
            teamLabel = visual.teamName,
            scoreLine = derived?.let {
                "${it.pointsLabel(TeamId.A)}-${it.pointsLabel(TeamId.B)}"
            }.orEmpty(),
            setsLabel = derived?.let { "${it.setsA}-${it.setsB}" }.orEmpty(),
            gamesLabel = derived?.let { "${it.gamesA}-${it.gamesB}" }.orEmpty(),
            format = storedFormat,
            sourceDevice = "WEAR_OS",
            eventCount = events.size,
            journalAvailable = events.isNotEmpty(),
        )
    }

    fun onAppForeground() {
        WorkoutDetectionManager.ensureRegistration(getApplication())
        refreshWorkoutDetectionState()
        refreshRecordingState()
        refreshResumableMatches()
        // Retries only a start that never happened (permissions granted after
        // the match began); a terminated recording is never auto-restarted.
        state?.let { if (!it.completed && !it.paused) startWorkoutIfNeeded() }
        retrySync()
        flushStoredPendingMatches()
    }

    fun onAppBackground() {
        persistLocally()
        retrySync()
    }

    fun onAppInactive() {
        // Ambient/wrist-down transitions are frequent. Events are already
        // committed before UI state changes, so do not wake the radio here.
        persistLocally()
    }

    fun retrySync() {
        if (matchId.isBlank()) return
        if (synced && store.pendingSyncCount(matchId) == 0) return
        persistAndSync()
    }

    private fun persistAndSync() {
        if (engine == null) return
        persistLocally()
        synced = false
        scheduleSync()
    }

    private fun persistLocally() {
        val e = engine ?: return
        if (matchId.isBlank()) return
        val events = e.allEvents
        val fingerprint = "$matchId:${events.size}:${events.lastOrNull()?.eventId.orEmpty()}"
        if (fingerprint == persistedEventFingerprint) return
        store.saveMatch(matchId, format, events)
        persistedEventFingerprint = fingerprint
    }

    private fun scheduleSync() {
        if (syncJob?.isActive == true) {
            syncAgain = true
            return
        }

        val syncMatchId = matchId
        val syncFormat = format
        syncJob = viewModelScope.launch {
            delay(WearEnergyPolicy.SYNC_DEBOUNCE_MS)
            do {
                syncAgain = false
                if (syncMatchId != matchId) return@launch

                val snapshot = store.loadEvents(syncMatchId)
                val pending = snapshot.filter { !it.synced }
                if (pending.isEmpty()) {
                    synced = true
                    return@launch
                }

                val acknowledgedIds = sync.pushEvents(syncMatchId, syncFormat, pending)
                if (acknowledgedIds.isEmpty()) {
                    synced = false
                    return@launch
                }

                store.markSynced(syncMatchId, acknowledgedIds)
            } while (syncAgain || store.pendingSyncCount(syncMatchId) > 0)

            synced = store.pendingSyncCount(syncMatchId) == 0
        }
    }

    /**
     * Single automatic entry point. Duplicate requests and terminal states are
     * refused here and again inside the service, so no caller can produce a
     * restart loop after another app takes the exercise.
     */
    private fun startWorkoutIfNeeded(userInitiated: Boolean = false) {
        if (matchId.isBlank()) return
        if (healthRecordingMode != WearHealthRecordingMode.RALLYMATE_MANAGED) {
            refreshRecordingState()
            return
        }
        val current = store.loadRecordingState(matchId)
        if (current.ownsSession) return
        if (current.isTerminal && !userInitiated) return
        MatchWorkoutService.start(getApplication(), matchId, userInitiated)
        refreshRecordingState()
    }

    /** Explicit user consent to open a new recording after an interruption. */
    fun restartHealthRecording() {
        if (state?.completed != false) return
        if (healthRecordingMode != WearHealthRecordingMode.RALLYMATE_MANAGED) return
        startWorkoutIfNeeded(userInitiated = true)
    }

    private fun stopWorkout() {
        if (matchId.isNotBlank() &&
            healthRecordingMode != WearHealthRecordingMode.RALLYMATE_MANAGED
        ) {
            refreshRecordingState()
            return
        }
        MatchWorkoutService.stop(getApplication())
        refreshRecordingState()
    }

    fun refreshRecordingState() {
        if (matchId.isBlank()) {
            recordingState = WearRecordingState.IDLE
            healthQuality = null
            return
        }
        recordingState = when (healthRecordingMode) {
            WearHealthRecordingMode.EXTERNAL_MANAGED -> WearRecordingState.EXTERNAL_OWNED
            WearHealthRecordingMode.DISABLED -> WearRecordingState.DISABLED
            WearHealthRecordingMode.RALLYMATE_MANAGED -> store.loadRecordingState(matchId)
        }
        val machine = WearRecordingStateMachine(healthRecordingMode)
        machine.restore(store.loadWorkoutSegments(matchId), recordingState)
        val events = engine?.allEvents.orEmpty()
        val startMs = events.firstOrNull { it.type == EventType.MATCH_STARTED }?.timestampMs
            ?: events.firstOrNull()?.timestampMs
            ?: return
        val endMs = events.lastOrNull { it.type == EventType.MATCH_COMPLETED }?.timestampMs
        healthQuality = machine.quality(startMs, endMs, System.currentTimeMillis())
    }

    /** True when the user may explicitly ask for a new recording segment. */
    val canRestartHealthRecording: Boolean
        get() = healthRecordingMode == WearHealthRecordingMode.RALLYMATE_MANAGED &&
            (recordingState == WearRecordingState.EXTERNAL_OWNED ||
                recordingState == WearRecordingState.FAILED)

    fun refreshWorkoutDetectionState() {
        val detectionStore = WorkoutDetectionStore(getApplication())
        pendingDetectedWorkout = detectionStore.pending()
        workoutDetectionRegistrationStatus = detectionStore.registrationStatus()
    }

    fun clearPendingDetectedWorkout() {
        WorkoutDetectionStore(getApplication()).clearPending()
        pendingDetectedWorkout = null
    }

    fun ignorePendingDetectedWorkout() {
        val detectionStore = WorkoutDetectionStore(getApplication())
        detectionStore.ignore(detectionStore.pending())
        pendingDetectedWorkout = null
    }

    private fun resetToHome() {
        engine = null
        matchId = ""
        state = null
        blindMode = false
        synced = true
        teamName = ""
        teamImagePath = null
        duoTeam = null
        persistedEventFingerprint = ""
        healthRecordingMode = WearHealthRecordingMode.RALLYMATE_MANAGED
        recordingState = WearRecordingState.IDLE
        healthQuality = null
    }

    private fun hapticSuccess() {
        vibrator()?.vibrate(
            VibrationEffect.createOneShot(120, VibrationEffect.DEFAULT_AMPLITUDE)
        )
    }

    private fun flushStoredPendingMatches() {
        val pending = store.pendingMatchIds().filter { it != matchId }
        if (pending.isEmpty()) return
        viewModelScope.launch {
            for (id in pending) {
                val storedFormat = store.loadFormat(id) ?: continue
                val snapshot = store.loadEvents(id)
                val pendingEvents = snapshot.filter { !it.synced }
                if (pendingEvents.isEmpty()) continue
                val acknowledgedIds = sync.pushEvents(id, storedFormat, pendingEvents)
                if (acknowledgedIds.isNotEmpty()) {
                    store.markSynced(id, acknowledgedIds)
                }
            }
        }
    }

    private fun shouldRestoreWorkout(events: List<MatchEvent>): Boolean =
        events.any {
            when (it.type) {
                EventType.POINT_TEAM_A,
                EventType.POINT_TEAM_B,
                EventType.GAME_COMPLETED,
                EventType.SET_COMPLETED,
                EventType.SCORE_EDITED -> true
                else -> false
            }
        }

    /** PRD D1: breve = punto, doppia = undo, lunga = game/set. */
    private fun haptics(transitions: List<Transition>) {
        val vibrator = vibrator() ?: return
        when {
            Transition.MATCH_WON in transitions ->
                vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 400, 150, 400), -1))
            Transition.SET_WON in transitions || Transition.GAME_WON in transitions ->
                vibrator.vibrate(VibrationEffect.createOneShot(350, VibrationEffect.DEFAULT_AMPLITUDE))
            Transition.UNDONE in transitions ->
                vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 80, 80, 80), -1))
            Transition.POINT in transitions ->
                vibrator.vibrate(VibrationEffect.createOneShot(60, VibrationEffect.DEFAULT_AMPLITUDE))
        }
    }

    private fun vibrator(): Vibrator? {
        val ctx = getApplication<Application>()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun loadTeamVisual(id: String) {
        val visual = store.loadTeamVisual(id)
        teamName = visual.teamName
        teamScoringStyle = visual.style
        teamImagePath = visual.imagePath
    }

    override fun onCleared() {
        runCatching { getApplication<Application>().unregisterReceiver(visualReceiver) }
        super.onCleared()
    }

}
