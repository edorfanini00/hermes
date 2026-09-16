import SwiftUI
import Security
#if canImport(HermesCore)
import HermesCore
#endif

struct SavedConnection: Codable {
    let server: String
    let pairing: ConnectionPairing
}

enum ConnectionKeychain {
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
final class ConnectionModel {
    var server = ""
    var code = ""
    var snapshot: WorkspaceSnapshot?
    var busy = false
    var error: String?
    var status = "Not connected"
    private var saved: SavedConnection?
    private var didRestore = false
    var hasSession: Bool { saved != nil }

    func restore() async {
        guard !didRestore else { return }
        didRestore = true
        do {
            saved = try ConnectionKeychain.read()
            if let saved { server = saved.server; await refresh() }
        } catch { self.error = error.localizedDescription }
    }
    func pair() async {
        guard !busy else { return }
        busy = true; error = nil; status = "Pairing…"
        defer { busy = false }
        do {
            let client = try ConnectionClient(server: server.trimmingCharacters(in: .whitespacesAndNewlines))
            let pairing = try await client.pair(code: code)
            code = ""
            let connection = SavedConnection(server: client.server.absoluteString, pairing: pairing)
            // Keep the in-memory credential if Keychain fails so revocation can still be attempted.
            saved = connection
            try ConnectionKeychain.save(connection)
            try await load(connection)
        } catch { fail(error) }
    }
    func refresh() async {
        guard !busy, let saved else { return }
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
    func decide(_ approval: ApprovalRequest, approve: Bool) async {
        guard !busy, let saved else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let client = try ConnectionClient(server: saved.server)
            let result = try await client.decide(token: saved.pairing.deviceToken, approvalID: approval.id, approve: approve)
            if var snap = snapshot, let i = snap.approvals.firstIndex(where: { $0.id == approval.id }) {
                snap.approvals[i] = result.approval
                snapshot = snap
            }
            status = "Decision recorded \(result.recordedAt.formatted(date: .omitted, time: .shortened)) · execution: \(result.executionStatus)"
        } catch { fail(error) }
    }
    func disconnect() async {
        guard !busy, let saved else { return }
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
    /// Erases only this device. Remote revocation must never be implied while offline.
    func forgetDevice() {
        guard !busy else { return }
        do {
            try ConnectionKeychain.remove()
            saved = nil
            snapshot = nil
            code = ""
            error = nil
            status = "Device disconnected locally · remote session not revoked"
        } catch { self.error = error.localizedDescription }
    }

    private func fail(_ error: Error) {
        snapshot = nil
        status = "Connection unavailable"
        self.error = error.localizedDescription
        if case ConnectionError.unauthorized = error, saved != nil {
            do {
                try ConnectionKeychain.remove()
                saved = nil
                status = "Session expired or revoked · pair again"
            } catch {
                self.error = "The session is no longer valid, but secure storage could not be cleared. Try removing this device again."
            }
        }
    }


}

struct AuthenticatedConnectionView: View {
    @State private var model = ConnectionModel()
    @State private var confirmForget = false
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
        .alert("Connection issue", isPresented: Binding(
            get: { model.error != nil },
            set: { if !$0 { model.error = nil } }
        )) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: {
            Text(model.error ?? "Please try again.")
        }
        .confirmationDialog("Remove this device without revoking its server session?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Remove from this device", role: .destructive) { model.forgetDevice() }
        } message: {
            Text("This clears the saved credential on this device. The server session stays valid until it expires or your operator revokes it.")
        }
    }

    private var connectedView: some View {
        NavigationStack {
            List {
                Section {
                    Label("Your Hermes agent, in your pocket", systemImage: "lock.shield")
                        .font(.headline)
                    Text(model.status).font(.subheadline).foregroundStyle(.secondary)
                    Text("Read-only workspace. Approval decisions are records, not executed work. Sending messages and running agents are not available.")
                        .font(.subheadline).foregroundStyle(.secondary)
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
                                    Text("Server history · read only").font(.subheadline)
                                    ForEach(workspace.messages.filter { $0.chatID == chat.id }) { message in
                                        VStack(alignment: .leading) {
                                            Text(message.sender).font(.headline)
                                            Text(message.body)
                                            Text(message.createdAt.formatted()).font(.subheadline).foregroundStyle(.secondary)
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
                    Section("Agents") {
                        ForEach(workspace.agents) { agent in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name).font(.headline)
                                Text(agent.goal).font(.subheadline).foregroundStyle(.secondary)
                                Text(agentStatusLabel(agent.status)).font(.subheadline).foregroundStyle(HermesTheme.blue)
                            }
                        }
                        if workspace.agents.isEmpty { Text("No agents on this server.") }
                    }
                    Section("Approvals · decisions are recorded, nothing is executed") {
                        ForEach(workspace.approvals) { approval in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(approval.title).font(.headline)
                                Text(approval.proposedAction).font(.subheadline)
                                Text("Status: \(approval.status.rawValue)").font(.subheadline).foregroundStyle(.secondary)
                                if approval.status == .pending {
                                    ViewThatFits(in: .horizontal) {
                                      approvalButtons(approval, vertical: false)
                                      approvalButtons(approval, vertical: true)
                                    }
                                    .disabled(model.busy)
                                    .padding(.top, 2)
                                }
                            }
                        }
                        if workspace.approvals.isEmpty { Text("No approval records.") }
                    }
                }
                if model.hasSession {
                    Section {
                        Button("Refresh workspace") { Task { await model.refresh() } }
                        Button("Revoke session & disconnect", role: .destructive) { Task { await model.disconnect() } }
                        if model.snapshot == nil {
                            Button("Remove connection from this device", role: .destructive) { confirmForget = true }
                        }
                    }.disabled(model.busy)
                }
            }
            .navigationTitle("Elara")
        }
    }

    private func approvalButtons(_ approval: ApprovalRequest, vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Button("Approve") { Task { await model.decide(approval, approve: true) } }
                .buttonStyle(.borderedProminent)
            Button("Reject", role: .destructive) { Task { await model.decide(approval, approve: false) } }
                .buttonStyle(.bordered)
        }
    }

    private func agentStatusLabel(_ status: CompanyAgent.Status) -> String {
        switch status {
        case .planning: "Planning"
        case .waitingForApproval: "Waiting for approval"
        case .running: "Running"
        case .blocked: "Blocked"
        case .complete: "Complete"
        }
    }
}

/// Scrollable onboarding with scalable text and a readable width on iPad.
private struct PairingScreen: View {
    @Bindable var model: ConnectionModel
    @FocusState private var focus: Field?
    @ScaledMetric(relativeTo: .body) private var fieldIconWidth: CGFloat = 24
    private enum Field { case server, code }

    var body: some View {
        ZStack(alignment: .top) {
            HermesTheme.groupedCanvas.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    hero
                    formCard
                    footer
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }

    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(.white.opacity(0.18)).frame(width: 92, height: 92)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Elara")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Your Hermes agent, in your pocket")
                .font(.body)
                .foregroundStyle(.white)
            Text(model.status)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.18), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .padding(.horizontal, 20)
        .multilineTextAlignment(.center)
        .background(HermesTheme.deepBlue, in: RoundedRectangle(cornerRadius: 22))
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONNECT TO HERMES")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HermesTheme.muted)
                .padding(.bottom, 12)

            Text("Server URL").font(.headline).padding(.bottom, 8)
            field(icon: "server.rack") {
                TextField("Server URL", text: $model.server, prompt: Text("https://agent.example").foregroundStyle(HermesTheme.muted))
                    .accessibilityLabel("Server URL")
                    .disabled(model.busy)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .server)
                    .submitLabel(.next)
                    .onSubmit { focus = .code }
            }
            Divider().padding(.vertical, 10)
            Text("Access code").font(.headline).padding(.bottom, 8)
            field(icon: "key.fill") {
                SecureField("Access code", text: $model.code, prompt: Text("Enter access code").foregroundStyle(HermesTheme.muted))
                    .accessibilityLabel("Access code")
                    .disabled(model.busy)
                    .focused($focus, equals: .code)
                    .submitLabel(.go)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await model.pair() } }
            }

            Text("Enter your Hermes agent URL and the access code generated by your agent operator.")
                .font(.subheadline)
                .foregroundStyle(HermesTheme.muted)
                .padding(.top, 14)

            Button {
                focus = nil
                Task { await model.pair() }
            } label: {
                HStack {
                    if model.busy { ProgressView().tint(.white) }
                    Text(model.busy ? "Connecting…" : "Pair securely")
                }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(HermesTheme.blue)
            .disabled(model.busy)
            .padding(.top, 18)

            if let error = model.error {
                statusCard(icon: "exclamationmark.triangle.fill", tint: .red, title: "Could not connect", body: error)
                    .padding(.top, 12)
            }
        }
        .padding(18)
        .background(HermesTheme.canvas, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }

    private func field<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(HermesTheme.blue)
                .frame(width: fieldIconWidth)
            content()
                .font(.body)
                .foregroundStyle(.black)
        }
        .frame(minHeight: 44)
    }

    private func statusCard(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.black)
                Text(body).font(.subheadline).foregroundStyle(HermesTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(HermesTheme.canvas, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Label("Read-only workspace", systemImage: "eye")
                .font(.subheadline.weight(.semibold))
            Text("Approval decisions are records, not executed work. Sending messages and running agents are not available.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(HermesTheme.muted)
        .padding(.top, 8)
    }
}
