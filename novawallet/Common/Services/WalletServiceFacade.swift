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
}
