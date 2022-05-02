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

    func createDisplayViewModel(from response: MetaChainAccountResponse) throws -> DisplayWalletViewModel {
        let walletIcon = try walletIconGenerator.generateFromAccountId(response.substrateAccountId)
        let iconViewModel = DrawableIconViewModel(icon: walletIcon)

        return DisplayWalletViewModel(name: response.chainAccount.name, imageViewModel: iconViewModel)
    }

    func createViewModel(from validatorInfo: ValidatorInfoProtocol) -> WalletAccountViewModel {
        do {
            let walletIconViewModel: ImageViewModelProtocol?
            let walletName: String?

            if let validatorName = validatorInfo.identity?.displayName {
                let walletIcon = try walletIconGenerator.generateFromAddress(validatorInfo.address)
                walletIconViewModel = DrawableIconViewModel(icon: walletIcon)
                walletName = validatorName
            } else {
                walletIconViewModel = nil
                walletName = nil
            }

            let addressIcon = try addressIconGenerator.generateFromAddress(validatorInfo.address)
            let addressIconViewModel = DrawableIconViewModel(icon: addressIcon)

            return WalletAccountViewModel(
                walletName: walletName,
                walletIcon: walletIconViewModel,
                address: validatorInfo.address,
                addressIcon: addressIconViewModel
            )
        } catch {
            return WalletAccountViewModel(
                walletName: validatorInfo.identity?.displayName,
                walletIcon: nil,
                address: validatorInfo.address,
                addressIcon: nil
            )
        }
    }
}
