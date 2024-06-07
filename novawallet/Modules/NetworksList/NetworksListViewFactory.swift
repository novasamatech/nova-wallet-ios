import Foundation
import SoraFoundation

struct NetworksListViewFactory {
    static func createView() -> NetworksListViewProtocol? {
        let interactor = NetworksListInteractor(chainRegistry: ChainRegistryFacade.sharedRegistry)
        let wireframe = NetworksListWireframe()

        let viewModelFactory = NetworksListViewModelFactory(
            networkViewModelFactory: NetworkViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )

        let presenter = NetworksListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )

        let view = NetworksListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
