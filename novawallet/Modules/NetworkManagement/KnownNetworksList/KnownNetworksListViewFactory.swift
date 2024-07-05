import Foundation
import SoraFoundation

struct KnownNetworksListViewFactory {
    static func createView(
        successAddPresenting: (wireframe: ModalAlertPresenting, view: ControllerBackedProtocol)
    ) -> KnownNetworksListViewProtocol? {
        let dataFetchFactory = DataOperationFactory()
        
        let operationQueue: OperationQueue = {
            let operationQueue = OperationQueue()
            operationQueue.qualityOfService = .userInitiated
            return operationQueue
        }()
        
        let lightChainsFetchFactory = LightChainsFetchFactory(dataFetchFactory: dataFetchFactory)
        let chainFetchFactory = PreConfiguredChainFetchFactory(dataFetchFactory: dataFetchFactory)
        
        let interactor = KnownNetworksListInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            lightChainsFetchFactory: lightChainsFetchFactory,
            preConfiguredChainFetchFactory: chainFetchFactory,
            operationQueue: operationQueue
        )
        
        let wireframe = KnownNetworksListWireframe(successAddPresenting: successAddPresenting)

        let viewModelFactory = KnownNetworksListviewModelFactory(networkViewModelFactory: NetworkViewModelFactory())
        let localizationManager = LocalizationManager.shared
        
        let presenter = KnownNetworksListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
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
