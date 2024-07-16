import Foundation
import Operation_iOS

final class BalanceRemoteSubscriptionHandlingProxy {
    let store: [String: RemoteSubscriptionHandlingFactoryProtocol]

    init(store: [String: RemoteSubscriptionHandlingFactoryProtocol]) {
        self.store = store
    }
}

extension BalanceRemoteSubscriptionHandlingProxy: RemoteSubscriptionHandlingFactoryProtocol {
    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        if let handler = store[localStorageKey] {
            return handler.createHandler(
                remoteStorageKey: remoteStorageKey,
                localStorageKey: localStorageKey,
                storage: storage,
                operationManager: operationManager,
                logger: logger
            )
        } else {
            return EmptyHandlingStorageSubscription(
                remoteStorageKey: remoteStorageKey,
                localStorageKey: localStorageKey,
                storage: storage,
                operationManager: operationManager,
                logger: logger
            )
        }
    }
}
