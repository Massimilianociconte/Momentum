import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suiteName: String!

  override func setUp() {
    super.setUp()
    suiteName = "AppleWatchEventQueueTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    suiteName = nil
    super.tearDown()
  }

  func testWatchQueuePeeksUntilAcknowledged() throws {
    let queue = AppleWatchEventQueue(defaults: defaults, key: "pending")
    let id = try XCTUnwrap(
      queue.enqueue(matchId: "match-1", events: "[]", format: nil)
    )

    let pending = try JSONDecoder().decode(
      [AppleWatchEventQueue.Item].self,
      from: Data(try XCTUnwrap(queue.pendingJSON()).utf8)
    )
    XCTAssertEqual(pending.map(\.queueId), [id])

    queue.acknowledge(id)
    XCTAssertEqual(try XCTUnwrap(queue.pendingJSON()), "[]")
  }

  func testWatchQueueDeduplicatesIdenticalPayloads() throws {
    let queue = AppleWatchEventQueue(defaults: defaults, key: "pending")
    let first = queue.enqueue(matchId: "match-1", events: "[{}]", format: "{}")
    let second = queue.enqueue(matchId: "match-1", events: "[{}]", format: "{}")

    XCTAssertEqual(first, second)
    let pending = try JSONDecoder().decode(
      [AppleWatchEventQueue.Item].self,
      from: Data(try XCTUnwrap(queue.pendingJSON()).utf8)
    )
    XCTAssertEqual(pending.count, 1)
  }

  func testWatchQueueRejectsMalformedReplacement() throws {
    let queue = AppleWatchEventQueue(defaults: defaults, key: "pending")
    _ = queue.enqueue(matchId: "match-1", events: "[]", format: nil)

    XCTAssertFalse(queue.replace(with: "not-json"))
    XCTAssertNotEqual(try XCTUnwrap(queue.pendingJSON()), "[]")
  }

  func testWatchQueueAppliesBackpressureWithoutEvictingUnacknowledgedItems() throws {
    let queue = AppleWatchEventQueue(defaults: defaults, key: "pending")
    var firstId: String?
    for index in 0..<256 {
      let id = try XCTUnwrap(
        queue.enqueue(matchId: "match-\(index)", events: "[\(index)]", format: nil)
      )
      if index == 0 { firstId = id }
    }

    XCTAssertNil(queue.enqueue(matchId: "overflow", events: "[]", format: nil))
    let pending = try JSONDecoder().decode(
      [AppleWatchEventQueue.Item].self,
      from: Data(try XCTUnwrap(queue.pendingJSON()).utf8)
    )
    XCTAssertEqual(pending.count, 256)
    XCTAssertEqual(pending.first?.queueId, firstId)
  }

  func testWatchQueueFailsClosedWithoutOverwritingCorruptStorage() {
    let corrupt = Data("not-json".utf8)
    defaults.set(corrupt, forKey: "pending")
    let queue = AppleWatchEventQueue(defaults: defaults, key: "pending")

    XCTAssertNil(queue.pendingJSON())
    XCTAssertNil(queue.enqueue(matchId: "match-1", events: "[]", format: nil))
    XCTAssertFalse(queue.replace(with: "[]"))
    XCTAssertFalse(queue.acknowledge("unknown"))
    XCTAssertEqual(defaults.data(forKey: "pending"), corrupt)
  }

  func testTerminalLifecycleRemovesOnlyTheMatchingStartContext() throws {
    let start: [String: Any] = [
      "path": "/rallymate/start_match",
      "matchId": "match-1",
    ]
    let resumable: [String: Any] = [
      "path": "/rallymate/resumable",
      "matches": "[]",
    ]
    let persisted: [String: Any] = [
      "path": "/rallymate/context_bundle",
      RallyMateContextKey.startMatch: start,
      RallyMateContextKey.resumable: resumable,
    ]

    let hydrated = RallyMateContextBundlePolicy.merged(
      inMemory: [:],
      persisted: persisted
    )
    let cleared = RallyMateContextBundlePolicy.terminatingStartMatch(
      matching: "match-1",
      stateVersion: 4,
      timestampMs: 123,
      from: hydrated
    )

    XCTAssertNil(cleared[RallyMateContextKey.startMatch])
    XCTAssertNotNil(cleared[RallyMateContextKey.startMatchTerminal])
    XCTAssertNotNil(cleared[RallyMateContextKey.resumable])
    XCTAssertTrue(
      RallyMateContextBundlePolicy.isTerminalLifecycle(
        action: "COMPLETED",
        status: "COMPLETED"
      )
    )
  }

  func testLifecycleCannotClearANewerMatchStartContext() throws {
    let newerStart: [String: Any] = [
      "path": "/rallymate/start_match",
      "matchId": "match-2",
    ]
    let bundle: [String: Any] = [
      RallyMateContextKey.startMatch: newerStart,
    ]

    let unchanged = RallyMateContextBundlePolicy.terminatingStartMatch(
      matching: "match-1",
      stateVersion: 4,
      timestampMs: 123,
      from: bundle
    )
    let retained = try XCTUnwrap(
      unchanged[RallyMateContextKey.startMatch] as? [String: Any]
    )
    XCTAssertEqual(retained["matchId"] as? String, "match-2")
    XCTAssertFalse(
      RallyMateContextBundlePolicy.isTerminalLifecycle(
        action: "RESUMED",
        status: "IN_PROGRESS"
      )
    )
  }

  func testTerminalTombstonePreventsStaleContextResurrection() {
    let staleStart: [String: Any] = [
      "path": "/rallymate/start_match",
      "matchId": "match-1",
    ]
    let persisted: [String: Any] = [
      RallyMateContextKey.startMatch: staleStart,
    ]
    let terminated = RallyMateContextBundlePolicy.terminatingStartMatch(
      matching: "match-1",
      stateVersion: 7,
      timestampMs: 456,
      from: persisted
    )

    // Simulate WCSession still exposing its stale previous context after an
    // update failure. The in-memory tombstone must continue to win.
    let mergedAgain = RallyMateContextBundlePolicy.merged(
      inMemory: terminated,
      persisted: persisted
    )
    XCTAssertNil(mergedAgain[RallyMateContextKey.startMatch])
    XCTAssertNotNil(mergedAgain[RallyMateContextKey.startMatchTerminal])

    let restarted = RallyMateContextBundlePolicy.setting(
      key: RallyMateContextKey.startMatch,
      payload: staleStart,
      in: mergedAgain
    )
    XCTAssertNotNil(restarted[RallyMateContextKey.startMatch])
    XCTAssertNil(restarted[RallyMateContextKey.startMatchTerminal])
  }

  func testLatestSnapshotInvalidatesAStartThatIsNoLongerActive() {
    let staleStart: [String: Any] = [
      "path": "/rallymate/start_match",
      "matchId": "match-1",
    ]
    let bundle: [String: Any] = [
      RallyMateContextKey.startMatch: staleStart,
    ]

    let reconciled = RallyMateContextBundlePolicy.reconcilingStartMatch(
      activeMatchId: nil,
      stateVersion: 1,
      timestampMs: 999,
      in: bundle
    )
    XCTAssertNil(reconciled[RallyMateContextKey.startMatch])
    XCTAssertNotNil(reconciled[RallyMateContextKey.startMatchTerminal])
  }
}
