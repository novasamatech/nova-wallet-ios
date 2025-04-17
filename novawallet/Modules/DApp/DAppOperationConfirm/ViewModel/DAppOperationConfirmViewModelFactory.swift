import Foundation
import SubstrateSdk
import BigInt

protocol DAppOperationConfirmViewModelFactoryProtocol {
    func createViewModel(from model: DAppOperationConfirmModel) -> DAppOperationConfirmViewModel
}

class DAppOperationConfirmViewModelFactory {
    let chain: DAppEitherChain

    init(chain: DAppEitherChain) {
        self.chain = chain
    }

    func createNetworkViewModel() -> DAppOperationConfirmViewModel.Network? {
        let networkIcon: ImageViewModelProtocol?

        if let networkIconUrl = chain.networkIcon {
            networkIcon = RemoteImageViewModel(url: networkIconUrl)
        } else {
            networkIcon = nil
        }

        return .init(
            name: chain.networkName,
            iconViewModel: networkIcon
        )
    }
}

extension DAppOperationConfirmViewModelFactory: DAppOperationConfirmViewModelFactoryProtocol {
    func createViewModel(from model: DAppOperationConfirmModel) -> DAppOperationConfirmViewModel {
        let iconViewModel: ImageViewModelProtocol

        if let iconUrl = model.dAppIcon {
            iconViewModel = RemoteImageViewModel(url: iconUrl)
        } else {
            iconViewModel = StaticImageViewModel(image: R.image.iconDefaultDapp()!)
        }

        let walletIcon = model.walletIdenticon.flatMap { try? NovaIconGenerator().generateFromAccountId($0) }

        let addressIcon = try? PolkadotIconGenerator().generateFromAccountId(model.chainAccountId)

        let networkModel = createNetworkViewModel()

        return DAppOperationConfirmViewModel(
            iconImageViewModel: iconViewModel,
            dApp: model.dApp,
            walletName: model.accountName,
            walletIcon: walletIcon,
            address: model.chainAddress.truncated,
            addressIcon: addressIcon,
            network: networkModel
        )
    }
}
