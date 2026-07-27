import Foundation
#if canImport(MomentumCore)
import MomentumCore
#endif

/// Lifecycle status shared with the phone. Mirrors `MatchStatus` in
/// `rally_core`, so a paused match is a persistent, synchronised resource and
/// not a value that only lives in the mobile app's memory.
public enum WatchMatchStatus: String, Codable, Sendable, Equatable {
    case created = "CREATED"
    case inProgress = "IN_PROGRESS"
    case paused = "PAUSED"
    case completed = "COMPLETED"
    case abandoned = "ABANDONED"

    public var isResumable: Bool {
        self == .inProgress || self == .paused || self == .created
    }

    public var isTerminal: Bool { self == .completed || self == .abandoned }

    public static func fromWire(_ value: String?) -> WatchMatchStatus {
        guard let value, let status = WatchMatchStatus(rawValue: value) else {
            return .inProgress
        }
        return status
    }
}

/// One entry of the resumable-match snapshot pushed by the phone.
///
/// Carries only what the watch needs to *show* the match; the event journal is
/// delivered separately (durably) so a resume works offline.
public struct WatchResumableMatch: Codable, Equatable, Sendable, Identifiable {
    public var matchId: String
    public var status: WatchMatchStatus
    /// Monotonic per match. A lower version never overwrites a higher one.
    public var stateVersion: Int
    public var updatedAtMs: Int64
    public var pausedAtMs: Int64?
    public var teamLabel: String
    public var scoreLine: String
    public var setsLabel: String
    public var gamesLabel: String
    public var format: MatchFormat
    public var sourceDevice: String
    public var eventCount: Int
    /// True when the phone attached the full journal, so the watch can resume
    /// and keep scoring with no connection at all.
    public var journalAvailable: Bool

    public var id: String { matchId }

    public init(
        matchId: String,
        status: WatchMatchStatus,
        stateVersion: Int = 0,
        updatedAtMs: Int64 = 0,
        pausedAtMs: Int64? = nil,
        teamLabel: String = "",
        scoreLine: String = "",
        setsLabel: String = "",
        gamesLabel: String = "",
        format: MatchFormat = MatchFormat(),
        sourceDevice: String = "PHONE",
        eventCount: Int = 0,
        journalAvailable: Bool = false
    ) {
        self.matchId = matchId
        self.status = status
        self.stateVersion = stateVersion
        self.updatedAtMs = updatedAtMs
        self.pausedAtMs = pausedAtMs
        self.teamLabel = teamLabel
        self.scoreLine = scoreLine
        self.setsLabel = setsLabel
        self.gamesLabel = gamesLabel
        self.format = format
        self.sourceDevice = sourceDevice
        self.eventCount = eventCount
        self.journalAvailable = journalAvailable
    }

    public var updatedAt: Date {
        Date(timeIntervalSince1970: Double(updatedAtMs) / 1000)
    }

    public var pausedAt: Date? {
        pausedAtMs.map { Date(timeIntervalSince1970: Double($0) / 1000) }
    }

    /// "Sospesa il 25 luglio alle 19:42" / "Attiva · 19:42".
    public var subtitle: String {
        let reference = pausedAt ?? updatedAt
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        let sameDay = Calendar.current.isDateInToday(reference)
        formatter.dateFormat = sameDay ? "HH:mm" : "d MMMM 'alle' HH:mm"
        let stamp = formatter.string(from: reference)
        switch status {
        case .paused: return sameDay ? "Sospesa alle \(stamp)" : "Sospesa il \(stamp)"
        case .completed: return "Terminata"
        case .abandoned: return "Archiviata"
        default: return sameDay ? "Attiva · \(stamp)" : "Attiva dal \(stamp)"
        }
    }

    public var scoreSummary: String {
        let sets = setsLabel.isEmpty ? "" : "Set \(setsLabel)"
        let games = gamesLabel.isEmpty ? "" : "Game \(gamesLabel)"
        return [sets, games, scoreLine]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    public static func listFromJson(_ json: String) -> [WatchResumableMatch] {
        guard let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode([WatchResumableMatch].self, from: data)
        else { return [] }
        return list
    }

    public static func listToJson(_ list: [WatchResumableMatch]) -> String {
        guard let data = try? JSONEncoder().encode(list) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }
}

public enum WatchSnapshotAuthorityScope: String, Codable, Sendable {
    case nonStarPoint = "NON_STAR_POINT"
    case starPoint = "STAR_POINT"

    public func owns(_ match: WatchResumableMatch) -> Bool {
        (match.format.gameScoringMode == .starPoint) == (self == .starPoint)
    }
}

/// The whole snapshot the phone publishes through the "latest state" channel
/// (`updateApplicationContext` on iOS, a Data Item on Wear OS).
public struct WatchResumableSnapshot: Codable, Equatable, Sendable {
    public var stateVersion: Int
    public var lastUpdatedAtMs: Int64
    public var activeMatchId: String?
    public var matches: [WatchResumableMatch]
    public var authoritative: Bool?
    public var authoritySource: String?
    public var authorityScope: String?
    public var authorityVersion: Int64?
    /// Last accepted authoritative generation for every independent scope.
    /// Optional for backward-compatible decoding of snapshots persisted by v1.
    public var authorityVersions: [String: Int64]?

    public init(
        stateVersion: Int = 0,
        lastUpdatedAtMs: Int64 = 0,
        activeMatchId: String? = nil,
        matches: [WatchResumableMatch] = [],
        authoritative: Bool? = nil,
        authoritySource: String? = nil,
        authorityScope: String? = nil,
        authorityVersion: Int64? = nil,
        authorityVersions: [String: Int64]? = nil
    ) {
        self.stateVersion = stateVersion
        self.lastUpdatedAtMs = lastUpdatedAtMs
        self.activeMatchId = activeMatchId
        self.matches = matches
        self.authoritative = authoritative
        self.authoritySource = authoritySource
        self.authorityScope = authorityScope
        self.authorityVersion = authorityVersion
        self.authorityVersions = authorityVersions
    }

    public static let empty = WatchResumableSnapshot()

    public func match(_ matchId: String) -> WatchResumableMatch? {
        matches.first { $0.matchId == matchId }
    }

    /// Merge rules (deterministic, no clock comparison between devices):
    /// - a terminal status always wins over a resumable one;
    /// - otherwise the higher `stateVersion` wins;
    /// - equal versions keep the most recently updated entry.
    public func merging(
        _ incoming: WatchResumableSnapshot,
        protectedMatchIds: Set<String> = []
    ) -> WatchResumableSnapshot {
        let declaresAuthority = incoming.authoritative == true
            || incoming.authoritySource != nil
            || incoming.authorityScope != nil
            || (incoming.authorityVersion ?? 0) > 0
        let incomingScope = incoming.authoritative == true
            && incoming.authoritySource == "PHONE"
            && (incoming.authorityVersion ?? 0) > 0
            ? incoming.authorityScope.flatMap(WatchSnapshotAuthorityScope.init(rawValue:))
            : nil
        // Partial or unknown authority metadata must not silently fall back to
        // legacy additive merge semantics.
        if declaresAuthority, incomingScope == nil { return self }
        var knownAuthorityVersions = authorityVersions ?? [:]
        let knownGlobalVersion = (authorityVersions ?? [:]).values.max() ?? 0
        if let incomingScope {
            let knownVersion = knownAuthorityVersions[incomingScope.rawValue] ?? 0
            guard (incoming.authorityVersion ?? 0) >= knownVersion else {
                // Reconnect delivery can be out of order. An older snapshot
                // must never resurrect a match removed by a newer clear.
                return self
            }
        }

        var byId: [String: WatchResumableMatch] = [:]
        for match in matches { byId[match.matchId] = match }
        if let incomingScope {
            let incomingIds = Set(
                incoming.matches
                    .filter(incomingScope.owns)
                    .map(\.matchId)
            )
            byId = byId.filter { matchId, match in
                !(match.sourceDevice == "PHONE"
                    && incomingScope.owns(match)
                    && !incomingIds.contains(matchId)
                    && !protectedMatchIds.contains(matchId))
            }
            knownAuthorityVersions[incomingScope.rawValue] =
                incoming.authorityVersion ?? 0
        }
        let incomingMatches = if let incomingScope {
            incoming.matches.filter(incomingScope.owns)
        } else {
            incoming.matches
        }
        for match in incomingMatches {
            guard let existing = byId[match.matchId] else {
                byId[match.matchId] = match
                continue
            }
            byId[match.matchId] = WatchResumableSnapshot.winner(existing, match)
        }
        let merged = byId.values.sorted { lhs, rhs in
            lhs.updatedAtMs > rhs.updatedAtMs
        }
        let newerIncoming = incoming.stateVersion >= stateVersion
        let mergedActiveMatchId: String?
        if let incomingScope {
            let incomingActive = incoming.activeMatchId.flatMap { activeId in
                incoming.matches.first {
                    $0.matchId == activeId && incomingScope.owns($0)
                }?.matchId
            }
            let currentActiveOwned = activeMatchId.flatMap { activeId in
                matches.first { $0.matchId == activeId }
            }.map(incomingScope.owns) == true
            if let incomingActive,
               (incoming.authorityVersion ?? 0) >= knownGlobalVersion {
                mergedActiveMatchId = incomingActive
            } else if currentActiveOwned,
                      let activeMatchId,
                      !protectedMatchIds.contains(activeMatchId) {
                mergedActiveMatchId = nil
            } else if let activeMatchId, byId[activeMatchId] != nil {
                mergedActiveMatchId = activeMatchId
            } else {
                mergedActiveMatchId = nil
            }
        } else {
            mergedActiveMatchId = newerIncoming
                ? incoming.activeMatchId
                : activeMatchId
        }
        return WatchResumableSnapshot(
            stateVersion: max(stateVersion, incoming.stateVersion),
            lastUpdatedAtMs: max(lastUpdatedAtMs, incoming.lastUpdatedAtMs),
            activeMatchId: mergedActiveMatchId,
            matches: merged,
            authoritative: incoming.authoritative,
            authoritySource: incoming.authoritySource,
            authorityScope: incoming.authorityScope,
            authorityVersion: incoming.authorityVersion,
            authorityVersions: knownAuthorityVersions
        )
    }

    static func winner(
        _ existing: WatchResumableMatch,
        _ incoming: WatchResumableMatch
    ) -> WatchResumableMatch {
        // COMPLETED/ABANDONED prevails over PAUSED and IN_PROGRESS.
        if existing.status.isTerminal, !incoming.status.isTerminal {
            return existing
        }
        if incoming.status.isTerminal, !existing.status.isTerminal {
            return incoming
        }
        if incoming.stateVersion > existing.stateVersion { return incoming }
        if incoming.stateVersion < existing.stateVersion { return existing }
        return incoming.updatedAtMs >= existing.updatedAtMs ? incoming : existing
    }

    /// Applies one match update, dropping stale versions.
    public func applying(_ update: WatchResumableMatch) -> WatchResumableSnapshot {
        merging(
            WatchResumableSnapshot(
                stateVersion: stateVersion,
                lastUpdatedAtMs: update.updatedAtMs,
                activeMatchId: activeMatchId,
                matches: [update]
            )
        )
    }

    /// Records a lifecycle generation without applying snapshot absence rules.
    /// Nil means a delayed lifecycle is older than the authoritative snapshot
    /// already accepted for the same scoring scope.
    public func acceptingLifecycleAuthority(
        source: String?,
        scope: WatchSnapshotAuthorityScope?,
        version: Int64
    ) -> WatchResumableSnapshot? {
        guard let scope else {
            return source == nil && version <= 0 ? self : nil
        }
        let known = authorityVersions?[scope.rawValue] ?? 0
        if source == nil, version <= 0 {
            return known == 0 ? self : nil
        }
        guard source == "PHONE", version > 0, version >= known else {
            return nil
        }
        guard version > known else { return self }
        var updated = self
        var versions = authorityVersions ?? [:]
        versions[scope.rawValue] = version
        updated.authorityVersions = versions
        return updated
    }

    /// Entries the watch may offer for resume, most recent first.
    public var resumable: [WatchResumableMatch] {
        matches
            .filter { $0.status.isResumable }
            .sorted { $0.updatedAtMs > $1.updatedAtMs }
    }
}
