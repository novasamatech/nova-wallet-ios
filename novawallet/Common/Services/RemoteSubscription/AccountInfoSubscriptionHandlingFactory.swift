import Foundation
import RobinHood

final class AccountInfoSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    let eventCenter: EventCenterProtocol
    let transactionSubscription: TransactionSubscription

    init(
        transactionSubscription: TransactionSubscription,
        eventCenter: EventCenterProtocol
    ) {
        self.transactionSubscription = transactionSubscription
        self.eventCenter = eventCenter
    }

    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        AccountInfoSubscription(
            transactionSubscription: transactionSubscription,
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger,
            eventCenter: eventCenter
        )
    }
}
