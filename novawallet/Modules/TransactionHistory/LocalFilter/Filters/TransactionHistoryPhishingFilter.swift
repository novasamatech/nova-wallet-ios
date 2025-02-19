import Foundation

final class TransactionHistoryPhishingFilter: TransactionHistoryLocalFilterProtocol {
    private func isPhishing(transaction: TransactionHistoryItem) -> Bool {
        transaction.source == .evmAsset && transaction.callPath.isERC20Transfer &&
            transaction.amountInPlankIntOrZero == 0
    }

    func shouldDisplayOperation(model: TransactionHistoryItem) -> Bool {
        !isPhishing(transaction: model)
    }
}
