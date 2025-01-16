import Foundation
import Foundation_iOS
import Keystore_iOS

struct NetworksListViewFactory {
    static func createView() -> NetworksListViewProtocol? {
        let interactor = NetworksListInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            settingsManager: SettingsManager.shared
        )

        let wireframe = NetworksListWireframe()

        let viewModelFactory = NetworksListViewModelFactory(
            networkViewModelFactory: NetworkViewModelFactory(),
            localizationManager: LocalizationManager.shared,
            settingsManager: SettingsManager.shared
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
