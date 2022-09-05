import Foundation
import RobinHood
import SubstrateSdk

final class OrmlAccountSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let currencyId: Data
    let chainRegistry: ChainRegistryProtocol
    let assetRepository: AnyDataProviderRepository<AssetBalance>
    let locksRepository: AnyDataProviderRepository<AssetLock>
    let eventCenter: EventCenterProtocol
    let transactionSubscription: TransactionSubscription?
    let queue = OperationManagerFacade.sharedDefaultQueue

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        currencyId: Data,
        chainRegistry: ChainRegistryProtocol,
        assetRepository: AnyDataProviderRepository<AssetBalance>,
        locksRepository: AnyDataProviderRepository<AssetLock>,
        eventCenter: EventCenterProtocol,
        transactionSubscription: TransactionSubscription?
    ) {
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.currencyId = currencyId
        self.chainRegistry = chainRegistry
        self.assetRepository = assetRepository
        self.locksRepository = locksRepository
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
        let ormlLocksKey = getKey(storagePath: .ormlTokenLocks)
        if remoteStorageKey == ormlLocksKey {
            return OrmLocksSubscribtion(
                remoteStorageKey: remoteStorageKey,
                chainAssetId: chainAssetId,
                accountId: accountId,
                chainRegistry: chainRegistry,
                repository: locksRepository,
                operationManager: operationManager
            )
        } else {
            return OrmlAccountSubscription(
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

    func getKey(storagePath: StorageCodingPath) -> Data? {
        guard let localKey = try? LocalStorageKeyFactory().createFromStoragePath(storagePath, encodableElement: accountId + currencyId, chainId: chainAssetId.chainId) else {
            return nil
        }

        let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId)!
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let accountRequest = DoubleMapSubscriptionRequest(
            storagePath: storagePath,
            localKey: localKey,
            keyParamClosure: { (self.accountId, self.currencyId) },
            param1Encoder: nil,
            param2Encoder: { $0 }
        )
        let encoding = accountRequest.createKeyEncodingWrapper(using: StorageKeyFactory()) {
            try codingFactoryOperation.extractNoCancellableResultData()
        }
        encoding.addDependency(operations: [codingFactoryOperation])

        queue.addOperations([codingFactoryOperation] + encoding.allOperations, waitUntilFinished: true)

        return try? encoding.targetOperation.extractNoCancellableResultData()
    }
}
