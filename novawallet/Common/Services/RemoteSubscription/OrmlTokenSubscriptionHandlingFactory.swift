import RobinHood

final class OrmlTokenSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    let accountLocalStorageKey: String
    let locksLocalStorageKey: String
    let factory: OrmlTokenSubscribtionFactoryProtocol

    init(
        accountLocalStorageKey: String,
        locksLocalStorageKey: String,
        factory: OrmlTokenSubscribtionFactoryProtocol
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
            return factory.createOrmLocksSubscribtion(
                remoteStorageKey: remoteStorageKey,
                operationManager: operationManager,
                logger: logger
            )
        }
        return factory.createOrmlAccountSubscription(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }
}
