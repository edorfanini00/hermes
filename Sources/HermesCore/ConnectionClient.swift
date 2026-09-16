import Foundation

public enum ConnectionError: Error, LocalizedError {
    case invalidServer, missingCode, invalidResponse, unauthorized, server(Int)
    public var errorDescription: String? {
        switch self {
        case .invalidServer: "Enter an HTTPS server origin without credentials, a path, query, or fragment."
        case .missingCode: "Enter the access code supplied by your agent operator. A server URL alone cannot pair this device."
        case .invalidResponse: "The server returned an unsupported response."
        case .unauthorized: "The pairing credential or session is expired, invalid, or revoked. Pair again."
        case .server(let status): "The server rejected this request (HTTP \(status))."
        }
    }
}

public struct ConnectionClient: Sendable {
    public let server: URL
    private let transport: @Sendable (URLRequest) async throws -> (Data, Int)
    public init(server: String, transport: @escaping @Sendable (URLRequest) async throws -> (Data, Int) = ConnectionClient.network) throws {
        self.transport = transport
        guard let url = URL(string: server.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else { throw ConnectionError.invalidServer }
        self.server = url
    }
    public static func network(_ request: URLRequest) async throws -> (Data, Int) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration, delegate: ConnectionRedirectGuard(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ConnectionError.invalidResponse }
        return (data, http.statusCode)
    }
    func request<T: Decodable>(_ path: String, token: String? = nil, body: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: server.appendingPathComponent(path))
        request.timeoutInterval = 20
        request.httpMethod = body == nil ? "GET" : "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .sortedKeys)
        }
        let data: Data
        let status: Int
        do { (data, status) = try await transport(request) }
        catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw NSError(domain: "HermesConnection", code: error.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "The server did not respond in time. Check the server URL and try again."])
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                throw NSError(domain: "HermesConnection", code: error.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "Cannot reach this server. Confirm the HTTPS address with your agent operator and check that the server is running."])
            default: throw error
            }
        }
        guard (200..<300).contains(status) else {
            if status == 401 { throw ConnectionError.unauthorized }
            throw ConnectionError.server(status)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do { return try decoder.decode(T.self, from: data) }
        catch { throw ConnectionError.invalidResponse }
    }
    public func workspace(token: String) async throws -> WorkspaceSnapshot {
        try await request("v1/workspace", token: token)
    }
    public func revoke(token: String) async throws {
        struct Result: Decodable { let revoked: Bool }
        let result: Result = try await request("v1/session/revoke", token: token, body: [:])
        guard result.revoked else { throw ConnectionError.invalidResponse }
    }
    public func pair(code: String) async throws -> ConnectionPairing {
        let credential = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else { throw ConnectionError.missingCode }
        return try await request("v1/pair", body: ["code": credential])
    }
    /// Records an approve/reject decision on the server. The server never executes work; it returns the updated record.
    public func decide(token: String, approvalID: UUID, approve: Bool) async throws -> ApprovalDecision {
        let key = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return try await request("v1/approvals/\(approvalID.uuidString.lowercased())/decision", token: token,
                                 body: ["decision": approve ? "approve" : "reject", "idempotencyKey": key])
    }
}

public struct ApprovalDecision: Codable, Sendable {
    public let approval: ApprovalRequest
    public let decisionID: UUID
    public let recordedAt: Date
    public let executionStatus: String
}

private final class ConnectionRedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct ConnectionPairing: Codable, Sendable {
    public let deviceToken: String
    public let sessionID: UUID
    public let companyID: UUID
    public let expiresAt: Date
}
