import Foundation

final class NovaFeeTransferFilter: TransactionHistoryLocalFilterProtocol {
    func shouldDisplayOperation(model: TransactionHistoryItem) -> Bool {
        guard model.callPath.isTransfer,
              let receiverAddress = model.receiver else {
            return true
        }

        // Try hex (raw accountId) and SS58 (any prefix) formats
        if let recipient = try? Data(hexString: receiverAddress),
           recipient == HydraConstants.novaFeeAccountId {
            return false
        }

        if let recipient = try? receiverAddress.toAccountId(),
           recipient == HydraConstants.novaFeeAccountId {
            return false
        }

        return true
    }
}

final class TransactionHistoryTransfersFilter {
    let ignoredSenders: Set<AccountId>
    let ignoredRecipients: Set<AccountId>

    let chainAsset: ChainAsset

    init(
        ignoredSenders: Set<AccountId>,
        ignoredRecipients: Set<AccountId>,
        chainAsset: ChainAsset
    ) {
        self.ignoredSenders = ignoredSenders
        self.ignoredRecipients = ignoredRecipients
        self.chainAsset = chainAsset
    }

    var chainFormat: ChainFormat {
        chainAsset.chain.chainFormat
    }
}

extension TransactionHistoryTransfersFilter: TransactionHistoryLocalFilterProtocol {
    func shouldDisplayOperation(model: TransactionHistoryItem) -> Bool {
        guard model.callPath.isBalancesTransfer else {
            return true
        }

        if
            let sender = try? model.sender.toAccountId(using: chainFormat),
            ignoredSenders.contains(sender) {
            return false
        }

        if
            let receiverAddress = model.receiver,
            let recepient = try? receiverAddress.toAccountId(using: chainFormat),
            ignoredRecipients.contains(recepient) {
            return false
        }

        return true
    }
}
