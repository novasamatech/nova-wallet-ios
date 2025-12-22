import Foundation
import Operation_iOS

final class OrmlTokenSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    let accountLocalStorageKey: String
    let locksLocalStorageKey: String
    let factory: OrmlTokenSubscriptionFactoryProtocol

    init(
        accountLocalStorageKey: String,
        locksLocalStorageKey: String,
        factory: OrmlTokenSubscriptionFactoryProtocol
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
            return factory.createOrmLocksSubscription(
                remoteStorageKey: remoteStorageKey,
                operationManager: operationManager,
                logger: logger
            )
        } else {
            return factory.createOrmlAccountSubscription(
                remoteStorageKey: remoteStorageKey,
                localStorageKey: localStorageKey,
                storage: storage,
                operationManager: operationManager,
                logger: logger
            )
        }
    }
}
