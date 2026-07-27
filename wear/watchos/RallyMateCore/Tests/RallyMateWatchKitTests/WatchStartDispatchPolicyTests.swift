@testable import RallyMateWatchKit
import XCTest

final class WatchStartDispatchPolicyTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "WatchStartDispatchPolicyTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testLegacyStartsRemainAcceptedUntilVersionedBoundaryExists() {
        let policy = WatchStartDispatchPolicy(
            defaults: defaults,
            key: "dispatch"
        )

        XCTAssertTrue(policy.shouldAccept(
            matchId: "legacy-a",
            dispatchedAtMs: nil
        ))
        XCTAssertTrue(policy.shouldAccept(
            matchId: "legacy-a",
            dispatchedAtMs: nil
        ))
        XCTAssertTrue(policy.shouldAccept(
            matchId: "legacy-b",
            dispatchedAtMs: 0
        ))

        XCTAssertTrue(policy.shouldAccept(
            matchId: "versioned",
            dispatchedAtMs: 100
        ))
        XCTAssertFalse(policy.shouldAccept(
            matchId: "late-legacy",
            dispatchedAtMs: nil
        ))
    }

    func testDuplicateAndOutOfOrderVersionedStartsAreIgnored() {
        let policy = WatchStartDispatchPolicy(
            defaults: defaults,
            key: "dispatch"
        )

        XCTAssertTrue(policy.shouldAccept(
            matchId: "first",
            dispatchedAtMs: 100
        ))
        XCTAssertFalse(policy.shouldAccept(
            matchId: "first",
            dispatchedAtMs: 100
        ))
        XCTAssertFalse(policy.shouldAccept(
            matchId: "collision",
            dispatchedAtMs: 100
        ))
        XCTAssertFalse(policy.shouldAccept(
            matchId: "older",
            dispatchedAtMs: 99
        ))
        XCTAssertTrue(policy.shouldAccept(
            matchId: "newer",
            dispatchedAtMs: 101
        ))
    }

    func testHighWaterMarkSurvivesWatchAppRelaunch() {
        let key = "dispatch"
        let firstProcess = WatchStartDispatchPolicy(
            defaults: defaults,
            key: key
        )
        XCTAssertTrue(firstProcess.shouldAccept(
            matchId: "new",
            dispatchedAtMs: 500
        ))

        let relaunchedProcess = WatchStartDispatchPolicy(
            defaults: defaults,
            key: key
        )
        XCTAssertFalse(relaunchedProcess.shouldAccept(
            matchId: "duplicate-copy",
            dispatchedAtMs: 500
        ))
        XCTAssertFalse(relaunchedProcess.shouldAccept(
            matchId: "old-queued",
            dispatchedAtMs: 499
        ))
        XCTAssertFalse(relaunchedProcess.shouldAccept(
            matchId: "legacy-queued",
            dispatchedAtMs: nil
        ))
        XCTAssertTrue(relaunchedProcess.shouldAccept(
            matchId: "latest",
            dispatchedAtMs: 501
        ))
    }

    func testCorruptHighWaterMarkFailsClosed() {
        defaults.set(Data("not-json".utf8), forKey: "dispatch")
        let policy = WatchStartDispatchPolicy(
            defaults: defaults,
            key: "dispatch"
        )

        XCTAssertFalse(policy.shouldAccept(
            matchId: "legacy",
            dispatchedAtMs: nil
        ))
        XCTAssertFalse(policy.shouldAccept(
            matchId: "versioned",
            dispatchedAtMs: 1_000
        ))
    }
}
