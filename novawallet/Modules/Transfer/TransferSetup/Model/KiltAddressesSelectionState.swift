final class KiltAddressesSelectionState {
    let accounts: [KiltTransferAssetRecipientAccount]
    let name: String

    init(accounts: [KiltTransferAssetRecipientAccount], name: String) {
        self.accounts = accounts
        self.name = name
    }
}
