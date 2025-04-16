import Foundation
import Foundation_iOS

struct NetworkNodeViewFactory {
    static func createNodeAddView(with chainId: ChainModel.Id) -> NetworkNodeViewProtocol? {
        let connectionFactory = ConnectionFactory(
            logger: Logger.shared,
            operationQueue: OperationManagerFacade.assetsSyncQueue
        )

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let repository = SubstrateRepositoryFactory().createChainRepository()

        let operationQueue: OperationQueue = {
            let operationQueue = OperationQueue()
            operationQueue.qualityOfService = .userInitiated
            return operationQueue
        }()

        let interactor = NetworkNodeAddInteractor(
            chainRegistry: chainRegistry,
            connectionFactory: connectionFactory,
            blockHashOperationFactory: BlockHashOperationFactory(),
            chainId: chainId,
            repository: repository,
            operationQueue: operationQueue
        )

        let wireframe = NetworkNodeWireframe()

        let networkViewModelFactory = NetworkViewModelFactory()

        let presenter = NetworkNodeAddPresenter(
            interactor: interactor,
            wireframe: wireframe,
            networkViewModelFactory: networkViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = NetworkNodeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createNodeEditView(
        with chainId: ChainModel.Id,
        _ node: ChainNodeModel
    ) -> NetworkNodeViewProtocol? {
        let connectionFactory = ConnectionFactory(
            logger: Logger.shared,
            operationQueue: OperationManagerFacade.assetsSyncQueue
        )

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let repository = SubstrateRepositoryFactory().createChainRepository()

        let operationQueue: OperationQueue = {
            let operationQueue = OperationQueue()
            operationQueue.qualityOfService = .userInitiated
            return operationQueue
        }()

        let interactor = NetworkNodeEditInteractor(
            nodeToEdit: node,
            chainRegistry: chainRegistry,
            connectionFactory: connectionFactory,
            blockHashOperationFactory: BlockHashOperationFactory(),
            chainId: chainId,
            repository: repository,
            operationQueue: operationQueue
        )

        let wireframe = NetworkNodeWireframe()

        let networkViewModelFactory = NetworkViewModelFactory()

        let presenter = NetworkNodeEditPresenter(
            interactor: interactor,
            wireframe: wireframe,
            networkViewModelFactory: networkViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = NetworkNodeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
