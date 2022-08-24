import Foundation
import SubstrateSdk

protocol DAppAuthViewModelFactoryProtocol {
    func createViewModel(from request: DAppAuthRequest) -> DAppAuthViewModel
}

final class DAppAuthViewModelFactory: DAppAuthViewModelFactoryProtocol {
    func createViewModel(from request: DAppAuthRequest) -> DAppAuthViewModel {
        let sourceViewModel = StaticImageViewModel(image: R.image.iconDappExtension()!)

        let destinationViewModel: ImageViewModelProtocol

        if let iconUrl = request.dAppIcon {
            destinationViewModel = RemoteImageViewModel(url: iconUrl)
        } else {
            destinationViewModel = StaticImageViewModel(image: R.image.iconDefaultDapp()!)
        }

        let iconGenerator = NovaIconGenerator()

        let walletIcon = request.wallet.walletIdenticonData().flatMap {
            try? iconGenerator.generateFromAccountId($0)
        }

        return DAppAuthViewModel(
            sourceImageViewModel: sourceViewModel,
            destinationImageViewModel: destinationViewModel,
            walletName: request.wallet.name,
            walletIcon: walletIcon,
            dApp: request.dApp,
            origin: request.origin
        )
    }
}
