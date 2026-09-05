import SwiftUI
#if canImport(HermesCore)
import HermesCore
#endif

@main
struct HermesApp: App {
    @State private var store = CompanyWorkspaceStore.loadOrSeed()

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("--screenshot-thread") {
                ScreenshotThreadRoot(store: $store)
            } else if ProcessInfo.processInfo.arguments.contains("--screenshot-profile") {
                CompanyProfileView(store: $store)
            } else {
                HermesRootView(store: $store)
            }
        }
        .environment(\.colorScheme, .light)
    }
}

struct ScreenshotThreadRoot: View {
    @Binding var store: CompanyWorkspaceStore

    var body: some View {
        NavigationStack {
            if let chatID = store.visibleChats.first?.id {
                ChatThreadView(store: $store, chatID: chatID)
            }
        }
        .tint(HermesTheme.blue)
    }
}

struct HermesRootView: View {
    @Binding var store: CompanyWorkspaceStore
    @State private var selectedTab = 2

    var body: some View {
        TabView(selection: $selectedTab) {
            PlaceholderTab(title: "Contacts", icon: "person.2.fill", detail: "Company people, clients, and agents will live here.")
                .tabItem { Label("Contacts", systemImage: "person.2") }
                .tag(0)
            PlaceholderTab(title: "Calls", icon: "phone.fill", detail: "Future voice approvals and company calls.")
                .tabItem { Label("Calls", systemImage: "phone") }
                .tag(1)
            ChatsHomeView(store: $store)
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(2)
            CompanyProfileView(store: $store)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(HermesTheme.blue)
    }
}

struct ChatsHomeView: View {
    @Binding var store: CompanyWorkspaceStore
    @State private var searchText = ""
    @State private var filter: ChatFilter = .all

    private var filteredChats: [CompanyChat] {
        store.visibleChats(matching: filter, search: searchText)
    }

    private var pinned: [CompanyChat] { filteredChats.filter(\.pinned) }
    private var regular: [CompanyChat] { filteredChats.filter { !$0.pinned } }

    var body: some View {
        NavigationStack {
            ZStack {
                HermesTheme.canvas.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        HeaderChrome(store: $store, searchText: $searchText, filter: $filter)
                            .padding(.bottom, 8)

                        if !pinned.isEmpty {
                            PinnedStrip(store: $store, chats: pinned)
                                .padding(.bottom, 8)
                        }

                        VStack(spacing: 0) {
                            ForEach(regular) { chat in
                                NavigationLink {
                                    ChatThreadView(store: $store, chatID: chat.id)
                                } label: {
                                    ChatRow(chat: chat)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 72)
                            }
                        }
                        .background(HermesTheme.canvas)
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") { }
                        .font(.system(size: 17))
                        .foregroundStyle(HermesTheme.blue)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .foregroundStyle(HermesTheme.blue)
                }
                #else
                ToolbarItem {
                    Button("Edit") { }
                        .font(.system(size: 17))
                        .foregroundStyle(HermesTheme.blue)
                }
                ToolbarItem {
                    Button { } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .foregroundStyle(HermesTheme.blue)
                }
                #endif
            }
            .hermesGlassChrome()
        }
    }
}

struct HeaderChrome: View {
    @Binding var store: CompanyWorkspaceStore
    @Binding var searchText: String
    @Binding var filter: ChatFilter

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Chats")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                Text(store.selectedCompany?.name ?? "Company")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HermesTheme.muted)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.companies) { company in
                        CompanyPill(company: company, selected: store.selectedCompany?.id == company.id) {
                            store.selectCompany(id: company.id)
                        }
                    }
                    AddCompanyPill()
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(HermesTheme.muted)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(HermesTheme.subtle)
                    }
                }
            }
            .font(.system(size: 17))
            .frame(height: 36)
            .padding(.horizontal, 12)
            .background(HermesTheme.fieldFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChatFilter.allCases) { option in
                        Button {
                            withAnimation(.snappy) { filter = option }
                        } label: {
                            Text(option.title)
                                .font(.system(size: 15, weight: filter == option ? .semibold : .regular))
                                .foregroundStyle(filter == option ? .white : HermesTheme.blue)
                                .padding(.horizontal, 14)
                                .frame(height: 30)
                                .background(filter == option ? HermesTheme.blue : HermesTheme.pillFill, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 4)
        .background(.ultraThinMaterial)
    }
}

struct CompanyPill: View {
    var company: Company
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Avatar(name: company.name, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(company.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text("CEO · \(company.profile.ceoName)")
                        .font(.system(size: 11))
                        .foregroundStyle(selected ? .white.opacity(0.82) : HermesTheme.muted)
                }
            }
            .foregroundStyle(selected ? .white : .primary)
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(selected ? HermesTheme.blue : HermesTheme.pillFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct AddCompanyPill: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(HermesTheme.fieldFill, in: Circle())
            Text("Add Company")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(HermesTheme.blue)
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(HermesTheme.pillFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PinnedStrip: View {
    @Binding var store: CompanyWorkspaceStore
    var chats: [CompanyChat]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(chats) { chat in
                    NavigationLink {
                        ChatThreadView(store: $store, chatID: chat.id)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                Avatar(name: chat.title, size: 58)
                                if chat.unreadCount > 0 {
                                    UnreadBadge(count: chat.unreadCount)
                                        .offset(x: 4, y: -4)
                                }
                            }
                            Text(chat.title.replacingOccurrences(of: " / ", with: "\n"))
                                .font(.system(size: 12, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: 72)
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

struct ChatRow: View {
    var chat: CompanyChat

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(name: chat.title, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.title)
                        .font(.chatName)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if chat.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(HermesTheme.subtle)
                    }
                    Spacer()
                    Text(HermesTimeFormatting.chatListTime(chat.lastMessageAt))
                        .font(.chatTime)
                        .foregroundStyle(chat.unreadCount > 0 ? HermesTheme.blue : HermesTheme.muted)
                }
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(chat.lastMessage)
                            .font(.chatPreview)
                            .foregroundStyle(HermesTheme.muted)
                            .lineLimit(2)
                        Text("\(chat.channel.displayName) · \(chat.kind.displayName)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HermesTheme.subtle)
                    }
                    Spacer(minLength: 8)
                    if chat.unreadCount > 0 {
                        UnreadBadge(count: chat.unreadCount)
                    }
                }
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(HermesTheme.canvas)
    }
}

struct ChatThreadView: View {
    @Binding var store: CompanyWorkspaceStore
    var chatID: UUID
    @State private var draft = ""

    private var chat: CompanyChat? { store.chats.first { $0.id == chatID } }
    private var company: Company? { store.selectedCompany }
    private var messages: [ChatMessage] { store.messages(for: chatID) }

    var body: some View {
        VStack(spacing: 0) {
            if let chat, let company {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            DateSeparator(title: "Today")
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    ceoName: company.profile.ceoName,
                                    quote: quoteText(for: message)
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                    }
                    .background(ChatWallpaper())
                    .onAppear {
                        if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }

                ComposerBar(draft: $draft, chatTitle: chat.title) {
                    let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !body.isEmpty else { return }
                    _ = store.addMessage(to: chat.id, sender: company.profile.ceoName, body: body, status: .sent)
                    draft = ""
                }
            }
        }
        .navigationTitle(chat?.title ?? "Chat")
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let chat {
                    HStack(spacing: 9) {
                        Avatar(name: chat.title, size: 32)
                        VStack(spacing: 0) {
                            Text(chat.title).font(.navTitle)
                            Text(chat.channel.displayName).font(.navSubtitle).foregroundStyle(HermesTheme.muted)
                        }
                    }
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "ellipsis.circle").foregroundStyle(HermesTheme.blue)
            }
            #else
            ToolbarItem {
                Image(systemName: "ellipsis.circle").foregroundStyle(HermesTheme.blue)
            }
            #endif
        }
        .inlineNavigationTitle()
        .hermesGlassChrome()
    }

    private func quoteText(for message: ChatMessage) -> String? {
        guard let quoted = message.quotedMessageID,
              let original = messages.first(where: { $0.id == quoted }) else { return nil }
        return original.body
    }
}

struct MessageBubble: View {
    var message: ChatMessage
    var ceoName: String
    var quote: String?

    private var isOutgoing: Bool { message.isOutgoing(ceoName: ceoName) }
    private var bubbleAlignment: Alignment { isOutgoing ? .trailing : .leading }

    var body: some View {
        HStack(alignment: .bottom) {
            if isOutgoing { Spacer(minLength: 54) }
            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 3) {
                if !isOutgoing {
                    Text(message.sender)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HermesTheme.avatarColor(for: message.sender))
                        .padding(.leading, 10)
                }
                VStack(alignment: .leading, spacing: 6) {
                    if let quote {
                        QuotePreview(sender: message.sender, text: quote)
                    }
                    Text(message.body)
                        .font(.bubbleBody)
                        .lineSpacing(2)
                    HStack(spacing: 3) {
                        Text(HermesTimeFormatting.clockTime(message.createdAt))
                            .font(.bubbleMeta)
                        if isOutgoing { Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)) }
                        if message.status == .pendingApproval { Text("approval").font(.bubbleMeta.weight(.semibold)) }
                    }
                    .foregroundStyle(isOutgoing ? HermesTheme.deepBlue.opacity(0.75) : HermesTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, HermesTheme.bubbleHorizontalPadding)
                .padding(.vertical, HermesTheme.bubbleVerticalPadding)
                .background {
                    if isOutgoing {
                        RoundedRectangle(cornerRadius: HermesTheme.bubbleRadius, style: .continuous)
                            .fill(HermesTheme.outgoingGradient)
                    } else {
                        RoundedRectangle(cornerRadius: HermesTheme.bubbleRadius, style: .continuous)
                            .fill(HermesTheme.incomingBubble)
                            .stroke(HermesTheme.hairline, lineWidth: 1)
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: 305, alignment: bubbleAlignment)
            }
            if !isOutgoing { Spacer(minLength: 54) }
        }
    }
}

struct QuotePreview: View {
    var sender: String
    var text: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(HermesTheme.avatarColor(for: sender))
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(sender)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HermesTheme.avatarColor(for: sender))
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(HermesTheme.muted)
                    .lineLimit(1)
            }
        }
        .frame(height: 34)
    }
}

struct ComposerBar: View {
    @Binding var draft: String
    var chatTitle: String
    var send: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "paperclip")
                .font(.system(size: 21))
                .foregroundStyle(HermesTheme.muted)
            TextField("Message", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(HermesTheme.canvas, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(HermesTheme.hairline, lineWidth: 1))
            Button(action: send) {
                Image(systemName: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(HermesTheme.blue)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

struct DateSeparator: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.38), in: Capsule())
            .padding(.vertical, 6)
    }
}

struct ChatWallpaper: View {
    var body: some View {
        ZStack {
            Color(hex: 0xDBE7F4).ignoresSafeArea()
            GeometryReader { proxy in
                let width = proxy.size.width
                let columns = max(Int(width / 46), 1)
                let rows = max(Int(proxy.size.height / 46) + 2, 1)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(46), spacing: 0), count: columns), spacing: 0) {
                    ForEach(0..<(rows * columns), id: \.self) { index in
                        Image(systemName: index.isMultiple(of: 3) ? "paperplane.fill" : "circle")
                            .font(.system(size: index.isMultiple(of: 3) ? 9 : 4))
                            .foregroundStyle(Color.white.opacity(0.18))
                            .frame(width: 46, height: 46)
                    }
                }
            }
        }
    }
}

struct CompanyProfileView: View {
    @Binding var store: CompanyWorkspaceStore

    var body: some View {
        NavigationStack {
            ScrollView {
                if let company = store.selectedCompany {
                    VStack(spacing: 10) {
                        VStack(spacing: 10) {
                            Avatar(name: company.name, size: 86)
                            Text(company.name).font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.black)
                            Text("CEO · \(company.profile.ceoName)")
                                .font(.system(size: 15))
                                .foregroundStyle(HermesTheme.muted)
                            Text(company.profile.mission)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 22)

                        ApprovalRuleCard(company: company, pending: store.approvals(for: company.id).filter { $0.status == .pending }.count)
                        AgentBoard(agents: store.agents(for: company.id))
                        OrgChart(company: company)

                        Button {
                            _ = store.spawnAgent(name: "CRM Planning Agent", goal: "Read context and draft a plan for approval.")
                        } label: {
                            Label("Spin out CRM planning agent", systemImage: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(HermesTheme.blue)
                    }
                    .padding(16)
                }
            }
            .background(HermesTheme.groupedCanvas.ignoresSafeArea())
            .navigationTitle("Company")
            .hermesGlassChrome()
        }
    }
}

struct ApprovalRuleCard: View {
    var company: Company
    var pending: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(HermesTheme.blue)
                Text("Approval Rules").font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("\(pending) pending")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(HermesTheme.blue, in: Capsule())
            }
            Text(company.profile.approvalRules)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .cardSurface()
    }
}

struct AgentBoard: View {
    var agents: [CompanyAgent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agents").font(.system(size: 20, weight: .bold))
            ForEach(agents) { agent in
                HStack(spacing: 12) {
                    Avatar(name: agent.name, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(agent.name).font(.system(size: 16, weight: .semibold))
                        Text(agent.goal).font(.system(size: 13)).foregroundStyle(HermesTheme.muted).lineLimit(2)
                    }
                    Spacer()
                    Text(agent.status.telegramLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(HermesTheme.pillFill, in: Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(16)
        .cardSurface()
    }
}

private extension CompanyAgent.Status {
    var telegramLabel: String {
        switch self {
        case .planning: "planning"
        case .waitingForApproval: "waiting"
        case .running: "running"
        case .blocked: "blocked"
        case .complete: "done"
        }
    }
}

struct OrgChart: View {
    var company: Company

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Company Structure").font(.system(size: 20, weight: .bold))
            VStack(spacing: 10) {
                ForEach(company.orgNodes) { node in
                    HStack(spacing: 12) {
                        Avatar(name: node.person, size: node.title == "CEO" ? 48 : 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.title).font(.system(size: 16, weight: .semibold))
                            Text(node.person).font(.system(size: 13)).foregroundStyle(HermesTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(node.title == "CEO" ? HermesTheme.blue.opacity(0.10) : HermesTheme.pillFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            Text(company.orgEdges.map { "\($0.parentTitle) → \($0.childTitle)" }.joined(separator: "   "))
                .font(.system(size: 12))
                .foregroundStyle(HermesTheme.muted)
        }
        .padding(16)
        .cardSurface()
    }
}

struct Avatar: View {
    var name: String
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(HermesTheme.avatarColor(for: name))
            Text(NameFormatting.initials(for: name))
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct UnreadBadge: View {
    var count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(HermesTheme.blue, in: Capsule())
    }
}

struct PlaceholderTab: View {
    var title: String
    var icon: String
    var detail: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 38))
                    .foregroundStyle(HermesTheme.blue)
                Text(title).font(.title2.bold())
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HermesTheme.groupedCanvas.ignoresSafeArea())
            .navigationTitle(title)
        }
    }
}

extension View {
    func cardSurface() -> some View {
        self
            .foregroundStyle(.black)
            .background(HermesTheme.canvas, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(HermesTheme.hairline, lineWidth: 1))
    }
}

#Preview("Chats") {
    @Previewable @State var store = CompanyWorkspaceStore.seeded()
    HermesRootView(store: $store)
}

#Preview("Thread") {
    @Previewable @State var store = CompanyWorkspaceStore.seeded()
    ChatThreadView(store: $store, chatID: store.visibleChats.first!.id)
}
