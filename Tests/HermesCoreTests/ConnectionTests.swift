import Foundation
import Testing
@testable import HermesCore

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
