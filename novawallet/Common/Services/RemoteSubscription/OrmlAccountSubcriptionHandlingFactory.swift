import Foundation
import RobinHood

final class OrmlAccountSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let assetRepository: AnyDataProviderRepository<AssetBalance>
    let eventCenter: EventCenterProtocol
    let transactionSubscription: TransactionSubscription?

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        assetRepository: AnyDataProviderRepository<AssetBalance>,
        eventCenter: EventCenterProtocol,
        transactionSubscription: TransactionSubscription?
    ) {
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.assetRepository = assetRepository
        self.eventCenter = eventCenter
        self.transactionSubscription = transactionSubscription
    }

    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        OrmlAccountSubscription(
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            assetRepository: assetRepository,
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger,
            eventCenter: eventCenter,
            transactionSubscription: transactionSubscription
        )
    }
}
