import Foundation
import Security

public struct WatchAssistantCredentials: Codable, Equatable, Sendable {
    public let endpoint: URL
    public let publishableKey: String
    public let accessToken: String
    public let expiresAt: Date

    public init(
        endpoint: URL,
        publishableKey: String,
        accessToken: String,
        expiresAt: Date
    ) {
        self.endpoint = endpoint
        self.publishableKey = publishableKey
        self.accessToken = accessToken
        self.expiresAt = expiresAt
    }

    public var usable: Bool {
        !publishableKey.isEmpty
            && !accessToken.isEmpty
            && expiresAt.timeIntervalSinceNow > 30
            && endpoint.scheme == "https"
    }
}

public struct WatchAssistantReply: Equatable, Sendable {
    public let answer: String
    public let sourceTitles: [String]
    public let remainingToday: Int?
}

public enum WatchAssistantError: Error, Equatable, Sendable {
    case notConfigured
    case sessionExpired
    case offline
    case planRequired
    case limitReached
    case unavailable

    public var message: String {
        switch self {
        case .notConfigured:
            "Apri Padelandia su iPhone per attivare Pallino sul Watch."
        case .sessionExpired:
            "Sessione scaduta. Avvicina l’iPhone per rinnovarla."
        case .offline:
            "Nessuna rete. Le regole rapide restano disponibili offline."
        case .planRequired:
            "Pallino sul Watch richiede il piano Pro."
        case .limitReached:
            "Limite domande raggiunto. Continua con le FAQ locali."
        case .unavailable:
            "Pallino non è disponibile. Riprova tra poco."
        }
    }
}

public protocol WatchAssistantCredentialProviding: Sendable {
    func load() -> WatchAssistantCredentials?
}

/// Stores only the short-lived Supabase session required by the Edge Function.
/// DeepSeek credentials never leave Supabase.
public final class WatchAssistantCredentialStore: WatchAssistantCredentialProviding, @unchecked Sendable {
    private let service = "com.rallymate.watch.assistant"
    private let account = "edge-session"

    public init() {}

    public func save(_ credentials: WatchAssistantCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    public func load() -> WatchAssistantCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(WatchAssistantCredentials.self, from: data)
    }

    public func clear() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
    }
}

public struct WatchAssistantClient: Sendable {
    private let credentials: any WatchAssistantCredentialProviding
    private let session: URLSession

    public init(
        credentials: any WatchAssistantCredentialProviding = WatchAssistantCredentialStore(),
        session: URLSession = .shared
    ) {
        self.credentials = credentials
        self.session = session
    }

    public func ask(
        question: String,
        matchId: String?,
        matchContext: String?
    ) async -> Result<WatchAssistantReply, WatchAssistantError> {
        guard let credential = credentials.load() else {
            return .failure(.notConfigured)
        }
        guard credential.expiresAt.timeIntervalSinceNow > 30 else {
            return .failure(.sessionExpired)
        }
        guard credential.usable else { return .failure(.notConfigured) }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.unavailable) }

        var request = URLRequest(url: credential.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 38
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credential.publishableKey, forHTTPHeaderField: "apikey")
        var body: [String: Any] = [
            "question": String(trimmed.prefix(800)),
            "mode": matchId == nil ? "RULES" : "LIVE_MATCH",
            "surface": "watch",
            "matchContext": String((matchContext ?? "").prefix(1200)),
        ]
        if let matchId { body["matchId"] = matchId }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.unavailable)
            }
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            guard (200 ..< 300).contains(http.statusCode) else {
                return .failure(mapError(payload?["error"] as? String, status: http.statusCode))
            }
            guard let answer = payload?["answer"] as? String,
                  !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return .failure(.unavailable) }
            let sources = (payload?["sources"] as? [[String: Any]] ?? [])
                .compactMap { ($0["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return .success(
                WatchAssistantReply(
                    answer: answer,
                    sourceTitles: Array(sources.prefix(3)),
                    remainingToday: payload?["remainingToday"] as? Int
                )
            )
        } catch let error as URLError where [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotFindHost,
            .cannotConnectToHost,
        ].contains(error.code) {
            return .failure(.offline)
        } catch {
            return .failure(.unavailable)
        }
    }

    private func mapError(_ code: String?, status: Int) -> WatchAssistantError {
        switch code {
        case "plan_required", "assistant_disabled": .planRequired
        case "daily_limit", "live_limit": .limitReached
        case "unauthorized": .sessionExpired
        default: status == 401 ? .sessionExpired : .unavailable
        }
    }
}
