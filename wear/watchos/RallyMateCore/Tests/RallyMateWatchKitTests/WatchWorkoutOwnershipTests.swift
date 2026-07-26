import RallyMateCore
@testable import RallyMateWatchKit
import XCTest

/// End-to-end ownership behaviour through the match view model: who may open a
/// recording, how many times, and what survives a relaunch.
@MainActor
final class WatchWorkoutOwnershipTests: XCTestCase {
    private final class OfflinePhoneSync: PhoneSyncing {
        var status = PhoneSyncStatus(connected: false, platformLabel: "iPhone")
        var onStartMatch: ((String, MatchFormat, [MatchEvent], TeamId?, WatchTeamVisual) -> Void)?
        var onTeamImage: ((String, WatchTeamVisual) -> Void)?
        var onAccountContext: ((WatchAccountContext) -> Void)?
        var onAssistantCredentials: ((WatchAssistantCredentials?) -> Void)?
        var onProfileImage: ((URL?, Int) -> Void)?
        var onStatusChanged: ((PhoneSyncStatus) -> Void)?
        var onResumableSnapshot: ((WatchResumableSnapshot) -> Void)?
        var onMatchLifecycle: ((WatchMatchLifecycle) -> Void)?

        func pushEvents(
            matchId _: String,
            format _: MatchFormat,
            events _: [MatchEvent]
        ) async -> Bool { false }

        func requestState(matchId _: String) async -> [MatchEvent]? { nil }
    }

    private func makeStore() throws -> (LocalMatchStore, UserDefaults, String) {
        let suiteName = "WatchWorkoutOwnershipTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (LocalMatchStore(defaults: defaults), defaults, suiteName)
    }

    /// Lets the view model's detached start/end tasks run.
    private func settle() async {
        for _ in 0 ..< 12 { await Task.yield() }
    }

    func testFullMatchOpensAndClosesExactlyOneRecording() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .advantageBo3,
                role: .right,
                recordingMode: .rallyMateManaged
            )
        )
        await settle()
        XCTAssertEqual(workout.acceptedStarts, 1)
        XCTAssertEqual(viewModel.workoutMetrics.state, .running)

        // A whole match of scoring, backgrounding and wrist-down transitions.
        for index in 0 ..< 40 {
            viewModel.point(index.isMultiple(of: 2) ? .a : .b)
            if index.isMultiple(of: 7) { viewModel.prepareForInactive() }
            if index.isMultiple(of: 11) { viewModel.prepareForBackground() }
        }
        await settle()
        XCTAssertEqual(workout.acceptedStarts, 1, "scoring must not re-arm the session")
        XCTAssertEqual(viewModel.workoutMetrics.state, .running)

        viewModel.finishCurrentMatch()
        await settle()

        XCTAssertEqual(viewModel.workoutMetrics.state, .saved)
        XCTAssertEqual(viewModel.workoutMetrics.segments.count, 1)
        XCTAssertTrue(viewModel.workoutMetrics.segments[0].saved)
        XCTAssertEqual(workout.acceptedStarts, 1)
    }

    func testExternalModeKeepsScoringAndNeverOpensASession() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .goldenPointBo3,
                role: .flex,
                recordingMode: .externalManaged
            )
        )
        await settle()

        viewModel.point(.a)
        viewModel.point(.a)
        await settle()

        XCTAssertEqual(workout.acceptedStarts, 0)
        XCTAssertEqual(viewModel.workoutMetrics.state, .externalOwned)
        XCTAssertEqual(viewModel.healthRecordingMode, .externalManaged)
        // Scoring is untouched by the recording choice.
        XCTAssertEqual(viewModel.state?.pointsA, 2)
        XCTAssertEqual(store.loadDefaultHealthRecordingMode(), .externalManaged)
    }

    func testDisabledModeRecordsNothing() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .singleSet,
                role: .left,
                recordingMode: .disabled
            )
        )
        await settle()
        viewModel.point(.b)
        viewModel.finishCurrentMatch()
        await settle()

        XCTAssertEqual(workout.acceptedStarts, 0)
        XCTAssertTrue(viewModel.workoutMetrics.segments.isEmpty)
        XCTAssertEqual(viewModel.workoutMetrics.state, .disabled)
    }

    func testPreemptionKeepsMatchAliveAndSuppressesAutomaticRestart() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .advantageBo3,
                role: .right,
                recordingMode: .rallyMateManaged
            )
        )
        await settle()

        // The user starts Apple Allenamento mid-match.
        workout.simulatePreemption()
        await settle()
        XCTAssertEqual(viewModel.workoutMetrics.state, .externalOwned)
        XCTAssertNotNil(viewModel.workoutMetrics.notice)

        for _ in 0 ..< 25 { viewModel.point(.a) }
        viewModel.pause()
        viewModel.resume()
        viewModel.becameActive()
        await settle()

        XCTAssertEqual(workout.acceptedStarts, 1, "no automatic restart loop")
        XCTAssertEqual(viewModel.workoutMetrics.state, .externalOwned)
        XCTAssertFalse(viewModel.state?.completed ?? true, "match keeps scoring")

        // Explicit consent opens a second segment, and only then.
        viewModel.restartHealthRecording()
        await settle()
        XCTAssertEqual(workout.acceptedStarts, 2)
        XCTAssertEqual(viewModel.workoutMetrics.segments.count, 2)
    }

    func testRecordingModeIsFrozenPerMatchAndSurvivesRelaunch() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .advantageBo3,
                role: .right,
                recordingMode: .externalManaged
            )
        )
        let matchId = viewModel.activeMatchId
        await settle()

        // The user changes the default before the next match: the running one
        // must keep its own owner.
        store.saveDefaultHealthRecordingMode(.rallyMateManaged)

        let relaunched = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )
        await settle()

        XCTAssertEqual(relaunched.activeMatchId, matchId)
        XCTAssertEqual(relaunched.healthRecordingMode, .externalManaged)
        XCTAssertEqual(store.loadHealthRecordingMode(matchId), .externalManaged)
    }

    func testSegmentsAndStateArePersistedForIdempotentFinalisation() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .advantageBo3,
                role: .right,
                recordingMode: .rallyMateManaged
            )
        )
        let matchId = viewModel.activeMatchId
        await settle()
        viewModel.point(.a)
        viewModel.finishCurrentMatch()
        await settle()

        XCTAssertEqual(store.loadWorkoutSegments(matchId).count, 1)
        XCTAssertTrue(store.loadWorkoutSegments(matchId)[0].saved)
        XCTAssertEqual(store.loadRecordingState(matchId), .saved)

        // A relaunch on the completed match must not reopen a recording.
        let relaunched = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )
        await settle()
        relaunched.becameActive()
        await settle()
        XCTAssertEqual(relaunched.workoutMetrics.segments.count, 1)
    }

    func testPhoneDisconnectionDoesNotAffectTheRecording() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        // Sync is offline for the whole match.
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .advantageBo3,
                role: .right,
                recordingMode: .rallyMateManaged
            )
        )
        await settle()
        for _ in 0 ..< 10 { viewModel.point(.a) }
        viewModel.retrySync()
        viewModel.becameActive()
        await settle()

        XCTAssertEqual(workout.acceptedStarts, 1)
        XCTAssertEqual(viewModel.workoutMetrics.state, .running)
        XCTAssertFalse(viewModel.synced)
    }

    /// Closing the app must actually release the workout session. A paused
    /// session that is never ended keeps the workout-processing background mode
    /// alive, so the watch app stays running after the user closes it.
    func testFinishingAPausedMatchClosesTheRecording() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .advantageBo3,
                role: .right,
                recordingMode: .rallyMateManaged
            )
        )
        let matchId = viewModel.activeMatchId
        await settle()
        viewModel.point(.a)
        viewModel.pause()
        await settle()
        XCTAssertEqual(viewModel.workoutMetrics.state, .paused)

        // Terminating straight from the paused state must still close it.
        viewModel.finishCurrentMatch()
        await settle()

        XCTAssertEqual(viewModel.workoutMetrics.state, .saved)
        XCTAssertFalse(
            viewModel.workoutMetrics.active,
            "no session may stay alive after the match is over"
        )
        XCTAssertEqual(viewModel.workoutMetrics.segments.count, 1)
        XCTAssertTrue(viewModel.workoutMetrics.segments[0].saved)

        // Leaving the summary must not reopen anything either.
        viewModel.dismissCompletedMatch()
        await settle()
        XCTAssertFalse(viewModel.workoutMetrics.active)
        XCTAssertEqual(store.loadRecordingState(matchId), .saved)
    }

    func testHealthKitUnavailableKeepsScoringAlive() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        workout.healthAvailable = false
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .advantageBo3,
                role: .right,
                recordingMode: .rallyMateManaged
            )
        )
        await settle()
        viewModel.point(.a)
        viewModel.point(.b)
        await settle()

        XCTAssertEqual(viewModel.workoutMetrics.state, .failed)
        XCTAssertEqual(viewModel.state?.pointsA, 1)
        XCTAssertEqual(viewModel.state?.pointsB, 1)
    }
}
