import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

struct NetworksViewFactory {
    static func createView() -> NetworksViewProtocol? {
        let wireframe = NetworksWireframe()

        let repository = ChainRepositoryFactory().createRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let interactor = NetworksInteractor(
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager
        )

        let localizationManager = LocalizationManager.shared
        let viewModelFactory = NetworksViewModelFactory()
        let presenter = NetworksPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
        let view = NetworksViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter
        return view
    }
}
