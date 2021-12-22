import Foundation
import SubstrateSdk

protocol DAppOperationConfirmViewModelFactoryProtocol {
    func createViewModel(from model: DAppOperationConfirmModel) -> DAppOperationConfirmViewModel
}

final class DAppOperationConfirmViewModelFactory: DAppOperationConfirmViewModelFactoryProtocol {
    func createViewModel(from model: DAppOperationConfirmModel) -> DAppOperationConfirmViewModel {
        let walletIcon = try? NovaIconGenerator().generateFromAccountId(
            model.wallet.substrateAccountId
        )

        let maybeAccountId: AccountId? = model.wallet.fetch(for: model.chain.accountRequest())?.accountId
        let addressIcon: DrawableIcon?

        if let accountId = maybeAccountId {
            addressIcon = try? PolkadotIconGenerator().generateFromAccountId(accountId)
        } else {
            addressIcon = nil
        }

        let address = try? maybeAccountId?.toAddress(using: model.chain.chainFormat)

        let networkIcon: ImageViewModelProtocol?

        if let asset = model.chain.utilityAssets().first {
            let url = asset.icon ?? model.chain.icon
            networkIcon = RemoteImageViewModel(url: url)
        } else {
            networkIcon = nil
        }

        return DAppOperationConfirmViewModel(
            iconImageViewModel: nil,
            walletName: model.wallet.name,
            walletIcon: walletIcon,
            address: address?.truncated ?? "",
            addressIcon: addressIcon,
            networkName: model.chain.name,
            networkIconViewModel: networkIcon
        )
    }
}
