import Flutter
import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

private enum RallyMateWatchPath {
    static let startMatch = "/rallymate/start_match"
    static let events = "/rallymate/events"
    static let requestState = "/rallymate/request_state"
    static let context = "/rallymate/context"
    static let workoutDetectionPreferences =
        "/rallymate/workout_detection_preferences"
    /// Latest snapshot of resumable (ACTIVE + PAUSED) matches.
    static let resumable = "/rallymate/resumable"
    /// Durable per-match lifecycle change, journal attached.
    static let lifecycle = "/rallymate/lifecycle"
    /// Envelope for the single application-context slot.
    static let contextBundle = "/rallymate/context_bundle"
    static let ping = "/rallymate/ping"
    static let testPoint = "/rallymate/test_point"
}

/// Keys inside the application-context envelope. WatchConnectivity keeps one
/// application context per session, so every payload that must survive as
/// "latest state" travels together instead of overwriting the previous one.
enum RallyMateContextKey {
    static let startMatch = "startMatch"
    static let startMatchTerminal = "startMatchTerminal"
    static let resumable = "resumable"
    static let context = "context"
    static let workoutDetectionPreferences = "workoutDetectionPreferences"
    static let all = [
        startMatch,
        startMatchTerminal,
        resumable,
        context,
        workoutDetectionPreferences,
    ]
}

/// Pure application-context rules used by the bridge and native tests.
///
/// WCSession retains the previous application context across phone-app
/// relaunches. Hydrating from that value prevents a later partial update from
/// dropping keys, while removing a terminal match prevents a stale start
/// command from reopening it on the Watch.
enum RallyMateContextBundlePolicy {
    static func merged(
        inMemory: [String: Any],
        persisted: [String: Any]
    ) -> [String: Any] {
        var merged: [String: Any] = [:]
        for key in RallyMateContextKey.all {
            if let value = persisted[key] { merged[key] = value }
            if let value = inMemory[key] { merged[key] = value }
        }
        return reconcilingStartTombstone(in: merged)
    }

    static func terminatingStartMatch(
        matching matchId: String,
        stateVersion: Int,
        timestampMs: Int64,
        from bundle: [String: Any]
    ) -> [String: Any] {
        var updated = bundle
        updated[RallyMateContextKey.startMatchTerminal] = [
            "matchId": matchId,
            "stateVersion": stateVersion,
            "ts": timestampMs,
        ]
        return reconcilingStartTombstone(in: updated)
    }

    static func setting(
        key: String,
        payload: [String: Any],
        in bundle: [String: Any]
    ) -> [String: Any] {
        var updated = bundle
        updated[key] = payload
        if key == RallyMateContextKey.startMatch,
           let terminal = updated[RallyMateContextKey.startMatchTerminal]
            as? [String: Any],
           let terminalMatchId = terminal["matchId"] as? String,
           let startMatchId = payload["matchId"] as? String,
           terminalMatchId == startMatchId {
            // A new explicit start for the same id (for example after a valid
            // undo/reopen flow) supersedes the older terminal tombstone.
            updated.removeValue(forKey: RallyMateContextKey.startMatchTerminal)
        }
        return reconcilingStartTombstone(in: updated)
    }

    static func reconcilingStartMatch(
        activeMatchId: String?,
        stateVersion: Int,
        timestampMs: Int64,
        in bundle: [String: Any]
    ) -> [String: Any] {
        guard let start = bundle[RallyMateContextKey.startMatch] as? [String: Any],
              let startMatchId = start["matchId"] as? String,
              startMatchId != activeMatchId
        else { return bundle }
        return terminatingStartMatch(
            matching: startMatchId,
            stateVersion: stateVersion,
            timestampMs: timestampMs,
            from: bundle
        )
    }

    static func isTerminalLifecycle(action: String, status: String?) -> Bool {
        let values = [action, status]
            .compactMap { $0?.uppercased() }
        return values.contains("COMPLETED") || values.contains("ABANDONED")
    }

    static func envelope(from bundle: [String: Any]) -> [String: Any] {
        var envelope = bundle
        envelope["path"] = RallyMateWatchPath.contextBundle
        envelope["schemaVersion"] = 1
        return envelope
    }

    private static func reconcilingStartTombstone(
        in bundle: [String: Any]
    ) -> [String: Any] {
        guard let start = bundle[RallyMateContextKey.startMatch] as? [String: Any],
              let terminal = bundle[RallyMateContextKey.startMatchTerminal]
                as? [String: Any],
              let startMatchId = start["matchId"] as? String,
              let terminalMatchId = terminal["matchId"] as? String,
              startMatchId == terminalMatchId
        else { return bundle }
        var reconciled = bundle
        reconciled.removeValue(forKey: RallyMateContextKey.startMatch)
        return reconciled
    }
}

final class RallyMateWatchBridge: NSObject {
    /// Upper bound for the journal carried by a queued transfer.
    static let maxDurableJournalBytes = 24 * 1024

    private let channel: FlutterMethodChannel
    private let eventQueue = AppleWatchEventQueue()

    #if canImport(WatchConnectivity)
    private var session: WCSession?
    /// Merged application context. Rebuilt on every update so a new payload
    /// never drops one delivered earlier.
    private var contextBundle: [String: Any] = [:]
    private let contextLock = NSLock()
    #endif

    init(binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.rallymate/watch",
            binaryMessenger: binaryMessenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
        activateSessionIfAvailable()
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "status":
            result(statusPayload())
        case "refreshStatus":
            result(statusPayload())
        case "testConnection":
            sendTest(path: RallyMateWatchPath.ping, result: result)
        case "testPoint":
            sendTest(path: RallyMateWatchPath.testPoint, result: result)
        case "drainEvents":
            guard let pendingJSON = eventQueue.pendingJSON() else {
                result(FlutterError(
                    code: "watch_queue_corrupt",
                    message: "La coda eventi Apple Watch non e decodificabile",
                    details: nil
                ))
                return
            }
            result(pendingJSON)
        case "replaceQueuedEvents":
            guard let args = call.arguments as? [String: Any],
                  let pendingJSON = args["pendingJson"] as? String
            else {
                result(FlutterError(
                    code: "bad_args",
                    message: "pendingJson richiesto",
                    details: nil
                ))
                return
            }
            result(eventQueue.replace(with: pendingJSON))
        case "startMatch":
            startMatch(call.arguments, result: result)
        case "matchLifecycle":
            matchLifecycle(call.arguments, result: result)
        case "publishResumableMatches":
            publishResumableMatches(call.arguments, result: result)
        case "syncProfileImage":
            syncProfileImage(call.arguments, result: result)
        case "updateWorkoutDetectionPreferences":
            updateWorkoutDetectionPreferences(call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Durable pause/resume/complete for the companion app.
    ///
    /// The full event journal travels with the payload so the watch can resume
    /// a match and keep scoring with no connection at all. `transferUserInfo`
    /// is the reliable channel here: it is queued and delivered even when the
    /// companion is suspended, unlike `sendMessage`.
    private func matchLifecycle(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let matchId = args["matchId"] as? String,
              let action = args["action"] as? String
        else {
            result(FlutterError(
                code: "bad_args",
                message: "matchLifecycle requires matchId and action",
                details: nil
            ))
            return
        }
        var payload: [String: Any] = [
            "path": RallyMateWatchPath.lifecycle,
            "schemaVersion": 1,
            "matchId": matchId,
            "action": action,
            "idempotencyKey": (args["idempotencyKey"] as? String)
                ?? UUID().uuidString,
            "stateVersion": (args["stateVersion"] as? NSNumber)?.intValue ?? 0,
            "ts": (args["ts"] as? NSNumber)?.int64Value
                ?? Int64(Date().timeIntervalSince1970 * 1000),
        ]
        if let status = args["status"] as? String { payload["status"] = status }
        if let format = args["format"] as? String { payload["format"] = format }
        if let summary = args["summary"] as? String { payload["summary"] = summary }
        // A queued transfer must stay small enough to be delivered. A very long
        // journal is dropped instead of truncated: a partial journal would
        // replay to the wrong score. The watch then pulls it with requestState.
        if let events = args["events"] as? String,
           events.utf8.count <= Self.maxDurableJournalBytes {
            payload["events"] = events
        } else {
            payload["journalTruncated"] = true
        }
        if RallyMateContextBundlePolicy.isTerminalLifecycle(
            action: action,
            status: args["status"] as? String
        ) {
            _ = removeStartMatchApplicationContext(
                matching: matchId,
                stateVersion: (args["stateVersion"] as? NSNumber)?.intValue ?? 0,
                timestampMs: (args["ts"] as? NSNumber)?.int64Value
                    ?? Int64(Date().timeIntervalSince1970 * 1000)
            )
        }
        sendOrQueue(payload, result: result)
    }

    /// Publishes the latest snapshot of resumable matches through the
    /// application context, which always holds the most recent state.
    private func publishResumableMatches(
        _ arguments: Any?,
        result: @escaping FlutterResult
    ) {
        #if canImport(WatchConnectivity)
        guard let args = arguments as? [String: Any] else {
            result(false)
            return
        }
        var payload: [String: Any] = [
            "path": RallyMateWatchPath.resumable,
            "schemaVersion": 1,
            "matches": (args["matches"] as? String) ?? "[]",
            "stateVersion": (args["stateVersion"] as? NSNumber)?.intValue ?? 0,
            "lastUpdatedAtMs": (args["lastUpdatedAtMs"] as? NSNumber)?.int64Value
                ?? Int64(Date().timeIntervalSince1970 * 1000),
        ]
        if let activeMatchId = args["activeMatchId"] as? String,
           !activeMatchId.isEmpty {
            payload["activeMatchId"] = activeMatchId
        }
        result(mergeApplicationContext(
            key: RallyMateContextKey.resumable,
            payload: payload,
            activeMatchId: payload["activeMatchId"] as? String,
            reconcileStartMatch: true
        ))
        #else
        result(false)
        #endif
    }

    private func updateWorkoutDetectionPreferences(
        _ arguments: Any?,
        result: @escaping FlutterResult
    ) {
        #if canImport(WatchConnectivity)
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              let args = arguments as? [String: Any]
        else {
            result(false)
            return
        }
        let requestedMode = args["mode"] as? String ?? "OFF"
        let mode = ["OFF", "ASK", "QUICK_START"].contains(requestedMode)
            ? requestedMode
            : "OFF"
        result(mergeApplicationContext(
            key: RallyMateContextKey.workoutDetectionPreferences,
            payload: [
                "path": RallyMateWatchPath.workoutDetectionPreferences,
                "schemaVersion": 1,
                "mode": mode,
                "racketSportsOnly": args["racketSportsOnly"] as? Bool ?? true,
                "onlyWhenWorn": args["onlyWhenWorn"] as? Bool ?? false,
            ]
        ))
        #else
        result(false)
        #endif
    }

    private func syncProfileImage(
        _ arguments: Any?,
        result: @escaping FlutterResult
    ) {
        #if canImport(WatchConnectivity)
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              let args = arguments as? [String: Any]
        else {
            result(false)
            return
        }
        let version = (args["version"] as? NSNumber)?.intValue ?? 0
        if let rawPath = args["path"] as? String,
           let imageURL = validatedTeamImageURL(rawPath) {
            session.transferFile(
                imageURL,
                metadata: [
                    "kind": "profile_image",
                    "version": version,
                ]
            )
            result(true)
            return
        }
        result(mergeApplicationContext(
            key: RallyMateContextKey.context,
            payload: [
                "path": RallyMateWatchPath.context,
                "profileImageRemoved": true,
            ]
        ))
        #else
        result(false)
        #endif
    }

    private func startMatch(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let matchId = args["matchId"] as? String,
              let format = args["format"] as? String
        else {
            result(FlutterError(
                code: "bad_args",
                message: "startMatch requires matchId and format",
                details: nil
            ))
            return
        }

        var payload: [String: Any] = [
            "path": RallyMateWatchPath.startMatch,
            "matchId": matchId,
            "format": format,
            // Mid-match handoff: ordered phone event journal (JSON array string).
            "events": (args["events"] as? String) ?? "[]",
        ]
        // Duo Mode: team assegnato al watch (opzionale).
        if let duoTeam = args["duoTeam"] as? String {
            payload["duoTeam"] = duoTeam
        }
        if let teamName = args["teamName"] as? String {
            payload["teamName"] = teamName
        }
        if let sourceUserId = args["sourceUserId"] as? String,
           !sourceUserId.isEmpty {
            payload["sourceUserId"] = sourceUserId
        }
        payload["premiumEnabled"] = args["premiumEnabled"] as? Bool ?? false
        let assistantEnabled = args["assistantEnabled"] as? Bool ?? false
        payload["assistantEnabled"] = assistantEnabled
        if assistantEnabled {
            payload["assistantEndpoint"] = args["assistantEndpoint"] as? String
            payload["assistantAccessToken"] = args["assistantAccessToken"] as? String
            payload["assistantPublishableKey"] = args["assistantPublishableKey"] as? String
            payload["assistantExpiresAtMs"] = args["assistantExpiresAtMs"] as? NSNumber
        }
        if let teamNames = args["teamNames"] as? [String] {
            payload["teamNames"] = Array(
                teamNames
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .prefix(12)
            )
        }
        if let defaultTeamName = args["defaultTeamName"] as? String {
            payload["defaultTeamName"] = defaultTeamName
        }
        let scoringStyle = (args["teamScoringStyle"] as? String) ?? "AUTO"
        let imageVersion = (args["teamImageVersion"] as? NSNumber)?.intValue ?? 0
        payload["teamScoringStyle"] = scoringStyle
        payload["teamImageVersion"] = imageVersion

        let imageURL = (args["teamImagePath"] as? String)
            .flatMap(validatedTeamImageURL)
        let shouldUseImage = scoringStyle != "COLOR" && imageURL != nil
        payload["teamImageExpected"] = shouldUseImage
        if shouldUseImage, let imageURL {
            transferTeamImage(
                imageURL,
                matchId: matchId,
                version: imageVersion,
                style: scoringStyle
            )
        }
        sendOrQueue(payload, result: result)
    }

    private func validatedTeamImageURL(_ rawPath: String) -> URL? {
        let url = URL(fileURLWithPath: rawPath).standardizedFileURL
        guard url.isFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey, .fileSizeKey,
              ]),
              values.isRegularFile == true,
              let size = values.fileSize,
              size > 0,
              size <= 2 * 1024 * 1024,
              ["jpg", "jpeg", "png", "webp"].contains(
                url.pathExtension.lowercased()
              )
        else { return nil }
        return url
    }

    private func transferTeamImage(
        _ url: URL,
        matchId: String,
        version: Int,
        style: String
    ) {
        #if canImport(WatchConnectivity)
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled
        else { return }
        session.transferFile(
            url,
            metadata: [
                "kind": "team_image",
                "matchId": matchId,
                "version": version,
                "style": style,
            ]
        )
        #endif
    }

    private func receive(_ payload: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let path = payload["path"] as? String else {
            replyHandler?(["ok": false])
            return
        }

        switch path {
        case RallyMateWatchPath.events:
            guard let matchId = payload["matchId"] as? String,
                  let events = payload["events"] as? String
            else {
                replyHandler?(["ok": false])
                return
            }
            let format = payload["format"] as? String
            guard let queueId = eventQueue.enqueue(
                matchId: matchId,
                events: events,
                format: format
            ) else {
                replyHandler?(["ok": false])
                return
            }
            DispatchQueue.main.async { [channel] in
                var arguments: [String: Any] = [
                    "queueId": queueId,
                    "matchId": matchId,
                    "events": events,
                ]
                if let format {
                    arguments["format"] = format
                }
                channel.invokeMethod(
                    "events",
                    arguments: arguments
                ) { [weak self] response in
                    let merged = response as? Bool == true
                    if merged {
                        self?.eventQueue.acknowledge(queueId)
                    }
                    replyHandler?(["ok": merged])
                }
            }
        case RallyMateWatchPath.requestState:
            guard let matchId = payload["matchId"] as? String else {
                replyHandler?(["events": "[]"])
                return
            }
            DispatchQueue.main.async { [channel] in
                channel.invokeMethod(
                    "requestState",
                    arguments: ["matchId": matchId]
                ) { response in
                    replyHandler?(["events": response as? String ?? "[]"])
                }
            }
        default:
            replyHandler?(["ok": false])
        }
    }

    private func notifyConnectionChanged() {
        let status = statusPayload()
        DispatchQueue.main.async { [channel] in
            channel.invokeMethod("connectionChanged", arguments: status)
        }
    }

    private func sendTest(path: String, result: @escaping FlutterResult) {
        #if canImport(WatchConnectivity)
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              session.isReachable
        else {
            result(false)
            return
        }
        session.sendMessage(
            ["path": path, "nonce": UUID().uuidString],
            replyHandler: { reply in
                DispatchQueue.main.async { result(reply["ok"] as? Bool == true) }
            },
            errorHandler: { _ in DispatchQueue.main.async { result(false) } }
        )
        #else
        result(false)
        #endif
    }
}

#if canImport(WatchConnectivity)
extension RallyMateWatchBridge: WCSessionDelegate {
    private func activateSessionIfAvailable() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        session = s
        s.delegate = self
        s.activate()
    }

    private func statusPayload() -> [String: Any] {
        guard let session else {
            return [
                "supported": WCSession.isSupported(),
                "paired": false,
                "companionInstalled": false,
                "reachable": false,
                "connected": false,
                "permissionsComplete": true,
                "platform": "Apple Watch",
                "deviceName": "Apple Watch",
                "status": WCSession.isSupported() ? "NOT_PAIRED" : "UNSUPPORTED",
                "capabilities": [],
            ]
        }
        let activated = session.activationState == .activated
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        // Real-time messaging only when the watch app is currently reachable.
        let reachable = activated && paired && installed && session.isReachable
        // Durable transferUserInfo works whenever the companion is installed,
        // even if the watch is momentarily unreachable (wrist down / background).
        let connected = activated && paired && installed
        let status: String
        if !paired {
            status = "NOT_PAIRED"
        } else if !activated {
            status = "SYNC_PENDING"
        } else if !installed {
            status = "COMPANION_MISSING"
        } else if reachable {
            status = "READY"
        } else {
            status = "NOT_REACHABLE"
        }
        return [
            "supported": true,
            "paired": paired,
            "companionInstalled": installed,
            "reachable": reachable,
            "connected": connected,
            "permissionsComplete": true,
            "platform": "Apple Watch",
            "deviceName": "Apple Watch",
            "status": status,
            "capabilities": [
                "scoring", "duo", "offline", "haptics", "voice", "workout", "alwaysOn",
            ],
        ]
    }

    /// Merges one payload into the single application-context slot.
    ///
    /// WatchConnectivity replaces the whole context on every call, so each
    /// payload is stored under its own key and the full envelope is resent.
    private func mergeApplicationContext(
        key: String,
        payload: [String: Any],
        activeMatchId: String? = nil,
        reconcileStartMatch: Bool = false
    ) -> Bool {
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled
        else { return false }
        contextLock.lock()
        contextBundle = RallyMateContextBundlePolicy.merged(
            inMemory: contextBundle,
            persisted: session.applicationContext
        )
        if reconcileStartMatch {
            contextBundle = RallyMateContextBundlePolicy.reconcilingStartMatch(
                activeMatchId: activeMatchId,
                stateVersion: (payload["stateVersion"] as? NSNumber)?.intValue ?? 0,
                timestampMs: (payload["lastUpdatedAtMs"] as? NSNumber)?.int64Value
                    ?? Int64(Date().timeIntervalSince1970 * 1000),
                in: contextBundle
            )
        }
        contextBundle = RallyMateContextBundlePolicy.setting(
            key: key,
            payload: payload,
            in: contextBundle
        )
        let envelope = RallyMateContextBundlePolicy.envelope(from: contextBundle)
        contextLock.unlock()
        do {
            try session.updateApplicationContext(envelope)
            return true
        } catch {
            return false
        }
    }

    /// Clears only the latest start command for the match that became terminal.
    /// Other context keys, and a newer match's start command, are preserved.
    private func removeStartMatchApplicationContext(
        matching matchId: String,
        stateVersion: Int,
        timestampMs: Int64
    ) -> Bool {
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled
        else { return false }

        contextLock.lock()
        let hydrated = RallyMateContextBundlePolicy.merged(
            inMemory: contextBundle,
            persisted: session.applicationContext
        )
        let updated = RallyMateContextBundlePolicy.terminatingStartMatch(
            matching: matchId,
            stateVersion: stateVersion,
            timestampMs: timestampMs,
            from: hydrated
        )
        contextBundle = updated
        let envelope = RallyMateContextBundlePolicy.envelope(from: updated)
        contextLock.unlock()

        do {
            try session.updateApplicationContext(envelope)
            return true
        } catch {
            return false
        }
    }

    private func sendOrQueue(_ payload: [String: Any], result: @escaping FlutterResult) {
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled
        else {
            result(false)
            return
        }

        // Always enqueue a durable copy first so a closed/suspended companion
        // still receives START_MATCH when it wakes (WatchConnectivity guarantees
        // transferUserInfo delivery, not live open).
        session.transferUserInfo(payload)

        // Application context carries the *latest* startMatch so a relaunch
        // without draining the transfer queue still restores the active match.
        if payload["path"] as? String == RallyMateWatchPath.startMatch {
            _ = mergeApplicationContext(
                key: RallyMateContextKey.startMatch,
                payload: payload
            )
        }

        guard session.isReachable else {
            // Durable queue accepted: treat as success so the phone does not
            // spuriously report "watch non raggiungibile" when the payload is
            // already on the wire for the next wake.
            result(true)
            return
        }

        session.sendMessage(
            payload,
            replyHandler: { reply in
                DispatchQueue.main.async {
                    // Live ack preferred; durable queue already covers failure.
                    result(reply["ok"] as? Bool == true)
                }
            },
            errorHandler: { _ in
                // transferUserInfo already queued above.
                DispatchQueue.main.async {
                    result(true)
                }
            }
        )
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        _ = session
        _ = activationState
        _ = error
        notifyConnectionChanged()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        _ = session
        notifyConnectionChanged()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        _ = session
        notifyConnectionChanged()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        _ = session
        receive(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        _ = session
        receive(message, replyHandler: replyHandler)
    }

    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        _ = session
        receive(userInfo)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        _ = session
        notifyConnectionChanged()
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        notifyConnectionChanged()
    }
}
#else
extension RallyMateWatchBridge {
    private func activateSessionIfAvailable() {}

    private func statusPayload() -> [String: Any] {
        [
            "supported": false,
            "paired": false,
            "companionInstalled": false,
            "reachable": false,
            "connected": false,
            "permissionsComplete": true,
            "platform": "",
            "deviceName": "",
            "status": "UNSUPPORTED",
            "capabilities": [],
        ]
    }

    private func sendOrQueue(_: [String: Any], result: @escaping FlutterResult) {
        result(false)
    }
}
#endif
