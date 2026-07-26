import Combine
import Foundation

#if os(watchOS) && canImport(HealthKit)
import HealthKit
#endif

public struct WatchWorkoutMetrics: Equatable, Sendable {
    public var available: Bool
    public var authorized: Bool
    public var active: Bool
    public var startedAt: Date?
    public var heartRateBPM: Double?
    public var activeEnergyKcal: Double?
    public var status: String
    public var mode: WatchHealthRecordingMode
    public var state: WatchRecordingState
    public var segments: [WatchWorkoutSegment]
    /// User-facing explanation of an expected interruption (another app took
    /// over the workout). Cleared on acknowledgement.
    public var notice: String?
    public var lastErrorCode: Int?

    public init(
        available: Bool,
        authorized: Bool,
        active: Bool,
        startedAt: Date?,
        heartRateBPM: Double?,
        activeEnergyKcal: Double?,
        status: String,
        mode: WatchHealthRecordingMode = .rallyMateManaged,
        state: WatchRecordingState = .idle,
        segments: [WatchWorkoutSegment] = [],
        notice: String? = nil,
        lastErrorCode: Int? = nil
    ) {
        self.available = available
        self.authorized = authorized
        self.active = active
        self.startedAt = startedAt
        self.heartRateBPM = heartRateBPM
        self.activeEnergyKcal = activeEnergyKcal
        self.status = status
        self.mode = mode
        self.state = state
        self.segments = segments
        self.notice = notice
        self.lastErrorCode = lastErrorCode
    }

    public static let unavailable = WatchWorkoutMetrics(
        available: false,
        authorized: false,
        active: false,
        startedAt: nil,
        heartRateBPM: nil,
        activeEnergyKcal: nil,
        status: "Workout non disponibile",
        mode: .rallyMateManaged,
        state: .idle
    )

    public func elapsed(at date: Date = Date()) -> TimeInterval {
        guard active, let startedAt else { return 0 }
        return max(0, date.timeIntervalSince(startedAt))
    }

    /// True when the user may explicitly ask for a new recording segment.
    public var canRestartRecording: Bool {
        mode == .rallyMateManaged
            && (state == .externalOwned || state == .failed)
    }
}

/// HealthKit changes workout state asynchronously. In particular, `resume()`
/// does not make a paused session immediately eligible for `end()`. Keeping the
/// decision pure makes the paused -> running -> ended handshake testable on the
/// host, where a real `HKWorkoutSession` is unavailable.
enum WatchWorkoutSystemState: Equatable, Sendable {
    case notStarted
    case prepared
    case running
    case paused
    case stopped
    case ended
}

enum WatchWorkoutTerminationAction: Equatable, Sendable {
    case waitForStateChange
    case resumeAndWait
    case end
    case finalize
}

enum WatchWorkoutTerminationPolicy {
    static func action(
        for state: WatchWorkoutSystemState
    ) -> WatchWorkoutTerminationAction {
        switch state {
        case .paused:
            // `HKWorkoutSession.end()` is ignored while paused. Resume, then
            // wait for the delegate's `.running` callback before ending.
            .resumeAndWait
        case .running, .stopped:
            .end
        case .ended:
            .finalize
        case .notStarted, .prepared:
            // Start/resume transitions are asynchronous; the delegate will
            // drive termination as soon as HealthKit reaches a valid state.
            .waitForStateChange
        }
    }
}

/// Contract used by the match view model. Implemented by the HealthKit-backed
/// manager on watchOS and by a session-less stand-in elsewhere, so the
/// ownership rules are exercised by host unit tests.
@MainActor
public protocol WatchWorkoutRecording: AnyObject {
    var metrics: WatchWorkoutMetrics { get }
    var metricsPublisher: AnyPublisher<WatchWorkoutMetrics, Never> { get }

    /// The single entry point allowed to create a workout session.
    func start(
        matchId: String,
        mode: WatchHealthRecordingMode,
        userInitiated: Bool
    ) async
    func end(reason: WatchRecordingReason) async
    func pause() async
    func resume() async
    /// Re-attaches a session HealthKit kept alive across an app termination.
    func recoverActiveSession(matchId: String, mode: WatchHealthRecordingMode)
    /// Restores persisted segments/state so finalisation stays idempotent.
    func restore(
        matchId: String,
        mode: WatchHealthRecordingMode,
        segments: [WatchWorkoutSegment],
        state: WatchRecordingState
    )
    func dismissNotice()
    func quality(matchStart: Date, matchEnd: Date?) -> WatchHealthDataQuality
}

/// Messages shown on the watch when the recording owner changes.
enum WatchWorkoutNotice {
    static let preempted =
        "Allenamento preso da un'altra app. Padelandia continua a segnare i punti; i dati salute della partita sono parziali."
    static let authorizationDenied =
        "Permessi Salute non concessi. La partita continua senza dati salute."
    static let unavailable =
        "HealthKit non disponibile. La partita continua senza dati salute."
    static let backgroundBlocked =
        "Apri Padelandia sul Watch per avviare l'allenamento."
}

#if os(watchOS) && canImport(HealthKit)
@MainActor
public final class WatchWorkoutSessionManager: NSObject, ObservableObject, WatchWorkoutRecording {
    public static let shared = WatchWorkoutSessionManager()

    @Published public private(set) var metrics = WatchWorkoutMetrics(
        available: HKHealthStore.isHealthDataAvailable(),
        authorized: false,
        active: false,
        startedAt: nil,
        heartRateBPM: nil,
        activeEnergyKcal: nil,
        status: "Workout pronto"
    )

    public var metricsPublisher: AnyPublisher<WatchWorkoutMetrics, Never> {
        $metrics.eraseToAnyPublisher()
    }

    /// Brand shown in Salute/Fitness for workouts created by this app.
    static let workoutBrandName = "Padelandia"

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
    private var matchId = ""
    /// Serialises `start` so a double tap cannot create two sessions before the
    /// state machine has observed the first one.
    private var startInFlight = false
    private var finalizeInFlight = false
    private var finalizeWatchdog: Task<Void, Never>?
    /// A paused workout must first reach `.running` before HealthKit accepts
    /// `end()`. This remains set across those asynchronous delegate callbacks.
    private var pendingEndReason: WatchRecordingReason?
    private var pendingHeartRateBPM: Double?
    private var pendingActiveEnergyKcal: Double?
    private var lastMetricPublishAt = Date.distantPast

    // MARK: - Public API

    public func start(
        matchId: String,
        mode: WatchHealthRecordingMode,
        userInitiated: Bool = false
    ) async {
        adopt(matchId: matchId, mode: mode)

        guard !startInFlight else {
            record(
                WatchRecordingTransition(
                    from: machine.state,
                    to: machine.state,
                    reason: .duplicateStartIgnored,
                    at: Date()
                )
            )
            return
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            if mode == .rallyMateManaged {
                apply(.healthUnavailable, notice: WatchWorkoutNotice.unavailable)
            }
            return
        }

        let (decision, transition) = machine.requestStart(
            at: Date(),
            userInitiated: userInitiated
        )
        if let transition { record(transition) }
        guard decision.isStart else {
            publishState()
            return
        }

        startInFlight = true
        defer { startInFlight = false }
        publishState()

        do {
            guard try await requestAuthorization() else {
                apply(
                    .authorizationDenied,
                    notice: WatchWorkoutNotice.authorizationDenied
                )
                return
            }
        } catch {
            apply(
                .authorizationDenied,
                notice: WatchWorkoutNotice.authorizationDenied,
                code: (error as? HKError)?.errorCode
            )
            return
        }

        // A session RallyMate already owns (crash, force quit) must be adopted
        // instead of creating a second one.
        if await adoptRecoveredSessionIfAny() { return }

        // The match may have ended while authorization was pending.
        guard machine.state == .preparing else { return }

        let configuration = HKWorkoutConfiguration()
        // HealthKit has no padel activity. `.paddleSports` is documented as
        // canoeing/kayaking/SUP, so `.tennis` is the closest correct racket
        // sport available in the SDK.
        configuration.activityType = .tennis
        configuration.locationType = .unknown

        let created: HKWorkoutSession
        do {
            created = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
        } catch let error as HKError
            where error.code == .errorAnotherWorkoutSessionStarted
        {
            // Expected: the user already started a workout elsewhere.
            apply(
                .preempted(code: error.errorCode),
                notice: WatchWorkoutNotice.preempted
            )
            return
        } catch let error as HKError
            where error.code == .errorBackgroundWorkoutSessionNotAllowed
        {
            // Nothing was created, so retrying on foreground is not a restart.
            apply(
                .startBlocked(code: error.errorCode),
                notice: WatchWorkoutNotice.backgroundBlocked
            )
            return
        } catch {
            apply(
                .creationFailed(code: (error as? HKError)?.errorCode),
                notice: "Allenamento non avviato: \(error.localizedDescription)"
            )
            return
        }

        guard machine.state == .preparing else {
            // Ownership changed under us: release the session instead of
            // leaving an orphan running.
            created.end()
            return
        }

        let liveBuilder = created.associatedWorkoutBuilder()
        liveBuilder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        created.delegate = self
        liveBuilder.delegate = self

        session = created
        builder = liveBuilder
        pendingEndReason = nil
        pendingHeartRateBPM = nil
        pendingActiveEnergyKcal = nil
        lastMetricPublishAt = .distantPast

        let startDate = Date()
        // No countdown UI, so the activity starts immediately; `prepare()` is
        // intentionally skipped (it only pre-warms sensors before a delay).
        created.startActivity(with: startDate)
        apply(.startAccepted, at: startDate, notice: nil)

        // Brand the workout so Salute/Fitness can attribute it to Padelandia.
        // The source name still comes from the app's localized display name;
        // the system decides how it renders both.
        try? await liveBuilder.addMetadata([
            HKMetadataKeyWorkoutBrandName: Self.workoutBrandName,
        ])

        do {
            try await liveBuilder.beginCollection(at: startDate)
        } catch {
            // Scoring must never depend on HealthKit: keep the match running
            // and surface the degraded state.
            metrics.status = "Allenamento senza metriche live"
            metrics.lastErrorCode = (error as? HKError)?.errorCode
        }
    }

    public func end(reason: WatchRecordingReason = .matchFinished) async {
        guard machine.state.ownsSession else {
            publishState()
            return
        }
        apply(.stopRequested(reason), notice: nil)

        guard let session else {
            pendingEndReason = nil
            finalize(at: Date(), reason: reason)
            return
        }
        pendingEndReason = reason
        drivePendingEnd(for: session)
        scheduleFinalizeWatchdog(reason: reason)
    }

    public func pause() async {
        guard let session, session.state == .running else { return }
        session.pause()
    }

    public func resume() async {
        guard let session, session.state == .paused else { return }
        session.resume()
    }

    public func recoverActiveSession(
        matchId: String,
        mode: WatchHealthRecordingMode
    ) {
        adopt(matchId: matchId, mode: mode)
        guard mode == .rallyMateManaged,
              HKHealthStore.isHealthDataAvailable(),
              session == nil,
              !startInFlight
        else { return }

        Task { [weak self] in
            _ = await self?.adoptRecoveredSessionIfAny()
        }
    }

    public func restore(
        matchId: String,
        mode: WatchHealthRecordingMode,
        segments: [WatchWorkoutSegment],
        state: WatchRecordingState
    ) {
        self.matchId = matchId
        machine.reset(mode: mode)
        machine.restore(segments: segments, state: state)
        pendingEndReason = state == .stopping || state == .finalizing
            ? .sessionEnded
            : nil
        publishState()
    }

    public func dismissNotice() {
        metrics.notice = nil
    }

    public func quality(
        matchStart: Date,
        matchEnd: Date?
    ) -> WatchHealthDataQuality {
        machine.quality(matchStart: matchStart, matchEnd: matchEnd)
    }

    // MARK: - Ownership plumbing

    private func adopt(matchId: String, mode: WatchHealthRecordingMode) {
        guard matchId != self.matchId || mode != machine.mode else { return }
        // A different match (or a changed preference) always starts from a
        // clean machine; the previous one is already terminal by construction.
        self.matchId = matchId
        machine.reset(mode: mode)
        metrics.mode = mode
        // The chosen mode is shown as a chip; a notice is reserved for
        // unexpected events the user did not ask for.
        metrics.notice = nil
        metrics.lastErrorCode = nil
        publishState()
    }

    private func adoptRecoveredSessionIfAny() async -> Bool {
        let recovered: HKWorkoutSession? = await withCheckedContinuation { continuation in
            healthStore.recoverActiveWorkoutSession { session, _ in
                continuation.resume(returning: session)
            }
        }
        guard let recovered else { return false }
        attach(recovered)
        return true
    }

    private func attach(_ recovered: HKWorkoutSession) {
        let recoveredBuilder = recovered.associatedWorkoutBuilder()
        recoveredBuilder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: recovered.workoutConfiguration
        )
        recovered.delegate = self
        recoveredBuilder.delegate = self
        session = recovered
        builder = recoveredBuilder

        // A process death between `resume()` and the `.running` callback must
        // not turn a persisted stop request into an immortal workout.
        if machine.state == .stopping || machine.state == .finalizing {
            pendingEndReason = pendingEndReason ?? .sessionEnded
            drivePendingEnd(for: recovered)
            scheduleFinalizeWatchdog(reason: pendingEndReason ?? .sessionEnded)
            return
        }

        let startedAt = recovered.startDate
            ?? recoveredBuilder.startDate
            ?? Date()
        apply(
            .recovered(startedAt: startedAt, paused: recovered.state == .paused),
            notice: nil
        )
        metrics.startedAt = startedAt
    }

    private func finalize(at date: Date, reason: WatchRecordingReason) {
        finalizeWatchdog?.cancel()
        finalizeWatchdog = nil
        pendingEndReason = nil
        guard !finalizeInFlight else { return }
        guard machine.state.ownsSession || machine.state == .finalizing else {
            return
        }

        guard let builder else {
            apply(.finalizeStarted, at: date, notice: nil)
            apply(.finalizeFailed(code: nil), at: date, notice: nil)
            session = nil
            return
        }

        finalizeInFlight = true
        apply(.finalizeStarted, at: date, notice: nil)

        Task { [weak self] in
            guard let self else { return }
            do {
                try await builder.endCollection(at: date)
                let workout = try await builder.finishWorkout()
                self.apply(.finalizeSucceeded, at: date, notice: nil)
                // Keep the provider identifier on the segment so the phone can
                // link this stretch without guessing.
                self.machine.attachExternalId(workout?.uuid.uuidString)
                self.publishState()
            } catch {
                self.apply(
                    .finalizeFailed(code: (error as? HKError)?.errorCode),
                    at: date,
                    notice: nil
                )
            }
            self.finalizeInFlight = false
            self.session = nil
            self.builder = nil
            _ = reason
        }
    }

    /// `end()` relies on the session delegate. If watchOS delays the `.ended`
    /// transition, re-drive the state but retain the session until HealthKit
    /// confirms that session mode has actually exited.
    private func scheduleFinalizeWatchdog(reason: WatchRecordingReason) {
        finalizeWatchdog?.cancel()
        finalizeWatchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            guard let self,
                  self.machine.state == .stopping || self.machine.state == .finalizing
            else { return }
            guard let session = self.session else {
                self.finalize(at: Date(), reason: reason)
                return
            }
            self.drivePendingEnd(for: session)
            guard self.machine.state == .stopping || self.machine.state == .finalizing
            else { return }
            // Never finish the builder or drop our session reference while the
            // system still reports paused/running/stopped. Doing so leaves
            // workout-processing alive and the app recoverable after a close.
            self.scheduleFinalizeWatchdog(reason: reason)
        }
    }

    private func drivePendingEnd(for session: HKWorkoutSession) {
        guard let reason = pendingEndReason else { return }
        switch WatchWorkoutTerminationPolicy.action(for: systemState(of: session)) {
        case .waitForStateChange:
            break
        case .resumeAndWait:
            session.resume()
        case .end:
            session.end()
        case .finalize:
            finalize(at: session.endDate ?? Date(), reason: reason)
        }
    }

    private func systemState(of session: HKWorkoutSession) -> WatchWorkoutSystemState {
        switch session.state {
        case .notStarted:
            .notStarted
        case .prepared:
            .prepared
        case .running:
            .running
        case .paused:
            .paused
        case .stopped:
            .stopped
        case .ended:
            .ended
        @unknown default:
            // A future state must not accidentally receive an invalid command.
            .notStarted
        }
    }

    private func requestAuthorization() async throws -> Bool {
        let workoutType = HKObjectType.workoutType()
        var readTypes: Set<HKObjectType> = [workoutType]
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergy)
        }
        try await healthStore.requestAuthorization(toShare: [workoutType], read: readTypes)
        return healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized
    }

    // MARK: - State publishing

    private func apply(
        _ event: WatchRecordingEvent,
        at date: Date = Date(),
        notice: String?,
        code: Int? = nil
    ) {
        if let transition = machine.apply(event, at: date) {
            record(transition)
        } else {
            publishState()
        }
        if let notice { metrics.notice = notice }
        if let code { metrics.lastErrorCode = code }
    }

    private func record(_ transition: WatchRecordingTransition) {
        WatchWorkoutLog.log(transition, matchId: matchId)
        publishState()
    }

    private func publishState() {
        let state = machine.state
        metrics.mode = machine.mode
        metrics.state = state
        metrics.segments = machine.segments
        metrics.available = HKHealthStore.isHealthDataAvailable()
        metrics.authorized = state.ownsSession || state == .saved
        metrics.active = state.ownsSession
        metrics.startedAt = machine.segments.last?.startedAt ?? metrics.startedAt
        metrics.lastErrorCode = machine.lastErrorCode ?? metrics.lastErrorCode
        metrics.status = machine.statusText
        if !state.ownsSession {
            metrics.heartRateBPM = nil
        }
    }
}

extension WatchWorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            guard workoutSession === self.session else { return }
            switch toState {
            case .running:
                if pendingEndReason != nil {
                    // This is the acknowledgement of the asynchronous resume
                    // requested while ending a paused workout.
                    drivePendingEnd(for: workoutSession)
                } else {
                    apply(.sessionRunning, at: date, notice: nil)
                }
            case .paused:
                if pendingEndReason != nil {
                    drivePendingEnd(for: workoutSession)
                } else {
                    apply(.sessionPaused, at: date, notice: nil)
                }
            case .stopped:
                // Activity stopped but the session is still open: close it so
                // the builder can be finalised exactly once.
                apply(.stopRequested(.sessionEnded), at: date, notice: nil)
                pendingEndReason = pendingEndReason ?? .sessionEnded
                drivePendingEnd(for: workoutSession)
            case .ended:
                let reason = pendingEndReason ?? .sessionEnded
                pendingEndReason = nil
                apply(.sessionEnded, at: date, notice: nil)
                finalize(at: date, reason: reason)
            case .notStarted, .prepared:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        // Always delivered before the matching state change, so the reason is
        // recorded before the session ends.
        Task { @MainActor in
            guard workoutSession === self.session else { return }
            let code = (error as? HKError)?.errorCode
            let reason: WatchRecordingReason
            if (error as? HKError)?.code == .errorAnotherWorkoutSessionStarted {
                reason = .preemptedByOtherApp
                apply(
                    .preempted(code: code ?? HKError.Code.errorAnotherWorkoutSessionStarted.rawValue),
                    notice: WatchWorkoutNotice.preempted
                )
            } else {
                reason = .sessionFailed
                apply(
                    .sessionFailed(code: code),
                    notice: "Allenamento interrotto: \(error.localizedDescription)"
                )
            }
            // HealthKit documents that the error callback precedes its matching
            // state change. Keep the session attached until `.ended` confirms
            // that background workout mode has been released.
            pendingEndReason = reason
            drivePendingEnd(for: workoutSession)
            scheduleFinalizeWatchdog(reason: reason)
        }
    }
}

extension WatchWorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            var collectedMetric = false
            if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
               collectedTypes.contains(heartRateType),
               let statistics = workoutBuilder.statistics(for: heartRateType),
               let quantity = statistics.mostRecentQuantity() {
                pendingHeartRateBPM = quantity.doubleValue(
                    for: HKUnit.count().unitDivided(by: .minute())
                )
                collectedMetric = true
            }

            if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
               collectedTypes.contains(energyType),
               let statistics = workoutBuilder.statistics(for: energyType),
               let quantity = statistics.sumQuantity() {
                pendingActiveEnergyKcal = quantity.doubleValue(for: .kilocalorie())
                collectedMetric = true
            }

            let now = Date()
            if collectedMetric,
               metrics.heartRateBPM == nil
                   || now.timeIntervalSince(lastMetricPublishAt)
                       >= WatchEnergyPolicy.workoutMetricPublishInterval {
                metrics.heartRateBPM = pendingHeartRateBPM
                metrics.activeEnergyKcal = pendingActiveEnergyKcal
                lastMetricPublishAt = now
            }
        }
    }
}
#else
/// Session-less stand-in used on iOS/macOS builds and by host unit tests.
/// It runs the same ownership state machine so the "single owner, no auto
/// restart, idempotent finalisation" rules are covered without HealthKit.
@MainActor
public final class WatchWorkoutSessionManager: ObservableObject, WatchWorkoutRecording {
    public static let shared = WatchWorkoutSessionManager()

    @Published public private(set) var metrics = WatchWorkoutMetrics.unavailable

    public var metricsPublisher: AnyPublisher<WatchWorkoutMetrics, Never> {
        $metrics.eraseToAnyPublisher()
    }

    /// Number of sessions the machine actually authorised. Host tests assert
    /// this stays at 1 for a full match.
    public private(set) var acceptedStarts = 0
    public private(set) var refusedStarts = 0

    private var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
    private var matchId = ""
    /// Simulates HealthKit availability in tests.
    public var healthAvailable = true

    public init() {}

    public func start(
        matchId: String,
        mode: WatchHealthRecordingMode,
        userInitiated: Bool = false
    ) async {
        if matchId != self.matchId || mode != machine.mode {
            self.matchId = matchId
            machine.reset(mode: mode)
        }
        guard healthAvailable else {
            apply(.healthUnavailable, notice: WatchWorkoutNotice.unavailable)
            return
        }
        let (decision, transition) = machine.requestStart(
            at: Date(),
            userInitiated: userInitiated
        )
        if let transition { WatchWorkoutLog.log(transition, matchId: matchId) }
        acceptedStarts = machine.acceptedStarts
        refusedStarts = machine.refusedStarts
        guard decision.isStart else {
            publishState()
            return
        }
        apply(.startAccepted, notice: nil)
    }

    public func end(reason: WatchRecordingReason = .matchFinished) async {
        guard machine.state.ownsSession else {
            publishState()
            return
        }
        apply(.stopRequested(reason), notice: nil)
        apply(.sessionEnded, notice: nil)
        apply(.finalizeSucceeded, notice: nil)
    }

    public func pause() async {
        apply(.sessionPaused, notice: nil)
    }

    public func resume() async {
        apply(.sessionResumed, notice: nil)
    }

    public func recoverActiveSession(
        matchId: String,
        mode: WatchHealthRecordingMode
    ) {
        if matchId != self.matchId || mode != machine.mode {
            self.matchId = matchId
            machine.reset(mode: mode)
        }
    }

    public func restore(
        matchId: String,
        mode: WatchHealthRecordingMode,
        segments: [WatchWorkoutSegment],
        state: WatchRecordingState
    ) {
        self.matchId = matchId
        machine.reset(mode: mode)
        machine.restore(segments: segments, state: state)
        publishState()
    }

    public func dismissNotice() {
        metrics.notice = nil
    }

    public func quality(
        matchStart: Date,
        matchEnd: Date?
    ) -> WatchHealthDataQuality {
        machine.quality(matchStart: matchStart, matchEnd: matchEnd)
    }

    /// Test hook: simulates another app taking the workout session.
    public func simulatePreemption() {
        apply(
            .preempted(code: 8),
            notice: WatchWorkoutNotice.preempted
        )
        apply(.finalizeSucceeded, notice: nil)
    }

    private func apply(_ event: WatchRecordingEvent, notice: String?) {
        if let transition = machine.apply(event, at: Date()) {
            WatchWorkoutLog.log(transition, matchId: matchId)
        }
        if let notice { metrics.notice = notice }
        publishState()
    }

    private func publishState() {
        acceptedStarts = machine.acceptedStarts
        refusedStarts = machine.refusedStarts
        metrics.available = healthAvailable
        metrics.mode = machine.mode
        metrics.state = machine.state
        metrics.segments = machine.segments
        metrics.active = machine.state.ownsSession
        metrics.authorized = machine.state.ownsSession || machine.state == .saved
        metrics.startedAt = machine.segments.last?.startedAt ?? metrics.startedAt
        metrics.lastErrorCode = machine.lastErrorCode
        metrics.status = machine.statusText
    }
}
#endif
