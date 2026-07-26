import Combine
import CoreGraphics
import Foundation
import ImageIO
#if canImport(RallyMateCore)
import RallyMateCore
#endif

public enum WatchPlayerRole: String, CaseIterable, Identifiable, Sendable {
    case right = "RIGHT"
    case left = "LEFT"
    case flex = "FLEX"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .right: "Destra"
        case .left: "Sinistra"
        case .flex: "Flex"
        }
    }
}

@MainActor
public final class WatchMatchViewModel: ObservableObject {
    private let store: LocalMatchStore
    private let sync: any PhoneSyncing
    private let haptics: any WatchHaptics
    private let workout: any WatchWorkoutRecording
    private let assistantCredentials: WatchAssistantCredentialStore

    private var engine: ScoringEngine?
    private var matchId = ""
    private var format = MatchFormat()
    private var syncTask: Task<Void, Never>?
    private var workoutMetricsCancellable: AnyCancellable?
    private var highlightTask: Task<Void, Never>?
    private var voiceFeedbackTask: Task<Void, Never>?
    private var persistedEventFingerprint = ""
    private var persistedWorkoutActive: Bool?
    private var persistedRecordingState: WatchRecordingState?

    @Published public private(set) var state: MatchState?
    @Published public var blindMode = false
    @Published public private(set) var synced = true
    @Published public private(set) var syncStatus = PhoneSyncStatus()
    @Published public private(set) var workoutMetrics = WatchWorkoutMetrics.unavailable
    @Published public private(set) var teamName = ""
    @Published public private(set) var teamScoringStyle = "AUTO"
    @Published public private(set) var teamImage: CGImage?
    @Published public private(set) var profileImage: CGImage?
    @Published public private(set) var accountContext = WatchAccountContext()
    @Published public private(set) var recoverableMatchId: String?
    @Published public private(set) var selectedRole: WatchPlayerRole = .flex
    @Published public private(set) var lastScoredTeam: TeamId?
    @Published public private(set) var scorePulse = 0
    @Published public private(set) var lastVoiceTranscript = ""
    @Published public private(set) var voiceFeedback = ""
    @Published public var finishConfirmationRequested = false
    @Published var pendingVoiceCommand: WatchVoiceCommand?
    /// Matches the user may resume from this watch (ACTIVE + PAUSED), most
    /// recently updated first. Populated from the local database first, then
    /// merged with the phone snapshot.
    @Published public private(set) var resumableMatches: [WatchResumableMatch] = []
    /// Set when a resume is refused (already completed elsewhere, journal not
    /// yet synchronised).
    @Published public var resumeBlockedMessage: String?
    /// Recording owner chosen for the active match (frozen at match start).
    @Published public private(set) var healthRecordingMode: WatchHealthRecordingMode = .rallyMateManaged
    /// Honest verdict on the health data saved for the match.
    @Published public private(set) var healthQuality: WatchHealthDataQuality?

    /// Duo Mode: team assegnato a QUESTO watch (nil = scoring classico).
    @Published public private(set) var duoTeam: TeamId?

    public var canUndo: Bool {
        if let duoTeam { return engine?.canUndoTeam(duoTeam) == true }
        return engine?.canUndo == true
    }
    public var isFreePlay: Bool { format.freePlay }
    public var usesGoldenPoint: Bool { format.goldenPoint }
    public var activeMatchId: String { matchId }
    public var activeFormat: MatchFormat { format }
    public var lastFormat: MatchFormat { store.loadLastFormat() }
    public var lastHealthRecordingMode: WatchHealthRecordingMode {
        store.loadDefaultHealthRecordingMode()
    }
    public var canScore: Bool { state?.completed == false && state?.paused == false }
    /// Match clock, independent from the HealthKit session clock.
    public var matchStartTime: Date? {
        guard let first = engine?.allEvents.first(where: { $0.type == .matchStarted })
            ?? engine?.allEvents.first
        else { return nil }
        return Date(timeIntervalSince1970: Double(first.ts) / 1000)
    }

    public var matchEndTime: Date? {
        guard let last = engine?.allEvents.last(where: { $0.type == .matchCompleted })
        else { return nil }
        return Date(timeIntervalSince1970: Double(last.ts) / 1000)
    }
    public var duoCreationAvailable: Bool {
        accountContext.premiumEnabled && syncStatus.connected
    }

    public init(
        store: LocalMatchStore = LocalMatchStore(),
        sync: any PhoneSyncing = PhoneSync(),
        haptics: any WatchHaptics = SystemWatchHaptics(),
        workout: (any WatchWorkoutRecording)? = nil,
        assistantCredentials: WatchAssistantCredentialStore = WatchAssistantCredentialStore()
    ) {
        self.store = store
        self.sync = sync
        self.haptics = haptics
        self.workout = workout ?? WatchWorkoutSessionManager.shared
        self.assistantCredentials = assistantCredentials
        accountContext = store.loadAccountContext()
        profileImage = store.loadProfileImage().flatMap { decodeTeamImage($0.url) }
        selectedRole = WatchPlayerRole(rawValue: store.loadPlayerRole()) ?? .flex
        recoverableMatchId = store.lastIncompleteMatchId()
        wireWorkoutCallbacks()
        wireSyncCallbacks()
        // 1. local database first, so the list is usable with no phone at all.
        refreshResumableMatches()
        restoreActiveMatch()
    }

    deinit {
        syncTask?.cancel()
        highlightTask?.cancel()
        voiceFeedbackTask?.cancel()
    }

    public func newStandaloneMatch(format: MatchFormat = MatchFormat()) {
        let id = "mt_aw_\(UUID().uuidString.lowercased())"
        startMatch(id: id, format: format, persisted: [], startWorkout: true)
    }

    @discardableResult
    public func createStandaloneMatch(
        format: MatchFormat,
        role: WatchPlayerRole,
        teamName: String = "",
        recordingMode: WatchHealthRecordingMode? = nil
    ) -> Bool {
        guard state == nil else { return false }
        selectedRole = role
        store.savePlayerRole(role.rawValue)
        store.saveLastFormat(format)
        let id = "mt_aw_\(UUID().uuidString.lowercased())"
        let mode = recordingMode ?? store.loadDefaultHealthRecordingMode()
        store.saveDefaultHealthRecordingMode(mode)
        store.saveHealthRecordingMode(id, mode: mode)
        startMatch(
            id: id,
            format: format,
            persisted: [],
            teamVisual: WatchTeamVisual(teamName: teamName),
            startWorkout: true
        )
        return true
    }

    public func startMatch(
        id: String,
        format: MatchFormat,
        persisted: [MatchEvent],
        duoTeam: TeamId? = nil,
        teamVisual: WatchTeamVisual? = nil,
        startWorkout: Bool = false,
        /// True when the user resumes a match paused in an earlier session.
        /// A resume opens a *new* health segment, never a continuation of the
        /// one closed hours or days ago.
        resumingSession: Bool = false
    ) {
        // START_MATCH can be redelivered by WatchConnectivity (for example a
        // queued transfer followed by an immediate retry).  The phone command
        // normally carries configuration only, so an empty incoming journal
        // must never replace events already committed on the watch.
        let storedEvents = store.loadEvents(id)
        let effectiveEvents: [MatchEvent]
        if persisted.isEmpty {
            effectiveEvents = storedEvents
        } else {
            let incomingIds = Set(persisted.map(\.eventId))
            effectiveEvents = persisted + storedEvents.filter {
                !incomingIds.contains($0.eventId)
            }
        }
        matchId = id
        self.format = format
        if let duoTeam {
            store.saveDuoTeam(id, team: duoTeam)
        }
        self.duoTeam = duoTeam ?? store.loadDuoTeam(id)
        let visual = teamVisual ?? store.loadTeamVisual(id)
        store.saveTeamVisual(id, visual: visual)
        teamName = visual.teamName
        teamScoringStyle = visual.style
        teamImage = decodeTeamImage(visual.imageURL)
        let assignedTeam = duoTeam ?? store.loadDuoTeam(id)
        let e = ScoringEngine(
            matchId: id,
            format: format,
            sourceUserId: accountContext.sourceUserId,
            assignedTeam: assignedTeam,
            duoMode: assignedTeam != nil
        )
        if effectiveEvents.isEmpty {
            e.start()
        } else {
            e.loadEvents(effectiveEvents)
        }
        engine = e
        state = e.state
        store.setActiveMatch(id)
        store.clearIncomplete(expected: id)
        recoverableMatchId = store.lastIncompleteMatchId()
        blindMode = false

        // The recording owner is frozen for the whole match: a later change of
        // the default preference must not move ownership mid-match.
        let mode = store.loadHealthRecordingMode(id)
            ?? store.loadDefaultHealthRecordingMode()
        store.saveHealthRecordingMode(id, mode: mode)
        healthRecordingMode = mode
        persistedRecordingState = nil
        // Restore what was already recorded so finalisation stays idempotent
        // and previous segments are never recorded twice.
        workout.restore(
            matchId: id,
            mode: mode,
            segments: store.loadWorkoutSegments(id),
            state: store.loadRecordingState(id) ?? .idle
        )
        refreshHealthQuality()

        persistAndSync()
        if e.state.completed {
            store.setWorkoutActive(id, active: false)
        } else if startWorkout {
            startWorkoutIfNeeded(userInitiated: resumingSession)
        } else if store.isWorkoutActive(id) {
            workout.recoverActiveSession(matchId: id, mode: mode)
        }
        publishLocalStatus()
    }

    public func point(_ team: TeamId, blind: Bool = false) {
        guard let engine, engine.state.paused == false else { return }
        // Duo Mode: questo watch segna SOLO i punti del proprio team — è la
        // barriera anti-duplicazione tra i due smartwatch.
        if let duoTeam, team != duoTeam { return }
        // Scoring never touches the recording lifecycle: the session is opened
        // once at match start and closed once at match end. Re-arming it here
        // was what produced restart ping-pong and 5-minute fragments.
        let result = engine.addPoint(team, method: blind ? "BLIND_TAP" : "TAP")
        guard !result.newEvents.isEmpty else { return }
        state = engine.state
        showScoreFeedback(team)
        haptics.play(result.transitions)
        persistAndSync()
        endWorkoutIfCompleted()
    }

    public func undo() {
        guard let engine, engine.state.paused == false else { return }
        // Duo Mode: undo team-scoped — mai gli eventi dell'altro team (§10).
        let result = engine.undo(team: duoTeam)
        guard !result.newEvents.isEmpty else { return }
        state = engine.state
        haptics.play(result.transitions)
        persistAndSync()
    }

    @discardableResult
    public func handleVoiceCommand(_ text: String) -> Bool {
        lastVoiceTranscript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = WatchVoiceCommand.match(text) else {
            voiceFeedback = lastVoiceTranscript.isEmpty
                ? "Nessun comando rilevato"
                : "Non riconosciuto: \(lastVoiceTranscript)"
            scheduleVoiceFeedbackClear()
            haptics.playError()
            return false
        }
        voiceFeedback = "Riconosciuto: \(match.command.label)"
        if match.requiresConfirmation {
            pendingVoiceCommand = match.command
            haptics.playSuccess()
            return true
        }
        let executed = executeVoiceCommand(match.command)
        scheduleVoiceFeedbackClear()
        return executed
    }

    @discardableResult
    func confirmPendingVoiceCommand() -> Bool {
        guard let command = pendingVoiceCommand else { return false }
        pendingVoiceCommand = nil
        let executed = executeVoiceCommand(command)
        scheduleVoiceFeedbackClear()
        return executed
    }

    func cancelPendingVoiceCommand() {
        pendingVoiceCommand = nil
        voiceFeedback = "Comando annullato"
        scheduleVoiceFeedbackClear()
    }

    @discardableResult
    private func executeVoiceCommand(_ command: WatchVoiceCommand) -> Bool {
        switch command {
        case .pointUs:
            guard canScore else { haptics.playError(); return false }
            point(duoTeam ?? .a)
        case .pointThem:
            guard duoTeam == nil, canScore else {
                haptics.playError()
                return false
            }
            point(.b)
        case .undo:
            guard canUndo, state?.paused == false else {
                haptics.playError()
                return false
            }
            undo()
        case .blindMode:
            guard canScore else { haptics.playError(); return false }
            blindMode = true
        case .pause:
            guard state?.paused == false else { haptics.playError(); return false }
            pause()
        case .resume:
            guard state?.paused == true else { haptics.playError(); return false }
            resume()
        case .finish:
            finishConfirmationRequested = true
        }
        return true
    }

    private func scheduleVoiceFeedbackClear(
        after delay: Duration = .seconds(2)
    ) {
        voiceFeedbackTask?.cancel()
        voiceFeedbackTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.pendingVoiceCommand == nil else { return }
                self?.voiceFeedback = ""
            }
        }
    }

    public func pause() {
        guard let engine, !engine.state.paused, !engine.state.completed else { return }
        guard !engine.pause().isEmpty else { return }
        state = engine.state
        haptics.playSuccess()
        persistAndSync()
        publishLocalStatus()
        Task { [weak self] in
            await self?.workout.pause()
        }
    }

    public func resume() {
        guard let engine, engine.state.paused, !engine.state.completed else { return }
        guard !engine.resume().isEmpty else { return }
        state = engine.state
        haptics.playSuccess()
        persistAndSync()
        Task { [weak self] in
            await self?.workout.resume()
        }
        // Only a start that never happened (e.g. refused while the app was in
        // the background) may still be attempted here; a terminated recording
        // is not restarted without an explicit user request.
        startWorkoutIfNeeded()
        publishLocalStatus()
    }

    public func finishCurrentMatch() {
        guard let engine, !engine.state.completed else { return }
        guard !engine.finish().isEmpty else { return }
        state = engine.state
        finishConfirmationRequested = false
        pendingVoiceCommand = nil
        voiceFeedback = "Partita terminata"
        scheduleVoiceFeedbackClear(after: .milliseconds(850))
        haptics.playSuccess()
        persistAndSync()
        publishLocalStatus()
        endWorkout(reason: .matchFinished)
    }

    public func dismissCompletedMatch() {
        let completedId = matchId
        endWorkout(reason: .matchFinished)
        store.clearActive(expected: completedId)
        store.clearIncomplete(expected: completedId)
        resetToHome()
        refreshResumableMatches()
    }

    public func abandonAsIncomplete() {
        guard let engine, !matchId.isEmpty else { return }
        if !engine.state.paused {
            _ = engine.pause()
        }
        state = engine.state
        persistAndSync()
        let abandonedId = matchId
        store.markIncomplete(abandonedId)
        publishLocalStatus()
        endWorkout(reason: .matchAbandoned)
        resetToHome()
        refreshResumableMatches()
    }

    public func resumeIncompleteMatch() {
        guard let id = recoverableMatchId else { return }
        resumeMatch(id)
    }

    // MARK: - Resumable matches (cross-device)

    /// Rebuilds the list shown on the home screen: everything the watch knows
    /// locally, merged with the latest phone snapshot. Works with no
    /// connectivity at all.
    public func refreshResumableMatches() {
        var snapshot = store.loadResumableSnapshot()
        // Locally known matches that the phone never told us about (started on
        // this watch, or abandoned here) must still be offered.
        for id in store.knownMatchIds() where snapshot.match(id) == nil {
            guard let summary = localSummary(for: id) else { continue }
            snapshot = snapshot.applying(summary)
        }
        store.saveResumableSnapshot(snapshot)
        resumableMatches = snapshot.resumable.filter { $0.matchId != matchId }
        recoverableMatchId = resumableMatches.first?.matchId
            ?? store.lastIncompleteMatchId()
    }

    /// Applies the phone's "latest state" snapshot (application context).
    public func applyResumableSnapshot(_ incoming: WatchResumableSnapshot) {
        // Journals that travelled with the snapshot are not present here; the
        // merge only decides which status/version wins.
        _ = store.mergeResumableSnapshot(incoming)
        // A match completed elsewhere must close on this watch too.
        if !matchId.isEmpty,
           let entry = incoming.match(matchId) {
            closeActiveMatchFromRemote(
                matchId: entry.matchId,
                status: entry.status
            )
        }
        refreshResumableMatches()
    }

    /// Applies a durable per-match lifecycle change (queued transfer).
    /// Idempotent: a redelivered payload is ignored.
    public func applyMatchLifecycle(_ lifecycle: WatchMatchLifecycle) {
        guard store.markLifecycleApplied(lifecycle.idempotencyKey) else { return }
        let known = store.stateVersion(lifecycle.matchId)
        // A lower version never overwrites a newer local state, but a terminal
        // status always wins so a completed match cannot be reopened.
        guard lifecycle.stateVersion >= known || lifecycle.status.isTerminal else {
            return
        }
        store.saveStateVersion(lifecycle.matchId, version: lifecycle.stateVersion)

        if !lifecycle.events.isEmpty {
            // The full journal travels with the lifecycle payload so the watch
            // can resume and keep scoring completely offline.
            let format = lifecycle.format
                ?? store.loadFormat(lifecycle.matchId)
                ?? MatchFormat()
            let merged = mergeJournals(
                stored: store.loadEvents(lifecycle.matchId),
                incoming: lifecycle.events
            )
            // Never hijack the match currently open on this watch.
            store.saveJournal(
                matchId: lifecycle.matchId,
                format: format,
                events: merged
            )
            // If the payload targets the match open right now, the running
            // engine must adopt the merged journal: otherwise the next local
            // point rewrites the file from an engine that never saw these
            // events, silently dropping them.
            if lifecycle.matchId == matchId,
               !lifecycle.status.isTerminal,
               merged.count > (engine?.allEvents.count ?? 0) {
                startMatch(
                    id: lifecycle.matchId,
                    format: format,
                    persisted: merged,
                    duoTeam: duoTeam
                )
            }
        }

        let summary = lifecycle.summary
            ?? localSummary(
                for: lifecycle.matchId,
                status: lifecycle.status,
                stateVersion: lifecycle.stateVersion,
                updatedAtMs: lifecycle.timestampMs
            )
        if let summary {
            _ = store.applyLocalMatchUpdate(summary)
        }

        closeActiveMatchFromRemote(
            matchId: lifecycle.matchId,
            status: lifecycle.status
        )
        refreshResumableMatches()
    }

    /// A terminal phone update is authoritative. Merely showing a warning left
    /// the local workout and active-match pointer alive, allowing WatchConnectivity
    /// recovery to reopen the companion after it had been closed.
    private func closeActiveMatchFromRemote(
        matchId terminalMatchId: String,
        status: WatchMatchStatus
    ) {
        guard !matchId.isEmpty,
              terminalMatchId == matchId,
              status.isTerminal
        else { return }

        resumeBlockedMessage = Self.completedElsewhereMessage
        let reason: WatchRecordingReason = status == .abandoned
            ? .matchAbandoned
            : .matchFinished
        endWorkout(reason: reason)
        store.clearActive(expected: terminalMatchId)
        store.clearIncomplete(expected: terminalMatchId)
        resetToHome()
    }

    /// Resumes a match that was paused here or on another device.
    ///
    /// - Parameter recordingMode: health recording owner for this new session.
    ///   A resume always opens a new health segment, so the choice is asked
    ///   again instead of being inherited.
    public func resumeMatch(
        _ id: String,
        recordingMode: WatchHealthRecordingMode? = nil
    ) {
        guard !id.isEmpty else { return }
        resumeBlockedMessage = nil

        let snapshot = store.loadResumableSnapshot()
        if let entry = snapshot.match(id), entry.status.isTerminal {
            resumeBlockedMessage = Self.completedElsewhereMessage
            haptics.playError()
            return
        }

        let events = store.loadEvents(id)
        guard let storedFormat = store.loadFormat(id) ?? snapshot.match(id)?.format
        else {
            resumeBlockedMessage = Self.notSynchronisedMessage
            haptics.playError()
            return
        }
        guard !events.isEmpty || snapshot.match(id)?.eventCount == 0 else {
            // We know the match exists but its journal never arrived: resuming
            // now would restart from 0-0 and lose the score.
            resumeBlockedMessage = Self.notSynchronisedMessage
            haptics.playError()
            if syncStatus.connected { pullJournal(id) }
            return
        }

        if let recordingMode {
            store.saveDefaultHealthRecordingMode(recordingMode)
            store.saveHealthRecordingMode(id, mode: recordingMode)
        }
        // The MATCH_RESUMED event itself bumps the shared state version
        // (version == number of events in the journal on every device).
        startMatch(
            id: id,
            format: storedFormat,
            persisted: events,
            startWorkout: true,
            resumingSession: true
        )
        if state?.paused == true {
            resume()
        } else {
            publishLocalStatus()
        }
        store.clearIncomplete(expected: id)
        refreshResumableMatches()
    }

    public func dismissResumeBlockedMessage() {
        resumeBlockedMessage = nil
    }

    static let completedElsewhereMessage =
        "Questa partita è già stata terminata su un altro dispositivo."
    static let notSynchronisedMessage =
        "Partita non ancora sincronizzata su questo Watch. Apri Padelandia sull'iPhone quando sono vicini."

    /// Publishes the status of the match owned by this watch so the local list
    /// stays right even with no phone contact.
    private func publishLocalStatus() {
        guard !matchId.isEmpty, let summary = localSummary(for: matchId) else {
            return
        }
        _ = store.applyLocalMatchUpdate(summary)
        refreshResumableMatches()
    }

    private func localSummary(
        for id: String,
        status: WatchMatchStatus? = nil,
        stateVersion: Int? = nil,
        updatedAtMs: Int64? = nil
    ) -> WatchResumableMatch? {
        let events = store.loadEvents(id)
        guard let storedFormat = store.loadFormat(id) else { return nil }
        let derived: MatchState?
        if id == matchId, let state {
            derived = state
        } else if !events.isEmpty {
            let engine = ScoringEngine(matchId: id, format: storedFormat)
            engine.loadEvents(events)
            derived = engine.state
        } else {
            derived = nil
        }
        let resolvedStatus: WatchMatchStatus = status ?? {
            guard let derived else { return .created }
            if derived.completed { return .completed }
            return derived.paused ? .paused : .inProgress
        }()
        let visual = store.loadTeamVisual(id)
        let lastEventMs = events.last?.ts ?? 0
        let pausedMs = events.last(where: { $0.type == .matchPaused })?.ts
        return WatchResumableMatch(
            matchId: id,
            status: resolvedStatus,
            // Version = journal length: both devices derive the same number
            // from the same events, with no clock comparison.
            stateVersion: stateVersion ?? max(store.stateVersion(id), events.count),
            updatedAtMs: updatedAtMs ?? lastEventMs,
            pausedAtMs: resolvedStatus == .paused ? pausedMs : nil,
            teamLabel: visual.teamName,
            scoreLine: derived.map { "\($0.pointsLabel(.a))-\($0.pointsLabel(.b))" } ?? "",
            setsLabel: derived.map { "\($0.setsA)-\($0.setsB)" } ?? "",
            gamesLabel: derived.map { "\($0.gamesA)-\($0.gamesB)" } ?? "",
            format: storedFormat,
            sourceDevice: "APPLE_WATCH",
            eventCount: events.count,
            journalAvailable: !events.isEmpty
        )
    }

    private func mergeJournals(
        stored: [MatchEvent],
        incoming: [MatchEvent]
    ) -> [MatchEvent] {
        // Event ids are UUIDs: an event is applied exactly once regardless of
        // how many times the transport redelivers it.
        var seen = Set(incoming.map(\.eventId))
        var merged = incoming
        for event in stored where !seen.contains(event.eventId) {
            seen.insert(event.eventId)
            merged.append(event)
        }
        return merged.sorted { $0.ts < $1.ts }
    }

    private func pullJournal(_ id: String) {
        Task { [weak self] in
            guard let self,
                  let events = await self.sync.requestState(matchId: id),
                  !events.isEmpty
            else { return }
            let format = self.store.loadFormat(id) ?? MatchFormat()
            self.store.saveJournal(matchId: id, format: format, events: events)
            self.refreshResumableMatches()
        }
    }

    public func refreshFromPhone() {
        guard !matchId.isEmpty else { return }
        let id = matchId
        Task { [weak self] in
            guard let self,
                  let events = await self.sync.requestState(matchId: id),
                  !events.isEmpty
            else { return }
            let remoteIds = Set(events.map(\.eventId))
            let localTail = self.store.loadEvents(id).filter {
                !remoteIds.contains($0.eventId)
            }
            self.startMatch(
                id: id,
                format: self.format,
                persisted: events + localTail,
                duoTeam: self.duoTeam
            )
        }
    }

    public func retrySync() {
        guard !matchId.isEmpty else { return }
        if synced && store.pendingSyncCount(matchId) == 0 { return }
        persistAndSync()
    }

    public func prepareForBackground() {
        persistLocally()
        retrySync()
    }

    public func prepareForInactive() {
        // Wrist-down/Always On transitions are frequent. The point was already
        // committed locally, so avoid waking the radio for a redundant retry.
        persistLocally()
    }

    public func becameActive() {
        if state == nil,
           let requestedFormat = store.consumeSystemQuickStart() {
            _ = createStandaloneMatch(
                format: requestedFormat,
                role: selectedRole,
                teamName: accountContext.defaultTeamName
            )
        }
        // A start refused because the app was in the background (HealthKit
        // rejects those) can legitimately be retried now: no session existed,
        // so no duplicate segment can be produced.
        if let state, !state.completed, !state.paused {
            startWorkoutIfNeeded()
        }
        refreshResumableMatches()
        guard syncStatus.connected else { return }
        retrySync()
        flushStoredPendingMatches()
    }

    private func restoreActiveMatch() {
        if let active = store.activeMatchId() {
            let storedFormat = store.loadFormat(active) ?? MatchFormat()
            startMatch(
                id: active,
                format: storedFormat,
                persisted: store.loadEvents(active)
            )
        }
    }

    private func resetToHome() {
        engine = nil
        matchId = ""
        state = nil
        blindMode = false
        synced = true
        teamImage = nil
        teamName = ""
        duoTeam = nil
        persistedEventFingerprint = ""
        persistedWorkoutActive = nil
        persistedRecordingState = nil
        healthQuality = nil
    }

    private func persistAndSync() {
        guard engine != nil else { return }
        persistLocally()
        let id = matchId
        let syncFormat = format
        synced = false

        syncTask?.cancel()
        syncTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: WatchEnergyPolicy.syncDebounce)
            guard !Task.isCancelled else { return }
            let snapshot = self.store.loadEvents(id)
            let pending = snapshot.filter { !$0.synced }
            guard !pending.isEmpty else {
                self.synced = true
                return
            }
            let sentIds = Set(pending.map(\.eventId))
            let ok = await self.sync.pushEvents(
                matchId: id,
                format: syncFormat,
                events: pending
            )
            guard !Task.isCancelled else { return }
            if ok {
                self.store.markSynced(id, eventIds: sentIds)
                self.synced = self.store.pendingSyncCount(id) == 0
            }
        }
    }

    private func persistLocally() {
        guard let engine, !matchId.isEmpty else { return }
        let events = engine.allEvents
        let fingerprint = "\(matchId):\(events.count):\(events.last?.eventId ?? "-")"
        guard fingerprint != persistedEventFingerprint else { return }
        store.saveMatch(
            matchId: matchId,
            format: format,
            events: events
        )
        persistedEventFingerprint = fingerprint
    }

    private func showScoreFeedback(_ team: TeamId) {
        highlightTask?.cancel()
        lastScoredTeam = team
        scorePulse += 1
        let pulse = scorePulse
        highlightTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.scorePulse == pulse else { return }
                self?.lastScoredTeam = nil
            }
        }
    }

    private func wireWorkoutCallbacks() {
        workoutMetrics = workout.metrics
        workoutMetricsCancellable = workout.metricsPublisher.sink { [weak self] metrics in
            Task { @MainActor in
                guard let self else { return }
                self.workoutMetrics = metrics
                let workoutMatchId = self.matchId.isEmpty
                    ? self.store.workoutRecoveryMatchId()
                    : self.matchId
                guard let workoutMatchId, !workoutMatchId.isEmpty else { return }
                if metrics.active {
                    self.store.setWorkoutRecoveryMatch(workoutMatchId)
                } else if metrics.state.isTerminal {
                    self.store.clearWorkoutRecoveryMatch(expected: workoutMatchId)
                }
                if self.persistedWorkoutActive != metrics.active {
                    self.store.setWorkoutActive(workoutMatchId, active: metrics.active)
                    self.persistedWorkoutActive = metrics.active
                }
                // Segments and state survive a relaunch so the summary keeps
                // every recorded stretch and finalisation stays idempotent.
                self.store.saveWorkoutSegments(workoutMatchId, segments: metrics.segments)
                if self.persistedRecordingState != metrics.state {
                    self.store.saveRecordingState(workoutMatchId, state: metrics.state)
                    self.persistedRecordingState = metrics.state
                }
                if workoutMatchId == self.matchId {
                    self.refreshHealthQuality()
                }
            }
        }
    }

    /// The single automatic entry point. Ownership rules live in the state
    /// machine: duplicates, terminal states and non-managed modes are refused
    /// there, so callers never need to reason about them.
    private func startWorkoutIfNeeded(userInitiated: Bool = false) {
        guard !matchId.isEmpty else { return }
        let id = matchId
        let mode = healthRecordingMode
        Task { [weak self] in
            await self?.workout.start(
                matchId: id,
                mode: mode,
                userInitiated: userInitiated
            )
        }
    }

    /// Explicit user consent to open a new recording after an interruption.
    public func restartHealthRecording() {
        guard !matchId.isEmpty,
              state?.completed == false,
              workoutMetrics.canRestartRecording
        else { return }
        let id = matchId
        let mode = healthRecordingMode
        Task { [weak self] in
            await self?.workout.start(
                matchId: id,
                mode: mode,
                userInitiated: true
            )
        }
    }

    public func dismissHealthNotice() {
        workout.dismissNotice()
    }

    private func endWorkoutIfCompleted() {
        guard state?.completed == true else { return }
        endWorkout(reason: .matchFinished)
    }

    private func endWorkout(reason: WatchRecordingReason) {
        guard !matchId.isEmpty else { return }
        // Capture the id: the caller may reset to home before the async end
        // completes, and the closed segment must still be persisted.
        let id = matchId
        if workout.metrics.active {
            store.setWorkoutRecoveryMatch(id)
        }
        Task { [weak self] in
            await self?.workout.end(reason: reason)
            await MainActor.run {
                guard let self else { return }
                self.store.saveWorkoutSegments(
                    id,
                    segments: self.workout.metrics.segments
                )
                self.store.saveRecordingState(id, state: self.workout.metrics.state)
                if !self.workout.metrics.active, self.workout.metrics.state.isTerminal {
                    self.store.clearWorkoutRecoveryMatch(expected: id)
                }
                self.refreshHealthQuality()
            }
        }
    }

    private func refreshHealthQuality() {
        guard let start = matchStartTime else {
            healthQuality = nil
            return
        }
        healthQuality = workout.quality(
            matchStart: start,
            matchEnd: matchEndTime
        )
    }

    private func wireSyncCallbacks() {
        syncStatus = sync.status
        sync.onStartMatch = { [weak self] id, format, events, duoTeam, visual in
            Task { @MainActor in
                self?.startMatch(
                    id: id,
                    format: format,
                    persisted: events,
                    duoTeam: duoTeam,
                    teamVisual: visual,
                    startWorkout: true
                )
            }
        }
        sync.onTeamImage = { [weak self] id, incoming in
            Task { @MainActor in
                guard let self, self.matchId == id else { return }
                var visual = incoming
                visual.teamName = self.teamName
                self.store.saveTeamVisual(id, visual: visual)
                self.teamScoringStyle = visual.style
                self.teamImage = self.decodeTeamImage(visual.imageURL)
            }
        }
        sync.onAccountContext = { [weak self] context in
            Task { @MainActor in
                guard let self else { return }
                self.accountContext = context
                self.store.saveAccountContext(context)
                if !context.assistantEnabled {
                    self.assistantCredentials.clear()
                }
            }
        }
        sync.onAssistantCredentials = { [weak self] credentials in
            guard let self else { return }
            if let credentials {
                self.assistantCredentials.save(credentials)
            } else {
                self.assistantCredentials.clear()
            }
        }
        sync.onProfileImage = { [weak self] url, version in
            Task { @MainActor in
                guard let self else { return }
                self.store.saveProfileImage(url: url, version: version)
                self.profileImage = self.decodeTeamImage(url)
            }
        }
        sync.onStatusChanged = { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.syncStatus = status
                if status.connected {
                    self.retrySync()
                    self.flushStoredPendingMatches()
                }
            }
        }
        // Latest snapshot of resumable matches (application context).
        sync.onResumableSnapshot = { [weak self] snapshot in
            Task { @MainActor in
                self?.applyResumableSnapshot(snapshot)
            }
        }
        // Durable per-match lifecycle change (queued transfer).
        sync.onMatchLifecycle = { [weak self] lifecycle in
            Task { @MainActor in
                self?.applyMatchLifecycle(lifecycle)
            }
        }
    }

    private func flushStoredPendingMatches() {
        let pending = store.pendingMatchIds().filter { $0 != matchId }
        guard !pending.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            for id in pending {
                guard let storedFormat = self.store.loadFormat(id) else { continue }
                let snapshot = self.store.loadEvents(id)
                let pendingEvents = snapshot.filter { !$0.synced }
                let sentIds = Set(pendingEvents.map(\.eventId))
                guard !sentIds.isEmpty else { continue }
                let ok = await self.sync.pushEvents(
                    matchId: id,
                    format: storedFormat,
                    events: pendingEvents
                )
                if ok {
                    self.store.markSynced(id, eventIds: sentIds)
                }
            }
        }
    }

    private func decodeTeamImage(_ url: URL?) -> CGImage? {
        guard let url,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: WatchEnergyPolicy.imageMaxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: false,
        ] as CFDictionary)
    }
}
