import Foundation
import Operation_iOS

enum BalanceRemoteSubscriptionHandlingParams {
    struct BalancesPallet {
        let accountLocalStorageKey: String
        let locksLocalStorageKey: String
        let holdsLocalStorageKey: String
        let freezesLocalStorageKey: String
    }

    struct OrmlPallet {
        let accountLocalStorageKey: String
        let locksLocalStorageKey: String
    }

    struct AssetsPallet {
        let assetAccountKey: String
        let assetDetailsKey: String
        let extras: StatemineAssetExtras
    }
}

protocol BalanceRemoteSubscriptionHandlingFactoryProtocol {
    func createNative(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        params: BalanceRemoteSubscriptionHandlingParams.BalancesPallet,
        transactionSubscription: TransactionSubscribing?
    ) -> RemoteSubscriptionHandlingFactoryProtocol

    func createOrml(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        params: BalanceRemoteSubscriptionHandlingParams.OrmlPallet,
        transactionSubscription: TransactionSubscribing?
    ) -> RemoteSubscriptionHandlingFactoryProtocol

    func createAssetsPallet(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        params: BalanceRemoteSubscriptionHandlingParams.AssetsPallet,
        transactionSubscription: TransactionSubscribing?
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
        transactionSubscription: TransactionSubscribing?
    ) -> TokenSubscriptionFactory {
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateStorageFacade)

        return TokenSubscriptionFactory(
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repositoryFactory: repositoryFactory,
            eventCenter: eventCenter,
            transactionSubscription: transactionSubscription
        )
    }
}

extension BalanceRemoteSubscriptionHandlingFactory: BalanceRemoteSubscriptionHandlingFactoryProtocol {
    func createNative(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        params: BalanceRemoteSubscriptionHandlingParams.BalancesPallet,
        transactionSubscription: TransactionSubscribing?
    ) -> RemoteSubscriptionHandlingFactoryProtocol {
        let innerFactory = createTokensSubscriptionFactory(
            for: accountId,
            chainAssetId: chainAssetId,
            transactionSubscription: transactionSubscription
        )

        return AccountInfoSubscriptionHandlingFactory(
            localKeys: .init(
                account: params.accountLocalStorageKey,
                locks: params.locksLocalStorageKey,
                holds: params.holdsLocalStorageKey,
                freezes: params.freezesLocalStorageKey
            ),
            factory: innerFactory
        )
    }

    func createOrml(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        params: BalanceRemoteSubscriptionHandlingParams.OrmlPallet,
        transactionSubscription: TransactionSubscribing?
    ) -> RemoteSubscriptionHandlingFactoryProtocol {
        let innerFactory = createTokensSubscriptionFactory(
            for: accountId,
            chainAssetId: chainAssetId,
            transactionSubscription: transactionSubscription
        )

        return OrmlTokenSubscriptionHandlingFactory(
            accountLocalStorageKey: params.accountLocalStorageKey,
            locksLocalStorageKey: params.locksLocalStorageKey,
            factory: innerFactory
        )
    }

    func createAssetsPallet(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        params: BalanceRemoteSubscriptionHandlingParams.AssetsPallet,
        transactionSubscription: TransactionSubscribing?
    ) -> RemoteSubscriptionHandlingFactoryProtocol {
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateStorageFacade)
        let assetRepository = repositoryFactory.createAssetBalanceRepository()

        let balanceUpdater = AssetsBalanceUpdater(
            chainAssetId: chainAssetId,
            accountId: accountId,
            extras: params.extras,
            chainRegistry: chainRegistry,
            assetRepository: assetRepository,
            transactionSubscription: transactionSubscription,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        return AssetsSubscriptionHandlingFactory(
            assetAccountKey: params.assetAccountKey,
            assetDetailsKey: params.assetDetailsKey,
            assetBalanceUpdater: balanceUpdater
        )
    }
}
