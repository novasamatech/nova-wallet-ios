import Foundation

protocol TransactionHistoryPhishingFilterProtocol {
    func isPhishing(transaction: TransactionHistoryItem) -> Bool
}

final class TransactionHistoryPhishingFilter: TransactionHistoryPhishingFilterProtocol {
    func isPhishing(transaction: TransactionHistoryItem) -> Bool {
        transaction.source == .evmAsset && transaction.callPath.isERC20Transfer &&
            transaction.amountInPlankIntOrZero == 0
    }
}
