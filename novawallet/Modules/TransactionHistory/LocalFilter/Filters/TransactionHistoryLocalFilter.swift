import Foundation

protocol TransactionHistoryLocalFilterProtocol {
    func shouldDisplayOperation(model: TransactionHistoryItem) -> Bool
}

final class TransactionHistoryAndPredicate {
    let innerFilters: [TransactionHistoryLocalFilterProtocol]

    init(innerFilters: [TransactionHistoryLocalFilterProtocol]) {
        self.innerFilters = innerFilters
    }
}

extension TransactionHistoryAndPredicate: TransactionHistoryLocalFilterProtocol {
    func shouldDisplayOperation(model: TransactionHistoryItem) -> Bool {
        innerFilters.allSatisfy { $0.shouldDisplayOperation(model: model) }
    }
}
