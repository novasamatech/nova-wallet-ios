import Foundation
import RobinHood
import SubstrateSdk

protocol OrmlTokenStorageChildSubscribingFactoryProtocol {
    func createTokenStorageChildSubscribingFactory(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing
    func createLocksStorageChildSubscribingFactory(
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing
}

final class OrmlTokenStorageChildSubscribingFactory: OrmlTokenStorageChildSubscribingFactoryProtocol {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let assetRepository: AnyDataProviderRepository<AssetBalance>
    let eventCenter: EventCenterProtocol
    let transactionSubscription: TransactionSubscription?
    let locksRepository: AnyDataProviderRepository<AssetLock>

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        assetRepository: AnyDataProviderRepository<AssetBalance>,
        locksRepository: AnyDataProviderRepository<AssetLock>,
        eventCenter: EventCenterProtocol,
        transactionSubscription: TransactionSubscription?
    ) {
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.assetRepository = assetRepository
        self.locksRepository = locksRepository
        self.eventCenter = eventCenter
        self.transactionSubscription = transactionSubscription
    }

    func createTokenStorageChildSubscribingFactory(
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

    func createLocksStorageChildSubscribingFactory(
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger _: LoggerProtocol
    ) -> StorageChildSubscribing {
        OrmLocksSubscribtion(
            remoteStorageKey: remoteStorageKey,
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repository: locksRepository,
            operationManager: operationManager
        )
    }
}
