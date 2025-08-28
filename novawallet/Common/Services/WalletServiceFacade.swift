import Foundation
import Operation_iOS
import SubstrateSdk

final class WalletServiceFacade {
    static let sharedTransactionSubscriptionFactory: TransactionSubscriptionFactoryProtocol = {
        let syncOperationQueue = OperationManagerFacade.assetsSyncQueue
        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let syncOperationManager = OperationManager(operationQueue: syncOperationQueue)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: syncOperationManager
        )

        return TransactionSubscriptionFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            eventCenter: EventCenter.shared,
            repositoryFactory: SubstrateRepositoryFactory(storageFacade: substrateStorageFacade),
            storageRequestFactory: storageRequestFactory,
            operationQueue: syncOperationQueue,
            logger: Logger.shared
        )
    }()

    static let sharedEquillibriumRemoteSubscriptionService: EquillibriumRemoteSubscriptionServiceProtocol = {
        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()
        let syncOperationQueue = OperationManagerFacade.assetsSyncQueue
        let repositoryOperationQueue = OperationManagerFacade.assetsRepositoryQueue
        let syncOperationManager = OperationManager(operationQueue: syncOperationQueue)
        let repositoryOperationManager = OperationManager(operationQueue: repositoryOperationQueue)

        return EquillibriumRemoteSubscriptionService(
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
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let subscriptionHandlingFactory = BalanceRemoteSubscriptionHandlingFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            substrateStorageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.assetsRepositoryQueue,
            logger: Logger.shared
        )

        let transactionSubscriptionFactory = WalletServiceFacade.sharedTransactionSubscriptionFactory

        return BalanceRemoteSubscriptionService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: repository,
            subscriptionHandlingFactory: subscriptionHandlingFactory,
            transactionSubscriptionFactory: transactionSubscriptionFactory,
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
