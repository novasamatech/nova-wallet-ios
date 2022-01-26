import Foundation

struct TransferInfoContext {
    static let accountStateKey = "transfer.info.account.state.key"

    let balanceContext: BalanceContext
    let accountWillBeDead: Bool
}

extension TransferInfoContext {
    init(context: [String: String]) {
        balanceContext = BalanceContext(context: context)

        if let boolString = context[Self.accountStateKey], let value = Bool(boolString) {
            accountWillBeDead = value
        } else {
            accountWillBeDead = false
        }
    }

    func toContext() -> [String: String] {
        var context = balanceContext.toContext()
        context[Self.accountStateKey] = String(accountWillBeDead)
        return context
    }
}
