import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

struct NetworksViewFactory {
    static func createView() -> NetworksViewProtocol? {
        let wireframe = NetworksWireframe()

        let logger = Logger.shared
        let operationManager = OperationManagerFacade.sharedManager
        let chainSettingsProviderFactory = ChainSettingsProviderFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: operationManager,
            logger: logger
        )
        let interactor = NetworksInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            chainSettingsProviderFactory: chainSettingsProviderFactory
        )

        let localizationManager = LocalizationManager.shared
        let viewModelFactory = NetworksViewModelFactory()
        let presenter = NetworksPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: logger
        )
        let view = NetworksViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter
        return view
    }
}
