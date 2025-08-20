import Foundation
import SubstrateSdk
import Operation_iOS

protocol OrmlHydrationEvmWalletSyncFactoryProtocol {
    func createSyncService(for chainId: ChainModel.Id, accountId: AccountId) -> ApplicationServiceProtocol
}

final class OrmlHydrationEvmWalletSyncFactory {
    let chainRegistry: ChainRegistryProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        repositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateStorageFacade)
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension OrmlHydrationEvmWalletSyncFactory: OrmlHydrationEvmWalletSyncFactoryProtocol {
    func createSyncService(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> ApplicationServiceProtocol {
        OrmlHydrationEvmBalanceSyncService(
            chainId: chainId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            balanceRepository: repositoryFactory.createAssetBalanceRepository(),
            transactionHandlerFactory: TransactionSubscriptionFactory(
                chainRegistry: chainRegistry,
                eventCenter: eventCenter,
                repositoryFactory: repositoryFactory,
                storageRequestFactory: StorageRequestFactory(
                    remoteFactory: StorageKeyFactory(),
                    operationManager: OperationManager(operationQueue: operationQueue)
                ),
                operationQueue: operationQueue,
                logger: logger
            ),
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
