import Foundation

struct WalletTransactionListUpdated: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processTransactionHistoryUpdate(event: self)
    }
}
