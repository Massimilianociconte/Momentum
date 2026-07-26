import RallyMateCore
@testable import RallyMateWatchKit
import XCTest

/// Cross-device pause/resume: a match paused on the phone must be visible and
/// resumable from the watch, offline, without losing score or format.
@MainActor
final class WatchResumableSyncTests: XCTestCase {
    private final class StubPhoneSync: PhoneSyncing {
        var status = PhoneSyncStatus(connected: false, platformLabel: "iPhone")
        var onStartMatch: ((String, MatchFormat, [MatchEvent], TeamId?, WatchTeamVisual) -> Void)?
        var onTeamImage: ((String, WatchTeamVisual) -> Void)?
        var onAccountContext: ((WatchAccountContext) -> Void)?
        var onAssistantCredentials: ((WatchAssistantCredentials?) -> Void)?
        var onProfileImage: ((URL?, Int) -> Void)?
        var onStatusChanged: ((PhoneSyncStatus) -> Void)?
        var onResumableSnapshot: ((WatchResumableSnapshot) -> Void)?
        var onMatchLifecycle: ((WatchMatchLifecycle) -> Void)?
        var journal: [MatchEvent] = []
        private(set) var stateRequests = 0

        func pushEvents(
            matchId _: String,
            format _: MatchFormat,
            events _: [MatchEvent]
        ) async -> Bool { false }

        func requestState(matchId _: String) async -> [MatchEvent]? {
            stateRequests += 1
            return journal.isEmpty ? nil : journal
        }
    }

    private func makeStore() throws -> (LocalMatchStore, UserDefaults, String) {
        let suiteName = "WatchResumableSyncTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (LocalMatchStore(defaults: defaults), defaults, suiteName)
    }

    private func settle() async {
        for _ in 0 ..< 12 { await Task.yield() }
    }

    /// A phone journal that reaches 4-1 in the first set.
    private func phoneJournal(
        matchId: String,
        format: MatchFormat,
        paused: Bool
    ) -> [MatchEvent] {
        let engine = ScoringEngine(matchId: matchId, format: format)
        engine.start()
        // Four games to us, one to them.
        for game in 0 ..< 5 {
            let winner: TeamId = game < 4 ? .a : .b
            for _ in 0 ..< 4 { _ = engine.addPoint(winner, method: "TAP") }
        }
        if paused { _ = engine.pause() }
        return engine.allEvents
    }

    // MARK: - Snapshot merge rules

    func testTerminalStatusAlwaysWinsOverResumable() {
        let paused = WatchResumableMatch(
            matchId: "m1",
            status: .paused,
            stateVersion: 9,
            updatedAtMs: 200
        )
        let completed = WatchResumableMatch(
            matchId: "m1",
            status: .completed,
            stateVersion: 3,
            updatedAtMs: 100
        )
        XCTAssertEqual(
            WatchResumableSnapshot.winner(paused, completed).status,
            .completed
        )
        XCTAssertEqual(
            WatchResumableSnapshot.winner(completed, paused).status,
            .completed
        )
    }

    func testHigherStateVersionWinsAndOlderNeverOverwrites() {
        let older = WatchResumableMatch(
            matchId: "m1",
            status: .paused,
            stateVersion: 4,
            updatedAtMs: 100
        )
        let newer = WatchResumableMatch(
            matchId: "m1",
            status: .inProgress,
            stateVersion: 12,
            updatedAtMs: 50
        )
        let snapshot = WatchResumableSnapshot(matches: [newer]).applying(older)
        XCTAssertEqual(snapshot.match("m1")?.stateVersion, 12)
        XCTAssertEqual(snapshot.match("m1")?.status, .inProgress)
    }

    func testResumableListIsOrderedByLastActivity() {
        let snapshot = WatchResumableSnapshot(matches: [
            WatchResumableMatch(matchId: "old", status: .paused, updatedAtMs: 10),
            WatchResumableMatch(matchId: "new", status: .paused, updatedAtMs: 90),
            WatchResumableMatch(matchId: "done", status: .completed, updatedAtMs: 99),
        ])
        XCTAssertEqual(snapshot.resumable.map(\.matchId), ["new", "old"])
    }

    // MARK: - Wire decoding

    func testSnapshotAndLifecycleDecodeFromWirePayload() {
        let match = WatchResumableMatch(
            matchId: "m1",
            status: .paused,
            stateVersion: 7,
            updatedAtMs: 1_700_000_000_000,
            teamLabel: "Noi",
            scoreLine: "40-30",
            setsLabel: "0-0",
            gamesLabel: "4-1"
        )
        let snapshot = WatchSyncDecoding.snapshot(from: [
            "path": WatchSyncPaths.resumable,
            "stateVersion": 7,
            "lastUpdatedAtMs": NSNumber(value: 1_700_000_000_000),
            "activeMatchId": "",
            "matches": WatchResumableMatch.listToJson([match]),
        ])
        XCTAssertEqual(snapshot?.matches.count, 1)
        XCTAssertEqual(snapshot?.matches.first?.gamesLabel, "4-1")
        XCTAssertNil(snapshot?.activeMatchId)

        let lifecycle = WatchSyncDecoding.lifecycle(from: [
            "path": WatchSyncPaths.lifecycle,
            "matchId": "m1",
            "action": "PAUSED",
            "stateVersion": 7,
            "ts": NSNumber(value: 1_700_000_000_000),
        ])
        XCTAssertEqual(lifecycle?.status, .paused)
        // A missing key must still dedup deterministically.
        XCTAssertEqual(lifecycle?.idempotencyKey, "m1#PAUSED#7")
    }

    // MARK: - Paused on the phone, resumed on the watch

    func testMatchPausedOnPhoneAppearsAndResumesOnWatch() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sync = StubPhoneSync()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: sync,
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )

        let matchId = "mt_phone_paused"
        let format = MatchFormat.advantageBo3
        let journal = phoneJournal(matchId: matchId, format: format, paused: true)

        // The phone delivers PAUSED with the full journal over the reliable
        // channel, exactly as transferUserInfo does.
        viewModel.applyMatchLifecycle(
            WatchMatchLifecycle(
                matchId: matchId,
                action: "PAUSED",
                status: .paused,
                stateVersion: journal.count,
                idempotencyKey: "k1",
                timestampMs: journal.last?.ts ?? 0,
                format: format,
                events: journal,
                summary: nil
            )
        )
        await settle()

        let listed = try XCTUnwrap(
            viewModel.resumableMatches.first { $0.matchId == matchId }
        )
        XCTAssertEqual(listed.status, .paused)
        XCTAssertEqual(listed.gamesLabel, "4-1")
        XCTAssertTrue(listed.journalAvailable)
        XCTAssertFalse(listed.subtitle.isEmpty)

        // Resume from the watch, with no phone connection at all.
        viewModel.resumeMatch(matchId, recordingMode: .rallyMateManaged)
        await settle()

        XCTAssertEqual(viewModel.activeMatchId, matchId)
        XCTAssertNil(viewModel.resumeBlockedMessage)
        let state = try XCTUnwrap(viewModel.state)
        XCTAssertFalse(state.paused, "resume must clear the paused flag")
        XCTAssertEqual(state.gamesA, 4)
        XCTAssertEqual(state.gamesB, 1)
        XCTAssertEqual(viewModel.activeFormat.id, format.id)
        XCTAssertTrue(
            store.loadEvents(matchId).contains { $0.type == .matchResumed },
            "MATCH_RESUMED must be appended to the journal"
        )
        // Keeps scoring offline.
        viewModel.point(.a)
        XCTAssertGreaterThan(store.pendingSyncCount(matchId), 0)
    }

    func testResumeIsRefusedWhenTheMatchWasCompletedElsewhere() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )

        let matchId = "mt_done_elsewhere"
        let format = MatchFormat.advantageBo3
        let journal = phoneJournal(matchId: matchId, format: format, paused: true)
        viewModel.applyMatchLifecycle(
            WatchMatchLifecycle(
                matchId: matchId,
                action: "PAUSED",
                status: .paused,
                stateVersion: journal.count,
                idempotencyKey: "k1",
                timestampMs: 1,
                format: format,
                events: journal,
                summary: nil
            )
        )
        await settle()

        // The phone finishes the match on another device.
        viewModel.applyResumableSnapshot(
            WatchResumableSnapshot(
                stateVersion: journal.count + 1,
                lastUpdatedAtMs: 2,
                matches: [
                    WatchResumableMatch(
                        matchId: matchId,
                        status: .completed,
                        stateVersion: journal.count + 1,
                        updatedAtMs: 2
                    ),
                ]
            )
        )
        await settle()

        viewModel.resumeMatch(matchId)
        await settle()

        XCTAssertEqual(
            viewModel.resumeBlockedMessage,
            WatchMatchViewModel.completedElsewhereMessage
        )
        XCTAssertNotEqual(viewModel.activeMatchId, matchId)
        XCTAssertFalse(viewModel.resumableMatches.contains { $0.matchId == matchId })
    }

    func testResumeIsRefusedWhenTheJournalNeverArrived() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sync = StubPhoneSync()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: sync,
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )

        // Snapshot only: the watch knows the match exists but has no events.
        viewModel.applyResumableSnapshot(
            WatchResumableSnapshot(
                stateVersion: 1,
                lastUpdatedAtMs: 10,
                matches: [
                    WatchResumableMatch(
                        matchId: "mt_no_journal",
                        status: .paused,
                        stateVersion: 30,
                        updatedAtMs: 10,
                        eventCount: 30,
                        journalAvailable: false
                    ),
                ]
            )
        )
        await settle()

        viewModel.resumeMatch("mt_no_journal")
        await settle()

        XCTAssertEqual(
            viewModel.resumeBlockedMessage,
            WatchMatchViewModel.notSynchronisedMessage
        )
        XCTAssertTrue(viewModel.activeMatchId.isEmpty)
    }

    func testRedeliveredLifecycleIsAppliedOnlyOnce() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )

        let matchId = "mt_redelivered"
        let format = MatchFormat.advantageBo3
        let journal = phoneJournal(matchId: matchId, format: format, paused: true)
        let lifecycle = WatchMatchLifecycle(
            matchId: matchId,
            action: "PAUSED",
            status: .paused,
            stateVersion: journal.count,
            idempotencyKey: "same-key",
            timestampMs: 5,
            format: format,
            events: journal,
            summary: nil
        )
        viewModel.applyMatchLifecycle(lifecycle)
        // WatchConnectivity may redeliver the same queued payload.
        viewModel.applyMatchLifecycle(lifecycle)
        viewModel.applyMatchLifecycle(lifecycle)
        await settle()

        XCTAssertEqual(store.loadEvents(matchId).count, journal.count)
        XCTAssertEqual(
            viewModel.resumableMatches.filter { $0.matchId == matchId }.count,
            1
        )
    }

    func testTerminalLifecycleClosesActiveWorkoutAndCannotRestoreIt() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
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
        viewModel.point(.a)
        viewModel.pause()
        await settle()
        XCTAssertTrue(viewModel.workoutMetrics.active)

        let terminal = ScoringEngine(matchId: matchId, format: .advantageBo3)
        terminal.loadEvents(store.loadEvents(matchId))
        _ = terminal.finish()
        viewModel.applyMatchLifecycle(
            WatchMatchLifecycle(
                matchId: matchId,
                action: "COMPLETED",
                status: .completed,
                stateVersion: terminal.allEvents.count,
                idempotencyKey: "terminal-\(matchId)",
                timestampMs: terminal.allEvents.last?.ts ?? 0,
                format: .advantageBo3,
                events: terminal.allEvents,
                summary: nil
            )
        )
        await settle()

        XCTAssertTrue(viewModel.activeMatchId.isEmpty)
        XCTAssertNil(store.activeMatchId())
        XCTAssertNil(store.workoutRecoveryMatchId())
        XCTAssertFalse(viewModel.workoutMetrics.active)
        XCTAssertEqual(viewModel.workoutMetrics.state, .saved)
        XCTAssertEqual(
            viewModel.resumeBlockedMessage,
            WatchMatchViewModel.completedElsewhereMessage
        )

        let relaunched = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )
        await settle()
        XCTAssertTrue(relaunched.activeMatchId.isEmpty)
        XCTAssertNil(store.activeMatchId())
    }

    func testStaleLifecycleNeverOverwritesNewerLocalState() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )

        let matchId = "mt_versioned"
        let format = MatchFormat.advantageBo3
        let journal = phoneJournal(matchId: matchId, format: format, paused: true)
        viewModel.applyMatchLifecycle(
            WatchMatchLifecycle(
                matchId: matchId,
                action: "PAUSED",
                status: .paused,
                stateVersion: journal.count,
                idempotencyKey: "new",
                timestampMs: 20,
                format: format,
                events: journal,
                summary: nil
            )
        )
        await settle()
        let storedCount = store.loadEvents(matchId).count

        // An out-of-order, older payload arrives afterwards.
        viewModel.applyMatchLifecycle(
            WatchMatchLifecycle(
                matchId: matchId,
                action: "RESUMED",
                status: .inProgress,
                stateVersion: 2,
                idempotencyKey: "old",
                timestampMs: 1,
                format: format,
                events: Array(journal.prefix(2)),
                summary: nil
            )
        )
        await settle()

        XCTAssertEqual(store.loadEvents(matchId).count, storedCount)
        XCTAssertEqual(
            viewModel.resumableMatches.first { $0.matchId == matchId }?.status,
            .paused
        )
    }

    func testSeveralPausedMatchesAreAllOfferedAndTheRightOneResumes() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )

        let format = MatchFormat.advantageBo3
        for (index, matchId) in ["mt_a", "mt_b", "mt_c"].enumerated() {
            let journal = phoneJournal(matchId: matchId, format: format, paused: true)
            viewModel.applyMatchLifecycle(
                WatchMatchLifecycle(
                    matchId: matchId,
                    action: "PAUSED",
                    status: .paused,
                    stateVersion: journal.count,
                    idempotencyKey: "k\(index)",
                    timestampMs: Int64(100 + index),
                    format: format,
                    events: journal,
                    summary: nil
                )
            )
        }
        await settle()

        XCTAssertEqual(viewModel.resumableMatches.count, 3)
        XCTAssertEqual(viewModel.resumableMatches.first?.matchId, "mt_c")

        viewModel.resumeMatch("mt_b", recordingMode: .disabled)
        await settle()
        XCTAssertEqual(viewModel.activeMatchId, "mt_b")
        XCTAssertEqual(viewModel.state?.gamesA, 4)
        // The resumed one leaves the list; the others stay.
        XCTAssertEqual(
            Set(viewModel.resumableMatches.map(\.matchId)),
            ["mt_a", "mt_c"]
        )
    }

    func testResumeInALaterSessionOpensANewHealthSegment() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WatchWorkoutSessionManager()
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: workout
        )

        // First session on this watch, closed as incomplete.
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
        viewModel.abandonAsIncomplete()
        await settle()
        XCTAssertEqual(workout.acceptedStarts, 1)

        // Next day: the same match is resumed and a NEW segment is opened,
        // never a continuation of the one closed hours earlier.
        viewModel.resumeMatch(matchId, recordingMode: .rallyMateManaged)
        await settle()

        XCTAssertEqual(viewModel.activeMatchId, matchId)
        // The first segment was persisted and restored; the resume adds a
        // second one instead of reopening the closed session.
        XCTAssertEqual(store.loadWorkoutSegments(matchId).count, 2)
        XCTAssertEqual(viewModel.workoutMetrics.segments.count, 2)
        let ids = Set(viewModel.workoutMetrics.segments.map(\.segmentId))
        XCTAssertEqual(ids.count, 2, "each segment carries its own id")
        XCTAssertTrue(
            viewModel.workoutMetrics.segments.allSatisfy {
                $0.provider == "APPLE_HEALTHKIT"
            }
        )
    }

    func testWatchOwnedPauseIsListedWithoutAnyPhoneContact() async throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )

        XCTAssertTrue(
            viewModel.createStandaloneMatch(
                format: .advantageBo3,
                role: .right,
                recordingMode: .disabled
            )
        )
        let matchId = viewModel.activeMatchId
        viewModel.point(.a)
        viewModel.pause()
        await settle()

        // A relaunch must still find it, from the local database alone.
        let relaunched = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )
        await settle()
        XCTAssertEqual(relaunched.activeMatchId, matchId)
        XCTAssertEqual(relaunched.state?.paused, true)
        XCTAssertEqual(
            store.loadResumableSnapshot().match(matchId)?.status,
            .paused
        )
    }
}
