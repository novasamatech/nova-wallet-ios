import Foundation
import SubstrateSdk

protocol DAppOperationConfirmViewModelFactoryProtocol {
    func createViewModel(from model: DAppOperationConfirmModel) -> DAppOperationConfirmViewModel
}

final class DAppOperationConfirmViewModelFactory: DAppOperationConfirmViewModelFactoryProtocol {
    func createViewModel(from model: DAppOperationConfirmModel) -> DAppOperationConfirmViewModel {
        let iconViewModel: ImageViewModelProtocol

        if let iconUrl = model.dAppIcon {
            iconViewModel = RemoteImageViewModel(url: iconUrl)
        } else {
            iconViewModel = StaticImageViewModel(image: R.image.iconDefaultDapp()!)
        }

        let walletIcon = try? NovaIconGenerator().generateFromAccountId(model.walletAccountId)

        let addressIcon = try? PolkadotIconGenerator().generateFromAccountId(model.chainAccountId)

        let networkIcon: ImageViewModelProtocol?

        if let networkIconUrl = model.networkIcon {
            networkIcon = RemoteImageViewModel(url: networkIconUrl)
        } else {
            networkIcon = nil
        }

        return DAppOperationConfirmViewModel(
            iconImageViewModel: iconViewModel,
            walletName: model.accountName,
            walletIcon: walletIcon,
            address: model.chainAddress.truncated,
            addressIcon: addressIcon,
            networkName: model.networkName,
            networkIconViewModel: networkIcon
        )
    }
}
