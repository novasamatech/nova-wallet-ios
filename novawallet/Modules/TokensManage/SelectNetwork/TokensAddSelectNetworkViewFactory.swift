import Foundation
import SoraFoundation

struct TokensAddSelectNetworkViewFactory {
    static func createView(for chains: [ChainModel.Id: ChainModel]) -> TokensAddSelectNetworkViewProtocol? {
        let interactor = TokensAddSelectNetworkInteractor(chainRegistry: ChainRegistryFacade.sharedRegistry)
        let wireframe = TokensAddSelectNetworkWireframe()

        let presenter = TokensAddSelectNetworkPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: NetworkViewModelFactory(),
            chains: chains
        )

        let view = TokensAddSelectNetworkViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
