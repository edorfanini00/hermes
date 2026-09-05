import Foundation
import Testing
@testable import HermesCore

@Test func seedsCeleritechAsFirstCompany() throws {
    let store = CompanyWorkspaceStore.seeded()
    #expect(store.companies.count == 1)
    #expect(store.companies.first?.name == "Celeritech")
    #expect(store.selectedCompany?.ceo.name == "Edoardo Orfanini")
}

@Test func filtersChatsBySelectedCompany() throws {
    var store = CompanyWorkspaceStore.seeded()
    let other = Company.seed(name: "Future Company", ceoName: "Future CEO")
    store.addCompany(other)
    store.addChat(CompanyChat.seed(companyID: other.id, title: "Future Ops"))

    store.selectCompany(id: other.id)

    #expect(store.visibleChats.allSatisfy { $0.companyID == other.id })
    #expect(store.visibleChats.map(\.title).contains("Future Ops"))
    #expect(!store.visibleChats.map(\.title).contains("Claudia / Management"))
}

@Test func agentSpawnCreatesCompanyScopedAgent() throws {
    var store = CompanyWorkspaceStore.seeded()
    let companyID = try #require(store.selectedCompany?.id)

    let agent = store.spawnAgent(name: "CRM Research Agent", goal: "Answer Claudia's GHL workflow question")

    #expect(agent.companyID == companyID)
    #expect(agent.status == .planning)
    #expect(store.agents(for: companyID).contains { $0.id == agent.id })
}

@Test func orgChartContainsCeleritechLeadershipAndOperations() throws {
    let store = CompanyWorkspaceStore.seeded()
    let company = try #require(store.selectedCompany)

    #expect(company.orgNodes.contains { $0.title == "CEO" && $0.person == "Edoardo Orfanini" })
    #expect(company.orgNodes.contains { $0.title == "Manager" && $0.person == "Claudia Ochoa" })
    #expect(company.orgEdges.contains { $0.parentTitle == "CEO" && $0.childTitle == "Manager" })
}

@Test func localDatabaseRoundTripsWorkspace() throws {
    let store = CompanyWorkspaceStore.seeded()
    let data = try WorkspaceDatabase.encoder.encode(store.snapshot())
    let decoded = try WorkspaceDatabase.decoder.decode(WorkspaceSnapshot.self, from: data)

    #expect(decoded.companies.first?.name == "Celeritech")
    #expect(decoded.chats.count >= 3)
    #expect(decoded.agents.contains { $0.name.contains("Approval") })
}

@Test func companyProfileCarriesApprovalRulesAndOperatingNotes() throws {
    let store = CompanyWorkspaceStore.seeded()
    let company = try #require(store.selectedCompany)

    #expect(company.profile.ceoName == "Edoardo Orfanini")
    #expect(company.profile.approvalRules.contains("approval"))
    #expect(company.profile.operatingNotes.contains("Claudia"))
}

@Test func chatMessagesAndApprovalRequestsAreCompanyScoped() throws {
    var store = CompanyWorkspaceStore.seeded()
    let companyID = try #require(store.selectedCompany?.id)
    let chatID = try #require(store.visibleChats.first?.id)

    let message = store.addMessage(
        to: chatID,
        sender: "Claudia Ochoa",
        body: "Can you check this CRM workflow?",
        status: .pendingApproval
    )
    let approval = store.requestApproval(
        companyID: companyID,
        chatID: chatID,
        title: "CRM workflow question",
        proposedAction: "Review GoHighLevel workflow and draft Edoardo-style reply."
    )

    #expect(message.companyID == companyID)
    #expect(store.messages(for: chatID).contains { $0.body.contains("CRM workflow") })
    #expect(approval.status == .pending)
    #expect(store.approvals(for: companyID).contains { $0.id == approval.id })
}

@Test func localDatabasePersistsSelectedChatAndMessages() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("hermes-workspace-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }

    var store = CompanyWorkspaceStore.seeded()
    let chatID = try #require(store.visibleChats.first?.id)
    store.selectChat(id: chatID)
    _ = store.addMessage(to: chatID, sender: "Edoardo", body: "Approved — proceed.", status: .sent)
    try store.persist(to: url)

    let reloaded = CompanyWorkspaceStore.loadOrSeed(databaseURL: url)
    #expect(reloaded.selectedChatID == chatID)
    #expect(reloaded.messages(for: chatID).contains { $0.body.contains("Approved") })
    #expect(reloaded.chats.first { $0.id == chatID }?.lastMessage.contains("Approved") == true)
}
