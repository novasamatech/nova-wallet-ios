final class KiltAddressesSelectionState {
    init(accounts: [KiltTransferAssetRecipientAccount], name: String) {
        self.accounts = accounts
        self.name = name
    }

    let accounts: [KiltTransferAssetRecipientAccount]
    let name: String
}
