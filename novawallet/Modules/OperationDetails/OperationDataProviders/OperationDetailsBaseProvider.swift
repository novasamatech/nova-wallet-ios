import Foundation

class OperationDetailsBaseProvider {
    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let transaction: TransactionHistoryItem

    var accountAddress: AccountAddress? {
        selectedAccount.chainAccount.toAddress()
    }

    var chain: ChainModel {
        chainAsset.chain
    }

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        transaction: TransactionHistoryItem
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.transaction = transaction
    }
}
