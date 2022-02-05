import Foundation
import RobinHood

protocol RemoteSubscriptionHandlingFactoryProtocol {
    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing
}

final class DefaultRemoteSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        EmptyHandlingStorageSubscription(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }
}

final class EventRemoteSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    let eventCenter: EventCenterProtocol
    let eventFactory: EventEmittingFactoryClosure

    init(eventCenter: EventCenterProtocol, eventFactory: @escaping EventEmittingFactoryClosure) {
        self.eventCenter = eventCenter
        self.eventFactory = eventFactory
    }

    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        EventEmittingStorageSubscription(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger,
            eventCenter: eventCenter,
            eventFactory: eventFactory
        )
    }
}
