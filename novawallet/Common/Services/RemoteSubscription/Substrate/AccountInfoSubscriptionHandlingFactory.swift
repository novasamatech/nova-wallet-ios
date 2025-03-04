import Foundation
import Operation_iOS

final class AccountInfoSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    struct LocalStorageKeys {
        let account: String
        let locks: String
        let holds: String
        let freezes: String
    }

    let localKeys: LocalStorageKeys
    let factory: NativeTokenSubscriptionFactoryProtocol

    init(
        localKeys: LocalStorageKeys,
        factory: NativeTokenSubscriptionFactoryProtocol
    ) {
        self.localKeys = localKeys
        self.factory = factory
    }

    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        if localKeys.locks == localStorageKey {
            return factory.createBalanceLocksSubscription(
                remoteStorageKey: remoteStorageKey,
                operationManager: operationManager,
                logger: logger
            )
        } else if localKeys.holds == localStorageKey {
            return factory.createBalanceHoldsSubscription(
                remoteStorageKey: remoteStorageKey,
                operationManager: operationManager,
                logger: logger
            )
        } else if localKeys.freezes == localStorageKey {
            return factory.createBalanceFreezesSubscription(
                remoteStorageKey: remoteStorageKey,
                operationManager: operationManager,
                logger: logger
            )
        } else {
            return factory.createAccountInfoSubscription(
                remoteStorageKey: remoteStorageKey,
                localStorageKey: localStorageKey,
                storage: storage,
                operationManager: operationManager,
                logger: logger
            )
        }
    }
}
