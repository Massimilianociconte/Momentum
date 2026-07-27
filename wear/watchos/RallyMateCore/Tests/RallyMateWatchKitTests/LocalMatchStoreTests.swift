import RallyMateCore
@testable import RallyMateWatchKit
import XCTest

final class LocalMatchStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: LocalMatchStore!

    override func setUp() {
        super.setUp()
        suiteName = "RallyMateWatchKitTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = LocalMatchStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSavesAndRestoresActiveMatch() throws {
        let event = MatchEvent(
            eventId: "e1",
            matchId: "m1",
            ts: 1,
            type: .pointTeamA,
            teamId: .a
        )

        store.saveMatch(
            matchId: "m1",
            format: MatchFormat(id: "TRAINING", name: "Training", freePlay: true),
            events: [event]
        )

        XCTAssertEqual(store.activeMatchId(), "m1")
        XCTAssertTrue(try XCTUnwrap(store.loadFormat("m1")).freePlay)
        XCTAssertEqual(store.loadEvents("m1"), [event])
        XCTAssertEqual(store.pendingSyncCount("m1"), 1)
    }

    func testMarkSyncedKeepsOnlyAckedEventIdsStable() throws {
        let events = [
            MatchEvent(eventId: "e1", matchId: "m1", ts: 1, type: .pointTeamA, teamId: .a),
            MatchEvent(eventId: "e2", matchId: "m1", ts: 2, type: .undo),
        ]
        store.saveMatch(matchId: "m1", format: MatchFormat(), events: events)

        store.markSynced("m1", eventIds: ["e1"])

        let updated = store.loadEvents("m1")
        XCTAssertEqual(updated.map(\.eventId), ["e1", "e2"])
        XCTAssertTrue(try XCTUnwrap(updated.first { $0.eventId == "e1" }).synced)
        XCTAssertFalse(try XCTUnwrap(updated.first { $0.eventId == "e2" }).synced)
        XCTAssertEqual(store.pendingSyncCount("m1"), 1)
    }

    func testSavePreservesPreviouslySyncedEvents() throws {
        let synced = MatchEvent(
            eventId: "e1",
            matchId: "m1",
            ts: 1,
            type: .pointTeamA,
            teamId: .a,
            synced: true
        )
        store.saveMatch(matchId: "m1", format: MatchFormat(), events: [synced])

        let engineCopy = MatchEvent(
            eventId: "e1",
            matchId: "m1",
            ts: 1,
            type: .pointTeamA,
            teamId: .a,
            synced: false
        )
        let newEvent = MatchEvent(eventId: "e2", matchId: "m1", ts: 2, type: .pointTeamB, teamId: .b)
        store.saveMatch(matchId: "m1", format: MatchFormat(), events: [engineCopy, newEvent])

        let updated = store.loadEvents("m1")
        XCTAssertTrue(try XCTUnwrap(updated.first { $0.eventId == "e1" }).synced)
        XCTAssertFalse(try XCTUnwrap(updated.first { $0.eventId == "e2" }).synced)
    }

    func testClearActiveDoesNotDeleteRecoverableLog() {
        store.saveMatch(matchId: "m1", format: MatchFormat(), events: [])

        store.clearActive()

        XCTAssertNil(store.activeMatchId())
        XCTAssertNotNil(store.loadFormat("m1"))
    }

    func testPersistsWorkoutRecoveryIntentPerMatch() {
        XCTAssertFalse(store.isWorkoutActive("m1"))

        store.setWorkoutActive("m1", active: true)
        XCTAssertTrue(store.isWorkoutActive("m1"))
        XCTAssertFalse(store.isWorkoutActive("m2"))

        store.setWorkoutActive("m1", active: false)
        XCTAssertFalse(store.isWorkoutActive("m1"))
    }

    func testWorkoutRecoveryPointerSurvivesUIClearUntilTerminalState() {
        store.setActiveMatch("m1")
        store.setWorkoutRecoveryMatch("m1")
        store.clearActive(expected: "m1")

        XCTAssertNil(store.activeMatchId())
        XCTAssertEqual(store.workoutRecoveryMatchId(), "m1")
        store.clearWorkoutRecoveryMatch(expected: "another-match")
        XCTAssertEqual(store.workoutRecoveryMatchId(), "m1")
        store.clearWorkoutRecoveryMatch(expected: "m1")
        XCTAssertNil(store.workoutRecoveryMatchId())
    }

    func testIncompleteMatchAndPreferencesRemainRecoverable() {
        store.saveMatch(
            matchId: "m1",
            format: .advantageBo3,
            events: [
                MatchEvent(
                    eventId: "e1",
                    matchId: "m1",
                    ts: 1,
                    type: .matchPaused
                ),
            ]
        )
        store.saveLastFormat(.singleSet)
        store.savePlayerRole(WatchPlayerRole.left.rawValue)
        store.markIncomplete("m1")

        XCTAssertNil(store.activeMatchId())
        XCTAssertEqual(store.lastIncompleteMatchId(), "m1")
        XCTAssertEqual(store.pendingMatchIds(), ["m1"])
        XCTAssertEqual(store.loadLastFormat(), .singleSet)
        XCTAssertEqual(store.loadPlayerRole(), WatchPlayerRole.left.rawValue)

        store.setActiveMatch("m1")
        store.clearIncomplete(expected: "m1")
        XCTAssertEqual(store.activeMatchId(), "m1")
        XCTAssertNil(store.lastIncompleteMatchId())
    }

    func testPersistsMinimalAccountContext() {
        let context = WatchAccountContext(
            sourceUserId: "user-1",
            premiumEnabled: true,
            teamNames: ["Rally Crew"],
            defaultTeamName: "Rally Crew"
        )

        store.saveAccountContext(context)

        XCTAssertEqual(store.loadAccountContext(), context)
    }

    func testSystemQuickStartIsConsumedExactlyOnce() {
        store.requestSystemQuickStart(format: .advantageBo3)

        XCTAssertEqual(store.consumeSystemQuickStart(), .advantageBo3)
        XCTAssertNil(store.consumeSystemQuickStart())
    }

    func testStarPointFormatAndDeucePhaseSurviveLocalPersistence() throws {
        let engine = ScoringEngine(
            matchId: "star-offline",
            format: .starPointBo3
        )
        engine.start()
        for _ in 0 ..< 3 {
            engine.addPoint(.a)
            engine.addPoint(.b)
        }
        engine.addPoint(.a)
        engine.addPoint(.b)
        engine.addPoint(.b)
        engine.addPoint(.a)
        XCTAssertEqual(engine.state.deuceNumber, 3)

        store.saveMatch(
            matchId: "star-offline",
            format: .starPointBo3,
            events: engine.allEvents
        )
        store.saveLastFormat(.starPointBo3)
        store.requestSystemQuickStart(format: .starPointBo3)

        let restoredFormat = try XCTUnwrap(store.loadFormat("star-offline"))
        XCTAssertEqual(restoredFormat, .starPointBo3)
        XCTAssertEqual(restoredFormat.gameScoringMode, .starPoint)
        XCTAssertEqual(store.loadLastFormat(), .starPointBo3)
        XCTAssertEqual(store.consumeSystemQuickStart(), .starPointBo3)
        XCTAssertNil(store.consumeSystemQuickStart())

        let restored = ScoringEngine(
            matchId: "star-offline",
            format: restoredFormat
        )
        restored.loadEvents(store.loadEvents("star-offline"))
        XCTAssertEqual(restored.state, engine.state)
        XCTAssertEqual(restored.state.deuceNumber, 3)
        restored.addPoint(.a)
        XCTAssertEqual(restored.state.gamesA, 1)
    }

    func testWorkoutDetectionPreferencesAreLocalAndExplicit() {
        let preferences = WatchWorkoutDetectionPreferences(
            mode: .quickStart,
            racketSportsOnly: true,
            onlyWhenWorn: false
        )

        store.saveWorkoutDetectionPreferences(preferences)

        XCTAssertEqual(store.loadWorkoutDetectionPreferences(), preferences)
    }

}
