enum TransferType {
    case income
    case outcome
    
    var title: String {
        switch self {
        case .income:
            return "⬇️ Received"
        case .outcome:
            return "💸 Sent"
        }
    }
    
    func subtitle(amount: String,
                  price: String?,
                  chainName: String,
                  address: AccountAddress) -> String {
        let priceString = price.map { "(\($0))" } ?? ""
        switch self {
        case .income:
            return "Received \(amount) \(priceString) on \(chainName)"
        case .outcome:
            return "Sent \(amount) \(priceString) to \(address) on \(chainName)"
        }
    }
    
    func address(from payload: NotificationTransferPayload) -> AccountAddress {
        switch self {
        case .income:
            return ""
        case .outcome:
            return payload.recipient
        }
    }
}
