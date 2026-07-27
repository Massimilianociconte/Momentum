import RallyMateCore
@testable import RallyMateWatchKit
import XCTest

/// Cross-device pause/resume: a match paused on the phone must be visible and
/// resumable from the watch, offline, without losing score or format.
@MainActor
final class WatchResumableSyncTests: XCTestCase {
    private final class StubPhoneSync: PhoneSyncing {
        var status = PhoneSyncStatus(connected: false, platformLabel: "iPhone")
        var onStartMatch: ((String, MatchFormat, [MatchEvent], TeamId?, TeamId, WatchTeamVisual) -> Void)?
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

    func testAuthoritativeStarClearRemovesPhoneEntryButPreservesPendingTail() {
        let stale = WatchResumableMatch(
            matchId: "stale-star",
            status: .paused,
            format: .starPointBo3
        )
        let pending = WatchResumableMatch(
            matchId: "pending-star",
            status: .paused,
            format: .starPointBo3
        )
        let classic = WatchResumableMatch(
            matchId: "classic",
            status: .paused,
            format: .advantageBo3
        )
        let stored = WatchResumableSnapshot(matches: [stale, pending, classic])
        let cleared = stored.merging(
            WatchResumableSnapshot(
                authoritative: true,
                authoritySource: "PHONE",
                authorityScope: WatchSnapshotAuthorityScope.starPoint.rawValue,
                authorityVersion: 20
            ),
            protectedMatchIds: ["pending-star"]
        )

        XCTAssertNil(cleared.match("stale-star"))
        XCTAssertNotNil(cleared.match("pending-star"))
        XCTAssertNotNil(cleared.match("classic"))
        XCTAssertEqual(
            cleared.authorityVersions?[
                WatchSnapshotAuthorityScope.starPoint.rawValue
            ],
            20
        )
    }

    func testOlderReconnectSnapshotCannotResurrectStarAfterClear() {
        let star = WatchResumableMatch(
            matchId: "star",
            status: .paused,
            format: .starPointBo3
        )
        let initial = WatchResumableSnapshot(matches: [star])
        let cleared = initial.merging(
            WatchResumableSnapshot(
                authoritative: true,
                authoritySource: "PHONE",
                authorityScope: WatchSnapshotAuthorityScope.starPoint.rawValue,
                authorityVersion: 30
            )
        )
        let staleReconnect = cleared.merging(
            WatchResumableSnapshot(
                matches: [star],
                authoritative: true,
                authoritySource: "PHONE",
                authorityScope: WatchSnapshotAuthorityScope.starPoint.rawValue,
                authorityVersion: 29
            )
        )

        XCTAssertNil(staleReconnect.match("star"))
    }

    func testLifecycleAndSnapshotClearConvergeInEitherDeliveryOrder() throws {
        let star = WatchResumableMatch(
            matchId: "star-lifecycle",
            status: .paused,
            format: .starPointBo3
        )
        let clear = WatchResumableSnapshot(
            authoritative: true,
            authoritySource: "PHONE",
            authorityScope: WatchSnapshotAuthorityScope.starPoint.rawValue,
            authorityVersion: 20
        )

        let clearFirst = WatchResumableSnapshot(matches: [star]).merging(clear)
        XCTAssertNil(
            clearFirst.acceptingLifecycleAuthority(
                source: "PHONE",
                scope: .starPoint,
                version: 19
            )
        )
        XCTAssertNil(
            clearFirst.acceptingLifecycleAuthority(
                source: nil,
                scope: .starPoint,
                version: 0
            )
        )
        XCTAssertNil(clearFirst.match(star.matchId))

        let lifecycleAuthority = try XCTUnwrap(
            WatchResumableSnapshot.empty.acceptingLifecycleAuthority(
                source: "PHONE",
                scope: .starPoint,
                version: 19
            )
        )
        let lifecycleFirst = lifecycleAuthority.applying(star)
        XCTAssertNotNil(lifecycleFirst.match(star.matchId))
        XCTAssertNil(lifecycleFirst.merging(clear).match(star.matchId))
    }

    func testLifecycleNewerThanClearMayReintroduceCurrentPhoneState() throws {
        let clear = WatchResumableSnapshot(
            authoritative: true,
            authoritySource: "PHONE",
            authorityScope: WatchSnapshotAuthorityScope.starPoint.rawValue,
            authorityVersion: 20
        )
        let cleared = WatchResumableSnapshot.empty.merging(clear)
        let accepted = try XCTUnwrap(
            cleared.acceptingLifecycleAuthority(
                source: "PHONE",
                scope: .starPoint,
                version: 21
            )
        )
        let updated = accepted.applying(
            WatchResumableMatch(
                matchId: "new-star",
                status: .paused,
                format: .starPointBo3
            )
        )
        XCTAssertNotNil(updated.match("new-star"))
    }

    func testViewModelRejectsDelayedLifecycleAfterNewerStarClear() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )
        let matchId = "delayed-star-lifecycle"
        viewModel.applyResumableSnapshot(
            WatchResumableSnapshot(
                authoritative: true,
                authoritySource: "PHONE",
                authorityScope: WatchSnapshotAuthorityScope.starPoint.rawValue,
                authorityVersion: 20
            )
        )

        viewModel.applyMatchLifecycle(
            WatchMatchLifecycle(
                matchId: matchId,
                action: "PAUSED",
                status: .paused,
                stateVersion: 4,
                idempotencyKey: "delayed-star#4",
                timestampMs: 100,
                format: .starPointBo3,
                events: [],
                summary: WatchResumableMatch(
                    matchId: matchId,
                    status: .paused,
                    stateVersion: 4,
                    updatedAtMs: 100,
                    format: .starPointBo3
                ),
                authoritySource: "PHONE",
                authorityScope: WatchSnapshotAuthorityScope.starPoint.rawValue,
                authorityVersion: 19
            )
        )

        XCTAssertNil(store.loadResumableSnapshot().match(matchId))
        XCTAssertFalse(
            viewModel.resumableMatches.contains { $0.matchId == matchId }
        )
    }

    func testViewModelRejectsLifecycleWhoseDeclaredScopeConflictsWithFormat() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = WatchMatchViewModel(
            store: store,
            sync: StubPhoneSync(),
            haptics: NoopWatchHaptics(),
            workout: WatchWorkoutSessionManager()
        )
        let matchId = "scope-mismatch"

        viewModel.applyMatchLifecycle(
            WatchMatchLifecycle(
                matchId: matchId,
                action: "PAUSED",
                status: .paused,
                stateVersion: 1,
                idempotencyKey: "scope-mismatch#1",
                timestampMs: 100,
                format: .starPointBo3,
                events: [],
                summary: WatchResumableMatch(
                    matchId: matchId,
                    status: .paused,
                    stateVersion: 1,
                    updatedAtMs: 100,
                    format: .starPointBo3
                ),
                authoritySource: "PHONE",
                authorityScope: WatchSnapshotAuthorityScope.nonStarPoint.rawValue,
                authorityVersion: 21
            )
        )

        XCTAssertNil(store.loadResumableSnapshot().match(matchId))
        XCTAssertEqual(store.stateVersion(matchId), 0)
    }

    func testScopedSnapshotsConvergeInEitherOrderAndPersistVersions() throws {
        let classic = WatchResumableMatch(
            matchId: "classic",
            status: .paused,
            format: .advantageBo3
        )
        let star = WatchResumableMatch(
            matchId: "star",
            status: .paused,
            format: .starPointBo3
        )
        let legacy = WatchResumableSnapshot(
            matches: [classic],
            authoritative: true,
            authoritySource: "PHONE",
            authorityScope: WatchSnapshotAuthorityScope.nonStarPoint.rawValue,
            authorityVersion: 40
        )
        let v2 = WatchResumableSnapshot(
            matches: [classic, star],
            authoritative: true,
            authoritySource: "PHONE",
            authorityScope: WatchSnapshotAuthorityScope.starPoint.rawValue,
            authorityVersion: 40
        )

        let legacyThenV2 = WatchResumableSnapshot.empty
            .merging(legacy)
            .merging(v2)
        let v2ThenLegacy = WatchResumableSnapshot.empty
            .merging(v2)
            .merging(legacy)
        XCTAssertEqual(Set(legacyThenV2.matches.map(\.matchId)), ["classic", "star"])
        XCTAssertEqual(Set(v2ThenLegacy.matches.map(\.matchId)), ["classic", "star"])

        let encoded = try JSONEncoder().encode(v2ThenLegacy)
        let decoded = try JSONDecoder().decode(
            WatchResumableSnapshot.self,
            from: encoded
        )
        XCTAssertEqual(
            decoded.authorityVersions?[
                WatchSnapshotAuthorityScope.nonStarPoint.rawValue
            ],
            40
        )
        XCTAssertEqual(
            decoded.authorityVersions?[
                WatchSnapshotAuthorityScope.starPoint.rawValue
            ],
            40
        )
    }

    func testV2FullPayloadCannotResurrectRowOwnedByNonStarScope() {
        let classic = WatchResumableMatch(
            matchId: "deleted-classic",
            status: .paused,
            format: .advantageBo3
        )
        let star = WatchResumableMatch(
            matchId: "current-star",
            status: .paused,
            format: .starPointBo3
        )
        let nonStarClear = WatchResumableSnapshot(
            authoritative: true,
            authoritySource: "PHONE",
            authorityScope: WatchSnapshotAuthorityScope.nonStarPoint.rawValue,
            authorityVersion: 50
        )
        let v2Full = WatchResumableSnapshot(
            activeMatchId: classic.matchId,
            matches: [classic, star],
            authoritative: true,
            authoritySource: "PHONE",
            authorityScope: WatchSnapshotAuthorityScope.starPoint.rawValue,
            authorityVersion: 50
        )

        let clearThenV2 = WatchResumableSnapshot.empty
            .merging(nonStarClear)
            .merging(v2Full)
        let v2ThenClear = WatchResumableSnapshot.empty
            .merging(v2Full)
            .merging(nonStarClear)

        XCTAssertEqual(Set(clearThenV2.matches.map(\.matchId)), [star.matchId])
        XCTAssertEqual(Set(v2ThenClear.matches.map(\.matchId)), [star.matchId])
        XCTAssertNil(clearThenV2.activeMatchId)
        XCTAssertNil(v2ThenClear.activeMatchId)
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
            "authoritySource": "PHONE",
            "authorityScope": "NON_STAR_POINT",
            "authorityVersion": NSNumber(value: 43),
        ])
        XCTAssertEqual(lifecycle?.status, .paused)
        // A missing key must still dedup deterministically.
        XCTAssertEqual(lifecycle?.idempotencyKey, "m1#PAUSED#7")
        XCTAssertEqual(lifecycle?.authoritySource, "PHONE")
        XCTAssertEqual(lifecycle?.authorityScope, "NON_STAR_POINT")
        XCTAssertEqual(lifecycle?.authorityVersion, 43)
    }

    func testVersionedScoringPathsAreAcceptedWithoutAliasingLegacyPaths() {
        let snapshot = WatchSyncDecoding.snapshot(from: [
            "path": WatchSyncPaths.resumableV2,
            "stateVersion": 0,
            "matches": "[]",
            "authoritative": true,
            "authoritySource": "PHONE",
            "authorityScope": "STAR_POINT",
            "authorityVersion": NSNumber(value: 42),
        ])
        let lifecycle = WatchSyncDecoding.lifecycle(from: [
            "path": WatchSyncPaths.lifecycleV2,
            "matchId": "star-1",
            "action": "PAUSED",
            "stateVersion": 3,
        ])

        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.authoritative, true)
        XCTAssertEqual(snapshot?.authoritySource, "PHONE")
        XCTAssertEqual(snapshot?.authorityScope, "STAR_POINT")
        XCTAssertEqual(snapshot?.authorityVersion, 42)
        XCTAssertNotNil(lifecycle)
        XCTAssertTrue(WatchSyncPaths.isStartMatch(WatchSyncPaths.startMatch))
        XCTAssertTrue(WatchSyncPaths.isStartMatch(WatchSyncPaths.startMatchV2))
        XCTAssertTrue(WatchSyncPaths.isResumable(WatchSyncPaths.resumable))
        XCTAssertTrue(WatchSyncPaths.isResumable(WatchSyncPaths.resumableV2))
        XCTAssertTrue(WatchSyncPaths.isLifecycle(WatchSyncPaths.lifecycle))
        XCTAssertTrue(WatchSyncPaths.isLifecycle(WatchSyncPaths.lifecycleV2))
        XCTAssertNotEqual(WatchSyncPaths.startMatch, WatchSyncPaths.startMatchV2)
        XCTAssertNotEqual(WatchSyncPaths.resumable, WatchSyncPaths.resumableV2)
        XCTAssertNotEqual(WatchSyncPaths.lifecycle, WatchSyncPaths.lifecycleV2)
        XCTAssertNil(WatchSyncDecoding.snapshot(from: [
            "path": "/rallymate/v3/resumable",
            "matches": "[]",
        ]))
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
