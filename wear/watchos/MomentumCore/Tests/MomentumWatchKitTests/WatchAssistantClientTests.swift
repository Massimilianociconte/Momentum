@testable import MomentumWatchKit
import Foundation
import XCTest

final class WatchAssistantClientTests: XCTestCase, @unchecked Sendable {
    private struct Credentials: WatchAssistantCredentialProviding {
        let value: WatchAssistantCredentials?
        func load() -> WatchAssistantCredentials? { value }
    }

    private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
        static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

        override class func canInit(with _: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testWatchRequestUsesEdgeFunctionAndNeverDeepSeekCredentials() async throws {
        let endpoint = try XCTUnwrap(URL(string: "https://example.supabase.co/functions/v1/assistant"))
        let credentials = WatchAssistantCredentials(
            endpoint: endpoint,
            publishableKey: "publishable-key",
            accessToken: "short-lived-user-token",
            expiresAt: Date().addingTimeInterval(3_600)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)

        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url, endpoint)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "publishable-key")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer short-lived-user-token"
            )
            XCTAssertNil(request.value(forHTTPHeaderField: "x-api-key"))
            let body = try XCTUnwrap(request.httpBody ?? Self.readBodyStream(request.httpBodyStream))
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(json["surface"] as? String, "watch")
            XCTAssertEqual(json["mode"] as? String, "LIVE_MATCH")
            XCTAssertEqual(json["matchId"] as? String, "match-1")
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            let payload = try JSONSerialization.data(withJSONObject: [
                "answer": "Sul 40 pari il punto successivo assegna AD.",
                "sources": [["title": "FIP Rules of Padel"]],
                "remainingToday": 4,
            ])
            return (response, payload)
        }

        let result = await WatchAssistantClient(
            credentials: Credentials(value: credentials),
            session: session
        ).ask(
            question: "Come funzionano i vantaggi?",
            matchId: "match-1",
            matchContext: "40-40"
        )

        let reply = try result.get()
        XCTAssertEqual(reply.remainingToday, 4)
        XCTAssertEqual(reply.sourceTitles, ["FIP Rules of Padel"])
    }

    private static func readBodyStream(_ stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read < 0 { return nil }
            if read == 0 { break }
            result.append(buffer, count: read)
        }
        return result.isEmpty ? nil : result
    }

    func testExpiredSessionFailsBeforeNetworkRequest() async throws {
        let endpoint = try XCTUnwrap(URL(string: "https://example.supabase.co/functions/v1/assistant"))
        let credentials = WatchAssistantCredentials(
            endpoint: endpoint,
            publishableKey: "publishable-key",
            accessToken: "expired",
            expiresAt: Date().addingTimeInterval(-1)
        )
        let result = await WatchAssistantClient(
            credentials: Credentials(value: credentials)
        ).ask(question: "Golden point?", matchId: nil, matchContext: nil)

        XCTAssertEqual(result, .failure(.sessionExpired))
    }
}
