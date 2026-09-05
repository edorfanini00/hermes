import SwiftUI
#if canImport(HermesCore)
import HermesCore
#endif

@main
struct HermesApp: App {
    @State private var store = CompanyWorkspaceStore.loadOrSeed()

    var body: some Scene {
        WindowGroup {
            CompanyCommandCenterView(store: $store)
                .onChange(of: store) { _, newValue in
                    try? newValue.persist()
                }
        }
    }
}

struct CompanyCommandCenterView: View {
    @Binding var store: CompanyWorkspaceStore

    var body: some View {
        NavigationSplitView {
            CompanySidebar(store: $store)
        } content: {
            ChatListView(store: $store)
        } detail: {
            if store.selectedChat != nil {
                ChatThreadView(store: $store)
            } else {
                CompanyDetailView(store: $store)
            }
        }
    }
}

struct CompanySidebar: View {
    @Binding var store: CompanyWorkspaceStore

    var body: some View {
        List(selection: Binding(get: { store.selectedCompany?.id }, set: { if let id = $0 { store.selectCompany(id: id) } })) {
            Section("Companies") {
                ForEach(store.companies) { company in
                    VStack(alignment: .leading) {
                        Text(company.name).font(.headline)
                        Text("CEO: \(company.ceo.name)").font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(company.id)
                }
            }
        }
        .navigationTitle("Hermes")
    }
}

struct ChatListView: View {
    @Binding var store: CompanyWorkspaceStore

    var body: some View {
        List(selection: Binding(get: { store.selectedChatID }, set: { if let id = $0 { store.selectChat(id: id) } })) {
            ForEach(store.visibleChats) { chat in
                HStack(spacing: 12) {
                    Circle().fill(chat.priority ? Color.orange : Color.accentColor).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(chat.title).font(.headline)
                            if chat.pinned {
                                Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Text(chat.lastMessage).lineLimit(2).foregroundStyle(.secondary)
                        Text(chat.channel.rawValue.uppercased()).font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
                .tag(chat.id)
            }
        }
        .navigationTitle(store.selectedCompany?.name ?? "Chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Profile") {
                    store.clearChatSelection()
                }
            }
        }
    }
}

struct ChatThreadView: View {
    @Binding var store: CompanyWorkspaceStore
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            if let chat = store.selectedChat {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(store.messages(for: chat.id)) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: store.messages(for: chat.id).count) { _, _ in
                        if let last = store.messages(for: chat.id).last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    TextField("Message \(chat.title)", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    Button {
                        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !body.isEmpty else { return }
                        _ = store.addMessage(to: chat.id, sender: "Edoardo", body: body, status: .sent)
                        draft = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
            }
        }
        .navigationTitle(store.selectedChat?.title ?? "Chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct MessageBubble: View {
    var message: ChatMessage

    private var isOutgoing: Bool {
        message.status == .sent || message.sender == "Edoardo"
    }

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 48) }
            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                if !isOutgoing {
                    Text(message.sender).font(.caption2).foregroundStyle(.secondary)
                }
                Text(message.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isOutgoing ? Color.accentColor : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(isOutgoing ? .white : .primary)
                Text(message.status.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !isOutgoing { Spacer(minLength: 48) }
        }
    }
}

struct CompanyDetailView: View {
    @Binding var store: CompanyWorkspaceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let company = store.selectedCompany {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(company.name).font(.largeTitle.bold())
                        Text(company.summary).foregroundStyle(.secondary)
                        Text("CEO: \(company.profile.ceoName)").font(.headline)
                        Text(company.profile.mission).font(.subheadline)
                        Text(company.profile.operatingNotes).font(.caption).foregroundStyle(.secondary)
                        Text(company.profile.approvalRules).font(.caption.bold()).foregroundStyle(.blue)
                    }

                    AgentBoard(agents: store.agents(for: company.id))
                    OrgChart(company: company)

                    Button("Spin out CRM planning agent") {
                        _ = store.spawnAgent(name: "CRM Planning Agent", goal: "Read context and draft a plan for approval.")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
    }
}

struct AgentBoard: View {
    var agents: [CompanyAgent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agents").font(.title2.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], alignment: .leading) {
                ForEach(agents) { agent in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(agent.name).font(.headline)
                        Text(agent.goal).font(.caption).foregroundStyle(.secondary)
                        Text(agent.status.rawValue).font(.caption.bold()).padding(6).background(.thinMaterial).clipShape(Capsule())
                    }
                    .padding()
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

struct OrgChart: View {
    var company: Company

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Company Structure").font(.title2.bold())
            VStack(alignment: .leading, spacing: 10) {
                ForEach(company.orgNodes) { node in
                    HStack {
                        RoundedRectangle(cornerRadius: 10).fill(.blue.opacity(0.12)).frame(width: 10, height: 44)
                        VStack(alignment: .leading) {
                            Text(node.title).font(.headline)
                            Text(node.person).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Text(company.orgEdges.map { "\($0.parentTitle) → \($0.childTitle)" }.joined(separator: "   "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    @Previewable @State var store = CompanyWorkspaceStore.seeded()
    CompanyCommandCenterView(store: $store)
}
