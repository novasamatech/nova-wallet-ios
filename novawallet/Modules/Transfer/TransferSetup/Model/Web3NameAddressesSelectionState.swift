final class Web3NameAddressesSelectionState {
    let accounts: [Web3TransferRecipient]
    let name: String

    init(accounts: [Web3TransferRecipient], name: String) {
        self.accounts = accounts
        self.name = name
    }
}
