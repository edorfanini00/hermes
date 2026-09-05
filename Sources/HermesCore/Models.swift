import Foundation

public struct WorkspaceSnapshot: Codable, Equatable, Sendable {
    public var companies: [Company]
    public var chats: [CompanyChat]
    public var messages: [ChatMessage]
    public var agents: [CompanyAgent]
    public var approvals: [ApprovalRequest]
    public var selectedCompanyID: UUID?
    public var selectedChatID: UUID?

    public init(
        companies: [Company],
        chats: [CompanyChat],
        messages: [ChatMessage] = [],
        agents: [CompanyAgent],
        approvals: [ApprovalRequest] = [],
        selectedCompanyID: UUID?,
        selectedChatID: UUID? = nil
    ) {
        self.companies = companies
        self.chats = chats
        self.messages = messages
        self.agents = agents
        self.approvals = approvals
        self.selectedCompanyID = selectedCompanyID
        self.selectedChatID = selectedChatID
    }
}

public struct CompanyProfile: Codable, Equatable, Sendable {
    public var companyID: UUID
    public var ceoName: String
    public var ceoTitle: String
    public var mission: String
    public var operatingNotes: String
    public var approvalRules: String

    public init(companyID: UUID, ceoName: String, ceoTitle: String, mission: String, operatingNotes: String, approvalRules: String) {
        self.companyID = companyID
        self.ceoName = ceoName
        self.ceoTitle = ceoTitle
        self.mission = mission
        self.operatingNotes = operatingNotes
        self.approvalRules = approvalRules
    }
}

public struct Company: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var ceo: Person
    public var profile: CompanyProfile
    public var summary: String
    public var orgNodes: [OrgNode]
    public var orgEdges: [OrgEdge]

    public init(
        id: UUID = UUID(),
        name: String,
        ceo: Person,
        profile: CompanyProfile? = nil,
        summary: String,
        orgNodes: [OrgNode],
        orgEdges: [OrgEdge]
    ) {
        self.id = id
        self.name = name
        self.ceo = ceo
        self.profile = profile ?? CompanyProfile(
            companyID: id,
            ceoName: ceo.name,
            ceoTitle: ceo.role,
            mission: summary,
            operatingNotes: "Company workspace for chats, structure, and agents.",
            approvalRules: "Ask for approval before external messages or business actions."
        )
        self.summary = summary
        self.orgNodes = orgNodes
        self.orgEdges = orgEdges
    }

    public static func seed(name: String, ceoName: String) -> Company {
        let id = UUID()
        let ceo = Person(name: ceoName, role: "CEO", email: nil)
        return Company(
            id: id,
            name: name,
            ceo: ceo,
            profile: CompanyProfile(
                companyID: id,
                ceoName: ceoName,
                ceoTitle: "CEO",
                mission: "Company workspace for chats, agents, approvals, and structure.",
                operatingNotes: "Future company profile placeholder.",
                approvalRules: "Ask for approval before action."
            ),
            summary: "Company workspace for chats, agents, approvals, and structure.",
            orgNodes: [OrgNode(title: "CEO", person: ceoName)],
            orgEdges: []
        )
    }

    public static let celeritechID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    public static func celeritech() -> Company {
        let ceo = Person(name: "Edoardo Orfanini", role: "CEO", email: "edoardo.orfanini@celeritech.biz")
        return Company(
            id: celeritechID,
            name: "Celeritech",
            ceo: ceo,
            profile: CompanyProfile(
                companyID: celeritechID,
                ceoName: "Edoardo Orfanini",
                ceoTitle: "CEO",
                mission: "Run Celeritech work through a company command center.",
                operatingNotes: "Claudia Ochoa is manager priority. Teams, email, Asana, GoHighLevel, Telegram, and iMessage feed approval workflows.",
                approvalRules: "Always ask Edoardo for approval before replying, moving CRM records, sending customer messages, or starting work."
            ),
            summary: "Celeritech command center for Teams, email, Asana, GoHighLevel, approvals, and operating agents.",
            orgNodes: [
                OrgNode(title: "CEO", person: "Edoardo Orfanini"),
                OrgNode(title: "Manager", person: "Claudia Ochoa"),
                OrgNode(title: "CRM / GoHighLevel", person: "Hermes CRM Agent"),
                OrgNode(title: "Content / Asana", person: "Hermes Content Agent"),
                OrgNode(title: "Messaging Gateway", person: "Hermes Approval Agent")
            ],
            orgEdges: [
                OrgEdge(parentTitle: "CEO", childTitle: "Manager"),
                OrgEdge(parentTitle: "CEO", childTitle: "CRM / GoHighLevel"),
                OrgEdge(parentTitle: "CEO", childTitle: "Content / Asana"),
                OrgEdge(parentTitle: "CEO", childTitle: "Messaging Gateway")
            ]
        )
    }
}

public struct Person: Codable, Equatable, Sendable {
    public var name: String
    public var role: String
    public var email: String?
    public init(name: String, role: String, email: String?) {
        self.name = name
        self.role = role
        self.email = email
    }
}

public struct OrgNode: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var person: String
    public init(id: UUID = UUID(), title: String, person: String) {
        self.id = id
        self.title = title
        self.person = person
    }
}

public struct OrgEdge: Codable, Equatable, Sendable {
    public var parentTitle: String
    public var childTitle: String
    public init(parentTitle: String, childTitle: String) {
        self.parentTitle = parentTitle
        self.childTitle = childTitle
    }
}

public struct CompanyChat: Identifiable, Codable, Equatable, Sendable {
    public enum Channel: String, Codable, Sendable, CaseIterable {
        case teams, email, asana, imessage, telegram, gohighlevel

        public var displayName: String {
            switch self {
            case .teams: "Teams"
            case .email: "Email"
            case .asana: "Asana"
            case .imessage: "iMessage"
            case .telegram: "Telegram"
            case .gohighlevel: "GoHighLevel"
            }
        }
    }

    public enum Kind: String, Codable, Sendable, CaseIterable {
        case general, approval, agent, project, direct

        public var displayName: String {
            switch self {
            case .general: "Group"
            case .approval: "Approvals"
            case .agent: "Agent"
            case .project: "Project"
            case .direct: "Direct"
            }
        }
    }

    public var id: UUID
    public var companyID: UUID
    public var title: String
    public var channel: Channel
    public var kind: Kind
    public var lastMessage: String
    public var lastMessageAt: Date?
    public var unreadCount: Int
    public var priority: Bool
    public var pinned: Bool

    public init(
        id: UUID = UUID(),
        companyID: UUID,
        title: String,
        channel: Channel,
        kind: Kind = .general,
        lastMessage: String = "",
        lastMessageAt: Date? = nil,
        unreadCount: Int = 0,
        priority: Bool = false,
        pinned: Bool = false
    ) {
        self.id = id
        self.companyID = companyID
        self.title = title
        self.channel = channel
        self.kind = kind
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.priority = priority
        self.pinned = pinned
    }

    public static func seed(companyID: UUID, title: String) -> CompanyChat {
        CompanyChat(companyID: companyID, title: title, channel: .teams, lastMessage: "Ready for approval workflow.", lastMessageAt: Date())
    }
}

/// Telegram-style folder filter applied on top of the company-scoped chat list.
public enum ChatFilter: String, CaseIterable, Codable, Sendable, Identifiable {
    case all, direct, agents, approvals

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: "All Chats"
        case .direct: "Direct"
        case .agents: "Agents"
        case .approvals: "Approvals"
        }
    }

    public func matches(_ chat: CompanyChat) -> Bool {
        switch self {
        case .all: true
        case .direct: chat.kind == .direct
        case .agents: chat.kind == .agent
        case .approvals: chat.kind == .approval
        }
    }
}

/// Deterministic helpers for avatar initials and colour selection.
public enum NameFormatting {
    public static func initials(for name: String) -> String {
        let words = name
            .split(whereSeparator: { $0.isWhitespace || $0 == "/" || $0 == "-" || $0 == "·" })
            .map(String.init)
            .filter { $0.contains { $0.isLetter || $0.isNumber } }
        let letters = words.prefix(2).compactMap { word in
            word.first { $0.isLetter || $0.isNumber }
        }
        if letters.isEmpty {
            return "?"
        }
        return String(letters).uppercased()
    }

    /// Stable across launches (unlike `hashValue`) so avatars keep their colour.
    public static func paletteIndex(for name: String, paletteCount: Int) -> Int {
        guard paletteCount > 0 else { return 0 }
        let sum = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return sum % paletteCount
    }
}

public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case received, sent, failed, pendingApproval }
    public var id: UUID
    public var companyID: UUID
    public var chatID: UUID
    public var sender: String
    public var body: String
    public var status: Status
    public var createdAt: Date
    /// Telegram-style quote reply: the message this one replies to, if any.
    public var quotedMessageID: UUID?

    public init(
        id: UUID = UUID(),
        companyID: UUID,
        chatID: UUID,
        sender: String,
        body: String,
        status: Status,
        createdAt: Date = Date(),
        quotedMessageID: UUID? = nil
    ) {
        self.id = id
        self.companyID = companyID
        self.chatID = chatID
        self.sender = sender
        self.body = body
        self.status = status
        self.createdAt = createdAt
        self.quotedMessageID = quotedMessageID
    }

    /// Messages authored by the CEO (or already marked as sent) render as outgoing bubbles.
    public func isOutgoing(ceoName: String) -> Bool {
        if status == .sent { return true }
        let first = ceoName.split(separator: " ").first.map(String.init) ?? ceoName
        return sender == ceoName || sender == first
    }
}

public struct CompanyAgent: Identifiable, Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case planning, waitingForApproval, running, blocked, complete }
    public var id: UUID
    public var companyID: UUID
    public var name: String
    public var goal: String
    public var status: Status

    public init(id: UUID = UUID(), companyID: UUID, name: String, goal: String, status: Status) {
        self.id = id
        self.companyID = companyID
        self.name = name
        self.goal = goal
        self.status = status
    }
}

public struct ApprovalRequest: Identifiable, Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case pending, approved, rejected, expired }
    public var id: UUID
    public var companyID: UUID
    public var chatID: UUID?
    public var title: String
    public var proposedAction: String
    public var status: Status
    public var createdAt: Date

    public init(id: UUID = UUID(), companyID: UUID, chatID: UUID?, title: String, proposedAction: String, status: Status = .pending, createdAt: Date = Date()) {
        self.id = id
        self.companyID = companyID
        self.chatID = chatID
        self.title = title
        self.proposedAction = proposedAction
        self.status = status
        self.createdAt = createdAt
    }
}

public struct WorkspaceDatabase: Sendable {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public var url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func defaultURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hermes", isDirectory: true)
            .appendingPathComponent("workspace.json")
    }

    public func save(_ snapshot: WorkspaceSnapshot) throws {
        let data = try Self.encoder.encode(snapshot)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    public func load() throws -> WorkspaceSnapshot {
        let data = try Data(contentsOf: url)
        return try Self.decoder.decode(WorkspaceSnapshot.self, from: data)
    }
}

public struct CompanyWorkspaceStore: Equatable, Sendable {
    public private(set) var companies: [Company]
    public private(set) var chats: [CompanyChat]
    public private(set) var chatMessages: [ChatMessage]
    public private(set) var companyAgents: [CompanyAgent]
    public private(set) var approvalRequests: [ApprovalRequest]
    public private(set) var selectedCompanyID: UUID?
    public private(set) var selectedChatID: UUID?

    public var selectedCompany: Company? {
        guard let selectedCompanyID else { return companies.first }
        return companies.first { $0.id == selectedCompanyID }
    }

    public var selectedChat: CompanyChat? {
        guard let selectedChatID else { return nil }
        return chats.first { $0.id == selectedChatID }
    }

    /// Company-scoped chats: pinned first, then priority, then most recent activity.
    public var visibleChats: [CompanyChat] {
        guard let id = selectedCompany?.id else { return [] }
        return chats.filter { $0.companyID == id }.sorted(by: Self.chatOrder)
    }

    public var pinnedChats: [CompanyChat] { visibleChats.filter(\.pinned) }
    public var regularChats: [CompanyChat] { visibleChats.filter { !$0.pinned } }

    public func visibleChats(matching filter: ChatFilter, search: String = "") -> [CompanyChat] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return visibleChats.filter { chat in
            guard filter.matches(chat) else { return false }
            guard !query.isEmpty else { return true }
            return chat.title.localizedCaseInsensitiveContains(query)
                || chat.lastMessage.localizedCaseInsensitiveContains(query)
        }
    }

    public func unreadCount(matching filter: ChatFilter = .all) -> Int {
        visibleChats(matching: filter).reduce(0) { $0 + $1.unreadCount }
    }

    private static func chatOrder(_ lhs: CompanyChat, _ rhs: CompanyChat) -> Bool {
        if lhs.pinned != rhs.pinned { return lhs.pinned }
        if lhs.priority != rhs.priority { return lhs.priority }
        let lhsDate = lhs.lastMessageAt ?? .distantPast
        let rhsDate = rhs.lastMessageAt ?? .distantPast
        if lhsDate != rhsDate { return lhsDate > rhsDate }
        return lhs.title < rhs.title
    }

    public init(
        companies: [Company],
        chats: [CompanyChat],
        messages: [ChatMessage] = [],
        agents: [CompanyAgent],
        approvals: [ApprovalRequest] = [],
        selectedCompanyID: UUID?,
        selectedChatID: UUID? = nil
    ) {
        self.companies = companies
        self.chats = chats
        self.chatMessages = messages
        self.companyAgents = agents
        self.approvalRequests = approvals
        self.selectedCompanyID = selectedCompanyID
        self.selectedChatID = selectedChatID
    }

    public init(snapshot: WorkspaceSnapshot) {
        self.init(
            companies: snapshot.companies,
            chats: snapshot.chats,
            messages: snapshot.messages,
            agents: snapshot.agents,
            approvals: snapshot.approvals,
            selectedCompanyID: snapshot.selectedCompanyID,
            selectedChatID: snapshot.selectedChatID
        )
    }

    public static func seeded(now: Date = Date()) -> CompanyWorkspaceStore {
        let celeritech = Company.celeritech()
        let minute: TimeInterval = 60
        let hour: TimeInterval = 3600
        let day: TimeInterval = 86_400

        let management = CompanyChat(
            companyID: celeritech.id,
            title: "Claudia / Management",
            channel: .teams,
            kind: .approval,
            lastMessage: "Draft plan ready — approve to re-trigger the two stalled follow-ups and reply to Claudia.",
            lastMessageAt: now.addingTimeInterval(-12 * minute),
            unreadCount: 1,
            priority: true,
            pinned: true
        )
        let claudiaDirect = CompanyChat(
            companyID: celeritech.id,
            title: "Claudia Ochoa",
            channel: .imessage,
            kind: .direct,
            lastMessage: "Ping me on iMessage when the plan is ready 🙏",
            lastMessageAt: now.addingTimeInterval(-47 * minute),
            unreadCount: 1,
            pinned: true
        )
        let agents = CompanyChat(
            companyID: celeritech.id,
            title: "Hermes Agents",
            channel: .telegram,
            kind: .agent,
            lastMessage: "CRM Agent finished planning. Waiting for approval.",
            lastMessageAt: now.addingTimeInterval(-2 * hour),
            unreadCount: 2
        )
        let allTeams = CompanyChat(
            companyID: celeritech.id,
            title: "All Teams",
            channel: .teams,
            kind: .general,
            lastMessage: "282 chats + 79 channels monitored.",
            lastMessageAt: now.addingTimeInterval(-5 * hour)
        )
        let asana = CompanyChat(
            companyID: celeritech.id,
            title: "Asana Video Reviews",
            channel: .asana,
            kind: .project,
            lastMessage: "New reviews ping Telegram + iMessage.",
            lastMessageAt: now.addingTimeInterval(-1 * day - 3 * hour)
        )
        let crm = CompanyChat(
            companyID: celeritech.id,
            title: "GoHighLevel CRM",
            channel: .gohighlevel,
            kind: .project,
            lastMessage: "CRM answers use the GHL dashboard/operator map.",
            lastMessageAt: now.addingTimeInterval(-3 * day)
        )
        let chats = [management, claudiaDirect, agents, allTeams, asana, crm]

        let claudiaAsk = ChatMessage(
            companyID: celeritech.id,
            chatID: management.id,
            sender: "Claudia Ochoa",
            body: "Can you check the GoHighLevel workflow for the new video review leads? Two of them didn't get the follow-up email.",
            status: .received,
            createdAt: now.addingTimeInterval(-1 * day - 2 * hour)
        )
        let messages = [
            ChatMessage(
                companyID: celeritech.id,
                chatID: management.id,
                sender: "Hermes",
                body: "Celeritech workspace is ready. Claudia requests require approval before action.",
                status: .received,
                createdAt: now.addingTimeInterval(-2 * day - 4 * hour)
            ),
            claudiaAsk,
            ChatMessage(
                companyID: celeritech.id,
                chatID: management.id,
                sender: "Edoardo",
                body: "On it — Hermes will draft a plan first and I'll approve before anything moves in the CRM.",
                status: .sent,
                createdAt: now.addingTimeInterval(-1 * day - 1 * hour - 40 * minute),
                quotedMessageID: claudiaAsk.id
            ),
            ChatMessage(
                companyID: celeritech.id,
                chatID: management.id,
                sender: "Hermes",
                body: "Draft plan ready — approve to re-trigger the two stalled follow-ups and reply to Claudia.",
                status: .pendingApproval,
                createdAt: now.addingTimeInterval(-12 * minute)
            ),
            ChatMessage(
                companyID: celeritech.id,
                chatID: claudiaDirect.id,
                sender: "Claudia Ochoa",
                body: "Ping me on iMessage when the plan is ready 🙏",
                status: .received,
                createdAt: now.addingTimeInterval(-47 * minute)
            ),
            ChatMessage(
                companyID: celeritech.id,
                chatID: agents.id,
                sender: "Teams Monitor",
                body: "Watching 282 chats. Claudia flagged as priority.",
                status: .received,
                createdAt: now.addingTimeInterval(-3 * hour)
            ),
            ChatMessage(
                companyID: celeritech.id,
                chatID: agents.id,
                sender: "CRM Agent",
                body: "CRM Agent finished planning. Waiting for approval.",
                status: .received,
                createdAt: now.addingTimeInterval(-2 * hour)
            ),
            ChatMessage(
                companyID: celeritech.id,
                chatID: allTeams.id,
                sender: "Hermes",
                body: "282 chats + 79 channels monitored.",
                status: .received,
                createdAt: now.addingTimeInterval(-5 * hour)
            ),
            ChatMessage(
                companyID: celeritech.id,
                chatID: asana.id,
                sender: "Hermes",
                body: "New reviews ping Telegram + iMessage.",
                status: .received,
                createdAt: now.addingTimeInterval(-1 * day - 3 * hour)
            ),
            ChatMessage(
                companyID: celeritech.id,
                chatID: crm.id,
                sender: "Hermes",
                body: "CRM answers use the GHL dashboard/operator map.",
                status: .received,
                createdAt: now.addingTimeInterval(-3 * day)
            )
        ]

        return CompanyWorkspaceStore(
            companies: [celeritech],
            chats: chats,
            messages: messages,
            agents: [
                CompanyAgent(companyID: celeritech.id, name: "Approval Router", goal: "Send pings to Telegram and iMessage, wait for approval.", status: .waitingForApproval),
                CompanyAgent(companyID: celeritech.id, name: "CRM Agent", goal: "Answer GHL/CRM questions when known, after approval.", status: .planning),
                CompanyAgent(companyID: celeritech.id, name: "Teams Monitor", goal: "Watch all Teams chats with Claudia priority.", status: .running)
            ],
            approvals: [
                ApprovalRequest(
                    companyID: celeritech.id,
                    chatID: management.id,
                    title: "Re-trigger video review follow-ups",
                    proposedAction: "Audit the “Video Review Follow-up” workflow in GoHighLevel, re-trigger the two stalled contacts, then reply to Claudia in Teams.",
                    createdAt: now.addingTimeInterval(-12 * minute)
                )
            ],
            selectedCompanyID: celeritech.id,
            selectedChatID: management.id
        )
    }

    public static func loadOrSeed(databaseURL: URL = WorkspaceDatabase.defaultURL()) -> CompanyWorkspaceStore {
        let database = WorkspaceDatabase(url: databaseURL)
        if let snapshot = try? database.load() {
            return CompanyWorkspaceStore(snapshot: snapshot)
        }
        let seeded = CompanyWorkspaceStore.seeded()
        try? database.save(seeded.snapshot())
        return seeded
    }

    public func persist(to databaseURL: URL = WorkspaceDatabase.defaultURL()) throws {
        try WorkspaceDatabase(url: databaseURL).save(snapshot())
    }

    public func snapshot() -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            companies: companies,
            chats: chats,
            messages: chatMessages,
            agents: companyAgents,
            approvals: approvalRequests,
            selectedCompanyID: selectedCompanyID,
            selectedChatID: selectedChatID
        )
    }

    public mutating func addCompany(_ company: Company) {
        companies.append(company)
    }

    public mutating func addChat(_ chat: CompanyChat) {
        chats.append(chat)
    }

    public mutating func selectCompany(id: UUID) {
        selectedCompanyID = id
        if let selectedChatID,
           let chat = chats.first(where: { $0.id == selectedChatID }),
           chat.companyID == id {
            return
        }
        selectedChatID = chats.first { $0.companyID == id }?.id
    }

    public mutating func selectChat(id: UUID) {
        selectedChatID = id
        if let chat = chats.first(where: { $0.id == id }) {
            selectedCompanyID = chat.companyID
        }
    }

    public mutating func clearChatSelection() {
        selectedChatID = nil
    }

    public mutating func markChatRead(id: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[index].unreadCount = 0
    }

    public mutating func setPinned(chatID: UUID, _ pinned: Bool) {
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }
        chats[index].pinned = pinned
    }

    public mutating func togglePinned(chatID: UUID) {
        guard let chat = chats.first(where: { $0.id == chatID }) else { return }
        setPinned(chatID: chatID, !chat.pinned)
    }

    @discardableResult
    public mutating func addMessage(
        to chatID: UUID,
        sender: String,
        body: String,
        status: ChatMessage.Status = .received,
        quoting quotedMessageID: UUID? = nil
    ) -> ChatMessage {
        let companyID = chats.first { $0.id == chatID }?.companyID ?? selectedCompany?.id ?? Company.celeritechID
        let message = ChatMessage(
            companyID: companyID,
            chatID: chatID,
            sender: sender,
            body: body,
            status: status,
            quotedMessageID: quotedMessageID
        )
        chatMessages.append(message)
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].lastMessage = body
            chats[index].lastMessageAt = message.createdAt
            chats[index].unreadCount = status == .received ? chats[index].unreadCount + 1 : 0
        }
        return message
    }

    public func messages(for chatID: UUID) -> [ChatMessage] {
        chatMessages.filter { $0.chatID == chatID }.sorted { $0.createdAt < $1.createdAt }
    }

    public func message(id: UUID) -> ChatMessage? {
        chatMessages.first { $0.id == id }
    }

    @discardableResult
    public mutating func requestApproval(companyID: UUID, chatID: UUID?, title: String, proposedAction: String) -> ApprovalRequest {
        let request = ApprovalRequest(companyID: companyID, chatID: chatID, title: title, proposedAction: proposedAction)
        approvalRequests.append(request)
        return request
    }

    public mutating func resolveApproval(id: UUID, status: ApprovalRequest.Status) {
        guard let index = approvalRequests.firstIndex(where: { $0.id == id }) else { return }
        approvalRequests[index].status = status
    }

    public func approvals(for companyID: UUID) -> [ApprovalRequest] {
        approvalRequests.filter { $0.companyID == companyID }.sorted { $0.createdAt < $1.createdAt }
    }

    public func pendingApprovals(forChat chatID: UUID) -> [ApprovalRequest] {
        approvalRequests
            .filter { $0.chatID == chatID && $0.status == .pending }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    public mutating func spawnAgent(name: String, goal: String) -> CompanyAgent {
        let companyID = selectedCompany?.id ?? Company.celeritechID
        let agent = CompanyAgent(companyID: companyID, name: name, goal: goal, status: .planning)
        companyAgents.append(agent)
        return agent
    }

    public func agents(for companyID: UUID) -> [CompanyAgent] {
        companyAgents.filter { $0.companyID == companyID }
    }
}
