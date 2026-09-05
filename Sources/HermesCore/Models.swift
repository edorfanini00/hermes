import Foundation

public struct WorkspaceSnapshot: Codable, Equatable, Sendable {
    public var companies: [Company]
    public var chats: [CompanyChat]
    public var agents: [CompanyAgent]
    public var selectedCompanyID: UUID?

    public init(companies: [Company], chats: [CompanyChat], agents: [CompanyAgent], selectedCompanyID: UUID?) {
        self.companies = companies
        self.chats = chats
        self.agents = agents
        self.selectedCompanyID = selectedCompanyID
    }
}

public struct Company: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var ceo: Person
    public var summary: String
    public var orgNodes: [OrgNode]
    public var orgEdges: [OrgEdge]

    public init(id: UUID = UUID(), name: String, ceo: Person, summary: String, orgNodes: [OrgNode], orgEdges: [OrgEdge]) {
        self.id = id
        self.name = name
        self.ceo = ceo
        self.summary = summary
        self.orgNodes = orgNodes
        self.orgEdges = orgEdges
    }

    public static func seed(name: String, ceoName: String) -> Company {
        let ceo = Person(name: ceoName, role: "CEO", email: nil)
        return Company(
            name: name,
            ceo: ceo,
            summary: "Company workspace for chats, agents, approvals, and structure.",
            orgNodes: [OrgNode(title: "CEO", person: ceoName)],
            orgEdges: []
        )
    }

    public static let celeritechID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    public static func celeritech() -> Company {
        Company(
            id: celeritechID,
            name: "Celeritech",
            ceo: Person(name: "Edoardo Orfanini", role: "CEO", email: "edoardo.orfanini@celeritech.biz"),
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
    public enum Channel: String, Codable, Sendable { case teams, email, asana, imessage, telegram, gohighlevel }
    public var id: UUID
    public var companyID: UUID
    public var title: String
    public var channel: Channel
    public var lastMessage: String
    public var unreadCount: Int
    public var priority: Bool

    public init(id: UUID = UUID(), companyID: UUID, title: String, channel: Channel, lastMessage: String = "", unreadCount: Int = 0, priority: Bool = false) {
        self.id = id
        self.companyID = companyID
        self.title = title
        self.channel = channel
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.priority = priority
    }

    public static func seed(companyID: UUID, title: String) -> CompanyChat {
        CompanyChat(companyID: companyID, title: title, channel: .teams, lastMessage: "Ready for approval workflow.")
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

public struct WorkspaceDatabase: Sendable {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    public static let decoder = JSONDecoder()

    public var url: URL

    public init(url: URL) {
        self.url = url
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
    public private(set) var companyAgents: [CompanyAgent]
    public private(set) var selectedCompanyID: UUID?

    public var selectedCompany: Company? {
        guard let selectedCompanyID else { return companies.first }
        return companies.first { $0.id == selectedCompanyID }
    }

    public var visibleChats: [CompanyChat] {
        guard let id = selectedCompany?.id else { return [] }
        return chats.filter { $0.companyID == id }.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority && !rhs.priority }
            return lhs.title < rhs.title
        }
    }

    public init(companies: [Company], chats: [CompanyChat], agents: [CompanyAgent], selectedCompanyID: UUID?) {
        self.companies = companies
        self.chats = chats
        self.companyAgents = agents
        self.selectedCompanyID = selectedCompanyID
    }

    public static func seeded() -> CompanyWorkspaceStore {
        let celeritech = Company.celeritech()
        return CompanyWorkspaceStore(
            companies: [celeritech],
            chats: [
                CompanyChat(companyID: celeritech.id, title: "Claudia / Management", channel: .teams, lastMessage: "Work requests become approval plans before action.", unreadCount: 0, priority: true),
                CompanyChat(companyID: celeritech.id, title: "All Teams", channel: .teams, lastMessage: "282 chats + 79 channels monitored.", unreadCount: 0),
                CompanyChat(companyID: celeritech.id, title: "Asana Video Reviews", channel: .asana, lastMessage: "New reviews ping Telegram + iMessage.", unreadCount: 0),
                CompanyChat(companyID: celeritech.id, title: "GoHighLevel CRM", channel: .gohighlevel, lastMessage: "CRM answers use the GHL dashboard/operator map.", unreadCount: 0)
            ],
            agents: [
                CompanyAgent(companyID: celeritech.id, name: "Approval Router", goal: "Send pings to Telegram and iMessage, wait for approval.", status: .waitingForApproval),
                CompanyAgent(companyID: celeritech.id, name: "CRM Agent", goal: "Answer GHL/CRM questions when known, after approval.", status: .planning),
                CompanyAgent(companyID: celeritech.id, name: "Teams Monitor", goal: "Watch all Teams chats with Claudia priority.", status: .running)
            ],
            selectedCompanyID: celeritech.id
        )
    }

    public func snapshot() -> WorkspaceSnapshot {
        WorkspaceSnapshot(companies: companies, chats: chats, agents: companyAgents, selectedCompanyID: selectedCompanyID)
    }

    public mutating func addCompany(_ company: Company) {
        companies.append(company)
    }

    public mutating func addChat(_ chat: CompanyChat) {
        chats.append(chat)
    }

    public mutating func selectCompany(id: UUID) {
        selectedCompanyID = id
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
