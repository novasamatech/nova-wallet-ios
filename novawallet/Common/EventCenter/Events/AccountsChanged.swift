struct AccountsChanged: EventProtocol {
    enum ChangeType {
        case manually
        case automatically
    }

    var method: ChangeType

    func accept(visitor: EventVisitorProtocol) {
        visitor.processAccountsChanged(event: self)
    }
}
