import Foundation
#if canImport(RallyMateCore)
import RallyMateCore
#endif

#if canImport(WatchConnectivity) && (os(iOS) || os(watchOS))
import WatchConnectivity
#endif
#if canImport(WatchKit) && os(watchOS)
import WatchKit
import UserNotifications
#endif

public enum WatchSyncPaths {
    public static let startMatch = "/rallymate/start_match"
    public static let events = "/rallymate/events"
    public static let requestState = "/rallymate/request_state"
    public static let context = "/rallymate/context"
    public static let workoutDetectionPreferences =
        "/rallymate/workout_detection_preferences"
    /// Latest snapshot of resumable matches (application context / Data Item).
    public static let resumable = "/rallymate/resumable"
    /// Envelope carrying every application-context payload at once. A single
    /// application context slot exists per session, so independent payloads
    /// must travel together instead of overwriting each other.
    public static let contextBundle = "/rallymate/context_bundle"
    /// Durable per-match lifecycle change (transferUserInfo / Data Item).
    public static let lifecycle = "/rallymate/lifecycle"
    public static let ping = "/rallymate/ping"
    public static let testPoint = "/rallymate/test_point"
}

/// Keys used inside the application-context envelope.
public enum WatchSyncBundleKeys {
    public static let startMatch = "startMatch"
    public static let resumable = "resumable"
    public static let context = "context"
    public static let workoutDetectionPreferences = "workoutDetectionPreferences"
    public static let all = [startMatch, resumable, context, workoutDetectionPreferences]
}

/// Durable lifecycle change delivered by the phone.
public struct WatchMatchLifecycle: Equatable, Sendable {
    public var matchId: String
    public var action: String
    public var status: WatchMatchStatus
    public var stateVersion: Int
    public var idempotencyKey: String
    public var timestampMs: Int64
    public var format: MatchFormat?
    public var events: [MatchEvent]
    public var summary: WatchResumableMatch?

    public init(
        matchId: String,
        action: String,
        status: WatchMatchStatus,
        stateVersion: Int,
        idempotencyKey: String,
        timestampMs: Int64,
        format: MatchFormat?,
        events: [MatchEvent],
        summary: WatchResumableMatch?
    ) {
        self.matchId = matchId
        self.action = action
        self.status = status
        self.stateVersion = stateVersion
        self.idempotencyKey = idempotencyKey
        self.timestampMs = timestampMs
        self.format = format
        self.events = events
        self.summary = summary
    }
}

/// Decodes the wire payloads shared by both transports. Pure function so the
/// contract is unit-testable on the host.
public enum WatchSyncDecoding {
    public static func snapshot(from payload: [String: Any]) -> WatchResumableSnapshot? {
        guard payload["path"] as? String == WatchSyncPaths.resumable else {
            return nil
        }
        let matchesJson = payload["matches"] as? String ?? "[]"
        return WatchResumableSnapshot(
            stateVersion: intValue(payload["stateVersion"]) ?? 0,
            lastUpdatedAtMs: int64Value(payload["lastUpdatedAtMs"]) ?? 0,
            activeMatchId: (payload["activeMatchId"] as? String)
                .flatMap { $0.isEmpty ? nil : $0 },
            matches: WatchResumableMatch.listFromJson(matchesJson)
        )
    }

    public static func lifecycle(from payload: [String: Any]) -> WatchMatchLifecycle? {
        guard payload["path"] as? String == WatchSyncPaths.lifecycle,
              let matchId = payload["matchId"] as? String,
              !matchId.isEmpty
        else { return nil }
        let action = (payload["action"] as? String ?? "").uppercased()
        let status = WatchMatchStatus.fromWire(
            payload["status"] as? String ?? statusForAction(action)
        )
        let summary = (payload["summary"] as? String)
            .flatMap { WatchResumableMatch.listFromJson("[\($0)]").first }
        return WatchMatchLifecycle(
            matchId: matchId,
            action: action,
            status: status,
            stateVersion: intValue(payload["stateVersion"]) ?? 0,
            // A missing key must not disable dedup: fall back to a stable
            // derived key so a redelivered payload is still recognised.
            idempotencyKey: (payload["idempotencyKey"] as? String).flatMap {
                $0.isEmpty ? nil : $0
            } ?? "\(matchId)#\(action)#\(intValue(payload["stateVersion"]) ?? 0)",
            timestampMs: int64Value(payload["ts"]) ?? 0,
            format: (payload["format"] as? String).flatMap(MatchFormat.fromJsonString),
            events: MatchEvent.listFromJson(payload["events"] as? String ?? "[]"),
            summary: summary
        )
    }

    static func statusForAction(_ action: String) -> String {
        switch action {
        case "PAUSED": return WatchMatchStatus.paused.rawValue
        case "COMPLETED": return WatchMatchStatus.completed.rawValue
        case "ABANDONED": return WatchMatchStatus.abandoned.rawValue
        default: return WatchMatchStatus.inProgress.rawValue
        }
    }

    static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }

    static func int64Value(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        if let text = value as? String { return Int64(text) }
        return nil
    }
}

public struct WatchTeamVisual: Equatable, Sendable {
    public var teamName: String
    public var style: String
    public var imageVersion: Int
    public var imageExpected: Bool
    public var imageURL: URL?

    public init(
        teamName: String = "",
        style: String = "AUTO",
        imageVersion: Int = 0,
        imageExpected: Bool = false,
        imageURL: URL? = nil
    ) {
        self.teamName = teamName
        self.style = style
        self.imageVersion = imageVersion
        self.imageExpected = imageExpected
        self.imageURL = imageURL
    }
}

public struct PhoneSyncStatus: Equatable, Sendable {
    public var connected: Bool
    public var platformLabel: String

    public init(connected: Bool = false, platformLabel: String = "") {
        self.connected = connected
        self.platformLabel = platformLabel
    }
}

@inline(__always)
func isCommittedEventReply(_ reply: [String: Any]) -> Bool {
    reply["ok"] as? Bool == true
}

public protocol PhoneSyncing: AnyObject {
    var status: PhoneSyncStatus { get }
    var onStartMatch: ((String, MatchFormat, [MatchEvent], TeamId?, WatchTeamVisual) -> Void)? { get set }
    var onTeamImage: ((String, WatchTeamVisual) -> Void)? { get set }
    var onAccountContext: ((WatchAccountContext) -> Void)? { get set }
    var onAssistantCredentials: ((WatchAssistantCredentials?) -> Void)? { get set }
    var onProfileImage: ((URL?, Int) -> Void)? { get set }
    var onStatusChanged: ((PhoneSyncStatus) -> Void)? { get set }
    /// Latest snapshot of resumable matches (application context).
    var onResumableSnapshot: ((WatchResumableSnapshot) -> Void)? { get set }
    /// Durable per-match lifecycle change (queued transfer).
    var onMatchLifecycle: ((WatchMatchLifecycle) -> Void)? { get set }

    func pushEvents(
        matchId: String,
        format: MatchFormat,
        events: [MatchEvent]
    ) async -> Bool
    func requestState(matchId: String) async -> [MatchEvent]?
}

#if canImport(WatchConnectivity) && (os(iOS) || os(watchOS))
public final class PhoneSync: NSObject, PhoneSyncing {
    public private(set) var status = PhoneSyncStatus(platformLabel: "iPhone")
    /// (matchId, format, events, duoTeam): duoTeam è il team assegnato a
    /// questo watch in Duo Mode ("TEAM_A"/"TEAM_B"), nil per lo scoring
    /// classico.
    public var onStartMatch: ((String, MatchFormat, [MatchEvent], TeamId?, WatchTeamVisual) -> Void)?
    public var onTeamImage: ((String, WatchTeamVisual) -> Void)?
    public var onAccountContext: ((WatchAccountContext) -> Void)?
    public var onAssistantCredentials: ((WatchAssistantCredentials?) -> Void)?
    public var onProfileImage: ((URL?, Int) -> Void)?
    public var onStatusChanged: ((PhoneSyncStatus) -> Void)?
    public var onResumableSnapshot: ((WatchResumableSnapshot) -> Void)?
    public var onMatchLifecycle: ((WatchMatchLifecycle) -> Void)?

    private var session: WCSession?

    public override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        session = s
        s.delegate = self
        s.activate()
        updateStatus()
    }

    /// Sends the complete event log to the phone.
    ///
    /// A reachable phone gets an immediate message and acknowledgement. When it
    /// is not reachable, the payload is queued via transferUserInfo and this
    /// method returns false so the UI can keep the pending-sync state.
    public func pushEvents(
        matchId: String,
        format: MatchFormat,
        events: [MatchEvent]
    ) async -> Bool {
        let payload = eventPayload(matchId: matchId, format: format, events: events)
        guard let session else { return false }

        guard session.isReachable else {
            queue(payload)
            updateStatus()
            return false
        }

        return await withCheckedContinuation { continuation in
            session.sendMessage(
                payload,
                // A WatchConnectivity reply only proves that the phone process
                // handled the message.  The native bridge replies `ok: true`
                // only after Dart has committed the event batch (or its durable
                // phone-side queue).  Never discard the watch journal on an
                // explicit negative/malformed acknowledgement.
                replyHandler: { reply in
                    continuation.resume(returning: isCommittedEventReply(reply))
                },
                errorHandler: { [weak self] _ in
                    self?.queue(payload)
                    self?.updateStatus()
                    continuation.resume(returning: false)
                }
            )
        }
    }

    public func requestState(matchId: String) async -> [MatchEvent]? {
        guard let session, session.isReachable else { return nil }
        let payload: [String: Any] = [
            "path": WatchSyncPaths.requestState,
            "matchId": matchId,
        ]

        return await withCheckedContinuation { continuation in
            session.sendMessage(
                payload,
                replyHandler: { reply in
                    let json = reply["events"] as? String ?? "[]"
                    continuation.resume(returning: MatchEvent.listFromJson(json))
                },
                errorHandler: { _ in continuation.resume(returning: nil) }
            )
        }
    }

    private func eventPayload(
        matchId: String,
        format: MatchFormat,
        events: [MatchEvent]
    ) -> [String: Any] {
        [
            "path": WatchSyncPaths.events,
            "matchId": matchId,
            "format": format.toJsonString(),
            "events": MatchEvent.listToJson(events),
        ]
    }

    private func queue(_ payload: [String: Any]) {
        session?.transferUserInfo(payload)
    }

    private func handle(
        _ payload: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil
    ) {
        let path = payload["path"] as? String
        if path == WatchSyncPaths.contextBundle {
            // Each entry is a full payload; dispatch them independently so a
            // new context never drops a previously delivered one.
            for key in WatchSyncBundleKeys.all {
                guard let nested = payload[key] as? [String: Any] else { continue }
                handle(nested)
            }
            replyHandler?(["ok": true])
            return
        }
        if payload["assistantEnabled"] != nil {
            onAssistantCredentials?(decodeAssistantCredentials(payload))
        }
        if payload["profileImageRemoved"] as? Bool == true {
            onProfileImage?(nil, 0)
        }
        #if canImport(WatchKit) && os(watchOS)
        if path == WatchSyncPaths.ping || path == WatchSyncPaths.testPoint {
            WKInterfaceDevice.current().play(
                path == WatchSyncPaths.testPoint ? .success : .click
            )
            replyHandler?(["ok": true, "nonce": payload["nonce"] as? String ?? ""])
            return
        }
        #endif
        if let snapshot = WatchSyncDecoding.snapshot(from: payload) {
            onResumableSnapshot?(snapshot)
            replyHandler?(["ok": true])
            return
        }
        if let lifecycle = WatchSyncDecoding.lifecycle(from: payload) {
            onMatchLifecycle?(lifecycle)
            replyHandler?(["ok": true])
            return
        }
        if path == WatchSyncPaths.context {
            onAccountContext?(decodeAccountContext(payload))
            replyHandler?(["ok": true])
            return
        }
        if path == WatchSyncPaths.workoutDetectionPreferences {
            LocalMatchStore().saveWorkoutDetectionPreferences(
                decodeWorkoutDetectionPreferences(payload)
            )
            replyHandler?(["ok": true])
            return
        }
        guard path == WatchSyncPaths.startMatch,
              let matchId = payload["matchId"] as? String
        else {
            replyHandler?(["ok": false])
            return
        }

        let format = decodeFormat(payload["format"]) ?? MatchFormat()
        let eventsJson = payload["events"] as? String ?? "[]"
        let duoTeam = (payload["duoTeam"] as? String)
            .flatMap { TeamId(rawValue: $0) }
        let imageVersion = (payload["teamImageVersion"] as? NSNumber)?.intValue ?? 0
        let imageExpected = payload["teamImageExpected"] as? Bool ?? false
        let visual = WatchTeamVisual(
            teamName: payload["teamName"] as? String ?? "",
            style: payload["teamScoringStyle"] as? String ?? "AUTO",
            imageVersion: imageVersion,
            imageExpected: imageExpected,
            imageURL: imageExpected
                ? cachedTeamImageURL(matchId: matchId, version: imageVersion)
                : nil
        )
        if payload["sourceUserId"] != nil
            || payload["premiumEnabled"] != nil
            || payload["teamNames"] != nil
            || payload["defaultTeamName"] != nil {
            onAccountContext?(decodeAccountContext(payload))
        }
        onStartMatch?(
            matchId,
            format,
            MatchEvent.listFromJson(eventsJson),
            duoTeam,
            visual
        )
        // When the companion is suspended, surface a local notification so the
        // user can open the scoring UI immediately with the correct match data.
        notifyMatchReadyIfBackgrounded(matchId: matchId, teamName: visual.teamName)
        replyHandler?(["ok": true])
    }

    private func notifyMatchReadyIfBackgrounded(matchId: String, teamName: String) {
        #if canImport(WatchKit) && os(watchOS)
        let state = WKApplication.shared().applicationState
        guard state != .active else {
            WKInterfaceDevice.current().play(.notification)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Partita Padelandia"
            let label = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
            content.body = label.isEmpty
                ? "Apri per segnare i punti."
                : "\(label) pronta. Apri per segnare i punti."
            content.sound = .default
            content.userInfo = [
                "matchId": matchId,
                "path": WatchSyncPaths.startMatch,
            ]
            let request = UNNotificationRequest(
                identifier: "start_match_\(matchId)",
                content: content,
                trigger: nil
            )
            center.add(request, withCompletionHandler: nil)
        }
        #endif
    }

    private func decodeAccountContext(_ payload: [String: Any]) -> WatchAccountContext {
        let names = (payload["teamNames"] as? [String] ?? [])
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return WatchAccountContext(
            sourceUserId: payload["sourceUserId"] as? String,
            premiumEnabled: payload["premiumEnabled"] as? Bool ?? false,
            assistantEnabled: payload["assistantEnabled"] as? Bool ?? false,
            teamNames: names,
            defaultTeamName: payload["defaultTeamName"] as? String
                ?? payload["teamName"] as? String
                ?? ""
        )
    }

    private func decodeWorkoutDetectionPreferences(
        _ payload: [String: Any]
    ) -> WatchWorkoutDetectionPreferences {
        WatchWorkoutDetectionPreferences(
            mode: WatchWorkoutDetectionMode(
                rawValue: payload["mode"] as? String ?? "OFF"
            ) ?? .off,
            racketSportsOnly: payload["racketSportsOnly"] as? Bool ?? true,
            // Stored only as an explicit preference. watchOS does not expose
            // a cross-provider worn-state trigger suitable for this feature.
            onlyWhenWorn: payload["onlyWhenWorn"] as? Bool ?? false
        )
    }

    private func decodeAssistantCredentials(
        _ payload: [String: Any]
    ) -> WatchAssistantCredentials? {
        guard payload["assistantEnabled"] as? Bool == true,
              let endpointValue = payload["assistantEndpoint"] as? String,
              let endpoint = URL(string: endpointValue),
              let publishableKey = payload["assistantPublishableKey"] as? String,
              let accessToken = payload["assistantAccessToken"] as? String,
              let expiresAtMs = (payload["assistantExpiresAtMs"] as? NSNumber)?.doubleValue
        else { return nil }
        let credentials = WatchAssistantCredentials(
            endpoint: endpoint,
            publishableKey: publishableKey,
            accessToken: accessToken,
            expiresAt: Date(timeIntervalSince1970: expiresAtMs / 1_000)
        )
        return credentials.usable ? credentials : nil
    }

    private func cachedTeamImageURL(matchId: String, version: Int) -> URL? {
        guard let directory = teamImageDirectory(create: false) else { return nil }
        let url = directory.appendingPathComponent(
            "\(safeComponent(matchId))_\(max(version, 0)).jpg",
            isDirectory: false
        )
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func teamImageDirectory(create: Bool) -> URL? {
        guard let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let directory = caches.appendingPathComponent("TeamImages", isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        return directory
    }

    private func safeComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        return String(scalars).prefix(96).description
    }

    private func decodeFormat(_ value: Any?) -> MatchFormat? {
        if let json = value as? String {
            return MatchFormat.fromJsonString(json)
        }
        if let dict = value as? [String: Any],
           JSONSerialization.isValidJSONObject(dict),
           let data = try? JSONSerialization.data(withJSONObject: dict),
           let json = String(data: data, encoding: .utf8) {
            return MatchFormat.fromJsonString(json)
        }
        return nil
    }

    private func updateStatus() {
        guard let session else {
            status = PhoneSyncStatus()
            onStatusChanged?(status)
            return
        }

        status = PhoneSyncStatus(
            connected: session.activationState == .activated && session.isReachable,
            platformLabel: "iPhone"
        )
        onStatusChanged?(status)
    }
}

extension PhoneSync: WCSessionDelegate {
    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        _ = error
        updateStatus()
        guard activationState == .activated else { return }
        // The last application context may have been delivered while this app
        // was not running: read it explicitly instead of waiting for a new one.
        let context = session.receivedApplicationContext
        if !context.isEmpty { handle(context) }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        _ = session
        updateStatus()
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        _ = session
        handle(message)
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        _ = session
        handle(message, replyHandler: replyHandler)
    }

    public func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        _ = session
        handle(userInfo)
    }

    public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        _ = session
        handle(applicationContext)
    }

    public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        _ = session
        let kind = file.metadata?["kind"] as? String
        if kind == "profile_image" {
            receiveProfileImage(file)
            return
        }
        guard kind == "team_image",
              let matchId = file.metadata?["matchId"] as? String,
              let directory = teamImageDirectory(create: true)
        else { return }
        let version = (file.metadata?["version"] as? NSNumber)?.intValue ?? 0
        let style = file.metadata?["style"] as? String ?? "AUTO"
        let safeMatch = safeComponent(matchId)
        let destination = directory.appendingPathComponent(
            "\(safeMatch)_\(max(version, 0)).jpg",
            isDirectory: false
        )
        let manager = FileManager.default
        guard let values = try? file.fileURL.resourceValues(forKeys: [
            .isRegularFileKey, .fileSizeKey,
        ]),
        values.isRegularFile == true,
        let size = values.fileSize,
        size > 0,
        size <= 2 * 1024 * 1024
        else { return }

        if let entries = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) {
            for old in entries where old.lastPathComponent.hasPrefix("\(safeMatch)_") {
                try? manager.removeItem(at: old)
            }
        }
        do {
            try manager.copyItem(at: file.fileURL, to: destination)
        } catch {
            return
        }
        let visual = WatchTeamVisual(
            style: style,
            imageVersion: version,
            imageExpected: true,
            imageURL: destination
        )
        DispatchQueue.main.async { [weak self] in
            self?.onTeamImage?(matchId, visual)
        }
    }

    private func receiveProfileImage(_ file: WCSessionFile) {
        guard let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return }
        let directory = caches.appendingPathComponent("ProfileImages", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let version = (file.metadata?["version"] as? NSNumber)?.intValue ?? 0
        let destination = directory.appendingPathComponent(
            "avatar_\(max(version, 0)).jpg",
            isDirectory: false
        )
        guard let values = try? file.fileURL.resourceValues(forKeys: [
            .isRegularFileKey, .fileSizeKey,
        ]),
        values.isRegularFile == true,
        let size = values.fileSize,
        size > 0,
        size <= 2 * 1024 * 1024
        else { return }
        let manager = FileManager.default
        if let entries = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) {
            for old in entries { try? manager.removeItem(at: old) }
        }
        do {
            try manager.copyItem(at: file.fileURL, to: destination)
        } catch {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onProfileImage?(destination, version)
        }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        _ = session
        updateStatus()
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        updateStatus()
    }
    #endif
}
#else
public final class PhoneSync: PhoneSyncing {
    public private(set) var status = PhoneSyncStatus()
    public var onStartMatch: ((String, MatchFormat, [MatchEvent], TeamId?, WatchTeamVisual) -> Void)?
    public var onTeamImage: ((String, WatchTeamVisual) -> Void)?
    public var onAccountContext: ((WatchAccountContext) -> Void)?
    public var onAssistantCredentials: ((WatchAssistantCredentials?) -> Void)?
    public var onProfileImage: ((URL?, Int) -> Void)?
    public var onStatusChanged: ((PhoneSyncStatus) -> Void)?
    public var onResumableSnapshot: ((WatchResumableSnapshot) -> Void)?
    public var onMatchLifecycle: ((WatchMatchLifecycle) -> Void)?

    public init() {}

    public func pushEvents(
        matchId: String,
        format: MatchFormat,
        events: [MatchEvent]
    ) async -> Bool {
        _ = matchId
        _ = format
        _ = events
        return false
    }

    public func requestState(matchId: String) async -> [MatchEvent]? {
        _ = matchId
        return nil
    }
}
#endif
