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
