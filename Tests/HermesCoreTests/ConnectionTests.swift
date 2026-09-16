import Foundation
import Testing
#if canImport(HermesCore)
@testable import HermesCore
#else
@testable import Hermes
#endif

@Test func connectionPairContract() async throws {
    let client = try ConnectionClient(server: "https://example.com", transport: { request in
        #expect(request.url?.path == "/v1/pair")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(String(data: request.httpBody!, encoding: .utf8) == "{\"code\":\"secret\"}")
        return (Data("{\"deviceToken\":\"token\",\"sessionID\":\"00000000-0000-0000-0000-000000000001\",\"companyID\":\"00000000-0000-0000-0000-000000000002\",\"expiresAt\":\"2026-10-01T00:00:00Z\"}".utf8), 200)
    })
    #expect(try await client.pair(code: "secret").deviceToken == "token")
}

@Test func connectionUnauthorizedHasNoOfflineFallback() async throws {
    let client = try ConnectionClient(server: "https://example.com", transport: { request in
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        return (Data("{\"error\":\"unauthorized\"}".utf8), 401)
    })
    await #expect(throws: ConnectionError.self) { try await client.workspace(token: "token") }
}

@Test func connectionRevokeContract() async throws {
    let client = try ConnectionClient(server: "https://example.com", transport: { request in
        #expect(request.url?.path == "/v1/session/revoke")
        #expect(request.httpMethod == "POST")
        return (Data("{\"revoked\":true}".utf8), 200)
    })
    try await client.revoke(token: "token")
}

@Test func connectionRequiresHTTPSOrigin() throws {
    #expect(throws: (any Error).self) { try ConnectionClient(server: "http://example.com") }
    #expect(throws: (any Error).self) { try ConnectionClient(server: "https://user:password@example.com") }
    #expect(throws: (any Error).self) { try ConnectionClient(server: "https://example.com/path?token=x") }
    #expect(try ConnectionClient(server: "https://example.com/").server.absoluteString == "https://example.com/")
}

@Test func missingPairingCodeDoesNotContactServer() async throws {
    let client = try ConnectionClient(server: "https://example.com", transport: { _ in
        Issue.record("An empty credential must never reach the network")
        return (Data(), 500)
    })
    do {
        _ = try await client.pair(code: " \n ")
        Issue.record("Expected validation failure")
    } catch ConnectionError.missingCode { }
}

@Test func pastedPairingInputIsTrimmed() async throws {
    let client = try ConnectionClient(server: " \nhttps://example.com/\n", transport: { request in
        #expect(String(data: request.httpBody!, encoding: .utf8) == "{\"code\":\"secret\"}")
        return (Data(), 401)
    })
    do { _ = try await client.pair(code: " secret\n") }
    catch ConnectionError.unauthorized { }
}

@Test func nonAPIResponseHasReadableError() async throws {
    let client = try ConnectionClient(server: "https://example.com", transport: { _ in
        (Data("<html>Server unavailable</html>".utf8), 200)
    })
    do {
        _ = try await client.pair(code: "secret")
        Issue.record("Expected invalid response")
    } catch ConnectionError.invalidResponse { }
}

@Test func timeoutExplainsHowToRetry() async throws {
    let client = try ConnectionClient(server: "https://example.com", transport: { _ in
        throw URLError(.timedOut)
    })
    do {
        _ = try await client.pair(code: "secret")
        Issue.record("Expected timeout")
    } catch {
        #expect(error.localizedDescription.contains("try again"))
    }
}
