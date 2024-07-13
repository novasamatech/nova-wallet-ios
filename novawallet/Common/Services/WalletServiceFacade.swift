import Foundation
import Operation_iOS

final class WalletServiceFacade {
    static let sharedRemoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol = {
        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()
        let syncOperationQueue = OperationManagerFacade.assetsSyncQueue
        let repositoryOperationQueue = OperationManagerFacade.assetsRepositoryQueue
        let syncOperationManager = OperationManager(operationQueue: syncOperationQueue)
        let repositoryOperationManager = OperationManager(operationQueue: repositoryOperationQueue)

        return WalletRemoteSubscriptionService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: repository,
            syncOperationManager: syncOperationManager,
            repositoryOperationManager: repositoryOperationManager,
            logger: Logger.shared
        )
    }()

    static let sharedSubstrateRemoteSubscriptionService: BalanceRemoteSubscriptionServiceProtocol = {
        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()
        let syncOperationQueue = OperationManagerFacade.assetsSyncQueue
        let repositoryOperationQueue = OperationManagerFacade.assetsRepositoryQueue
        let syncOperationManager = OperationManager(operationQueue: syncOperationQueue)
        let repositoryOperationManager = OperationManager(operationQueue: repositoryOperationQueue)

        let subscriptionHandlingFactory = BalanceRemoteSubscriptionHandlingFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.assetsRepositoryQueue,
            logger: Logger.shared
        )

        return BalanceRemoteSubscriptionService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: repository,
            subscriptionHandlingFactory: subscriptionHandlingFactory,
            syncOperationManager: syncOperationManager,
            repositoryOperationManager: repositoryOperationManager,
            logger: Logger.shared
        )
    }()

    static let sharedEvmRemoteSubscriptionService: WalletRemoteEvmSubscriptionServiceProtocol = {
        let assetsOperationQueue = OperationManagerFacade.assetsSyncQueue
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let logger = Logger.shared

        let serviceFactory = EvmBalanceUpdateServiceFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            chainRegistry: chainRegistry,
            operationQueue: assetsOperationQueue,
            logger: logger
        )

        return WalletRemoteEvmSubscriptionService(
            chainRegistry: chainRegistry,
            balanceUpdateServiceFactory: serviceFactory,
            eventCenter: EventCenter.shared,
            logger: logger
        )
    }()
}
