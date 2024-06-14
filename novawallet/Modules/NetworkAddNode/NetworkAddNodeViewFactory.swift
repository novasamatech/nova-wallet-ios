import Foundation
import SoraFoundation

struct NetworkAddNodeViewFactory {
    static func createView(with chainId: ChainModel.Id) -> NetworkAddNodeViewProtocol? {
        let connectionFactory = ConnectionFactory(
            logger: Logger.shared,
            operationQueue: OperationManagerFacade.assetsSyncQueue
        )

        let chainRegistry = ChainRegistryFactory.createDefaultRegistry()

        let repository = SubstrateRepositoryFactory().createChainRepository()
        
        let operationQueue: OperationQueue = {
            let operationQueue = OperationQueue()
            operationQueue.qualityOfService = .userInitiated
            return operationQueue
        }()
        
        let interactor = NetworkAddNodeInteractor(
            chainRegistry: chainRegistry,
            connectionFactory: connectionFactory,
            chainId: chainId,
            repository: repository,
            operationQueue: operationQueue
        )
        
        let wireframe = NetworkAddNodeWireframe()

        let presenter = NetworkAddNodePresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = NetworkAddNodeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
