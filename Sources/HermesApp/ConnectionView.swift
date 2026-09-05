import SwiftUI
import Security
#if canImport(HermesCore)
import HermesCore
#endif

private struct SavedConnection: Codable {
    let server: String
    let pairing: ConnectionPairing
}

private enum ConnectionKeychain {
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.prismtrade.hermes.connection",
         kSecAttrAccount as String: "device-session"]
    }
    static func read() throws -> SavedConnection? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw keychainError(status) }
        return try JSONDecoder().decode(SavedConnection.self, from: data)
    }
    static func save(_ connection: SavedConnection) throws {
        let data = try JSONEncoder().encode(connection)
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var q = query
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(q as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw keychainError(status) }
    }
    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw keychainError(status) }
    }
    static func keychainError(_ status: OSStatus) -> NSError {
        NSError(domain: "Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Secure session storage is unavailable (\(status))."])
    }
}

@MainActor @Observable
private final class ConnectionModel {
    var server = ""
    var code = ""
    var snapshot: WorkspaceSnapshot?
    var busy = false
    var error: String?
    var status = "Not connected"
    private var saved: SavedConnection?
    var hasSession: Bool { saved != nil }

    func restore() async {
        do {
            saved = try ConnectionKeychain.read()
            if let saved { server = saved.server; await refresh() }
        } catch { self.error = error.localizedDescription }
    }
    func pair() async {
        busy = true; error = nil; status = "Pairing…"
        defer { busy = false; code = "" }
        do {
            let client = try ConnectionClient(server: server.trimmingCharacters(in: .whitespacesAndNewlines))
            let pairing = try await client.pair(code: code)
            let connection = SavedConnection(server: client.server.absoluteString, pairing: pairing)
            // Keep the in-memory credential if Keychain fails so revocation can still be attempted.
            saved = connection
            try ConnectionKeychain.save(connection)
            try await load(connection)
        } catch { fail(error) }
    }
    func refresh() async {
        guard let saved else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await load(saved) } catch { fail(error) }
    }
    private func load(_ connection: SavedConnection) async throws {
        let client = try ConnectionClient(server: connection.server)
        let workspace = try await client.workspace(token: connection.pairing.deviceToken)
        guard workspace.companies.count == 1,
              workspace.companies.first?.id == connection.pairing.companyID,
              workspace.selectedCompanyID == connection.pairing.companyID,
              workspace.chats.allSatisfy({ $0.companyID == connection.pairing.companyID }),
              workspace.messages.allSatisfy({ $0.companyID == connection.pairing.companyID }),
              workspace.approvals.allSatisfy({ $0.companyID == connection.pairing.companyID }),
              workspace.agents.allSatisfy({ $0.companyID == connection.pairing.companyID }) else { throw ConnectionError.invalidResponse }
        snapshot = workspace
        status = "Authenticated · last refresh \(Date().formatted(date: .omitted, time: .shortened))"
    }
    func disconnect() async {
        guard let saved else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let client = try ConnectionClient(server: saved.server)
            do { try await client.revoke(token: saved.pairing.deviceToken) }
            catch ConnectionError.unauthorized { /* Already unusable. */ }
            // Verify the exact revoked session cannot read its workspace.
            do {
                _ = try await client.workspace(token: saved.pairing.deviceToken)
                throw ConnectionError.invalidResponse
            } catch ConnectionError.unauthorized { }
            try ConnectionKeychain.remove()
            self.saved = nil; snapshot = nil; status = "Disconnected · session revoked"
        } catch { fail(error); status = "Revocation not confirmed · retry disconnect" }
    }
    private func fail(_ error: Error) {
        snapshot = nil
        status = "Connection unavailable"
        self.error = error.localizedDescription
    }
}

struct AuthenticatedConnectionView: View {
    @State private var model = ConnectionModel()
    var body: some View {
        Group {
            if model.hasSession {
                connectedView
            } else {
                PairingScreen(model: model)
            }
        }
        .task { await model.restore() }
        .tint(HermesTheme.blue)
    }

    private var connectedView: some View {
        NavigationStack {
            List {
                Section {
                    Label("Connect your workspace securely", systemImage: "lock.shield")
                        .font(.headline)
                    Text(model.status).font(.subheadline).foregroundStyle(.secondary)
                    Text("Read-only workspace. Approval decisions are records, not executed work. Sending messages and running agents are not available.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error = model.error {
                    Section("Connection issue") { Text(error).foregroundStyle(.red) }
                }
                if model.busy { ProgressView("Contacting server…") }
                if let workspace = model.snapshot {
                    Section(workspace.companies.first?.name ?? "Workspace") {
                        ForEach(workspace.chats) { chat in
                            NavigationLink {
                                List {
                                    Text("Server history · read only").font(.caption)
                                    ForEach(workspace.messages.filter { $0.chatID == chat.id }) { message in
                                        VStack(alignment: .leading) {
                                            Text(message.sender).font(.headline)
                                            Text(message.body)
                                            Text(message.createdAt.formatted()).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }.navigationTitle(chat.title)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(chat.title).font(.headline)
                                    Text(chat.lastMessage).lineLimit(2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if workspace.chats.isEmpty { Text("No chats on this server.") }
                    }
                    Section("Approval records · no execution") {
                        ForEach(workspace.approvals) { approval in
                            VStack(alignment: .leading) {
                                Text(approval.title).font(.headline)
                                Text(approval.proposedAction)
                                Text("Recorded status: \(approval.status.rawValue)").font(.caption)
                            }
                        }
                        if workspace.approvals.isEmpty { Text("No approval records.") }
                    }
                }
                if model.hasSession {
                    Section {
                        Button("Refresh workspace") { Task { await model.refresh() } }
                        Button("Revoke session & disconnect", role: .destructive) { Task { await model.disconnect() } }
                    }.disabled(model.busy)
                }
            }
            .navigationTitle("Helios Workspace")
        }
    }
}

/// Full-bleed pairing screen: gradient hero runs under the status bar so there is
/// no empty nav-bar gap above the content.
private struct PairingScreen: View {
    @Bindable var model: ConnectionModel
    @FocusState private var focus: Field?
    private enum Field { case server, code }

    var body: some View {
        ZStack(alignment: .top) {
            HermesTheme.groupedCanvas.ignoresSafeArea()
            LinearGradient(colors: [HermesTheme.deepBlue, HermesTheme.blue, HermesTheme.lightBlue],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 400)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 20) {
                    hero
                    formCard
                    if let error = model.error {
                        statusCard(icon: "exclamationmark.triangle.fill", tint: .red, title: "Connection issue", body: error)
                    }
                    if model.busy {
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Contacting server…").foregroundStyle(.white)
                        }
                        .font(.subheadline)
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onTapGesture { focus = nil }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(.white.opacity(0.18)).frame(width: 92, height: 92)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Helios Workspace")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Text("Connect your workspace securely")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.9))
            Text(model.status)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.18), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.bottom, 8)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONNECT YOUR SERVER")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HermesTheme.muted)
                .padding(.bottom, 12)

            field(icon: "server.rack") {
                TextField("https://your-server.example", text: $model.server)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .server)
                    .submitLabel(.next)
                    .onSubmit { focus = .code }
            }
            Divider().padding(.vertical, 10)
            field(icon: "key.fill") {
                SecureField("One-time pairing credential", text: $model.code)
                    .focused($focus, equals: .code)
                    .submitLabel(.go)
                    .onSubmit { if canPair { Task { await model.pair() } } }
            }

            Text("Obtain a short-lived, single-use credential from your server operator. An HTTPS endpoint with a valid certificate is required.")
                .font(.footnote)
                .foregroundStyle(HermesTheme.muted)
                .padding(.top, 14)

            Button {
                focus = nil
                Task { await model.pair() }
            } label: {
                Text("Pair securely")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(HermesTheme.blue)
            .disabled(!canPair)
            .padding(.top, 18)
        }
        .padding(18)
        .background(HermesTheme.canvas, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }

    private var canPair: Bool {
        !model.busy && !model.code.isEmpty && !model.server.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func field<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(HermesTheme.blue)
                .frame(width: 24)
            content()
                .font(.system(size: 17))
                .foregroundStyle(.black)
        }
        .frame(minHeight: 30)
    }

    private func statusCard(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                Text(body).font(.footnote).foregroundStyle(HermesTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(HermesTheme.canvas, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Label("Read-only workspace", systemImage: "eye")
                .font(.system(size: 13, weight: .semibold))
            Text("Approval decisions are records, not executed work. Sending messages and running agents are not available.")
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(HermesTheme.muted)
        .padding(.top, 8)
    }
}
