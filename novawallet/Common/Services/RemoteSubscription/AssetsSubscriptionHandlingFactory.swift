import Foundation
import RobinHood

final class AssetsSubscriptionHandlingFactory {
    let assetAccountKey: String
    let assetDetailsKey: String
    let assetBalanceUpdater: AssetsBalanceUpdater
    let transactionSubscription: TransactionSubscription?

    init(
        assetAccountKey: String,
        assetDetailsKey: String,
        assetBalanceUpdater: AssetsBalanceUpdater,
        transactionSubscription: TransactionSubscription?
    ) {
        self.assetAccountKey = assetAccountKey
        self.assetDetailsKey = assetDetailsKey
        self.assetBalanceUpdater = assetBalanceUpdater
        self.transactionSubscription = transactionSubscription
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
