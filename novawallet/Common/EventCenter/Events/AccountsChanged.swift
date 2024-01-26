enum AccountChangeType {
    case manually
    case automatically
}

struct AccountsChanged: EventProtocol {
    let method: AccountChangeType

    func accept(visitor: EventVisitorProtocol) {
        visitor.processAccountsChanged(event: self)
    }
}
