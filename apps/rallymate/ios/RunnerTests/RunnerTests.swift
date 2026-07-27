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

  func testStarPointUsesVersionedWatchConnectivityPaths() {
    let starFormat = """
    {"formatSchemaVersion":2,"gameScoringMode":"STAR_POINT","goldenPoint":false}
    """
    let advantageFormat = """
    {"formatSchemaVersion":2,"gameScoringMode":"ADVANTAGE","goldenPoint":false}
    """
    let starSummary = """
    {"matchId":"star-1","format":{"gameScoringMode":"STAR_POINT"}}
    """

    XCTAssertEqual(
      RallyMateScoringProtocolPathPolicy.startMatchPath(formatJSON: starFormat),
      "/rallymate/v2/start_match"
    )
    XCTAssertEqual(
      RallyMateScoringProtocolPathPolicy.startMatchPath(formatJSON: advantageFormat),
      "/rallymate/start_match"
    )
    XCTAssertEqual(
      RallyMateScoringProtocolPathPolicy.lifecyclePath(
        formatJSON: starFormat,
        summaryJSON: nil
      ),
      "/rallymate/v2/lifecycle"
    )
    XCTAssertEqual(
      RallyMateScoringProtocolPathPolicy.lifecyclePath(
        formatJSON: nil,
        summaryJSON: starSummary
      ),
      "/rallymate/v2/lifecycle"
    )
    XCTAssertEqual(
      RallyMateScoringProtocolPathPolicy.resumablePath(requiresScoringV2: true),
      "/rallymate/v2/resumable"
    )
    XCTAssertEqual(
      RallyMateScoringProtocolPathPolicy.resumablePath(requiresScoringV2: false),
      "/rallymate/resumable"
    )
    XCTAssertFalse(
      RallyMateScoringProtocolPathPolicy.formatRequiresScoringV2("not-json")
    )

    let fullV2Snapshot: [String: Any] = [
      "requiresScoringV2": true,
      "matches": "[{\"matchId\":\"star-1\"}]",
    ]
    XCTAssertFalse(
      RallyMateScoringProtocolPathPolicy.permitsResumablePublish(
        arguments: fullV2Snapshot,
        starPointCapabilityConfirmed: false
      )
    )
    XCTAssertTrue(
      RallyMateScoringProtocolPathPolicy.permitsResumablePublish(
        arguments: fullV2Snapshot,
        starPointCapabilityConfirmed: true
      )
    )

    let downgradeClear: [String: Any] = [
      "requiresScoringV2": true,
      "clearScoringV2Slot": true,
      "matches": "[]",
      "authoritative": true,
      "authoritySource": "PHONE",
      "authorityScope": "STAR_POINT",
      "authorityVersion": NSNumber(value: 42),
    ]
    XCTAssertTrue(
      RallyMateScoringProtocolPathPolicy.permitsResumablePublish(
        arguments: downgradeClear,
        starPointCapabilityConfirmed: false
      )
    )
    var invalidClear = downgradeClear
    invalidClear["matches"] = "[{}]"
    XCTAssertFalse(
      RallyMateScoringProtocolPathPolicy.permitsResumablePublish(
        arguments: invalidClear,
        starPointCapabilityConfirmed: false
      )
    )
  }

  func testWatchAuthoredStarEventsAreCrossVersionFailClosed() throws {
    let starFormat = """
    {"formatSchemaVersion":2,"gameScoringMode":"STAR_POINT","goldenPoint":false}
    """
    let advantageFormat = """
    {"formatSchemaVersion":2,"gameScoringMode":"ADVANTAGE","goldenPoint":false}
    """
    let goldenFormat = """
    {"formatSchemaVersion":2,"gameScoringMode":"GOLDEN_POINT","goldenPoint":true}
    """
    let v2Payload: [String: Any] = [
      "scoringProtocolVersion": 2,
      "capabilities": ["star_point_v1"],
    ]

    let legacyStarRoute =
      RallyMateWatchInboundScoringPolicy.eventRoute(
        path: "/rallymate/events",
        formatJSON: starFormat,
        payload: v2Payload
      )
    XCTAssertEqual(legacyStarRoute, .rejected)
    XCTAssertEqual(
      RallyMateWatchInboundScoringPolicy.eventRoute(
        path: "/rallymate/v2/events",
        formatJSON: advantageFormat,
        payload: v2Payload
      ),
      .rejected
    )
    XCTAssertEqual(
      RallyMateWatchInboundScoringPolicy.eventRoute(
        path: "/rallymate/v2/events",
        formatJSON: starFormat,
        payload: [:]
      ),
      .rejected
    )
    XCTAssertEqual(
      RallyMateWatchInboundScoringPolicy.eventRoute(
        path: "/rallymate/v2/events",
        formatJSON:
          #"{"gameScoringMode":"STAR_POINT","goldenPoint":false}"#,
        payload: v2Payload
      ),
      .rejected
    )
    XCTAssertEqual(
      RallyMateWatchInboundScoringPolicy.eventRoute(
        path: "/rallymate/v2/events",
        formatJSON: starFormat,
        payload: v2Payload
      ),
      .scoringV2
    )
    XCTAssertEqual(
      RallyMateWatchInboundScoringPolicy.eventRoute(
        path: "/rallymate/events",
        formatJSON: advantageFormat,
        payload: [:]
      ),
      .legacy
    )
    XCTAssertEqual(
      RallyMateWatchInboundScoringPolicy.eventRoute(
        path: "/rallymate/events",
        formatJSON: goldenFormat,
        payload: [:]
      ),
      .legacy
    )

    let malformedLegacyFormats = [
      #"{"gameScoringMode":"ADVANTAGE","goldenPoint":true}"#,
      #"{"gameScoringMode":"GOLDEN_POINT","goldenPoint":false}"#,
      #"{"gameScoringMode":"FUTURE_MODE","goldenPoint":false}"#,
      #"{"gameScoringMode":2,"goldenPoint":false}"#,
      #"{"gameScoringMode":"ADVANTAGE"}"#,
      #"not-json"#,
    ]
    for malformed in malformedLegacyFormats {
      XCTAssertEqual(
        RallyMateWatchInboundScoringPolicy.eventRoute(
          path: "/rallymate/events",
          formatJSON: malformed,
          payload: [:]
        ),
        .rejected,
        malformed
      )
    }

    let malformedStarV2Formats = [
      #"{"formatSchemaVersion":3,"gameScoringMode":"STAR_POINT","goldenPoint":false}"#,
      #"{"formatSchemaVersion":"2","gameScoringMode":"STAR_POINT","goldenPoint":false}"#,
      #"{"formatSchemaVersion":2,"gameScoringMode":"STAR_POINT","goldenPoint":true}"#,
      #"{"formatSchemaVersion":2,"gameScoringMode":"ADVANTAGE","goldenPoint":false}"#,
    ]
    for malformed in malformedStarV2Formats {
      XCTAssertEqual(
        RallyMateWatchInboundScoringPolicy.eventRoute(
          path: "/rallymate/v2/events",
          formatJSON: malformed,
          payload: v2Payload
        ),
        .rejected,
        malformed
      )
    }

    // Mirrors the bridge's pre-enqueue guard: a Star payload on the legacy
    // path cannot mutate even the durable native queue.
    let queue = AppleWatchEventQueue(
      defaults: defaults,
      key: "legacy-star-rejected"
    )
    if legacyStarRoute != .rejected {
      _ = queue.enqueue(
        matchId: "star-legacy",
        events: "[{}]",
        format: starFormat
      )
    }
    XCTAssertEqual(try XCTUnwrap(queue.pendingJSON()), "[]")
  }

  func testStarRequestStateAndCommitAckRequireScoringV2() {
    let starFormat = """
    {"formatSchemaVersion":2,"gameScoringMode":"STAR_POINT","goldenPoint":false}
    """
    let advantageFormat = """
    {"formatSchemaVersion":2,"gameScoringMode":"ADVANTAGE","goldenPoint":false}
    """
    let v2Payload: [String: Any] = [
      "scoringProtocolVersion": 2,
      "capabilities": ["star_point_v1"],
    ]

    XCTAssertEqual(
      RallyMateWatchInboundScoringPolicy.requestStateRoute(
        path: "/rallymate/request_state",
        formatJSON: starFormat,
        payload: v2Payload
      ),
      .rejected
    )
    XCTAssertEqual(
      RallyMateWatchInboundScoringPolicy.requestStateRoute(
        path: "/rallymate/v2/request_state",
        formatJSON: advantageFormat,
        payload: v2Payload
      ),
      .rejected
    )
    XCTAssertEqual(
      RallyMateWatchInboundScoringPolicy.requestStateRoute(
        path: "/rallymate/v2/request_state",
        formatJSON: starFormat,
        payload: v2Payload
      ),
      .scoringV2
    )

    let pendingAck =
      RallyMateWatchInboundScoringPolicy.acknowledgement(
        committed: false,
        route: .scoringV2
      )
    XCTAssertEqual(pendingAck["ok"] as? Bool, false)

    let committedAck =
      RallyMateWatchInboundScoringPolicy.acknowledgement(
        committed: true,
        route: .scoringV2
      )
    XCTAssertEqual(committedAck["ok"] as? Bool, true)
    XCTAssertEqual(committedAck["scoringProtocolVersion"] as? Int, 2)
    XCTAssertEqual(
      committedAck["capabilities"] as? [String],
      ["star_point_v1"]
    )

    let legacyAck =
      RallyMateWatchInboundScoringPolicy.acknowledgement(
        committed: true,
        route: .legacy
      )
    XCTAssertNil(legacyAck["scoringProtocolVersion"])
  }

  func testApplicationContextKeepsLegacyAndV2SnapshotsInSeparateSlots() throws {
    let legacy: [String: Any] = [
      "path": "/rallymate/resumable",
      "matches": "[]",
      "authorityScope": "NON_STAR_POINT",
    ]
    let v2: [String: Any] = [
      "path": "/rallymate/v2/resumable",
      "matches": "[]",
      "authorityScope": "STAR_POINT",
      "authoritative": true,
    ]
    let withLegacy = RallyMateContextBundlePolicy.setting(
      key: RallyMateContextKey.resumable,
      payload: legacy,
      in: [:]
    )
    let withBoth = RallyMateContextBundlePolicy.setting(
      key: RallyMateContextKey.resumableV2,
      payload: v2,
      in: withLegacy
    )
    let envelope = RallyMateContextBundlePolicy.envelope(from: withBoth)
    let retainedLegacy = try XCTUnwrap(
      envelope[RallyMateContextKey.resumable] as? [String: Any]
    )
    let retainedV2 = try XCTUnwrap(
      envelope[RallyMateContextKey.resumableV2] as? [String: Any]
    )

    XCTAssertEqual(retainedLegacy["path"] as? String, "/rallymate/resumable")
    XCTAssertEqual(retainedV2["path"] as? String, "/rallymate/v2/resumable")
    XCTAssertNotEqual(
      retainedLegacy["path"] as? String,
      retainedV2["path"] as? String
    )
  }

  func testStartDispatchClockIsMonotonicAcrossRelaunchAndClockRollback() {
    let key = "start-dispatch-\(UUID().uuidString)"
    let firstProcess = RallyMateStartDispatchClock(defaults: defaults, key: key)

    XCTAssertEqual(firstProcess.next(nowMs: 1_000), 1_000)
    XCTAssertEqual(firstProcess.next(nowMs: 1_000), 1_001)
    XCTAssertEqual(firstProcess.next(nowMs: 900), 1_002)

    let relaunchedProcess = RallyMateStartDispatchClock(
      defaults: defaults,
      key: key
    )
    XCTAssertEqual(relaunchedProcess.next(nowMs: 950), 1_003)
    XCTAssertEqual(relaunchedProcess.next(nowMs: 2_000), 2_000)
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
