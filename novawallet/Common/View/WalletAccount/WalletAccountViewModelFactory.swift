import Foundation
import SubstrateSdk

final class WalletAccountViewModelFactory {
    private lazy var addressIconGenerator = PolkadotIconGenerator()
    private lazy var walletIconGenerator = NovaIconGenerator()

    func createViewModel(from account: MetaChainAccountResponse) throws -> WalletAccountViewModel {
        let addressIcon = try addressIconGenerator.generateFromAccountId(account.chainAccount.accountId)
        let addressIconViewModel = DrawableIconViewModel(icon: addressIcon)

        let walletIcon = try walletIconGenerator.generateFromAccountId(account.substrateAccountId)
        let walletIconViewModel = DrawableIconViewModel(icon: walletIcon)
        let address = account.chainAccount.toAddress() ?? ""

        return WalletAccountViewModel(
            walletName: account.chainAccount.name,
            walletIcon: walletIconViewModel,
            address: address,
            addressIcon: addressIconViewModel
        )
    }
}
