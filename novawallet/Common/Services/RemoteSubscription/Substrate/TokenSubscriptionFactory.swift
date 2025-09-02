import Foundation
import Operation_iOS
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

    func createBalanceHoldsSubscription(
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing

    func createBalanceFreezesSubscription(
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
    let eventCenter: EventCenterProtocol
    let transactionSubscription: TransactionSubscribing?
    let repositoryFactory: SubstrateRepositoryFactoryProtocol

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        eventCenter: EventCenterProtocol,
        transactionSubscription: TransactionSubscribing?
    ) {
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.repositoryFactory = repositoryFactory
        self.eventCenter = eventCenter
        self.transactionSubscription = transactionSubscription
    }

    private func createAssetBalanceRepository() -> AnyDataProviderRepository<AssetBalance> {
        repositoryFactory.createAssetBalanceRepository()
    }

    private func createAssetLocksRepository() -> AnyDataProviderRepository<AssetLock> {
        repositoryFactory.createAssetStorageLocksRepository(
            for: accountId,
            chainAssetId: chainAssetId
        )
    }

    private func createAssetFreezesRepository() -> AnyDataProviderRepository<AssetLock> {
        repositoryFactory.createAssetStorageFreezesRepository(
            for: accountId,
            chainAssetId: chainAssetId
        )
    }

    private func createAssetHoldsRepository() -> AnyDataProviderRepository<AssetHold> {
        repositoryFactory.createAssetHoldsRepository(for: accountId, chainAssetId: chainAssetId)
    }

    func createOrmlAccountSubscription(
        remoteStorageKey: Data,
        localStorageKey _: String,
        storage _: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        OrmlAccountSubscription(
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            assetRepository: createAssetBalanceRepository(),
            remoteStorageKey: remoteStorageKey,
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
            repository: createAssetLocksRepository(),
            operationManager: operationManager,
            logger: logger
        )
    }
}

// MARK: - NativeTokenSubscriptionFactoryProtocol

extension TokenSubscriptionFactory: NativeTokenSubscriptionFactoryProtocol {
    func createAccountInfoSubscription(
        remoteStorageKey: Data,
        localStorageKey _: String,
        storage _: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        AccountInfoSubscription(
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            assetRepository: createAssetBalanceRepository(),
            transactionSubscription: transactionSubscription,
            remoteStorageKey: remoteStorageKey,
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
            repository: createAssetLocksRepository(),
            operationManager: operationManager,
            logger: logger
        )
    }

    func createBalanceHoldsSubscription(
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        HoldsSubscription(
            storageCodingPath: BalancesPallet.holdsPath,
            remoteStorageKey: remoteStorageKey,
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repository: createAssetHoldsRepository(),
            operationManager: operationManager,
            logger: logger
        )
    }

    func createBalanceFreezesSubscription(
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        FreezesSubscription(
            storageCodingPath: BalancesPallet.freezesPath,
            remoteStorageKey: remoteStorageKey,
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repository: createAssetFreezesRepository(),
            operationManager: operationManager,
            logger: logger
        )
    }
}
