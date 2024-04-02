import Foundation

struct AccountsRemovedManually: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processAccountsRemoved(event: AccountsRemovedManually())
    }
}
