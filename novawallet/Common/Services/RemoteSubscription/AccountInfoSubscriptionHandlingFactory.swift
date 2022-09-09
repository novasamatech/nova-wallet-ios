import Foundation
import RobinHood

final class AccountInfoSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    let accountLocalStorageKey: String
    let locksLocalStorageKey: String
    let factory: NativeTokenSubscriptionFactoryProtocol

    init(
        accountLocalStorageKey: String,
        locksLocalStorageKey: String,
        factory: NativeTokenSubscriptionFactoryProtocol
    ) {
        self.accountLocalStorageKey = accountLocalStorageKey
        self.locksLocalStorageKey = locksLocalStorageKey
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
        }
        return factory.createAccountInfoSubscription(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }
}
