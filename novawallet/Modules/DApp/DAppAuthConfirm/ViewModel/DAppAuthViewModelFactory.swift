import Foundation
import SubstrateSdk

protocol DAppAuthViewModelFactoryProtocol {
    func createViewModel(from request: DAppAuthRequest) -> DAppAuthViewModel
}

final class DAppAuthViewModelFactory: DAppAuthViewModelFactoryProtocol {
    private let iconViewModelFactory: DAppIconViewModelFactoryProtocol

    init(iconViewModelFactory: DAppIconViewModelFactoryProtocol) {
        self.iconViewModelFactory = iconViewModelFactory
    }

    func createViewModel(from request: DAppAuthRequest) -> DAppAuthViewModel {
        let sourceViewModel = StaticImageViewModel(image: R.image.iconDappExtension()!)

        let destinationViewModel = iconViewModelFactory.createIconViewModel(for: request)

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
