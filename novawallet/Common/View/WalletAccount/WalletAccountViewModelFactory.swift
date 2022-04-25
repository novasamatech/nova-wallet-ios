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

    func createViewModel(from walletAddress: WalletDisplayAddress) throws -> WalletAccountViewModel {
        let addressIcon = try addressIconGenerator.generateFromAddress(walletAddress.address)
        let addressIconViewModel = DrawableIconViewModel(icon: addressIcon)

        let walletIconViewModel: DrawableIconViewModel? = try walletAddress.walletIconData.map { data in
            let icon = try walletIconGenerator.generateFromAccountId(data)
            return DrawableIconViewModel(icon: icon)
        }

        return WalletAccountViewModel(
            walletName: walletAddress.walletName,
            walletIcon: walletIconViewModel,
            address: walletAddress.address,
            addressIcon: addressIconViewModel
        )
    }

    func createViewModel(from address: AccountAddress) throws -> WalletAccountViewModel {
        let addressIcon = try addressIconGenerator.generateFromAddress(address)
        let addressIconViewModel = DrawableIconViewModel(icon: addressIcon)

        return WalletAccountViewModel(
            walletName: nil,
            walletIcon: nil,
            address: address,
            addressIcon: addressIconViewModel
        )
    }
}
