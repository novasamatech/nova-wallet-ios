import Foundation

struct WalletDisplayAddress {
    let address: AccountAddress
    let walletName: String?
    let walletIconData: Data?

    init(
        address: AccountAddress,
        walletName: String? = nil,
        walletIconData: Data? = nil
    ) {
        self.address = address
        self.walletName = walletName
        self.walletIconData = walletIconData
    }

    init?(response: MetaChainAccountResponse) {
        guard let address = response.chainAccount.toAddress() else {
            return nil
        }

        self.address = address
        walletName = response.chainAccount.name
        walletIconData = response.substrateAccountId
    }
}
