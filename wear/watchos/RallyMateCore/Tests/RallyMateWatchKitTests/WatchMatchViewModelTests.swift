import RallyMateCore
@testable import RallyMateWatchKit
import XCTest

@MainActor
final class WatchMatchViewModelTests: XCTestCase {
    private final class OfflinePhoneSync: PhoneSyncing {
        var status = PhoneSyncStatus(connected: false, platformLabel: "iPhone")
        var onStartMatch: ((String, MatchFormat, [MatchEvent], TeamId?, TeamId, WatchTeamVisual) -> Void)?
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
        ) async -> Bool {
            false
        }

        func requestState(matchId _: String) async -> [MatchEvent]? {
            nil
        }
    }

    func testEventReplyIsFailClosedUntilPhoneCommitAck() {
        XCTAssertTrue(isCommittedEventReply(["ok": true]))
        XCTAssertFalse(isCommittedEventReply(["ok": false]))
        XCTAssertFalse(isCommittedEventReply([:]))
        XCTAssertFalse(isCommittedEventReply(["ok": "true"]))

        let v2Ack: [String: Any] = [
            "ok": true,
            "scoringProtocolVersion": 2,
            "capabilities": ["star_point_v1"],
        ]
        XCTAssertTrue(
            isCommittedEventReply(v2Ack, requiresScoringV2: true)
        )
        // A schema-v1 companion can answer `ok` generically, but that must not
        // clear a Star Point journal.
        XCTAssertFalse(
            isCommittedEventReply(
                ["ok": true],
                requiresScoringV2: true
            )
        )
        XCTAssertFalse(
            isCommittedEventReply(
                [
                    "ok": true,
                    "scoringProtocolVersion": 2,
                    "capabilities": [],
                ],
                requiresScoringV2: true
            )
        )
    }

    func testWatchAdvertisesStarPointScoringProtocol() {
        XCTAssertEqual(WatchSyncPaths.scoringProtocolVersion, 2)
        // Capability tokens are additive: the protocol version stays at 2 so a
        // phone on the previous build still negotiates Star Point.
        XCTAssertEqual(
            WatchSyncPaths.scoringCapabilities,
            ["star_point_v1", "deciding_set_no_tiebreak_v1"]
        )
        XCTAssertEqual(
            WatchToPhoneScoringWirePolicy.eventsPath(for: .starPointBo3),
            "/rallymate/v2/events"
        )
        XCTAssertEqual(
            WatchToPhoneScoringWirePolicy.requestStatePath(
                for: .starPointBo3
            ),
            "/rallymate/v2/request_state"
        )
        XCTAssertEqual(
            WatchToPhoneScoringWirePolicy.eventsPath(for: .advantageBo3),
            "/rallymate/events"
        )
        XCTAssertEqual(
            WatchToPhoneScoringWirePolicy.eventsPath(for: .goldenPointBo3),
            "/rallymate/events"
        )
        XCTAssertEqual(
            WatchToPhoneScoringWirePolicy.requestStatePath(
                for: .advantageBo3
            ),
            "/rallymate/request_state"
        )
    }

    func testStarPointJournalStaysRetryableUntilVersionedCommitAck() throws {
        let suiteName = "WatchV2AckRetryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LocalMatchStore(defaults: defaults)
        let event = MatchEvent(
            eventId: "star-pending-1",
            matchId: "star-match",
            ts: 1,
            type: .pointTeamA,
            teamId: .a
        )
        store.saveMatch(
            matchId: "star-match",
            format: .starPointBo3,
            events: [event]
        )

        let v1OnlyAck: [String: Any] = ["ok": true]
        if isCommittedEventReply(
            v1OnlyAck,
            requiresScoringV2: true
        ) {
            store.markSynced("star-match", eventIds: [event.eventId])
        }
        XCTAssertEqual(store.pendingSyncCount("star-match"), 1)
        XCTAssertTrue(store.pendingMatchIds().contains("star-match"))

        let v2CommitAck: [String: Any] = [
            "ok": true,
            "scoringProtocolVersion": 2,
            "capabilities": ["star_point_v1"],
        ]
        if isCommittedEventReply(
            v2CommitAck,
            requiresScoringV2: true
        ) {
            store.markSynced("star-match", eventIds: [event.eventId])
        }
        XCTAssertEqual(store.pendingSyncCount("star-match"), 0)
    }

    private final class RecordingPhoneSync: PhoneSyncing {
        var status = PhoneSyncStatus(connected: true, platformLabel: "iPhone")
        var onStartMatch: ((String, MatchFormat, [MatchEvent], TeamId?, TeamId, WatchTeamVisual) -> Void)?
        var onTeamImage: ((String, WatchTeamVisual) -> Void)?
        var onAccountContext: ((WatchAccountContext) -> Void)?
        var onAssistantCredentials: ((WatchAssistantCredentials?) -> Void)?
        var onProfileImage: ((URL?, Int) -> Void)?
        var onStatusChanged: ((PhoneSyncStatus) -> Void)?
        var onResumableSnapshot: ((WatchResumableSnapshot) -> Void)?
        var onMatchLifecycle: ((WatchMatchLifecycle) -> Void)?
        var pushCount = 0

        func pushEvents(
            matchId _: String,
            format _: MatchFormat,
            events _: [MatchEvent]
        ) async -> Bool {
            pushCount += 1
            return false
        }

        func requestState(matchId _: String) async -> [MatchEvent]? { nil }
    }

    func testOfflineFinishSurvivesRelaunchAndRemainsQueued() throws {
        let suiteName = "WatchMatchViewModelTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LocalMatchStore(defaults: defaults)
        let first = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics()
        )

        XCTAssertTrue(first.createStandaloneMatch(format: .advantageBo3, role: .right))
        let matchId = first.activeMatchId
        first.point(.a)
        first.finishCurrentMatch()

        XCTAssertTrue(try XCTUnwrap(first.state).completed)
        XCTAssertGreaterThan(store.pendingSyncCount(matchId), 0)
        XCTAssertEqual(store.loadEvents(matchId).last?.type, .matchCompleted)

        let relaunched = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics()
        )
        XCTAssertEqual(relaunched.activeMatchId, matchId)
        XCTAssertTrue(try XCTUnwrap(relaunched.state).completed)

        relaunched.dismissCompletedMatch()
        XCTAssertNil(relaunched.state)
        XCTAssertTrue(store.pendingMatchIds().contains(matchId))
    }

    func testRepeatedStartMatchKeepsOfflineJournalAndPendingIds() throws {
        let suiteName = "WatchRepeatedStartTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LocalMatchStore(defaults: defaults)
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics()
        )
        let matchId = "mt_phone_idempotent"

        viewModel.startMatch(
            id: matchId,
            format: .advantageBo3,
            persisted: []
        )
        viewModel.point(.a)
        viewModel.point(.b)
        let before = store.loadEvents(matchId)
        let pendingBefore = Set(before.filter { !$0.synced }.map(\.eventId))

        viewModel.startMatch(
            id: matchId,
            format: .advantageBo3,
            persisted: []
        )

        let after = store.loadEvents(matchId)
        XCTAssertEqual(after.map(\.eventId), before.map(\.eventId))
        XCTAssertEqual(
            Set(after.filter { !$0.synced }.map(\.eventId)),
            pendingBefore
        )
        XCTAssertEqual(viewModel.state?.pointsLabel(.a), "15")
        XCTAssertEqual(viewModel.state?.pointsLabel(.b), "15")
    }

    func testStandaloneStarPointRelaunchesOfflineAtDecidingPoint() throws {
        let suiteName = "WatchStarPointRelaunchTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LocalMatchStore(defaults: defaults)
        let first = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )
        XCTAssertTrue(
            first.createStandaloneMatch(
                format: .starPointBo3,
                role: .flex,
                recordingMode: .disabled
            )
        )
        for _ in 0 ..< 3 {
            first.point(.a)
            first.point(.b)
        }
        first.point(.a)
        first.point(.b)
        first.point(.b)
        first.point(.a)

        let matchId = first.activeMatchId
        XCTAssertEqual(first.activeFormat, .starPointBo3)
        XCTAssertEqual(first.gameScoringMode, .starPoint)
        XCTAssertTrue(first.usesStarPoint)
        XCTAssertEqual(first.state?.deuceNumber, 3)
        XCTAssertGreaterThan(store.pendingSyncCount(matchId), 0)

        let relaunched = WatchMatchViewModel(
            store: store,
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )
        XCTAssertEqual(relaunched.activeMatchId, matchId)
        XCTAssertEqual(relaunched.activeFormat, .starPointBo3)
        XCTAssertEqual(relaunched.state?.deuceNumber, 3)

        relaunched.point(.a)
        XCTAssertEqual(relaunched.state?.gamesA, 1)
        XCTAssertEqual(relaunched.state?.deuceNumber, 0)
    }

    func testFinishFeedbackClearsWithoutCoveringCompletedSummary() async throws {
        let suiteName = "WatchFinishFeedbackTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = WatchMatchViewModel(
            store: LocalMatchStore(defaults: defaults),
            sync: OfflinePhoneSync(),
            haptics: NoopWatchHaptics()
        )
        XCTAssertTrue(
            viewModel.createStandaloneMatch(format: .advantageBo3, role: .right)
        )
        viewModel.finishCurrentMatch()
        XCTAssertEqual(viewModel.voiceFeedback, "Partita terminata")

        try await Task.sleep(for: .milliseconds(950))
        XCTAssertEqual(viewModel.voiceFeedback, "")
        XCTAssertTrue(try XCTUnwrap(viewModel.state).completed)
    }

    func testWristDownPersistsWithoutRadioRetryButBackgroundRetries() async throws {
        let suiteName = "WatchEnergyLifecycleTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sync = RecordingPhoneSync()
        let viewModel = WatchMatchViewModel(
            store: LocalMatchStore(defaults: defaults),
            sync: sync,
            haptics: NoopWatchHaptics()
        )
        XCTAssertTrue(viewModel.createStandaloneMatch(format: .advantageBo3, role: .flex))
        try await Task.sleep(for: .milliseconds(260))
        let afterStart = sync.pushCount
        XCTAssertGreaterThan(afterStart, 0)

        viewModel.prepareForInactive()
        try await Task.sleep(for: .milliseconds(260))
        XCTAssertEqual(sync.pushCount, afterStart)

        viewModel.prepareForBackground()
        try await Task.sleep(for: .milliseconds(260))
        XCTAssertGreaterThan(sync.pushCount, afterStart)
    }
}
