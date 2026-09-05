import HermesCore
import Foundation

let store = CompanyWorkspaceStore.seeded()
let company = store.selectedCompany!

print("Hermes company command center")
print("Company: \(company.name)")
print("CEO: \(company.ceo.name)")
print("Chats: \(store.visibleChats.count)")
print("Agents: \(store.agents(for: company.id).count)")
print("Org nodes: \(company.orgNodes.map { $0.title }.joined(separator: ", "))")
