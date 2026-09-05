import SwiftUI
import HermesCore

@main
struct HermesApp: App {
    @State private var store = CompanyWorkspaceStore.seeded()

    var body: some Scene {
        WindowGroup {
            CompanyCommandCenterView(store: $store)
        }
    }
}

struct CompanyCommandCenterView: View {
    @Binding var store: CompanyWorkspaceStore

    var body: some View {
        NavigationSplitView {
            CompanySidebar(store: $store)
        } content: {
            ChatListView(store: store)
        } detail: {
            CompanyDetailView(store: $store)
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
    var store: CompanyWorkspaceStore

    var body: some View {
        List(store.visibleChats) { chat in
            HStack(spacing: 12) {
                Circle().fill(chat.priority ? .orange : .blue).frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 4) {
                    Text(chat.title).font(.headline)
                    Text(chat.lastMessage).lineLimit(2).foregroundStyle(.secondary)
                    Text(chat.channel.rawValue.uppercased()).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                if chat.unreadCount > 0 {
                    Text("\(chat.unreadCount)").font(.caption).padding(6).background(.blue).foregroundStyle(.white).clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle(store.selectedCompany?.name ?? "Chats")
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
