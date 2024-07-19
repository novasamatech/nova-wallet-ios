import Foundation
import Operation_iOS

final class AccountInfoSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    let accountLocalStorageKey: String
    let locksLocalStorageKey: String
    let holdsLocalStorageKey: String
    let factory: NativeTokenSubscriptionFactoryProtocol

    init(
        accountLocalStorageKey: String,
        locksLocalStorageKey: String,
        holdsLocalStorageKey: String,
        factory: NativeTokenSubscriptionFactoryProtocol
    ) {
        self.accountLocalStorageKey = accountLocalStorageKey
        self.locksLocalStorageKey = locksLocalStorageKey
        self.holdsLocalStorageKey = holdsLocalStorageKey
        self.factory = factory
    }

    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        if locksLocalStorageKey == localStorageKey {
            return factory.createBalanceLocksSubscription(
                remoteStorageKey: remoteStorageKey,
                operationManager: operationManager,
                logger: logger
            )
        } else if holdsLocalStorageKey == localStorageKey {
            return factory.createBalanceHoldsSubscription(
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
