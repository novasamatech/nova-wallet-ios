import Foundation
import RobinHood

final class AssetsSubscriptionHandlingFactory {
    let assetAccountKey: String
    let assetDetailsKey: String
    let assetLocksKey: String
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<AssetLock>
    let assetBalanceUpdater: AssetsBalanceUpdater
    let transactionSubscription: TransactionSubscription?

    init(
        assetAccountKey: String,
        assetDetailsKey: String,
        assetLocksKey: String,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<AssetLock>,
        assetBalanceUpdater: AssetsBalanceUpdater,
        transactionSubscription: TransactionSubscription?
    ) {
        self.assetAccountKey = assetAccountKey
        self.assetDetailsKey = assetDetailsKey
        self.assetLocksKey = assetLocksKey
        self.assetBalanceUpdater = assetBalanceUpdater
        self.transactionSubscription = transactionSubscription
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.repository = repository
    }
}

extension AssetsSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        if localStorageKey == assetAccountKey {
            return AssetAccountSubscription(
                assetBalanceUpdater: assetBalanceUpdater,
                remoteStorageKey: remoteStorageKey,
                localStorageKey: localStorageKey,
                storage: storage,
                operationManager: operationManager,
                transactionSubscription: transactionSubscription,
                logger: logger
            )
        } else if localStorageKey == assetLocksKey {
            return BalanceLocksSubscribtion(
                remoteStorageKey: remoteStorageKey,
                chainAssetId: chainAssetId,
                accountId: accountId,
                chainRegistry: chainRegistry,
                repository: repository,
                operationManager: operationManager
            )
        } else {
            return AssetDetailsSubscription(
                assetBalanceUpdater: assetBalanceUpdater,
                remoteStorageKey: remoteStorageKey,
                localStorageKey: localStorageKey,
                storage: storage,
                operationManager: operationManager,
                transactionSubscription: nil,
                logger: logger
            )
        }
    }
}
