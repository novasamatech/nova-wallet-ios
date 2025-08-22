import Foundation
import SubstrateSdk
import Operation_iOS

protocol OrmlHydrationEvmWalletSyncFactoryProtocol {
    func createSyncService(for chainId: ChainModel.Id, accountId: AccountId) -> ApplicationServiceProtocol
}

final class OrmlHydrationEvmWalletSyncFactory {
    let chainRegistry: ChainRegistryProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let transactionSubscriptionFactory: TransactionSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        transactionSubscriptionFactory: TransactionSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        repositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateStorageFacade)
        self.transactionSubscriptionFactory = transactionSubscriptionFactory
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
            transactionHandlerFactory: transactionSubscriptionFactory,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
