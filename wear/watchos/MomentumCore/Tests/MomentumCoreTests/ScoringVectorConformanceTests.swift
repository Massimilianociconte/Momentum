import XCTest
@testable import MomentumCore

/// Conformità cross-piattaforma: rigioca i vettori generati dall'engine Dart
/// (wear/shared/scoring_vectors.json, contratto canonico) su questo engine e
/// confronta lo snapshot dopo ogni operazione.
///
/// Rigenerare i vettori con:
///   cd packages/momentum_core && dart run tool/generate_scoring_vectors.dart
final class ScoringVectorConformanceTests: XCTestCase {

    private func vectorsURL() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while dir.path != "/" {
            let candidate = dir
                .appendingPathComponent("wear/shared/scoring_vectors.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            dir.deleteLastPathComponent()
        }
        throw XCTSkip("wear/shared/scoring_vectors.json non trovato")
    }

    private func team(_ value: Any?) -> TeamId? {
        guard let wire = value as? String else { return nil }
        return wire == "TEAM_A" ? .a : wire == "TEAM_B" ? .b : nil
    }

    private func format(from json: [String: Any]) -> MatchFormat {
        let legacyGolden = json["goldenPoint"] as? Bool ?? true
        let mode = (json["gameScoringMode"] as? String)
            .flatMap(GameScoringMode.init(rawValue:))
        return MatchFormat(
            id: json["id"] as? String ?? "GOLDEN_BO3",
            name: json["name"] as? String ?? "Custom",
            setsToWin: json["setsToWin"] as? Int ?? 2,
            gamesPerSet: json["gamesPerSet"] as? Int ?? 6,
            goldenPoint: legacyGolden,
            gameScoringMode: mode,
            tieBreakAtGamesAll: json["tieBreakAtGamesAll"] as? Bool ?? true,
            tieBreakPoints: json["tieBreakPoints"] as? Int ?? 7,
            tieBreakInDecidingSet: json["tieBreakInDecidingSet"] as? Bool ?? true,
            superTieBreakDecider: json["superTieBreakDecider"] as? Bool ?? false,
            superTieBreakPoints: json["superTieBreakPoints"] as? Int ?? 10,
            freePlay: json["freePlay"] as? Bool ?? false
        )
    }

    private func label(
        _ state: MatchState, freePlay: Bool, _ team: TeamId
    ) -> String {
        if freePlay {
            return String(team == .a ? state.freePlayA : state.freePlayB)
        }
        if state.inTieBreak || state.inSuperTieBreak {
            return String(team == .a ? state.tieBreakA : state.tieBreakB)
        }
        return state.pointsLabel(team)
    }

    private func assertSnapshot(
        _ engine: ScoringEngine,
        freePlay: Bool,
        contractVersion: Int,
        expect: [String: Any],
        _ context: String
    ) {
        let s = engine.state
        XCTAssertEqual(s.completed, expect["completed"] as? Bool, "\(context) completed")
        XCTAssertEqual(s.paused, expect["paused"] as? Bool, "\(context) paused")
        XCTAssertEqual(s.winner, team(expect["winner"]), "\(context) winner")
        XCTAssertEqual(s.setsA, expect["setsA"] as? Int, "\(context) setsA")
        XCTAssertEqual(s.setsB, expect["setsB"] as? Int, "\(context) setsB")
        XCTAssertEqual(s.gamesA, expect["gamesA"] as? Int, "\(context) gamesA")
        XCTAssertEqual(s.gamesB, expect["gamesB"] as? Int, "\(context) gamesB")
        XCTAssertEqual(
            label(s, freePlay: freePlay, .a),
            expect["labelA"] as? String, "\(context) labelA"
        )
        XCTAssertEqual(
            label(s, freePlay: freePlay, .b),
            expect["labelB"] as? String, "\(context) labelB"
        )
        XCTAssertEqual(s.advantage, team(expect["advantage"]), "\(context) advantage")
        XCTAssertEqual(s.inTieBreak, expect["inTieBreak"] as? Bool, "\(context) inTieBreak")
        XCTAssertEqual(
            s.inSuperTieBreak,
            expect["inSuperTieBreak"] as? Bool, "\(context) inSuperTieBreak"
        )
        XCTAssertEqual(s.tieBreakA, expect["tieBreakA"] as? Int, "\(context) tieBreakA")
        XCTAssertEqual(s.tieBreakB, expect["tieBreakB"] as? Int, "\(context) tieBreakB")
        XCTAssertEqual(s.freePlayA, expect["freePlayA"] as? Int, "\(context) freePlayA")
        XCTAssertEqual(s.freePlayB, expect["freePlayB"] as? Int, "\(context) freePlayB")
        if contractVersion >= 2 {
            guard
                let expectedDeuceNumber = expect["deuceNumber"] as? Int,
                let expectedIsStarPoint = expect["isStarPoint"] as? Bool
            else {
                XCTFail(
                    "\(context) contratto v2 senza deuceNumber/isStarPoint"
                )
                return
            }
            XCTAssertEqual(
                s.deuceNumber,
                expectedDeuceNumber,
                "\(context) deuceNumber"
            )
            XCTAssertEqual(
                s.isStarPoint,
                expectedIsStarPoint,
                "\(context) isStarPoint"
            )
        } else if let expectedDeuceNumber = expect["deuceNumber"] as? Int {
            XCTAssertEqual(
                s.deuceNumber,
                expectedDeuceNumber,
                "\(context) deuceNumber"
            )
        }

        let expectedSets = expect["completedSets"] as? [[String: Any]] ?? []
        XCTAssertEqual(
            s.completedSets.count, expectedSets.count,
            "\(context) completedSets.count"
        )
        for (i, set) in expectedSets.enumerated() where i < s.completedSets.count {
            let actual = s.completedSets[i]
            XCTAssertEqual(actual.gamesA, set["gamesA"] as? Int, "\(context) set[\(i)].gamesA")
            XCTAssertEqual(actual.gamesB, set["gamesB"] as? Int, "\(context) set[\(i)].gamesB")
            XCTAssertEqual(
                actual.tieBreakA, set["tieBreakA"] as? Int,
                "\(context) set[\(i)].tieBreakA"
            )
            XCTAssertEqual(
                actual.tieBreakB, set["tieBreakB"] as? Int,
                "\(context) set[\(i)].tieBreakB"
            )
            XCTAssertEqual(
                actual.isSuperTieBreak, set["superTieBreak"] as? Bool,
                "\(context) set[\(i)].superTieBreak"
            )
        }
    }

    func testEngineMatchesEveryDartVector() throws {
        let data = try Data(contentsOf: try vectorsURL())
        guard
            let document = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let contractVersion = document["version"] as? Int,
            let vectors = document["vectors"] as? [[String: Any]]
        else {
            return XCTFail("scoring_vectors.json non leggibile")
        }

        var executed = 0
        for vector in vectors {
            guard
                let id = vector["id"] as? String,
                let platforms = vector["platforms"] as? [String],
                platforms.contains("swift"),
                let formatJson = vector["format"] as? [String: Any],
                let steps = vector["steps"] as? [[String: Any]]
            else { continue }
            executed += 1

            let format = format(from: formatJson)
            var tick: Int64 = 0
            let engine = ScoringEngine(
                matchId: "vec_\(id)",
                format: format,
                clock: { tick += 1; return 1_750_000_000_000 + tick * 1000 },
                idGen: { tick += 1; return "evt_\(id)_\(tick)" }
            )
            engine.start()

            for (i, step) in steps.enumerated() {
                let stepTeam = team(step["team"])
                switch step["op"] as? String {
                case "point": engine.addPoint(stepTeam!)
                case "edit":
                    guard let rawPayload = step["payload"] as? [String: Any] else {
                        XCTFail("\(id)#\(i): payload edit mancante")
                        continue
                    }
                    let payload = rawPayload.compactMapValues { $0 as? Int }
                    engine.loadEvents(engine.allEvents + [
                        MatchEvent(
                            eventId: "evt_\(id)_edit_\(i)",
                            matchId: "vec_\(id)",
                            ts: 1_760_000_000_000 + Int64(i),
                            type: .scoreEdited,
                            sourceMethod: "MANUAL_EDIT",
                            payload: payload
                        ),
                    ])
                case "undo": engine.undo(team: stepTeam)
                case "pause": engine.pause()
                case "resume": engine.resume()
                case "finish": engine.finish(winner: stepTeam)
                default: XCTFail("\(id)#\(i): operazione sconosciuta")
                }
                guard let expect = step["expect"] as? [String: Any] else {
                    XCTFail("\(id)#\(i): expect mancante")
                    continue
                }
                assertSnapshot(
                    engine,
                    freePlay: format.freePlay,
                    contractVersion: contractVersion,
                    expect: expect,
                    "\(id)#\(i)"
                )
            }
        }
        XCTAssertGreaterThan(executed, 0, "Nessun vettore swift eseguito")
    }
}
