import XCTest
@testable import RallyMateCore

/// Parità semantica con la suite Dart (rally_core) e Kotlin (Wear OS).
final class ScoringEngineTests: XCTestCase {

    func testDefaultEventIdsAreCanonicalUniqueUUIDv4() {
        let engine = ScoringEngine(matchId: "uuid-match", format: MatchFormat())
        let ids = engine.start() + engine.addPoint(.a).newEvents

        XCTAssertEqual(Set(ids.map(\.eventId)).count, ids.count)
        for event in ids {
            let id = event.eventId
            XCTAssertEqual(id.count, 36)
            XCTAssertNotNil(UUID(uuidString: id))
            XCTAssertEqual(id[id.index(id.startIndex, offsetBy: 14)], "4")
            XCTAssertTrue("89ab".contains(id[id.index(id.startIndex, offsetBy: 19)]))
        }
    }

    private func engine(_ format: MatchFormat = MatchFormat()) -> ScoringEngine {
        var t: Int64 = 0
        var i = 0
        return ScoringEngine(
            matchId: "m1", format: format,
            clock: { t += 1; return t },
            idGen: { i += 1; return "e\(i)" })
    }

    private func winGame(_ e: ScoringEngine, _ team: TeamId) {
        let games = team == .a ? e.state.gamesA : e.state.gamesB
        let sets = team == .a ? e.state.setsA : e.state.setsB
        while !e.state.completed {
            e.addPoint(team)
            let g = team == .a ? e.state.gamesA : e.state.gamesB
            let s = team == .a ? e.state.setsA : e.state.setsB
            if g > games || s > sets || e.state.completed { return }
        }
    }

    private func winSet(_ e: ScoringEngine, _ team: TeamId) {
        let sets = team == .a ? e.state.setsA : e.state.setsB
        while !e.state.completed {
            winGame(e, team)
            let s = team == .a ? e.state.setsA : e.state.setsB
            if s > sets || e.state.completed { return }
        }
    }

    /// Like `winGame` but returns the transitions of the game-winning point.
    private func playGame(_ e: ScoringEngine, _ team: TeamId) -> [Transition] {
        let games = team == .a ? e.state.gamesA : e.state.gamesB
        let sets = team == .a ? e.state.setsA : e.state.setsB
        while true {
            let (_, transitions) = e.addPoint(team)
            let g = team == .a ? e.state.gamesA : e.state.gamesB
            let s = team == .a ? e.state.setsA : e.state.setsB
            if g > games || s > sets || e.state.completed { return transitions }
        }
    }

    private func reachDeuce(_ e: ScoringEngine) {
        for _ in 0 ..< 3 {
            e.addPoint(.a)
            e.addPoint(.b)
        }
    }

    func testGoldenPointFourPointsWinGame() {
        let e = engine()
        e.start()
        for _ in 0..<3 { e.addPoint(.a) }
        XCTAssertEqual(e.state.pointsLabel(.a), "40")
        e.addPoint(.a)
        XCTAssertEqual(e.state.gamesA, 1)
    }

    func testGoldenPointDeuceNextPointWins() {
        let e = engine()
        e.start()
        for _ in 0..<3 { e.addPoint(.a); e.addPoint(.b) }
        XCTAssertEqual(
            e.state.pointSituation(goldenPoint: true),
            "40 PARI · PUNTO DECISIVO"
        )
        e.addPoint(.b)
        XCTAssertEqual(e.state.gamesB, 1)
    }

    func testAdvantageScoring() {
        let e = engine(MatchFormat(id: "ADV_BO3", goldenPoint: false))
        e.start()
        for _ in 0..<3 { e.addPoint(.a); e.addPoint(.b) }
        XCTAssertEqual(
            e.state.pointSituation(goldenPoint: false),
            "40 PARI · VANTAGGI"
        )
        e.addPoint(.a)
        XCTAssertEqual(e.state.pointsLabel(.a), "AD")
        XCTAssertEqual(
            e.state.pointSituation(
                goldenPoint: false,
                teamALabel: "CASA",
                teamBLabel: "OSPITI"
            ),
            "VANTAGGIO CASA · GAME POINT"
        )
        e.addPoint(.b)
        XCTAssertEqual(e.state.pointsLabel(.a), "40")
        XCTAssertEqual(
            e.state.pointSituation(goldenPoint: false),
            "40 PARI · VANTAGGI"
        )
        e.addPoint(.b)
        e.addPoint(.b)
        XCTAssertEqual(e.state.gamesB, 1)
    }

    func testAdvantageAlternatesThroughDeuceAndUndoRestoresDeuce() {
        let e = engine(MatchFormat(id: "ADV_BO3", goldenPoint: false))
        e.start()
        for _ in 0..<3 { e.addPoint(.a); e.addPoint(.b) }

        e.addPoint(.a)
        XCTAssertEqual(e.state.pointsLabel(.a), "AD")
        XCTAssertEqual(e.state.pointsLabel(.b), "40")

        e.addPoint(.b)
        XCTAssertEqual(e.state.pointsLabel(.a), "40")
        XCTAssertEqual(e.state.pointsLabel(.b), "40")

        e.addPoint(.b)
        XCTAssertEqual(e.state.pointsLabel(.a), "40")
        XCTAssertEqual(e.state.pointsLabel(.b), "AD")

        e.addPoint(.a)
        XCTAssertEqual(e.state.pointsLabel(.a), "40")
        XCTAssertEqual(e.state.pointsLabel(.b), "40")

        e.addPoint(.a)
        XCTAssertEqual(e.state.pointsLabel(.a), "AD")
        e.undo()
        XCTAssertEqual(e.state.pointsLabel(.a), "40")
        XCTAssertEqual(e.state.pointsLabel(.b), "40")
    }

    func testStarPointFIPDeuceAndAdvantageSequenceEndsAtDecidingPoint() {
        let e = engine(.starPointBo3)
        e.start()
        reachDeuce(e)

        XCTAssertEqual(e.state.deuceNumber, 1)
        XCTAssertFalse(e.state.isStarPoint)
        XCTAssertEqual(
            e.state.pointSituation(gameScoringMode: .starPoint),
            "40 PARI · DEUCE 1"
        )

        e.addPoint(.a)
        XCTAssertEqual(e.state.advantage, .a)
        XCTAssertEqual(e.state.deuceNumber, 1)
        XCTAssertEqual(
            e.state.pointSituation(
                gameScoringMode: .starPoint,
                teamALabel: "CASA",
                teamBLabel: "OSPITI"
            ),
            "AD 1 CASA · GAME POINT"
        )

        e.addPoint(.b)
        XCTAssertNil(e.state.advantage)
        XCTAssertEqual(e.state.deuceNumber, 2)
        XCTAssertEqual(
            e.state.pointSituation(gameScoringMode: .starPoint),
            "40 PARI · DEUCE 2"
        )

        e.addPoint(.b)
        XCTAssertEqual(e.state.advantage, .b)
        XCTAssertEqual(e.state.deuceNumber, 2)
        XCTAssertEqual(
            e.state.pointSituation(gameScoringMode: .starPoint),
            "AD 2 LORO · GAME POINT"
        )

        e.addPoint(.a)
        XCTAssertNil(e.state.advantage)
        XCTAssertEqual(e.state.deuceNumber, 3)
        XCTAssertTrue(e.state.isStarPoint)
        XCTAssertEqual(
            e.state.pointSituation(gameScoringMode: .starPoint),
            "DEUCE 3 · STAR POINT"
        )

        e.addPoint(.b)
        XCTAssertEqual(e.state.gamesB, 1)
        XCTAssertEqual(e.state.deuceNumber, 0)
        XCTAssertFalse(e.state.isStarPoint)
        XCTAssertEqual(e.state.pointsLabel(.a), "0")
        XCTAssertEqual(e.state.pointsLabel(.b), "0")
    }

    func testStarPointCanCloseAtAdvantageOneOrAdvantageTwo() {
        let atAdvantageOne = engine(.starPointBo3)
        atAdvantageOne.start()
        reachDeuce(atAdvantageOne)
        atAdvantageOne.addPoint(.a)
        atAdvantageOne.addPoint(.a)
        XCTAssertEqual(atAdvantageOne.state.gamesA, 1)

        let atAdvantageTwo = engine(.starPointBo3)
        atAdvantageTwo.start()
        reachDeuce(atAdvantageTwo)
        atAdvantageTwo.addPoint(.a)
        atAdvantageTwo.addPoint(.b)
        atAdvantageTwo.addPoint(.b)
        atAdvantageTwo.addPoint(.b)
        XCTAssertEqual(atAdvantageTwo.state.gamesB, 1)
    }

    func testStarPointUndoAndJsonReplayRestoreExactDeucePhase() {
        let e = engine(.starPointBo3)
        e.start()
        reachDeuce(e)
        e.addPoint(.a)
        e.addPoint(.b)
        e.addPoint(.b)
        e.addPoint(.a)
        XCTAssertEqual(e.state.deuceNumber, 3)

        let rebuilt = engine(.starPointBo3)
        rebuilt.loadEvents(
            MatchEvent.listFromJson(MatchEvent.listToJson(e.allEvents))
        )
        XCTAssertEqual(rebuilt.state, e.state)
        XCTAssertEqual(rebuilt.state.deuceNumber, 3)

        e.addPoint(.a)
        XCTAssertEqual(e.state.gamesA, 1)
        e.undo()
        XCTAssertEqual(e.state.gamesA, 0)
        XCTAssertEqual(e.state.deuceNumber, 3)
        XCTAssertNil(e.state.advantage)

        e.undo()
        XCTAssertEqual(e.state.deuceNumber, 2)
        XCTAssertEqual(e.state.advantage, .b)
    }

    func testStarPointScoreEditRestoresDeuceThree() {
        let e = engine(.starPointBo3)
        e.loadEvents([
            MatchEvent(
                eventId: "start",
                matchId: "m1",
                ts: 1,
                type: .matchStarted
            ),
            MatchEvent(
                eventId: "edit",
                matchId: "m1",
                ts: 2,
                type: .scoreEdited,
                sourceMethod: "MANUAL_EDIT",
                payload: [
                    "pointsA": 3,
                    "pointsB": 3,
                    "deuceNumber": 3,
                ]
            ),
        ])

        XCTAssertEqual(e.state.deuceNumber, 3)
        XCTAssertEqual(
            e.state.pointSituation(gameScoringMode: .starPoint),
            "DEUCE 3 · STAR POINT"
        )
        e.addPoint(.a)
        XCTAssertEqual(e.state.gamesA, 1)
        XCTAssertEqual(e.state.deuceNumber, 0)
    }

    func testTieBreakRecorded76() {
        let e = engine()
        e.start()
        for _ in 0..<6 { winGame(e, .a); winGame(e, .b) }
        XCTAssertTrue(e.state.inTieBreak)
        for _ in 0..<6 { e.addPoint(.a); e.addPoint(.b) }
        e.addPoint(.a)
        XCTAssertTrue(e.state.inTieBreak) // 7-6: serve 2 di scarto
        e.addPoint(.a)
        XCTAssertEqual(e.state.setsA, 1)
        let set = e.state.completedSets[0]
        XCTAssertEqual(set.gamesA, 7)
        XCTAssertEqual(set.gamesB, 6)
        XCTAssertEqual(set.tieBreakA, 8)
    }

    func testSuperTieBreakDecider() {
        let e = engine(MatchFormat(id: "STB", superTieBreakDecider: true))
        e.start()
        winSet(e, .a)
        winSet(e, .b)
        XCTAssertTrue(e.state.inSuperTieBreak)
        for _ in 0..<10 { e.addPoint(.a) }
        XCTAssertTrue(e.state.completed)
        XCTAssertEqual(e.state.winner, .a)
        XCTAssertTrue(e.state.completedSets.last!.isSuperTieBreak)
    }

    func testUndoAcrossGameBoundary() {
        let e = engine()
        e.start()
        winGame(e, .a)
        XCTAssertEqual(e.state.gamesA, 1)
        e.undo()
        XCTAssertEqual(e.state.gamesA, 0)
        XCTAssertEqual(e.state.pointsLabel(.a), "40")
    }

    func testUndoReopensCompletedMatch() {
        let e = engine(MatchFormat(id: "SINGLE", setsToWin: 1))
        e.start()
        winSet(e, .a)
        XCTAssertTrue(e.state.completed)
        e.undo()
        XCTAssertFalse(e.state.completed)
    }

    func testJsonRoundTrip() {
        let e = engine()
        e.start()
        winGame(e, .a)
        e.addPoint(.b)
        e.undo()
        let json = MatchEvent.listToJson(e.allEvents)
        let rebuilt = engine()
        rebuilt.loadEvents(MatchEvent.listFromJson(json))
        XCTAssertEqual(rebuilt.state, e.state)
    }

    func testJsonWireDefaultsMatchMobileContract() {
        let json = """
        [{"eventId":"e1","matchId":"m1","ts":42,"type":"POINT_TEAM_A","teamId":"TEAM_A"}]
        """
        let events = MatchEvent.listFromJson(json)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].sourceDevice, "APPLE_WATCH")
        XCTAssertEqual(events[0].sourceMethod, "TAP")
        XCTAssertFalse(events[0].synced)

        let encoded = MatchEvent.listToJson(events)
        XCTAssertTrue(encoded.contains("\"sourceDevice\":\"APPLE_WATCH\""))
        XCTAssertTrue(encoded.contains("\"sourceMethod\":\"TAP\""))
        XCTAssertTrue(encoded.contains("\"teamId\":\"TEAM_A\""))
        XCTAssertTrue(encoded.contains("\"ts\":42"))
    }

    func testMatchFormatJsonDefaults() throws {
        let format = try XCTUnwrap(MatchFormat.fromJsonString("{\"id\":\"TRAINING\",\"freePlay\":true}"))
        XCTAssertEqual(format.name, "Custom")
        XCTAssertEqual(format.setsToWin, 2)
        XCTAssertTrue(format.goldenPoint)
        XCTAssertTrue(format.freePlay)
        XCTAssertTrue(format.toJsonString().contains("\"freePlay\":true"))
    }

    func testMatchFormatSchemaV3RoundTripAndLegacyFallbacks() throws {
        let json = MatchFormat.starPointBo3.toJsonString()
        XCTAssertTrue(json.contains("\"formatSchemaVersion\":3"))
        XCTAssertFalse(json.contains("\"schemaVersion\":"))
        XCTAssertTrue(json.contains("\"gameScoringMode\":\"STAR_POINT\""))
        XCTAssertTrue(json.contains("\"goldenPoint\":false"))

        let decoded = try XCTUnwrap(MatchFormat.fromJsonString(json))
        XCTAssertEqual(decoded, .starPointBo3)
        XCTAssertEqual(decoded.gameScoringMode, .starPoint)
        XCTAssertFalse(decoded.goldenPoint)
        XCTAssertTrue(MatchFormat.presets.contains(.starPointBo3))

        let legacyAdvantage = try XCTUnwrap(
            MatchFormat.fromJsonString(
                "{\"id\":\"ADV_OLD\",\"goldenPoint\":false}"
            )
        )
        XCTAssertEqual(legacyAdvantage.gameScoringMode, .advantage)

        let legacyGolden = try XCTUnwrap(
            MatchFormat.fromJsonString(
                "{\"id\":\"GOLDEN_OLD\",\"goldenPoint\":true}"
            )
        )
        XCTAssertEqual(legacyGolden.gameScoringMode, .goldenPoint)

        let unknownMode = try XCTUnwrap(
            MatchFormat.fromJsonString(
                """
                {
                  "id": "FUTURE",
                  "gameScoringMode": "FUTURE_RULE",
                  "goldenPoint": false
                }
                """
            )
        )
        XCTAssertEqual(unknownMode.gameScoringMode, .advantage)

        let transitionalAlias = try XCTUnwrap(
            MatchFormat.fromJsonString(
                """
                {
                  "schemaVersion": 2,
                  "id": "STAR_ALIAS",
                  "gameScoringMode": "STAR_POINT",
                  "goldenPoint": false
                }
                """
            )
        )
        XCTAssertEqual(transitionalAlias.gameScoringMode, .starPoint)
        XCTAssertTrue(
            transitionalAlias.toJsonString()
                .contains("\"formatSchemaVersion\":3")
        )
    }

    func testServeRotation() {
        let e = engine()
        e.start()
        XCTAssertEqual(e.state.servingTeam, .a)
        winGame(e, .a)
        XCTAssertEqual(e.state.servingTeam, .b)
    }

    func testFreePlay() {
        let e = engine(MatchFormat(id: "TRAINING", setsToWin: 1, freePlay: true))
        e.start()
        e.addPoint(.a); e.addPoint(.a); e.addPoint(.b)
        XCTAssertEqual(e.state.freePlayA, 2)
        XCTAssertEqual(e.state.freePlayB, 1)
        XCTAssertFalse(e.state.completed)
    }

    func testPauseResumeAndManualFinishAreReplayable() {
        let e = engine(MatchFormat.training)
        e.start()
        e.addPoint(.a)

        XCTAssertEqual(e.pause().map(\.type), [.matchPaused])
        XCTAssertTrue(e.state.paused)
        XCTAssertTrue(e.pause().isEmpty)

        XCTAssertEqual(e.resume().map(\.type), [.matchResumed])
        XCTAssertFalse(e.state.paused)
        XCTAssertTrue(e.resume().isEmpty)

        XCTAssertEqual(e.finish(winner: .a).map(\.type), [.matchCompleted])
        XCTAssertTrue(e.state.completed)
        XCTAssertEqual(e.state.winner, .a)

        let replayed = engine(MatchFormat.training)
        replayed.loadEvents(MatchEvent.listFromJson(MatchEvent.listToJson(e.allEvents)))
        XCTAssertEqual(replayed.state, e.state)
    }

    func testPausedMutationsAreNoOpsLiveAndOnReplay() {
        let live = engine()
        live.start()
        live.addPoint(.a)
        live.pause()
        let eventCount = live.allEvents.count
        XCTAssertTrue(live.addPoint(.b).newEvents.isEmpty)
        XCTAssertTrue(live.undo().newEvents.isEmpty)
        XCTAssertEqual(live.allEvents.count, eventCount)

        func event(
            _ id: String,
            _ ts: Int64,
            _ type: EventType,
            team: TeamId? = nil,
            payload: [String: Int]? = nil,
            method: String = "TAP"
        ) -> MatchEvent {
            MatchEvent(
                eventId: id,
                matchId: "paused-replay",
                ts: ts,
                type: type,
                teamId: team,
                sourceMethod: method,
                payload: payload
            )
        }

        let replayed = engine()
        replayed.loadEvents([
            event("start", 1, .matchStarted),
            event("point-a", 2, .pointTeamA, team: .a),
            event("pause", 3, .matchPaused),
            event("paused-point", 4, .pointTeamB, team: .b),
            event("paused-undo", 5, .undo),
            event(
                "paused-edit",
                6,
                .scoreEdited,
                payload: ["pointsA": 3, "pointsB": 0, "gamesA": 4, "gamesB": 0]
            ),
            event("resume", 7, .matchResumed),
            event("point-b", 8, .pointTeamB, team: .b),
            event("valid-undo", 9, .undo),
        ])
        XCTAssertFalse(replayed.state.paused)
        XCTAssertEqual(replayed.state.pointsLabel(.a), "15")
        XCTAssertEqual(replayed.state.pointsLabel(.b), "0")
        XCTAssertEqual(replayed.state.gamesA, 0)
    }

    func testCompletedReplayBlocksLatePointAndScoreEdit() {
        let replayed = engine(.training)
        replayed.loadEvents([
            MatchEvent(eventId: "start", matchId: "done", ts: 1, type: .matchStarted),
            MatchEvent(
                eventId: "point-a", matchId: "done", ts: 2,
                type: .pointTeamA, teamId: .a
            ),
            MatchEvent(
                eventId: "finish", matchId: "done", ts: 3,
                type: .matchCompleted, teamId: .a, sourceMethod: "MANUAL_EDIT"
            ),
            MatchEvent(
                eventId: "late-point", matchId: "done", ts: 4,
                type: .pointTeamB, teamId: .b
            ),
            MatchEvent(
                eventId: "late-edit", matchId: "done", ts: 5,
                type: .scoreEdited,
                payload: ["pointsA": 0, "pointsB": 0, "gamesA": 4, "gamesB": 3]
            ),
        ])
        XCTAssertTrue(replayed.state.completed)
        XCTAssertEqual(replayed.state.freePlayA, 1)
        XCTAssertEqual(replayed.state.freePlayB, 0)
        XCTAssertEqual(replayed.state.gamesA, 0)
    }

    func testWatchAttributionSurvivesJsonRoundTrip() throws {
        let e = ScoringEngine(
            matchId: "duo-1",
            format: .advantageBo3,
            sourceUserId: "user-1",
            assignedTeam: .b,
            duoMode: true,
            clock: { 99 },
            idGen: { "evt-1" }
        )
        let event = try XCTUnwrap(e.start().first)
        XCTAssertEqual(event.sourceUserId, "user-1")
        XCTAssertEqual(event.sourceTeamId, .b)
        XCTAssertTrue(event.duoMode)
        XCTAssertEqual(event.createdLocallyAtMs, 99)

        let decoded = try XCTUnwrap(
            MatchEvent.listFromJson(MatchEvent.listToJson([event])).first
        )
        XCTAssertEqual(decoded, event)
    }

    // MARK: - Duo Mode

    func testDuoTeamUndoCancelsOnlyOwnTeamPoint() {
        let e = engine()
        e.start()
        e.addPoint(.a)
        e.addPoint(.b)
        XCTAssertTrue(e.canUndoTeam(.a))
        e.undo(team: .a)
        XCTAssertEqual(e.state.pointsLabel(.a), "0")
        XCTAssertEqual(e.state.pointsLabel(.b), "15")
        XCTAssertFalse(e.canUndoTeam(.a))
        XCTAssertTrue(e.canUndoTeam(.b))
    }

    func testDuoTeamUndoWithNoOwnPointIsNoOp() {
        let e = engine()
        e.start()
        e.addPoint(.a)
        let result = e.undo(team: .b)
        XCTAssertTrue(result.newEvents.isEmpty)
        XCTAssertEqual(e.state.pointsLabel(.a), "15")
    }

    // FIP Rules of Padel, Rule 11 (Change of ends): every odd game, and at the
    // end of a set only when that set's total number of games is odd.

    func testSetWonSixFourDoesNotChangeEnds() {
        let e = engine()
        e.start()
        for _ in 0..<4 {
            playGame(e, .a)
            playGame(e, .b)
        }
        playGame(e, .a)
        let transitions = playGame(e, .a) // 6-4 → set
        XCTAssertTrue(transitions.contains(.setWon))
        XCTAssertFalse(transitions.contains(.sideChange))
        XCTAssertFalse(e.state.sideChangePending)
    }

    func testDeferredChangeOfEndsHappensAfterFirstGameOfNextSet() {
        let e = engine()
        e.start()
        for _ in 0..<4 {
            playGame(e, .a)
            playGame(e, .b)
        }
        playGame(e, .a)
        playGame(e, .a) // 6-4, no change of ends yet
        let transitions = playGame(e, .b) // first game of set 2
        XCTAssertTrue(transitions.contains(.sideChange))
        XCTAssertTrue(e.state.sideChangePending)
    }

    func testSetWonSixThreeChangesEnds() {
        let e = engine()
        e.start()
        for _ in 0..<3 {
            playGame(e, .a)
            playGame(e, .b)
        }
        playGame(e, .a)
        playGame(e, .a)
        let transitions = playGame(e, .a) // 6-3 → set
        XCTAssertTrue(transitions.contains(.setWon))
        XCTAssertTrue(transitions.contains(.sideChange))
        XCTAssertTrue(e.state.sideChangePending)
    }

    func testSetWonSixLoveDoesNotChangeEnds() {
        let e = engine()
        e.start()
        for _ in 0..<5 { playGame(e, .a) }
        let transitions = playGame(e, .a) // 6-0 → set
        XCTAssertFalse(transitions.contains(.sideChange))
        XCTAssertFalse(e.state.sideChangePending)
    }

    func testSetWonOnTieBreakChangesEnds() {
        let e = engine()
        e.start()
        for _ in 0..<6 {
            playGame(e, .a)
            playGame(e, .b)
        }
        XCTAssertTrue(e.state.inTieBreak)
        var transitions: [Transition] = []
        for _ in 0..<7 { transitions = e.addPoint(.a).transitions }
        XCTAssertTrue(transitions.contains(.setWon))
        XCTAssertTrue(transitions.contains(.sideChange))
        XCTAssertTrue(e.state.sideChangePending)
    }

    func testMatchWinningSetLeavesNoPendingChangeOfEnds() {
        let e = engine()
        e.start()
        winSet(e, .a)
        for _ in 0..<3 {
            playGame(e, .a)
            playGame(e, .b)
        }
        playGame(e, .a)
        playGame(e, .a)
        let transitions = playGame(e, .a) // 6-3 → set and match
        XCTAssertTrue(transitions.contains(.matchWon))
        XCTAssertTrue(e.state.completed)
        XCTAssertFalse(e.state.sideChangePending)
    }

    func testDuoLifecycleEventsAreAuditOnlyOnReplay() {
        let e = engine()
        e.start()
        e.addPoint(.a)
        let log = e.allEvents + [
            MatchEvent(
                eventId: "j1", matchId: "m1", ts: 99,
                type: .teamConfirmed, teamId: .b
            ),
        ]
        let replayed = engine()
        replayed.loadEvents(log)
        XCTAssertEqual(replayed.state.pointsLabel(.a), "15")
        XCTAssertFalse(replayed.state.completed)
    }
}
