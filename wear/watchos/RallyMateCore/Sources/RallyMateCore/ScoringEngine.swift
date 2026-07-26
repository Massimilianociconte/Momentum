//
//  Swift port of the rally_core padel scoring engine.
//
//  MUST stay semantically identical to packages/rally_core (Dart) and the
//  Kotlin port (Wear OS). The JSON wire format is the sync contract.
//

import Foundation

public enum TeamId: String, Codable, Sendable {
    case a = "TEAM_A"
    case b = "TEAM_B"

    public var opponent: TeamId { self == .a ? .b : .a }
}

public enum EventType: String, Codable, Sendable {
    case matchStarted = "MATCH_STARTED"
    case pointTeamA = "POINT_TEAM_A"
    case pointTeamB = "POINT_TEAM_B"
    case undo = "UNDO"
    case gameCompleted = "GAME_COMPLETED"
    case setCompleted = "SET_COMPLETED"
    case sideChange = "SIDE_CHANGE"
    case matchPaused = "MATCH_PAUSED"
    case matchResumed = "MATCH_RESUMED"
    case matchCompleted = "MATCH_COMPLETED"
    case scoreEdited = "SCORE_EDITED"
    // Duo Mode session lifecycle (audit-only on replay).
    case deviceJoinedMatch = "DEVICE_JOINED_MATCH"
    case deviceLeftMatch = "DEVICE_LEFT_MATCH"
    case teamConfirmed = "TEAM_CONFIRMED"
}

public struct MatchFormat: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var setsToWin: Int
    public var gamesPerSet: Int
    public var goldenPoint: Bool
    public var tieBreakAtGamesAll: Bool
    public var tieBreakPoints: Int
    public var superTieBreakDecider: Bool
    public var superTieBreakPoints: Int
    public var freePlay: Bool

    public init(
        id: String = "GOLDEN_BO3",
        name: String = "Golden point — meglio di 3",
        setsToWin: Int = 2,
        gamesPerSet: Int = 6,
        goldenPoint: Bool = true,
        tieBreakAtGamesAll: Bool = true,
        tieBreakPoints: Int = 7,
        superTieBreakDecider: Bool = false,
        superTieBreakPoints: Int = 10,
        freePlay: Bool = false
    ) {
        self.id = id
        self.name = name
        self.setsToWin = setsToWin
        self.gamesPerSet = gamesPerSet
        self.goldenPoint = goldenPoint
        self.tieBreakAtGamesAll = tieBreakAtGamesAll
        self.tieBreakPoints = tieBreakPoints
        self.superTieBreakDecider = superTieBreakDecider
        self.superTieBreakPoints = superTieBreakPoints
        self.freePlay = freePlay
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, setsToWin, gamesPerSet, goldenPoint
        case tieBreakAtGamesAll, tieBreakPoints
        case superTieBreakDecider, superTieBreakPoints, freePlay
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(String.self, forKey: .id) ?? "GOLDEN_BO3",
            name: try c.decodeIfPresent(String.self, forKey: .name) ?? "Custom",
            setsToWin: try c.decodeIfPresent(Int.self, forKey: .setsToWin) ?? 2,
            gamesPerSet: try c.decodeIfPresent(Int.self, forKey: .gamesPerSet) ?? 6,
            goldenPoint: try c.decodeIfPresent(Bool.self, forKey: .goldenPoint) ?? true,
            tieBreakAtGamesAll: try c.decodeIfPresent(Bool.self, forKey: .tieBreakAtGamesAll) ?? true,
            tieBreakPoints: try c.decodeIfPresent(Int.self, forKey: .tieBreakPoints) ?? 7,
            superTieBreakDecider: try c.decodeIfPresent(Bool.self, forKey: .superTieBreakDecider) ?? false,
            superTieBreakPoints: try c.decodeIfPresent(Int.self, forKey: .superTieBreakPoints) ?? 10,
            freePlay: try c.decodeIfPresent(Bool.self, forKey: .freePlay) ?? false
        )
    }

    public func toJsonString() -> String {
        let data = (try? Self.encoder.encode(self)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    public static func fromJsonString(_ json: String) -> MatchFormat? {
        try? Self.decoder.decode(MatchFormat.self, from: Data(json.utf8))
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder = JSONDecoder()

    public static let goldenPointBo3 = MatchFormat()

    public static let advantageBo3 = MatchFormat(
        id: "ADV_BO3",
        name: "Vantaggi - meglio di 3",
        goldenPoint: false
    )

    public static let superTieBreakBo3 = MatchFormat(
        id: "SUPER_TB_BO3",
        name: "Super tie-break al terzo",
        superTieBreakDecider: true
    )

    public static let singleSet = MatchFormat(
        id: "SINGLE_SET",
        name: "Partita secca - 1 set",
        setsToWin: 1
    )

    public static let training = MatchFormat(
        id: "TRAINING",
        name: "Allenamento libero",
        setsToWin: 1,
        freePlay: true
    )

    public static let presets: [MatchFormat] = [
        goldenPointBo3,
        advantageBo3,
        superTieBreakBo3,
        singleSet,
        training,
    ]
}

public struct MatchEvent: Codable, Equatable, Sendable {
    public var eventId: String
    public var matchId: String
    public var ts: Int64
    public var type: EventType
    public var teamId: TeamId?
    public var scoreBefore: String?
    public var scoreAfter: String?
    public var sourceDevice: String
    public var sourceMethod: String
    public var synced: Bool
    public var payload: [String: Int]?
    public var sourceUserId: String?
    public var sourceTeamId: TeamId?
    public var duoMode: Bool
    public var createdLocallyAtMs: Int64?

    public init(
        eventId: String,
        matchId: String,
        ts: Int64,
        type: EventType,
        teamId: TeamId? = nil,
        scoreBefore: String? = nil,
        scoreAfter: String? = nil,
        sourceDevice: String = "APPLE_WATCH",
        sourceMethod: String = "TAP",
        synced: Bool = false,
        payload: [String: Int]? = nil,
        sourceUserId: String? = nil,
        sourceTeamId: TeamId? = nil,
        duoMode: Bool = false,
        createdLocallyAtMs: Int64? = nil
    ) {
        self.eventId = eventId
        self.matchId = matchId
        self.ts = ts
        self.type = type
        self.teamId = teamId
        self.scoreBefore = scoreBefore
        self.scoreAfter = scoreAfter
        self.sourceDevice = sourceDevice
        self.sourceMethod = sourceMethod
        self.synced = synced
        self.payload = payload
        self.sourceUserId = sourceUserId
        self.sourceTeamId = sourceTeamId
        self.duoMode = duoMode
        self.createdLocallyAtMs = createdLocallyAtMs
    }

    private enum CodingKeys: String, CodingKey {
        case eventId, matchId, ts, type, teamId, scoreBefore, scoreAfter
        case sourceDevice, sourceMethod, synced, payload
        case sourceUserId, sourceTeamId, duo = "duo", createdLocallyAt = "createdLocallyAt"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            eventId: try c.decode(String.self, forKey: .eventId),
            matchId: try c.decode(String.self, forKey: .matchId),
            ts: try c.decode(Int64.self, forKey: .ts),
            type: try c.decode(EventType.self, forKey: .type),
            teamId: try c.decodeIfPresent(TeamId.self, forKey: .teamId),
            scoreBefore: try c.decodeIfPresent(String.self, forKey: .scoreBefore),
            scoreAfter: try c.decodeIfPresent(String.self, forKey: .scoreAfter),
            sourceDevice: try c.decodeIfPresent(String.self, forKey: .sourceDevice) ?? "APPLE_WATCH",
            sourceMethod: try c.decodeIfPresent(String.self, forKey: .sourceMethod) ?? "TAP",
            synced: try c.decodeIfPresent(Bool.self, forKey: .synced) ?? false,
            payload: try c.decodeIfPresent([String: Int].self, forKey: .payload),
            sourceUserId: try c.decodeIfPresent(String.self, forKey: .sourceUserId),
            sourceTeamId: try c.decodeIfPresent(TeamId.self, forKey: .sourceTeamId),
            duoMode: try c.decodeIfPresent(Bool.self, forKey: .duo) ?? false,
            createdLocallyAtMs: try c.decodeIfPresent(Int64.self, forKey: .createdLocallyAt)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(eventId, forKey: .eventId)
        try c.encode(matchId, forKey: .matchId)
        try c.encode(ts, forKey: .ts)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(teamId, forKey: .teamId)
        try c.encodeIfPresent(scoreBefore, forKey: .scoreBefore)
        try c.encodeIfPresent(scoreAfter, forKey: .scoreAfter)
        try c.encode(sourceDevice, forKey: .sourceDevice)
        try c.encode(sourceMethod, forKey: .sourceMethod)
        try c.encode(synced, forKey: .synced)
        try c.encodeIfPresent(payload, forKey: .payload)
        try c.encodeIfPresent(sourceUserId, forKey: .sourceUserId)
        try c.encodeIfPresent(sourceTeamId, forKey: .sourceTeamId)
        if duoMode { try c.encode(true, forKey: .duo) }
        try c.encodeIfPresent(createdLocallyAtMs, forKey: .createdLocallyAt)
    }

    public func copy(synced: Bool? = nil) -> MatchEvent {
        MatchEvent(
            eventId: eventId,
            matchId: matchId,
            ts: ts,
            type: type,
            teamId: teamId,
            scoreBefore: scoreBefore,
            scoreAfter: scoreAfter,
            sourceDevice: sourceDevice,
            sourceMethod: sourceMethod,
            synced: synced ?? self.synced,
            payload: payload,
            sourceUserId: sourceUserId,
            sourceTeamId: sourceTeamId,
            duoMode: duoMode,
            createdLocallyAtMs: createdLocallyAtMs
        )
    }

    public static func listToJson(_ events: [MatchEvent]) -> String {
        let data = (try? encoder.encode(events)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    public static func listFromJson(_ json: String) -> [MatchEvent] {
        (try? decoder.decode([MatchEvent].self, from: Data(json.utf8))) ?? []
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder = JSONDecoder()
}

public struct SetResult: Codable, Equatable, Sendable {
    public var gamesA: Int
    public var gamesB: Int
    public var tieBreakA: Int?
    public var tieBreakB: Int?
    public var isSuperTieBreak: Bool

    public init(gamesA: Int, gamesB: Int, tieBreakA: Int? = nil,
                tieBreakB: Int? = nil, isSuperTieBreak: Bool = false) {
        self.gamesA = gamesA
        self.gamesB = gamesB
        self.tieBreakA = tieBreakA
        self.tieBreakB = tieBreakB
        self.isSuperTieBreak = isSuperTieBreak
    }
}

public enum Transition: Sendable {
    case point, gameWon, setWon, matchWon, sideChange, undone
}

public struct MatchState: Equatable, Sendable {
    public var completed: Bool
    public var paused: Bool
    public var pointsA: Int
    public var pointsB: Int
    public var advantage: TeamId?
    public var gamesA: Int
    public var gamesB: Int
    public var setsA: Int
    public var setsB: Int
    public var completedSets: [SetResult]
    public var servingTeam: TeamId
    public var inTieBreak: Bool
    public var inSuperTieBreak: Bool
    public var tieBreakA: Int
    public var tieBreakB: Int
    public var freePlayA: Int
    public var freePlayB: Int
    public var sideChangePending: Bool
    public var winner: TeamId?

    public func pointsLabel(_ team: TeamId) -> String {
        let labels = ["0", "15", "30", "40"]
        if let adv = advantage { return adv == team ? "AD" : "40" }
        let v = team == .a ? pointsA : pointsB
        return labels[min(max(v, 0), 3)]
    }

    public func pointSituation(
        goldenPoint: Bool,
        teamALabel: String = "NOI",
        teamBLabel: String = "LORO"
    ) -> String? {
        guard !inTieBreak, !inSuperTieBreak else { return nil }
        if let advantage {
            let label = advantage == .a ? teamALabel : teamBLabel
            return "VANTAGGIO \(label) · GAME POINT"
        }
        guard pointsA >= 3, pointsB >= 3 else { return nil }
        return goldenPoint
            ? "40 PARI · PUNTO DECISIVO"
            : "40 PARI · VANTAGGI"
    }
}

public final class ScoringEngine {
    public let matchId: String
    public let format: MatchFormat
    public let firstServer: TeamId
    public let sourceUserId: String?
    public let assignedTeam: TeamId?
    public let duoMode: Bool
    private let clock: () -> Int64
    private let idGen: () -> String

    private var events: [MatchEvent] = []
    public private(set) var state: MatchState

    public var allEvents: [MatchEvent] { events }

    public init(
        matchId: String,
        format: MatchFormat,
        firstServer: TeamId = .a,
        sourceUserId: String? = nil,
        assignedTeam: TeamId? = nil,
        duoMode: Bool = false,
        clock: @escaping () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1000)
        },
        idGen: @escaping () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.matchId = matchId
        self.format = format
        self.firstServer = firstServer
        self.sourceUserId = sourceUserId
        self.assignedTeam = assignedTeam
        self.duoMode = duoMode
        self.clock = clock
        self.idGen = idGen
        self.state = Self.replay(events: [], format: format,
                                 firstServer: firstServer).0
    }

    public var canUndo: Bool {
        let resolution = Self.resolveUndos(events: events)
        for (i, event) in events.enumerated() {
            if resolution.cancelled.contains(i)
                || resolution.ignored.contains(i) {
                continue
            }
            switch event.type {
            case .pointTeamA, .pointTeamB, .scoreEdited:
                return true
            default:
                continue
            }
        }
        return false
    }

    /// Duo Mode: whether a team-scoped undo would cancel anything.
    public func canUndoTeam(_ team: TeamId) -> Bool {
        let resolution = Self.resolveUndos(events: events)
        let wanted: EventType = team == .a ? .pointTeamA : .pointTeamB
        for (i, e) in events.enumerated().reversed() {
            if resolution.cancelled.contains(i)
                || resolution.ignored.contains(i) {
                continue
            }
            if e.type == wanted { return true }
        }
        return false
    }

    public func loadEvents(_ persisted: [MatchEvent]) {
        events = persisted
        recompute()
    }

    @discardableResult
    public func start() -> [MatchEvent] {
        guard !events.contains(where: { $0.type == .matchStarted }) else {
            return []
        }
        let e = make(.matchStarted)
        events.append(e)
        recompute()
        return [e]
    }

    @discardableResult
    public func addPoint(_ team: TeamId, method: String = "TAP")
        -> (newEvents: [MatchEvent], transitions: [Transition]) {
        guard !state.completed, !state.paused else { return ([], []) }
        let point = make(team == .a ? .pointTeamA : .pointTeamB,
                         teamId: team, method: method)
        events.append(point)
        let transitions = recompute()

        var derived: [MatchEvent] = []
        func derive(_ t: EventType) {
            let d = make(t, teamId: team, method: "AUTO")
            derived.append(d)
            events.append(d)
        }
        if transitions.contains(.gameWon) { derive(.gameCompleted) }
        if transitions.contains(.setWon) { derive(.setCompleted) }
        if transitions.contains(.sideChange) { derive(.sideChange) }
        if transitions.contains(.matchWon) { derive(.matchCompleted) }
        return ([point] + derived, transitions)
    }

    /// `team` (Duo Mode): the UNDO cancels only the last point of that team,
    /// so the two devices' interleaved logs converge. `nil` = classic undo.
    @discardableResult
    public func undo(team: TeamId? = nil)
        -> (newEvents: [MatchEvent], transitions: [Transition]) {
        guard !state.paused else { return ([], []) }
        if let team {
            guard canUndoTeam(team) else { return ([], []) }
        } else {
            guard canUndo else { return ([], []) }
        }
        let e = make(.undo, teamId: team)
        events.append(e)
        recompute()
        return ([e], [.undone])
    }

    @discardableResult
    public func pause() -> [MatchEvent] {
        guard !state.completed, !state.paused else { return [] }
        let event = make(.matchPaused)
        events.append(event)
        recompute()
        return [event]
    }

    @discardableResult
    public func resume() -> [MatchEvent] {
        guard !state.completed, state.paused else { return [] }
        let event = make(.matchResumed)
        events.append(event)
        recompute()
        return [event]
    }

    /// Explicit completion used by wearable-first sessions and free play.
    /// It is deliberately distinct from the derived MATCH_COMPLETED event.
    @discardableResult
    public func finish(winner: TeamId? = nil) -> [MatchEvent] {
        guard !state.completed else { return [] }
        let event = make(
            .matchCompleted,
            teamId: winner,
            method: "MANUAL_EDIT"
        )
        events.append(event)
        recompute()
        return [event]
    }

    private func make(_ type: EventType, teamId: TeamId? = nil,
                      method: String = "TAP") -> MatchEvent {
        let now = clock()
        return MatchEvent(
            eventId: idGen(),
            matchId: matchId,
            ts: now,
            type: type,
            teamId: teamId,
            sourceMethod: method,
            sourceUserId: sourceUserId,
            sourceTeamId: assignedTeam,
            duoMode: duoMode,
            createdLocallyAtMs: duoMode ? now : nil
        )
    }

    @discardableResult
    private func recompute() -> [Transition] {
        let (s, t) = Self.replay(events: events, format: format,
                                 firstServer: firstServer)
        state = s
        return t
    }

    // ---------------------------------------------------------- replay

    private enum ReplayLifecycle {
        case created, inProgress, paused, completed
    }

    private struct UndoResolution {
        var cancelled: Set<Int>
        var ignored: Set<Int>
    }

    /// Pass 1 of the replay: resolves UNDOs and lifecycle-invalid events.
    /// An UNDO carrying a teamId (Duo Mode) cancels only the most recent
    /// still-active point of that team (order-independent across devices).
    private static func resolveUndos(events: [MatchEvent]) -> UndoResolution {
        var cancelled = Set<Int>()
        var ignored = Set<Int>()
        var stack: [Int] = []
        var lifecycle = ReplayLifecycle.created
        var manuallyCompleted = false
        for (i, e) in events.enumerated() {
            switch e.type {
            case .matchStarted:
                if lifecycle == .created { lifecycle = .inProgress }
            case .matchPaused:
                if lifecycle == .inProgress { lifecycle = .paused }
            case .matchResumed:
                if lifecycle == .paused { lifecycle = .inProgress }
            case .pointTeamA, .pointTeamB:
                if lifecycle == .paused || lifecycle == .completed {
                    ignored.insert(i)
                    continue
                }
                if lifecycle == .created { lifecycle = .inProgress }
                stack.append(i)
            case .scoreEdited:
                if lifecycle == .paused || lifecycle == .completed {
                    ignored.insert(i)
                    continue
                }
                stack.append(i)
            case .matchCompleted:
                lifecycle = .completed
                if e.sourceMethod == "MANUAL_EDIT" {
                    manuallyCompleted = true
                }
            case .undo:
                if lifecycle == .paused {
                    ignored.insert(i)
                    continue
                }
                var didCancel = false
                if let team = e.teamId {
                    let wanted: EventType = team == .a ? .pointTeamA : .pointTeamB
                    if let s = stack.lastIndex(where: { events[$0].type == wanted }) {
                        cancelled.insert(stack.remove(at: s))
                        didCancel = true
                    }
                } else if let last = stack.popLast() {
                    cancelled.insert(last)
                    didCancel = true
                }
                // A derived completion belongs to the point that produced it:
                // undoing that point reopens the match. Manual completion does
                // not become mutable through a later UNDO.
                if didCancel && lifecycle == .completed && !manuallyCompleted {
                    lifecycle = .inProgress
                }
            default: break
            }
        }
        return UndoResolution(cancelled: cancelled, ignored: ignored)
    }

    private static func replay(
        events: [MatchEvent],
        format: MatchFormat,
        firstServer: TeamId
    ) -> (MatchState, [Transition]) {
        let resolution = resolveUndos(events: events)

        var w = Working(format: format, serving: firstServer)
        var last: [Transition] = []
        for (i, e) in events.enumerated() {
            if resolution.cancelled.contains(i)
                || resolution.ignored.contains(i) {
                continue
            }
            switch e.type {
            case .matchStarted: break
            case .matchPaused: if !w.completed { w.paused = true }
            case .matchResumed: if !w.completed && w.paused { w.paused = false }
            case .pointTeamA:
                if !w.completed && !w.paused { last = w.applyPoint(.a) }
            case .pointTeamB:
                if !w.completed && !w.paused { last = w.applyPoint(.b) }
            case .scoreEdited:
                if !w.completed && !w.paused, let p = e.payload {
                    w.applyEdit(p)
                    last = []
                }
            case .matchCompleted:
                if e.sourceMethod == "MANUAL_EDIT" && !w.completed {
                    w.completed = true
                    w.winner = e.teamId ?? w.leading()
                    last = [.matchWon]
                }
            default: break
            }
        }
        return (w.snapshot(), last)
    }

    private struct Working {
        let f: MatchFormat
        var paused = false
        var completed = false
        var pA = 0, pB = 0
        var gA = 0, gB = 0
        var sA = 0, sB = 0
        var sets: [SetResult] = []
        var serving: TeamId
        var inTb = false, inStb = false
        var tbA = 0, tbB = 0
        var tbFirstServer: TeamId = .a
        var freeA = 0, freeB = 0
        var sidePending = false
        var winner: TeamId?

        init(format: MatchFormat, serving: TeamId) {
            self.f = format
            self.serving = serving
        }

        func leading() -> TeamId? {
            if f.freePlay {
                if freeA == freeB { return nil }
                return freeA > freeB ? .a : .b
            }
            if sA != sB { return sA > sB ? .a : .b }
            if gA != gB { return gA > gB ? .a : .b }
            return nil
        }

        func currentServer() -> TeamId {
            if !inTb && !inStb { return serving }
            let idx = tbA + tbB
            if idx == 0 { return tbFirstServer }
            let block = (idx - 1) / 2
            return block % 2 == 0 ? tbFirstServer.opponent : tbFirstServer
        }

        mutating func applyPoint(_ team: TeamId) -> [Transition] {
            sidePending = false
            if f.freePlay {
                if team == .a { freeA += 1 } else { freeB += 1 }
                return [.point]
            }
            return (inTb || inStb) ? tieBreakPoint(team) : gamePoint(team)
        }

        private mutating func gamePoint(_ team: TeamId) -> [Transition] {
            var gameWon = false
            if f.goldenPoint {
                if team == .a { pA += 1 } else { pB += 1 }
                gameWon = pA >= 4 || pB >= 4
            } else if pA == 4 && pB == 3 {
                if team == .a { gameWon = true } else { pA = 3; pB = 3 }
            } else if pB == 4 && pA == 3 {
                if team == .b { gameWon = true } else { pA = 3; pB = 3 }
            } else if pA == 3 && pB == 3 {
                if team == .a { pA = 4 } else { pB = 4 }
            } else {
                if team == .a { pA += 1 } else { pB += 1 }
                gameWon = (pA >= 4 && pA - pB >= 2)
                    || (pB >= 4 && pB - pA >= 2)
            }
            if !gameWon { return [.point] }

            let gWinner: TeamId = pA > pB ? .a : .b
            pA = 0; pB = 0
            if gWinner == .a { gA += 1 } else { gB += 1 }
            serving = serving.opponent

            var out: [Transition] = [.point, .gameWon]
            if (gA + gB) % 2 == 1 { sidePending = true; out.append(.sideChange) }

            let lg = gWinner == .a ? gA : gB
            let og = gWinner == .a ? gB : gA
            if lg >= f.gamesPerSet && lg - og >= 2 {
                out.append(contentsOf: completeSet(gWinner, tb: false))
                return out
            }
            if f.tieBreakAtGamesAll && gA == f.gamesPerSet && gB == f.gamesPerSet {
                inTb = true; tbA = 0; tbB = 0; tbFirstServer = serving
            }
            return out
        }

        private mutating func tieBreakPoint(_ team: TeamId) -> [Transition] {
            if team == .a { tbA += 1 } else { tbB += 1 }
            let target = inStb ? f.superTieBreakPoints : f.tieBreakPoints
            var out: [Transition] = [.point]
            let leader: TeamId = tbA > tbB ? .a : .b
            let lead = abs(tbA - tbB)
            let maxPts = max(tbA, tbB)
            if maxPts >= target && lead >= 2 {
                if inStb {
                    out.append(contentsOf: completeSuperTb(leader))
                } else {
                    out.append(.gameWon)
                    out.append(contentsOf: completeSet(leader, tb: true))
                }
                return out
            }
            let total = tbA + tbB
            if total > 0 && total % 6 == 0 {
                sidePending = true
                out.append(.sideChange)
            }
            return out
        }

        private mutating func completeSet(_ setWinner: TeamId, tb: Bool)
            -> [Transition] {
            if tb {
                sets.append(SetResult(
                    gamesA: setWinner == .a ? f.gamesPerSet + 1 : f.gamesPerSet,
                    gamesB: setWinner == .b ? f.gamesPerSet + 1 : f.gamesPerSet,
                    tieBreakA: tbA, tieBreakB: tbB))
            } else {
                sets.append(SetResult(gamesA: gA, gamesB: gB))
            }
            if setWinner == .a { sA += 1 } else { sB += 1 }
            gA = 0; gB = 0; pA = 0; pB = 0
            if inTb { serving = tbFirstServer.opponent }
            inTb = false; tbA = 0; tbB = 0
            sidePending = true

            var out: [Transition] = [.setWon, .sideChange]
            let winSets = setWinner == .a ? sA : sB
            if winSets >= f.setsToWin {
                completed = true
                winner = setWinner
                out.append(.matchWon)
                return out
            }
            if f.superTieBreakDecider && sA == f.setsToWin - 1
                && sB == f.setsToWin - 1 {
                inStb = true; tbA = 0; tbB = 0; tbFirstServer = serving
            }
            return out
        }

        private mutating func completeSuperTb(_ stbWinner: TeamId)
            -> [Transition] {
            sets.append(SetResult(
                gamesA: stbWinner == .a ? 1 : 0,
                gamesB: stbWinner == .b ? 1 : 0,
                tieBreakA: tbA, tieBreakB: tbB, isSuperTieBreak: true))
            if stbWinner == .a { sA += 1 } else { sB += 1 }
            inStb = false
            completed = true
            winner = stbWinner
            return [.setWon, .matchWon]
        }

        mutating func applyEdit(_ p: [String: Int]) {
            if let v = p["pointsA"] { pA = min(max(v, 0), 4) }
            if let v = p["pointsB"] { pB = min(max(v, 0), 4) }
            if let v = p["gamesA"] { gA = min(max(v, 0), f.gamesPerSet + 1) }
            if let v = p["gamesB"] { gB = min(max(v, 0), f.gamesPerSet + 1) }
            if inTb || inStb {
                if let v = p["tieBreakA"] { tbA = v }
                if let v = p["tieBreakB"] { tbB = v }
            }
        }

        func snapshot() -> MatchState {
            var adv: TeamId?
            if !f.goldenPoint {
                if pA == 4 && pB == 3 { adv = .a }
                if pB == 4 && pA == 3 { adv = .b }
            }
            return MatchState(
                completed: completed,
                paused: paused,
                pointsA: min(max(pA, 0), 3),
                pointsB: min(max(pB, 0), 3),
                advantage: adv,
                gamesA: gA, gamesB: gB,
                setsA: sA, setsB: sB,
                completedSets: sets,
                servingTeam: currentServer(),
                inTieBreak: inTb, inSuperTieBreak: inStb,
                tieBreakA: tbA, tieBreakB: tbB,
                freePlayA: freeA, freePlayB: freeB,
                sideChangePending: sidePending,
                winner: winner)
        }
    }
}
