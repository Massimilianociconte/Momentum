import Foundation

/// Who owns the health recording of a match.
///
/// watchOS allows a single active `HKWorkoutSession` per device: when a second
/// app starts one, the previous session is terminated with
/// `HKError.errorAnotherWorkoutSessionStarted`. RallyMate therefore never
/// competes for ownership — the user picks the owner up front and the app
/// honours that choice for the whole match.
public enum WatchHealthRecordingMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// RallyMate creates and owns the one HealthKit session.
    case rallyMateManaged = "RALLYMATE_MANAGED"
    /// The user records with Apple Allenamento or another provider.
    /// RallyMate only scores and links the imported workout afterwards.
    case externalManaged = "EXTERNAL_MANAGED"
    /// No health recording at all.
    case disabled = "DISABLED"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rallyMateManaged: "Registra con Momentum"
        case .externalManaged: "Uso l'app Allenamento"
        case .disabled: "Non registrare"
        }
    }

    public var subtitle: String {
        switch self {
        case .rallyMateManaged:
            "Momentum apre e chiude l'unico allenamento della partita."
        case .externalManaged:
            "Momentum segna solo i punti e collega dopo il workout da Salute."
        case .disabled:
            "Solo punteggio, nessun dato salute."
        }
    }

    public var shortLabel: String {
        switch self {
        case .rallyMateManaged: "Momentum"
        case .externalManaged: "App esterna"
        case .disabled: "Off"
        }
    }

    public var symbolName: String {
        switch self {
        case .rallyMateManaged: "heart.text.square.fill"
        case .externalManaged: "figure.run.circle.fill"
        case .disabled: "heart.slash.fill"
        }
    }

    /// Shown once on the setup screen: two concurrent workout sessions cannot
    /// coexist on watchOS, so the user must pick one owner.
    public static let exclusivityNote =
        "Non avviare due allenamenti insieme: watchOS ne tiene attivo uno solo."
}

/// Lifecycle of the single recording RallyMate may own for a match.
public enum WatchRecordingState: String, Sendable, Equatable {
    /// Nothing started yet for this match.
    case idle
    /// Authorization / session creation in flight.
    case preparing
    /// Session running and collecting.
    case running
    /// Session paused by the user.
    case paused
    /// `end()` issued, waiting for the delegate to confirm.
    case stopping
    /// `endCollection` + `finishWorkout` in flight.
    case finalizing
    /// Workout persisted in HealthKit. Terminal.
    case saved
    /// Terminal failure without a saved workout.
    case failed
    /// Another app owns the recording (user choice or pre-emption). Terminal
    /// unless the user explicitly asks for a new segment.
    case externalOwned
    /// User disabled health recording for this match. Terminal.
    case disabled

    /// True while RallyMate holds (or is acquiring) the HealthKit session.
    public var ownsSession: Bool {
        switch self {
        case .preparing, .running, .paused, .stopping, .finalizing: true
        case .idle, .saved, .failed, .externalOwned, .disabled: false
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .saved, .failed, .externalOwned, .disabled: true
        default: false
        }
    }
}

/// Why a transition happened. Logged verbatim; never contains health values.
public enum WatchRecordingReason: String, Sendable, Equatable {
    case matchStarted = "MATCH_STARTED"
    case matchResumed = "MATCH_RESUMED"
    case userRetry = "USER_RETRY"
    case sessionRunning = "SESSION_RUNNING"
    case userPaused = "USER_PAUSED"
    case userResumed = "USER_RESUMED"
    case matchFinished = "MATCH_FINISHED"
    case matchAbandoned = "MATCH_ABANDONED"
    case sessionEnded = "SESSION_ENDED"
    case workoutSaved = "WORKOUT_SAVED"
    case finalizeFailed = "FINALIZE_FAILED"
    case recovered = "RECOVERED"
    /// `HKError.errorAnotherWorkoutSessionStarted` — expected, not a crash.
    case preemptedByOtherApp = "PREEMPTED_BY_OTHER_APP"
    case sessionFailed = "SESSION_FAILED"
    case healthUnavailable = "HEALTH_UNAVAILABLE"
    case authorizationDenied = "AUTHORIZATION_DENIED"
    case sessionCreationFailed = "SESSION_CREATION_FAILED"
    case userChoiceExternal = "USER_CHOICE_EXTERNAL"
    case userChoiceDisabled = "USER_CHOICE_DISABLED"
    /// A second start request while a session is already owned (double tap,
    /// redelivered phone command, scoring taps).
    case duplicateStartIgnored = "DUPLICATE_START_IGNORED"
    /// A start request after a terminal state, without explicit user consent.
    case autoRestartSuppressed = "AUTO_RESTART_SUPPRESSED"
}

/// One contiguous stretch of RallyMate-owned recording.
///
/// A match normally has exactly one. Extra segments only appear when the user
/// explicitly restarts recording after a pre-emption, and they are merged (not
/// summed) when computing coverage so overlapping ranges never double count.
public struct WatchWorkoutSegment: Codable, Equatable, Sendable, Identifiable {
    /// Stable id of this health segment. One RallyMate match may span several
    /// segments (paused today, resumed tomorrow) without ever being merged
    /// into one artificial continuous workout.
    public var segmentId: String
    public var startedAt: Date
    public var endedAt: Date?
    public var saved: Bool
    public var endReason: String?
    /// Health provider that owns this segment (`APPLE_HEALTHKIT`, …).
    public var provider: String
    /// Identifier of the workout in the provider, when known.
    public var externalId: String?

    public var id: String { segmentId }

    public init(
        segmentId: String = UUID().uuidString.lowercased(),
        startedAt: Date,
        endedAt: Date? = nil,
        saved: Bool = false,
        endReason: String? = nil,
        provider: String = "APPLE_HEALTHKIT",
        externalId: String? = nil
    ) {
        self.segmentId = segmentId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.saved = saved
        self.endReason = endReason
        self.provider = provider
        self.externalId = externalId
    }

    private enum CodingKeys: String, CodingKey {
        case segmentId, startedAt, endedAt, saved, endReason, provider, externalId
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            segmentId: try values.decodeIfPresent(String.self, forKey: .segmentId)
                ?? UUID().uuidString.lowercased(),
            startedAt: try values.decode(Date.self, forKey: .startedAt),
            endedAt: try values.decodeIfPresent(Date.self, forKey: .endedAt),
            saved: try values.decodeIfPresent(Bool.self, forKey: .saved) ?? false,
            endReason: try values.decodeIfPresent(String.self, forKey: .endReason),
            provider: try values.decodeIfPresent(String.self, forKey: .provider)
                ?? "APPLE_HEALTHKIT",
            externalId: try values.decodeIfPresent(String.self, forKey: .externalId)
        )
    }

    public var isOpen: Bool { endedAt == nil }

    public func duration(now: Date = Date()) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }
}

/// Structured log record: previous state, new state, reason, timestamp and the
/// HealthKit error code. No heart rate, calories or account identifiers.
public struct WatchRecordingTransition: Equatable, Sendable {
    public var from: WatchRecordingState
    public var to: WatchRecordingState
    public var reason: WatchRecordingReason
    public var at: Date
    public var healthKitErrorCode: Int?

    public init(
        from: WatchRecordingState,
        to: WatchRecordingState,
        reason: WatchRecordingReason,
        at: Date,
        healthKitErrorCode: Int? = nil
    ) {
        self.from = from
        self.to = to
        self.reason = reason
        self.at = at
        self.healthKitErrorCode = healthKitErrorCode
    }
}

/// Inputs the HealthKit layer feeds into the state machine.
public enum WatchRecordingEvent: Equatable, Sendable {
    case startAccepted
    case healthUnavailable
    case authorizationDenied
    case creationFailed(code: Int?)
    /// Start refused by the system for a transient reason (typically
    /// `HKError.errorBackgroundWorkoutSessionNotAllowed`). No session existed,
    /// so retrying later creates no duplicate segment.
    case startBlocked(code: Int?)
    case sessionRunning
    case sessionPaused
    case sessionResumed
    case stopRequested(WatchRecordingReason)
    case sessionEnded
    case preempted(code: Int)
    case sessionFailed(code: Int?)
    case finalizeStarted
    case finalizeSucceeded
    case finalizeFailed(code: Int?)
    case recovered(startedAt: Date, paused: Bool)
}

public enum WatchRecordingCompleteness: String, Sendable, Equatable {
    /// One saved segment covering the match.
    case complete
    /// Saved but shorter than the match, or split across segments.
    case partial
    /// Recording owned by another app/provider.
    case external
    /// Nothing recorded.
    case none
    /// Still recording.
    case pending
}

/// Honest verdict on what the saved health data actually represents.
public struct WatchHealthDataQuality: Equatable, Sendable {
    public var completeness: WatchRecordingCompleteness
    public var matchDuration: TimeInterval
    public var recordedDuration: TimeInterval
    public var segmentCount: Int

    public init(
        completeness: WatchRecordingCompleteness,
        matchDuration: TimeInterval,
        recordedDuration: TimeInterval,
        segmentCount: Int
    ) {
        self.completeness = completeness
        self.matchDuration = matchDuration
        self.recordedDuration = recordedDuration
        self.segmentCount = segmentCount
    }

    /// Fraction of the match covered by saved recording, 0...1.
    public var coverage: Double {
        guard matchDuration > 0 else { return 0 }
        return min(1, max(0, recordedDuration / matchDuration))
    }

    public var label: String {
        switch completeness {
        case .complete: "Dati salute completi"
        case .partial: "Dati salute parziali"
        case .external: "Registrato da app esterna"
        case .none: "Nessun dato salute"
        case .pending: "Registrazione in corso"
        }
    }

    public var detail: String {
        switch completeness {
        case .complete:
            "Allenamento \(Self.minutes(recordedDuration)) su partita \(Self.minutes(matchDuration))."
        case .partial:
            "Registrati \(Self.minutes(recordedDuration)) su \(Self.minutes(matchDuration)) di partita"
                + (segmentCount > 1 ? " in \(segmentCount) segmenti." : ".")
        case .external:
            "Collega l'allenamento da Salute: durata partita \(Self.minutes(matchDuration))."
        case .none:
            "Solo punteggio. Durata partita \(Self.minutes(matchDuration))."
        case .pending:
            "Allenamento ancora attivo."
        }
    }

    /// True when the saved workout must not be presented as the match duration.
    public var isPartial: Bool { completeness == .partial }

    static func minutes(_ interval: TimeInterval) -> String {
        "\(Int((interval / 60).rounded())) min"
    }
}

/// Single-owner recording state machine.
///
/// Pure value type with no HealthKit dependency so the full matrix (double tap,
/// duplicate delegate callbacks, pre-emption, background, crash recovery) is
/// unit-testable on the host.
public struct WorkoutRecordingStateMachine: Sendable, Equatable {
    public private(set) var mode: WatchHealthRecordingMode
    public private(set) var state: WatchRecordingState
    public private(set) var segments: [WatchWorkoutSegment]
    public private(set) var lastReason: WatchRecordingReason?
    public private(set) var lastErrorCode: Int?
    /// How many times the HealthKit layer was actually allowed to create a
    /// session for this match. Must stay at 1 for a normal match.
    public private(set) var acceptedStarts = 0
    /// Requests refused by the ownership rules (duplicates, auto-restarts).
    public private(set) var refusedStarts = 0

    public init(mode: WatchHealthRecordingMode = .rallyMateManaged) {
        self.mode = mode
        self.segments = []
        switch mode {
        case .rallyMateManaged: state = .idle
        case .externalManaged: state = .externalOwned
        case .disabled: state = .disabled
        }
    }

    public enum StartDecision: Equatable, Sendable {
        case start
        case rejected(WatchRecordingReason)

        public var isStart: Bool { self == .start }
    }

    /// The only gate that may create an `HKWorkoutSession`.
    ///
    /// `userInitiated` is true only for an explicit tap on "Riavvia
    /// registrazione". Automatic callers (match start, resume, scoring) never
    /// restart a recording that already ended.
    public mutating func requestStart(
        at date: Date,
        userInitiated: Bool = false
    ) -> (decision: StartDecision, transition: WatchRecordingTransition?) {
        switch mode {
        case .disabled:
            return refuse(.userChoiceDisabled, to: .disabled, at: date)
        case .externalManaged:
            return refuse(.userChoiceExternal, to: .externalOwned, at: date)
        case .rallyMateManaged:
            break
        }

        if state.ownsSession {
            return refuse(.duplicateStartIgnored, to: state, at: date)
        }
        if state.isTerminal, !userInitiated {
            return refuse(.autoRestartSuppressed, to: state, at: date)
        }

        acceptedStarts += 1
        let reason: WatchRecordingReason = userInitiated ? .userRetry : .matchStarted
        return (.start, transition(to: .preparing, reason: reason, at: date))
    }

    /// Applies a HealthKit lifecycle event. Returns the transition to log, or
    /// nil when the event is a no-op (duplicate delegate callback).
    @discardableResult
    public mutating func apply(
        _ event: WatchRecordingEvent,
        at date: Date
    ) -> WatchRecordingTransition? {
        switch event {
        case .startAccepted:
            guard state == .preparing else { return nil }
            segments.append(WatchWorkoutSegment(startedAt: date))
            return transition(to: .running, reason: .sessionRunning, at: date)

        case .healthUnavailable:
            guard !state.isTerminal else { return nil }
            return transition(to: .failed, reason: .healthUnavailable, at: date)

        case .authorizationDenied:
            guard !state.isTerminal else { return nil }
            return transition(to: .failed, reason: .authorizationDenied, at: date)

        case let .creationFailed(code):
            guard !state.isTerminal else { return nil }
            return transition(
                to: .failed,
                reason: .sessionCreationFailed,
                at: date,
                code: code
            )

        case let .startBlocked(code):
            guard state == .preparing else { return nil }
            return transition(
                to: .idle,
                reason: .sessionCreationFailed,
                at: date,
                code: code
            )

        case .sessionRunning:
            guard state == .preparing || state == .paused else { return nil }
            if segments.isEmpty || segments.last?.isOpen == false {
                segments.append(WatchWorkoutSegment(startedAt: date))
            }
            return transition(
                to: .running,
                reason: state == .paused ? .userResumed : .sessionRunning,
                at: date
            )

        case .sessionPaused:
            guard state == .running else { return nil }
            return transition(to: .paused, reason: .userPaused, at: date)

        case .sessionResumed:
            guard state == .paused else { return nil }
            return transition(to: .running, reason: .userResumed, at: date)

        case let .stopRequested(reason):
            guard state == .running || state == .paused || state == .preparing
            else { return nil }
            return transition(to: .stopping, reason: reason, at: date)

        case .sessionEnded:
            guard state.ownsSession, state != .finalizing else { return nil }
            closeOpenSegment(at: date, reason: .sessionEnded)
            return transition(to: .finalizing, reason: .sessionEnded, at: date)

        case let .preempted(code):
            // Expected condition, never a restart trigger.
            guard state.ownsSession else { return nil }
            closeOpenSegment(at: date, reason: .preemptedByOtherApp)
            return transition(
                to: .finalizing,
                reason: .preemptedByOtherApp,
                at: date,
                code: code
            )

        case let .sessionFailed(code):
            guard state.ownsSession else { return nil }
            closeOpenSegment(at: date, reason: .sessionFailed)
            return transition(
                to: .finalizing,
                reason: .sessionFailed,
                at: date,
                code: code
            )

        case .finalizeStarted:
            guard state.ownsSession else { return nil }
            closeOpenSegment(at: date, reason: lastReason ?? .sessionEnded)
            guard state != .finalizing else { return nil }
            return transition(to: .finalizing, reason: .sessionEnded, at: date)

        case .finalizeSucceeded:
            guard state == .finalizing else { return nil }
            markLastSegmentSaved()
            let wasPreempted = lastReason == .preemptedByOtherApp
            return transition(
                to: wasPreempted ? .externalOwned : .saved,
                reason: .workoutSaved,
                at: date
            )

        case let .finalizeFailed(code):
            guard state == .finalizing else { return nil }
            let wasPreempted = lastReason == .preemptedByOtherApp
            return transition(
                to: wasPreempted ? .externalOwned : .failed,
                reason: .finalizeFailed,
                at: date,
                code: code
            )

        case let .recovered(startedAt, paused):
            // Adopting a surviving session is allowed while preparing (the
            // normal start path probes for one first) or from a resting state,
            // never on top of a session already being tracked.
            guard state == .idle || state == .preparing || state.isTerminal
            else { return nil }
            if state != .preparing { acceptedStarts += 1 }
            if segments.last?.isOpen != true {
                segments.append(WatchWorkoutSegment(startedAt: startedAt))
            }
            return transition(
                to: paused ? .paused : .running,
                reason: .recovered,
                at: date
            )
        }
    }

    /// Applies a mode change chosen for a *new* match.
    public mutating func reset(mode: WatchHealthRecordingMode) {
        self = WorkoutRecordingStateMachine(mode: mode)
    }

    /// Restores persisted segments after a relaunch so finalisation stays
    /// idempotent and the summary keeps every stretch of the match.
    public mutating func restore(
        segments: [WatchWorkoutSegment],
        state: WatchRecordingState
    ) {
        self.segments = segments
        self.state = state
    }

    // MARK: - Quality

    /// Non-overlapping recorded time inside the match window.
    public func recordedDuration(
        matchStart: Date,
        matchEnd: Date?,
        now: Date = Date()
    ) -> TimeInterval {
        let upperBound = matchEnd ?? now
        let ranges = segments.compactMap { segment -> ClosedRange<Date>? in
            let start = max(segment.startedAt, matchStart)
            let end = min(segment.endedAt ?? now, upperBound)
            guard end > start else { return nil }
            return start...end
        }.sorted { $0.lowerBound < $1.lowerBound }

        var total: TimeInterval = 0
        var current: ClosedRange<Date>?
        for range in ranges {
            guard let open = current else {
                current = range
                continue
            }
            if range.lowerBound <= open.upperBound {
                // Overlapping segments are merged, never summed twice.
                current = open.lowerBound...max(open.upperBound, range.upperBound)
            } else {
                total += open.upperBound.timeIntervalSince(open.lowerBound)
                current = range
            }
        }
        if let open = current {
            total += open.upperBound.timeIntervalSince(open.lowerBound)
        }
        return total
    }

    public func quality(
        matchStart: Date,
        matchEnd: Date?,
        now: Date = Date(),
        completeCoverage: Double = 0.9
    ) -> WatchHealthDataQuality {
        let matchDuration = max(0, (matchEnd ?? now).timeIntervalSince(matchStart))
        let savedSegments = segments.filter(\.saved)
        let recorded = WorkoutRecordingStateMachine.duration(
            of: savedSegments,
            matchStart: matchStart,
            matchEnd: matchEnd,
            now: now
        )

        let completeness: WatchRecordingCompleteness
        switch mode {
        case .disabled:
            completeness = .none
        case .externalManaged:
            completeness = .external
        case .rallyMateManaged:
            if state.ownsSession, matchEnd == nil {
                completeness = .pending
            } else if savedSegments.isEmpty || recorded <= 0 {
                completeness = state == .externalOwned ? .external : .none
            } else if savedSegments.count == 1,
                      matchDuration > 0,
                      recorded / matchDuration >= completeCoverage {
                completeness = .complete
            } else {
                completeness = .partial
            }
        }

        return WatchHealthDataQuality(
            completeness: completeness,
            matchDuration: matchDuration,
            recordedDuration: recorded,
            segmentCount: savedSegments.count
        )
    }

    // MARK: - Private

    private static func duration(
        of segments: [WatchWorkoutSegment],
        matchStart: Date,
        matchEnd: Date?,
        now: Date
    ) -> TimeInterval {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        machine.segments = segments
        return machine.recordedDuration(
            matchStart: matchStart,
            matchEnd: matchEnd,
            now: now
        )
    }

    private mutating func refuse(
        _ reason: WatchRecordingReason,
        to target: WatchRecordingState,
        at date: Date
    ) -> (StartDecision, WatchRecordingTransition?) {
        refusedStarts += 1
        let logged = state == target
            ? WatchRecordingTransition(
                from: state,
                to: target,
                reason: reason,
                at: date,
                healthKitErrorCode: nil
            )
            : transition(to: target, reason: reason, at: date)
        lastReason = reason
        return (.rejected(reason), logged)
    }

    private mutating func transition(
        to target: WatchRecordingState,
        reason: WatchRecordingReason,
        at date: Date,
        code: Int? = nil
    ) -> WatchRecordingTransition {
        let record = WatchRecordingTransition(
            from: state,
            to: target,
            reason: reason,
            at: date,
            healthKitErrorCode: code
        )
        state = target
        lastReason = reason
        if let code { lastErrorCode = code }
        return record
    }

    private mutating func closeOpenSegment(
        at date: Date,
        reason: WatchRecordingReason
    ) {
        guard let index = segments.indices.last, segments[index].isOpen else {
            return
        }
        segments[index].endedAt = max(segments[index].startedAt, date)
        segments[index].endReason = reason.rawValue
    }

    private mutating func markLastSegmentSaved() {
        guard let index = segments.indices.last else { return }
        segments[index].saved = true
    }

    /// Records the provider identifier of the workout just persisted.
    public mutating func attachExternalId(_ externalId: String?) {
        guard let index = segments.indices.last, let externalId else { return }
        segments[index].externalId = externalId
    }
}

public extension WorkoutRecordingStateMachine {
    /// Short user-facing description of the current ownership state.
    var statusText: String {
        switch mode {
        case .disabled: return "Registrazione salute disattivata"
        case .externalManaged: return "Registrazione esterna"
        case .rallyMateManaged: break
        }
        switch state {
        case .idle: return "Allenamento pronto"
        case .preparing: return "Avvio allenamento"
        case .running: return "Allenamento attivo"
        case .paused: return "Allenamento in pausa"
        case .stopping: return "Chiusura allenamento"
        case .finalizing: return "Salvataggio allenamento"
        case .saved: return "Allenamento salvato"
        case .failed: return "Allenamento non salvato"
        case .externalOwned: return "Allenamento gestito da un'altra app"
        case .disabled: return "Registrazione salute disattivata"
        }
    }
}
