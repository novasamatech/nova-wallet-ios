import Foundation
import RobinHood

final class WalletServiceFacade {
    static let sharedRemoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol = {
        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()
        let assetsOperationQueue = OperationManagerFacade.assetsQueue
        let assetsOperationManager = OperationManager(operationQueue: assetsOperationQueue)

        return WalletRemoteSubscriptionService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: repository,
            operationManager: assetsOperationManager,
            logger: Logger.shared
        )
    }()

    static let sharedEvmRemoteSubscriptionService: WalletRemoteEvmSubscriptionServiceProtocol = {
        let assetsOperationQueue = OperationManagerFacade.assetsQueue
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
