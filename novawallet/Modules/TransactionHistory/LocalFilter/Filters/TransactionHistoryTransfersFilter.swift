import Foundation

final class HydrationSwapAccountsFilter: TransactionHistoryLocalFilterProtocol {
    let systemAccounts: Set<AccountId> = [
        HydraConstants.novaFeeAccountId,
        HydraConstants.hydraRouterAccountId
    ]

    func shouldDisplayOperation(model: TransactionHistoryItem) -> Bool {
        guard model.callPath.isTransfer else {
            return true
        }

        return !matchesSystemAccount(model.sender) && !matchesSystemAccount(model.receiver)
    }

    private func matchesSystemAccount(_ address: AccountAddress?) -> Bool {
        guard let address else {
            return false
        }

        // Addresses may arrive as raw hex (accountId) or SS58 (any prefix)
        if let accountId = try? Data(hexString: address), systemAccounts.contains(accountId) {
            return true
        }

        if let accountId = try? address.toAccountId(), systemAccounts.contains(accountId) {
            return true
        }

        return false
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
