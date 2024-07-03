import Foundation
import SoraFoundation

struct CustomNetworkViewFactory {
    static func createNetworkAddView() -> CustomNetworkViewProtocol? {
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
        
        let runtimeFetchOperationFactory = RuntimeFetchOperationFactory(operationQueue: operationQueue)
        let runtimeTypeRegistryFactory = RuntimeTypeRegistryFactory(logger: Logger.shared)
        let blockHashOperationFactory = BlockHashOperationFactory()
        let systemPropertiesOperationFactory = SystemPropertiesOperationFactory()
        
        let interactor = CustomNetworkAddInteractor(
            chainRegistry: chainRegistry,
            runtimeFetchOperationFactory: runtimeFetchOperationFactory,
            runtimeTypeRegistryFactory: runtimeTypeRegistryFactory,
            blockHashOperationFactory: blockHashOperationFactory,
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            connectionFactory: connectionFactory,
            repository: repository,
            operationQueue: operationQueue
        )
        
        let wireframe = CustomNetworkWireframe()

        let localizationManager = LocalizationManager.shared
        
        let presenter = CustomNetworkAddPresenter(
            chainType: .substrate, 
            knownChain: nil,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager
        )

        let view = CustomNetworkViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
    
    static func createNetworkEditView(
        for network: ChainModel,
        selectedNode: ChainNodeModel
    ) -> CustomNetworkViewProtocol? {
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
        
        let runtimeFetchOperationFactory = RuntimeFetchOperationFactory(operationQueue: operationQueue)
        let runtimeTypeRegistryFactory = RuntimeTypeRegistryFactory(logger: Logger.shared)
        let blockHashOperationFactory = BlockHashOperationFactory()
        let systemPropertiesOperationFactory = SystemPropertiesOperationFactory()
        
        let interactor = CustomNetworkEditInteractor(
            networkToEdit: network,
            selectedNode: selectedNode,
            chainRegistry: chainRegistry,
            runtimeFetchOperationFactory: runtimeFetchOperationFactory,
            runtimeTypeRegistryFactory: runtimeTypeRegistryFactory,
            blockHashOperationFactory: blockHashOperationFactory,
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            connectionFactory: connectionFactory,
            repository: repository,
            operationQueue: operationQueue
        )
        
        let wireframe = CustomNetworkWireframe()

        let localizationManager = LocalizationManager.shared
        
        let presenter = CustomNetworkEditPresenter(
            chainType: .substrate,
            knownChain: nil,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager
        )

        let view = CustomNetworkViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
