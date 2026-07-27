import Foundation
#if canImport(MomentumCore)
import MomentumCore
#endif

public struct WatchAccountContext: Codable, Equatable, Sendable {
    public var sourceUserId: String?
    public var premiumEnabled: Bool
    public var assistantEnabled: Bool
    public var teamNames: [String]
    public var defaultTeamName: String

    public init(
        sourceUserId: String? = nil,
        premiumEnabled: Bool = false,
        assistantEnabled: Bool = false,
        teamNames: [String] = [],
        defaultTeamName: String = ""
    ) {
        self.sourceUserId = sourceUserId
        self.premiumEnabled = premiumEnabled
        self.assistantEnabled = assistantEnabled
        self.teamNames = Array(teamNames.prefix(12))
        self.defaultTeamName = defaultTeamName
    }

    private enum CodingKeys: String, CodingKey {
        case sourceUserId
        case premiumEnabled
        case assistantEnabled
        case teamNames
        case defaultTeamName
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sourceUserId = try values.decodeIfPresent(String.self, forKey: .sourceUserId)
        premiumEnabled = try values.decodeIfPresent(Bool.self, forKey: .premiumEnabled) ?? false
        assistantEnabled = try values.decodeIfPresent(Bool.self, forKey: .assistantEnabled) ?? false
        teamNames = Array(
            (try values.decodeIfPresent([String].self, forKey: .teamNames) ?? []).prefix(12)
        )
        defaultTeamName = try values.decodeIfPresent(String.self, forKey: .defaultTeamName) ?? ""
    }
}

public enum WatchWorkoutDetectionMode: String, Codable, Sendable {
    case off = "OFF"
    case ask = "ASK"
    case quickStart = "QUICK_START"
}

public struct WatchWorkoutDetectionPreferences: Codable, Equatable, Sendable {
    public var mode: WatchWorkoutDetectionMode
    public var racketSportsOnly: Bool
    public var onlyWhenWorn: Bool

    public init(
        mode: WatchWorkoutDetectionMode = .off,
        racketSportsOnly: Bool = true,
        onlyWhenWorn: Bool = false
    ) {
        self.mode = mode
        self.racketSportsOnly = racketSportsOnly
        self.onlyWhenWorn = onlyWhenWorn
    }
}

/// Crash-safe, offline-first storage for the active watch match.
///
/// The watch keeps the full event log locally before attempting sync. This
/// mirrors the Wear OS SharedPreferences store and satisfies the PRD recovery
/// requirement when phone and watch temporarily lose connection.
public final class LocalMatchStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func saveMatch(
        matchId: String,
        format: MatchFormat,
        events: [MatchEvent]
    ) {
        saveJournal(matchId: matchId, format: format, events: events)
        defaults.set(matchId, forKey: Keys.activeMatchId)
    }

    /// Stores the journal of any match **without** making it the active one.
    /// Used for background updates about other matches (a pause that happened
    /// on the phone must never hijack the match being played here).
    public func saveJournal(
        matchId: String,
        format: MatchFormat,
        events: [MatchEvent]
    ) {
        guard !matchId.isEmpty else { return }
        let syncedIds = Set(loadEvents(matchId).filter(\.synced).map(\.eventId))
        let merged = events.map { event in
            event.synced || syncedIds.contains(event.eventId)
                ? event.copy(synced: true)
                : event
        }
        defaults.set(format.toJsonString(), forKey: Keys.format(matchId))
        defaults.set(MatchEvent.listToJson(merged), forKey: Keys.events(matchId))
        var known = Set(defaults.stringArray(forKey: Keys.knownMatchIds) ?? [])
        known.insert(matchId)
        defaults.set(Array(known).sorted(), forKey: Keys.knownMatchIds)
    }

    public func activeMatchId() -> String? {
        defaults.string(forKey: Keys.activeMatchId)
    }

    public func setActiveMatch(_ matchId: String) {
        defaults.set(matchId, forKey: Keys.activeMatchId)
    }

    public func saveLastFormat(_ format: MatchFormat) {
        defaults.set(format.toJsonString(), forKey: Keys.lastFormat)
    }

    public func loadLastFormat() -> MatchFormat {
        defaults.string(forKey: Keys.lastFormat)
            .flatMap(MatchFormat.fromJsonString) ?? .goldenPointBo3
    }

    /// Bridges an explicit App Intent/Siri/Action Button request into the
    /// foreground watch UI without starting a workout in the background.
    public func requestSystemQuickStart(format: MatchFormat) {
        defaults.set(format.toJsonString(), forKey: Keys.systemQuickStartFormat)
    }

    public func consumeSystemQuickStart() -> MatchFormat? {
        guard let json = defaults.string(forKey: Keys.systemQuickStartFormat)
        else { return nil }
        defaults.removeObject(forKey: Keys.systemQuickStartFormat)
        return MatchFormat.fromJsonString(json)
    }

    public func savePlayerRole(_ role: String) {
        defaults.set(role, forKey: Keys.playerRole)
    }

    public func loadPlayerRole() -> String {
        defaults.string(forKey: Keys.playerRole) ?? "FLEX"
    }

    public func saveAccountContext(_ context: WatchAccountContext) {
        guard let data = try? JSONEncoder().encode(context) else { return }
        guard defaults.data(forKey: Keys.accountContext) != data else { return }
        defaults.set(data, forKey: Keys.accountContext)
    }

    public func loadAccountContext() -> WatchAccountContext {
        guard let data = defaults.data(forKey: Keys.accountContext),
              let context = try? JSONDecoder().decode(
                WatchAccountContext.self,
                from: data
              )
        else { return WatchAccountContext() }
        return context
    }

    public func saveWorkoutDetectionPreferences(
        _ preferences: WatchWorkoutDetectionPreferences
    ) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Keys.workoutDetectionPreferences)
    }

    public func loadWorkoutDetectionPreferences()
        -> WatchWorkoutDetectionPreferences {
        guard let data = defaults.data(forKey: Keys.workoutDetectionPreferences),
              let preferences = try? JSONDecoder().decode(
                WatchWorkoutDetectionPreferences.self,
                from: data
              )
        else { return WatchWorkoutDetectionPreferences() }
        return preferences
    }

    public func saveProfileImage(url: URL?, version: Int) {
        if let url {
            defaults.set(url.path, forKey: Keys.profileImagePath)
            defaults.set(max(version, 0), forKey: Keys.profileImageVersion)
        } else {
            defaults.removeObject(forKey: Keys.profileImagePath)
            defaults.removeObject(forKey: Keys.profileImageVersion)
        }
    }

    public func loadProfileImage() -> (url: URL, version: Int)? {
        guard let path = defaults.string(forKey: Keys.profileImagePath),
              FileManager.default.fileExists(atPath: path)
        else { return nil }
        return (
            URL(fileURLWithPath: path),
            defaults.integer(forKey: Keys.profileImageVersion)
        )
    }

    /// Keeps a paused/abandoned match recoverable without presenting it as an
    /// active workout every time the app opens.
    public func markIncomplete(_ matchId: String) {
        defaults.set(matchId, forKey: Keys.lastIncompleteMatchId)
        clearActive(expected: matchId)
    }

    public func lastIncompleteMatchId() -> String? {
        defaults.string(forKey: Keys.lastIncompleteMatchId)
    }

    public func clearIncomplete(expected matchId: String? = nil) {
        if let matchId,
           defaults.string(forKey: Keys.lastIncompleteMatchId) != matchId {
            return
        }
        defaults.removeObject(forKey: Keys.lastIncompleteMatchId)
    }

    /// Duo Mode: team assegnato a questo watch per la partita (o nil).
    /// Serving rotation of the match (FIP Rule 4), pushed by the phone.
    /// Stored per match so a resume after a relaunch keeps attributing holds
    /// and breaks to the right pair.
    public func saveFirstServer(_ matchId: String, team: TeamId) {
        defaults.set(team.rawValue, forKey: Keys.firstServer(matchId))
    }

    public func loadFirstServer(_ matchId: String) -> TeamId {
        defaults.string(forKey: Keys.firstServer(matchId))
            .flatMap { TeamId(rawValue: $0) } ?? .a
    }

    public func saveDuoTeam(_ matchId: String, team: TeamId?) {
        if let team {
            defaults.set(team.rawValue, forKey: Keys.duoTeam(matchId))
        } else {
            defaults.removeObject(forKey: Keys.duoTeam(matchId))
        }
    }

    public func loadDuoTeam(_ matchId: String) -> TeamId? {
        defaults.string(forKey: Keys.duoTeam(matchId))
            .flatMap { TeamId(rawValue: $0) }
    }

    public func saveTeamVisual(_ matchId: String, visual: WatchTeamVisual) {
        var value: [String: Any] = [
            "teamName": visual.teamName,
            "style": visual.style,
            "imageVersion": visual.imageVersion,
            "imageExpected": visual.imageExpected,
        ]
        if let path = visual.imageURL?.path {
            value["imagePath"] = path
        }
        defaults.set(value, forKey: Keys.teamVisual(matchId))
    }

    public func loadTeamVisual(_ matchId: String) -> WatchTeamVisual {
        guard let value = defaults.dictionary(forKey: Keys.teamVisual(matchId))
        else { return WatchTeamVisual() }
        let path = value["imagePath"] as? String
        let url = path.flatMap { candidate -> URL? in
            FileManager.default.fileExists(atPath: candidate)
                ? URL(fileURLWithPath: candidate)
                : nil
        }
        return WatchTeamVisual(
            teamName: value["teamName"] as? String ?? "",
            style: value["style"] as? String ?? "AUTO",
            imageVersion: value["imageVersion"] as? Int ?? 0,
            imageExpected: value["imageExpected"] as? Bool ?? false,
            imageURL: url
        )
    }

    public func setWorkoutActive(_ matchId: String, active: Bool) {
        let key = Keys.workoutActive(matchId)
        if defaults.object(forKey: key) != nil,
           defaults.bool(forKey: key) == active {
            return
        }
        defaults.set(active, forKey: key)
    }

    public func isWorkoutActive(_ matchId: String) -> Bool {
        defaults.bool(forKey: Keys.workoutActive(matchId))
    }

    /// Match whose HealthKit session still needs recovery/finalisation.
    ///
    /// This is intentionally separate from `activeMatchId`: the UI may return
    /// home as soon as a terminal lifecycle arrives, while HealthKit is still
    /// asynchronously moving from paused -> running -> ended.
    public func setWorkoutRecoveryMatch(_ matchId: String) {
        guard !matchId.isEmpty else { return }
        defaults.set(matchId, forKey: Keys.workoutRecoveryMatchId)
    }

    public func workoutRecoveryMatchId() -> String? {
        defaults.string(forKey: Keys.workoutRecoveryMatchId)
    }

    public func clearWorkoutRecoveryMatch(expected matchId: String? = nil) {
        if let matchId,
           defaults.string(forKey: Keys.workoutRecoveryMatchId) != matchId {
            return
        }
        defaults.removeObject(forKey: Keys.workoutRecoveryMatchId)
    }

    // MARK: - Resumable matches (phone ⇄ watch snapshot)

    /// Latest snapshot of matches the user may resume, merged with what the
    /// watch already knew. Survives relaunch so the list is available offline
    /// and before any phone contact.
    @discardableResult
    public func mergeResumableSnapshot(
        _ incoming: WatchResumableSnapshot
    ) -> WatchResumableSnapshot {
        let merged = loadResumableSnapshot().merging(
            incoming,
            protectedMatchIds: Set(pendingLocalMatchIds())
        )
        saveResumableSnapshot(merged)
        if let incomplete = lastIncompleteMatchId(),
           merged.match(incomplete) == nil,
           pendingLocalSyncCount(incomplete) == 0 {
            clearIncomplete(expected: incomplete)
        }
        return merged
    }

    /// Orders queued lifecycle transfers against scoped authoritative
    /// snapshots. Legacy unversioned transfers remain compatible only until a
    /// versioned phone authority has been observed for that scope.
    public func acceptLifecycleAuthority(
        source: String?,
        scope: WatchSnapshotAuthorityScope?,
        version: Int64
    ) -> Bool {
        let current = loadResumableSnapshot()
        guard let accepted = current.acceptingLifecycleAuthority(
            source: source,
            scope: scope,
            version: version
        ) else { return false }
        if accepted != current { saveResumableSnapshot(accepted) }
        return true
    }

    public func saveResumableSnapshot(_ snapshot: WatchResumableSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        guard defaults.data(forKey: Keys.resumableSnapshot) != data else { return }
        defaults.set(data, forKey: Keys.resumableSnapshot)
    }

    public func loadResumableSnapshot() -> WatchResumableSnapshot {
        guard let data = defaults.data(forKey: Keys.resumableSnapshot),
              let snapshot = try? JSONDecoder().decode(
                WatchResumableSnapshot.self,
                from: data
              )
        else { return .empty }
        return snapshot
    }

    /// Records a locally produced status change so the watch list stays correct
    /// even with no phone contact at all.
    @discardableResult
    public func applyLocalMatchUpdate(
        _ update: WatchResumableMatch
    ) -> WatchResumableSnapshot {
        let current = loadResumableSnapshot()
        // Preserve PHONE ownership while a local Apple Watch tail is pending.
        // Once acknowledged, a later authoritative clear may remove the row
        // instead of retaining a permanent APPLE_WATCH orphan.
        var ownedUpdate = update
        if current.match(update.matchId)?.sourceDevice == "PHONE" {
            ownedUpdate.sourceDevice = "PHONE"
        }
        let merged = current.applying(ownedUpdate)
        saveResumableSnapshot(merged)
        return merged
    }

    /// Monotonic per-match version used to reject stale updates.
    public func stateVersion(_ matchId: String) -> Int {
        defaults.integer(forKey: Keys.stateVersion(matchId))
    }

    public func saveStateVersion(_ matchId: String, version: Int) {
        guard !matchId.isEmpty else { return }
        // Never let an older version overwrite a newer one.
        guard version > stateVersion(matchId) else { return }
        defaults.set(version, forKey: Keys.stateVersion(matchId))
    }

    @discardableResult
    public func bumpStateVersion(_ matchId: String) -> Int {
        guard !matchId.isEmpty else { return 0 }
        let next = stateVersion(matchId) + 1
        defaults.set(next, forKey: Keys.stateVersion(matchId))
        return next
    }

    /// Idempotency guard for lifecycle payloads: WatchConnectivity and the Wear
    /// Data Layer can both redeliver the same message.
    /// - Returns: true the first time a key is seen, false on redelivery.
    public func markLifecycleApplied(_ key: String, limit: Int = 64) -> Bool {
        guard !key.isEmpty else { return true }
        var seen = defaults.stringArray(forKey: Keys.appliedLifecycleKeys) ?? []
        guard !seen.contains(key) else { return false }
        seen.append(key)
        if seen.count > limit { seen.removeFirst(seen.count - limit) }
        defaults.set(seen, forKey: Keys.appliedLifecycleKeys)
        return true
    }

    // MARK: - Health recording ownership

    /// Preference chosen on the New match screen. Sticky across matches but
    /// always editable before starting the next one.
    public func saveDefaultHealthRecordingMode(_ mode: WatchHealthRecordingMode) {
        defaults.set(mode.rawValue, forKey: Keys.defaultHealthRecordingMode)
    }

    public func loadDefaultHealthRecordingMode() -> WatchHealthRecordingMode {
        defaults.string(forKey: Keys.defaultHealthRecordingMode)
            .flatMap(WatchHealthRecordingMode.init(rawValue:))
            ?? .rallyMateManaged
    }

    /// Mode frozen for one match: changing the default later must never change
    /// the owner of a recording already in progress.
    public func saveHealthRecordingMode(
        _ matchId: String,
        mode: WatchHealthRecordingMode
    ) {
        guard !matchId.isEmpty else { return }
        defaults.set(mode.rawValue, forKey: Keys.healthRecordingMode(matchId))
    }

    public func loadHealthRecordingMode(_ matchId: String) -> WatchHealthRecordingMode? {
        defaults.string(forKey: Keys.healthRecordingMode(matchId))
            .flatMap(WatchHealthRecordingMode.init(rawValue:))
    }

    public func saveWorkoutSegments(
        _ matchId: String,
        segments: [WatchWorkoutSegment]
    ) {
        guard !matchId.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(segments) else { return }
        guard defaults.data(forKey: Keys.workoutSegments(matchId)) != data else {
            return
        }
        defaults.set(data, forKey: Keys.workoutSegments(matchId))
    }

    public func loadWorkoutSegments(_ matchId: String) -> [WatchWorkoutSegment] {
        guard let data = defaults.data(forKey: Keys.workoutSegments(matchId)),
              let segments = try? JSONDecoder().decode(
                [WatchWorkoutSegment].self,
                from: data
              )
        else { return [] }
        return segments
    }

    public func saveRecordingState(_ matchId: String, state: WatchRecordingState) {
        guard !matchId.isEmpty else { return }
        defaults.set(state.rawValue, forKey: Keys.recordingState(matchId))
    }

    public func loadRecordingState(_ matchId: String) -> WatchRecordingState? {
        defaults.string(forKey: Keys.recordingState(matchId))
            .flatMap(WatchRecordingState.init(rawValue:))
    }

    public func loadFormat(_ matchId: String) -> MatchFormat? {
        defaults.string(forKey: Keys.format(matchId))
            .flatMap(MatchFormat.fromJsonString)
    }

    public func loadEvents(_ matchId: String) -> [MatchEvent] {
        guard let json = defaults.string(forKey: Keys.events(matchId)) else {
            return []
        }
        return MatchEvent.listFromJson(json)
    }

    public func pendingSyncCount(_ matchId: String) -> Int {
        loadEvents(matchId).filter { !$0.synced }.count
    }

    /// Unsynced tail authored on this watch, excluding phone-originated rows.
    public func pendingLocalSyncCount(_ matchId: String) -> Int {
        loadEvents(matchId).filter {
            !$0.synced && $0.sourceDevice == "APPLE_WATCH"
        }.count
    }

    /// Every match this watch has ever stored a journal for.
    public func knownMatchIds() -> [String] {
        defaults.stringArray(forKey: Keys.knownMatchIds) ?? []
    }

    public func pendingMatchIds() -> [String] {
        (defaults.stringArray(forKey: Keys.knownMatchIds) ?? [])
            .filter { pendingSyncCount($0) > 0 && loadFormat($0) != nil }
    }

    public func pendingLocalMatchIds() -> [String] {
        (defaults.stringArray(forKey: Keys.knownMatchIds) ?? [])
            .filter { pendingLocalSyncCount($0) > 0 && loadFormat($0) != nil }
    }

    public func markSynced(_ matchId: String, eventIds: Set<String>) {
        guard !eventIds.isEmpty else { return }
        var changed = false
        let updated = loadEvents(matchId).map { event in
            if eventIds.contains(event.eventId), !event.synced { changed = true }
            return eventIds.contains(event.eventId) ? event.copy(synced: true) : event
        }
        guard changed else { return }
        defaults.set(MatchEvent.listToJson(updated), forKey: Keys.events(matchId))
    }

    public func clearActive(expected matchId: String? = nil) {
        if let matchId,
           defaults.string(forKey: Keys.activeMatchId) != matchId {
            return
        }
        defaults.removeObject(forKey: Keys.activeMatchId)
    }
}

private enum Keys {
    static let activeMatchId = "active_match_id"
    static let lastIncompleteMatchId = "last_incomplete_match_id"
    static let lastFormat = "last_match_format"
    static let systemQuickStartFormat = "system_quick_start_format"
    static let playerRole = "last_player_role"
    static let accountContext = "watch_account_context"
    static let workoutDetectionPreferences =
        "watch_workout_detection_preferences"
    static let profileImagePath = "watch_profile_image_path"
    static let profileImageVersion = "watch_profile_image_version"
    static let knownMatchIds = "known_match_ids"
    static let defaultHealthRecordingMode = "health_recording_mode_default"
    static let workoutRecoveryMatchId = "workout_recovery_match_id"
    static let resumableSnapshot = "resumable_matches_snapshot"
    static let appliedLifecycleKeys = "applied_lifecycle_keys"

    static func stateVersion(_ matchId: String) -> String {
        "state_version_\(matchId)"
    }

    static func healthRecordingMode(_ matchId: String) -> String {
        "health_recording_mode_\(matchId)"
    }

    static func workoutSegments(_ matchId: String) -> String {
        "workout_segments_\(matchId)"
    }

    static func recordingState(_ matchId: String) -> String {
        "recording_state_\(matchId)"
    }

    static func format(_ matchId: String) -> String {
        "format_\(matchId)"
    }

    static func events(_ matchId: String) -> String {
        "events_\(matchId)"
    }

    static func duoTeam(_ matchId: String) -> String {
        "duo_team_\(matchId)"
    }

    static func firstServer(_ matchId: String) -> String {
        "first_server_\(matchId)"
    }

    static func workoutActive(_ matchId: String) -> String {
        "workout_active_\(matchId)"
    }

    static func teamVisual(_ matchId: String) -> String {
        "team_visual_\(matchId)"
    }
}
