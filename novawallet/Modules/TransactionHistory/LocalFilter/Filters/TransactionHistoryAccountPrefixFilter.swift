import Foundation

final class TransactionHistoryAccountPrefixFilter {
    let accountPrefix: Data
    let chainAsset: ChainAsset

    init(accountPrefix: Data, chainAsset: ChainAsset) {
        self.accountPrefix = accountPrefix
        self.chainAsset = chainAsset
    }

    var chainFormat: ChainFormat {
        chainAsset.chain.chainFormat
    }
}

extension TransactionHistoryAccountPrefixFilter: TransactionHistoryLocalFilterProtocol {
    func shouldDisplayOperation(model: TransactionHistoryItem) -> Bool {
        guard model.callPath.isBalancesTransfer else {
            return true
        }

        if
            let sender = try? model.sender.toAccountId(using: chainFormat),
            sender.starts(with: accountPrefix) {
            return false
        }

        if
            let receiverAddress = model.receiver,
            let recepient = try? receiverAddress.toAccountId(using: chainFormat),
            recepient.starts(with: accountPrefix) {
            return false
        }

        return true
    }
}
