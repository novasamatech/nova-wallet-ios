import Foundation
import SoraFoundation

struct KnownNetworksListViewFactory {
    static func createView() -> KnownNetworksListViewProtocol? {
        let dataFetchFactory = DataOperationFactory()
        let chainConverter = ChainModelConverter()
        
        let operationQueue: OperationQueue = {
            let operationQueue = OperationQueue()
            operationQueue.qualityOfService = .userInitiated
            return operationQueue
        }()
        
        let interactor = KnownNetworksListInteractor(
            dataFetchFactory: dataFetchFactory,
            chainConverter: chainConverter,
            operationQueue: operationQueue
        )
        
        let wireframe = KnownNetworksListWireframe()

        let networkViewModelFactory = NetworkViewModelFactory()
        let localizationManager = LocalizationManager.shared
        
        let presenter = KnownNetworksListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            networkViewModelFactory: networkViewModelFactory,
            localizationManager: localizationManager
        )

        let view = KnownNetworksListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
