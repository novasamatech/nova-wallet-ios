import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

struct SignerConnectViewFactory {
    static func createBeaconView(for info: BeaconConnectionInfo) -> SignerConnectViewProtocol? {
        guard let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let interactor = SignerConnectInteractor(
            wallet: selectedWallet,
            info: info,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            logger: Logger.shared
        )

        let wireframe = SignerConnectWireframe()

        let viewModelFactory = SignerConnectViewModelFactory()

        let presenter = SignerConnectPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )

        let view = SignerConnectViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
