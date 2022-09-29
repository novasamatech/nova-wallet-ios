import Foundation
import RobinHood
import SubstrateSdk

protocol OrmlTokenSubscriptionFactoryProtocol {
    func createOrmlAccountSubscription(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing

    func createOrmLocksSubscription(
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing
}

protocol NativeTokenSubscriptionFactoryProtocol {
    func createAccountInfoSubscription(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing

    func createBalanceLocksSubscription(
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing
}

// MARK: - OrmlTokenSubscriptionFactoryProtocol

final class TokenSubscriptionFactory: OrmlTokenSubscriptionFactoryProtocol {
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

    func createOrmlAccountSubscription(
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

    func createOrmLocksSubscription(
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        OrmLocksSubscription(
            remoteStorageKey: remoteStorageKey,
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repository: locksRepository,
            operationManager: operationManager,
            logger: logger
        )
    }
}

// MARK: - NativeTokenSubscriptionFactoryProtocol

extension TokenSubscriptionFactory: NativeTokenSubscriptionFactoryProtocol {
    func createAccountInfoSubscription(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        AccountInfoSubscription(
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            assetRepository: assetRepository,
            transactionSubscription: transactionSubscription,
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger,
            eventCenter: eventCenter
        )
    }

    func createBalanceLocksSubscription(
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        BalanceLocksSubscription(
            remoteStorageKey: remoteStorageKey,
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repository: locksRepository,
            operationManager: operationManager,
            logger: logger
        )
    }
}
