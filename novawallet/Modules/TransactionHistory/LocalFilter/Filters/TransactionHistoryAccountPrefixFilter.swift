import Foundation
import SubstrateSdk

final class TransactionHistoryAccountPrefixFilter {
    let accountPrefix: Data
    let ignoresOnlyWithinExtrinsic: Bool
    let chainAsset: ChainAsset

    init(
        accountPrefix: Data,
        ignoresOnlyWithinExtrinsic: Bool = false,
        chainAsset: ChainAsset
    ) {
        self.accountPrefix = accountPrefix
        self.ignoresOnlyWithinExtrinsic = ignoresOnlyWithinExtrinsic
        self.chainAsset = chainAsset
    }

    var chainFormat: ChainFormat {
        chainAsset.chain.chainFormat
    }
}

private extension TransactionHistoryAccountPrefixFilter {
    func hasExtrinsicHash(_ model: TransactionHistoryItem) -> Bool {
        guard let hash = try? Data(hexString: model.txHash) else {
            return false
        }

        return !hash.isEmpty
    }
}

extension TransactionHistoryAccountPrefixFilter: TransactionHistoryLocalFilterProtocol {
    func shouldDisplayOperation(model: TransactionHistoryItem) -> Bool {
        guard model.callPath.isBalancesTransfer else {
            return true
        }

        if ignoresOnlyWithinExtrinsic, !hasExtrinsicHash(model) {
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
