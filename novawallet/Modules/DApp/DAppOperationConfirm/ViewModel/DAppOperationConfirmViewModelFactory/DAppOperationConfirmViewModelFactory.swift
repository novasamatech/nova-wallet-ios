import Foundation
import SubstrateSdk
import BigInt

protocol DAppOperationConfirmViewModelFactoryProtocol {
    func createViewModel(from model: DAppOperationConfirmModel) -> DAppOperationConfirmViewModel
}

class DAppOperationBaseConfirmViewModelFactory {
    let chain: DAppEitherChain

    init(chain: DAppEitherChain) {
        self.chain = chain
    }

    func createNetworkViewModel() -> DAppOperationConfirmViewModel.Network? {
        fatalError("Must be overriden by subsclass")
    }
}

extension DAppOperationBaseConfirmViewModelFactory: DAppOperationConfirmViewModelFactoryProtocol {
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
