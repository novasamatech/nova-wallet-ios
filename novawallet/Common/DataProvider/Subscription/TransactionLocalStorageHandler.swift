import Foundation
import Operation_iOS

protocol TransactionLocalSubscriptionHandler: AnyObject {
    func handleTransactions(result: Result<[DataProviderChange<TransactionHistoryItem>], Error>)
}

extension TransactionLocalSubscriptionHandler {
    func handleTransactions(
        result _: Result<[DataProviderChange<TransactionHistoryItem>], Error>
    ) {}
}
