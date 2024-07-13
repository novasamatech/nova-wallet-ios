import Foundation
import Operation_iOS

protocol BalanceRemoteSubscriptionHandlingFactoryProtocol {
    func createNative(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        accountLocalStorageKey: String,
        locksLocalStorageKey: String,
        transactionSubscription: TransactionSubscription?
    ) -> RemoteSubscriptionHandlingFactoryProtocol

    func createOrml(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        accountLocalStorageKey: String,
        locksLocalStorageKey: String,
        transactionSubscription: TransactionSubscription?
    ) -> RemoteSubscriptionHandlingFactoryProtocol

    func createAssetsPallet(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        extras: StatemineAssetExtras,
        assetAccountKey: String,
        assetDetailsKey: String,
        transactionSubscription: TransactionSubscription?
    ) -> RemoteSubscriptionHandlingFactoryProtocol
}

final class BalanceRemoteSubscriptionHandlingFactory {
    let chainRegistry: ChainRegistryProtocol
    let substrateStorageFacade: StorageFacadeProtocol
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
        self.substrateStorageFacade = substrateStorageFacade
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createTokensSubscriptionFactory(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        transactionSubscription: TransactionSubscription?
    ) -> TokenSubscriptionFactory {
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateStorageFacade)
        let assetRepository = repositoryFactory.createAssetBalanceRepository()
        let locksRepository = repositoryFactory.createAssetLocksRepository(for: accountId, chainAssetId: chainAssetId)

        return TokenSubscriptionFactory(
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            assetRepository: assetRepository,
            locksRepository: locksRepository,
            eventCenter: eventCenter,
            transactionSubscription: transactionSubscription
        )
    }
}

extension BalanceRemoteSubscriptionHandlingFactory: BalanceRemoteSubscriptionHandlingFactoryProtocol {
    func createNative(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        accountLocalStorageKey: String,
        locksLocalStorageKey: String,
        transactionSubscription: TransactionSubscription?
    ) -> RemoteSubscriptionHandlingFactoryProtocol {
        let innerFactory = createTokensSubscriptionFactory(
            for: accountId,
            chainAssetId: chainAssetId,
            transactionSubscription: transactionSubscription
        )

        return AccountInfoSubscriptionHandlingFactory(
            accountLocalStorageKey: accountLocalStorageKey,
            locksLocalStorageKey: locksLocalStorageKey,
            factory: innerFactory
        )
    }

    func createOrml(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        accountLocalStorageKey: String,
        locksLocalStorageKey: String,
        transactionSubscription: TransactionSubscription?
    ) -> RemoteSubscriptionHandlingFactoryProtocol {
        let innerFactory = createTokensSubscriptionFactory(
            for: accountId,
            chainAssetId: chainAssetId,
            transactionSubscription: transactionSubscription
        )

        return OrmlTokenSubscriptionHandlingFactory(
            accountLocalStorageKey: accountLocalStorageKey,
            locksLocalStorageKey: locksLocalStorageKey,
            factory: innerFactory
        )
    }

    func createAssetsPallet(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        extras: StatemineAssetExtras,
        assetAccountKey: String,
        assetDetailsKey: String,
        transactionSubscription: TransactionSubscription?
    ) -> RemoteSubscriptionHandlingFactoryProtocol {
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateStorageFacade)
        let assetRepository = repositoryFactory.createAssetBalanceRepository()

        let balanceUpdater = AssetsBalanceUpdater(
            chainAssetId: chainAssetId,
            accountId: accountId,
            extras: extras,
            chainRegistry: chainRegistry,
            assetRepository: assetRepository,
            transactionSubscription: transactionSubscription,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        return AssetsSubscriptionHandlingFactory(
            assetAccountKey: assetAccountKey,
            assetDetailsKey: assetDetailsKey,
            assetBalanceUpdater: balanceUpdater
        )
    }
}
