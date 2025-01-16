import Foundation
import Foundation_iOS

struct CustomNetworkViewFactory {
    static func createNetworkAddView(networkToAdd: ChainModel? = nil) -> CustomNetworkViewProtocol? {
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
        let chainNameOperationFactory = SubstrateChainNameOperationFactory()

        let customNetworkSetupFactory = CustomNetworkSetupFactory(
            rawRuntimeFetchFactory: runtimeFetchOperationFactory,
            blockHashOperationFactory: blockHashOperationFactory,
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            chainNameOperationFactory: chainNameOperationFactory,
            typeRegistryFactory: runtimeTypeRegistryFactory,
            operationQueue: operationQueue
        )

        let setupFinishStrategyFactory = CustomNetworkSetupFinishStrategyFactory(
            chainRegistry: chainRegistry,
            repository: repository,
            operationQueue: operationQueue
        )

        let interactor = CustomNetworkAddInteractor(
            networkToAdd: networkToAdd,
            chainRegistry: chainRegistry,
            customNetworkSetupFactory: customNetworkSetupFactory,
            connectionFactory: connectionFactory,
            repository: repository,
            priceIdParser: CoingeckoUrlParser(),
            setupFinishStrategyFactory: setupFinishStrategyFactory,
            operationQueue: operationQueue
        )

        let wireframe = CustomNetworkWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = CustomNetworkAddPresenter(
            chainType: .substrate,
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
        let chainNameOperationFactory = SubstrateChainNameOperationFactory()

        let customNetworkSetupFactory = CustomNetworkSetupFactory(
            rawRuntimeFetchFactory: runtimeFetchOperationFactory,
            blockHashOperationFactory: blockHashOperationFactory,
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            chainNameOperationFactory: chainNameOperationFactory,
            typeRegistryFactory: runtimeTypeRegistryFactory,
            operationQueue: operationQueue
        )

        let setupFinishStrategyFactory = CustomNetworkSetupFinishStrategyFactory(
            chainRegistry: chainRegistry,
            repository: repository,
            operationQueue: operationQueue
        )

        let interactor = CustomNetworkEditInteractor(
            networkToEdit: network,
            selectedNode: selectedNode,
            chainRegistry: chainRegistry,
            customNetworkSetupFactory: customNetworkSetupFactory,
            connectionFactory: connectionFactory,
            repository: repository,
            priceIdParser: CoingeckoUrlParser(),
            setupFinishStrategyFactory: setupFinishStrategyFactory,
            operationQueue: operationQueue
        )

        let wireframe = CustomNetworkWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = CustomNetworkEditPresenter(
            chainType: network.isEthereumBased ? .evm : .substrate,
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
