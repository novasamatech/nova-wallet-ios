final class Web3NameAddressesSelectionState {
    let accounts: [Web3NameTransferAssetRecipientAccount]
    let name: String

    init(accounts: [Web3NameTransferAssetRecipientAccount], name: String) {
        self.accounts = accounts
        self.name = name
    }
}
