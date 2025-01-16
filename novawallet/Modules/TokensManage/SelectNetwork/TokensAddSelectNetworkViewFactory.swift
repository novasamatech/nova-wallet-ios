import Foundation
import Foundation_iOS

struct TokensAddSelectNetworkViewFactory {
    static func createView() -> TokensAddSelectNetworkViewProtocol? {
        let interactor = TokensAddSelectNetworkInteractor(chainRegistry: ChainRegistryFacade.sharedRegistry)
        let wireframe = TokensAddSelectNetworkWireframe()

        let presenter = TokensAddSelectNetworkPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: NetworkViewModelFactory()
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
