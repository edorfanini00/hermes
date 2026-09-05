import Foundation

public enum ConnectionError: Error, LocalizedError {
    case invalidServer, invalidResponse, unauthorized, server(Int)
    public var errorDescription: String? {
        switch self {
        case .invalidServer: "Enter an HTTPS server origin without credentials, a path, query, or fragment."
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
        guard let url = URL(string: server), url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else { throw ConnectionError.invalidServer }
        self.server = url
    }
    public static func network(_ request: URLRequest) async throws -> (Data, Int) {
        let session = URLSession(configuration: .ephemeral, delegate: ConnectionRedirectGuard(), delegateQueue: nil)
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
        let (data, status) = try await transport(request)
        guard (200..<300).contains(status) else {
            if status == 401 { throw ConnectionError.unauthorized }
            throw ConnectionError.server(status)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
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
        try await request("v1/pair", body: ["code": code])
    }
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
