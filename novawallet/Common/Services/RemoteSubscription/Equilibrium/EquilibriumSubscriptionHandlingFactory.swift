import Foundation
import RobinHood

final class EquilibriumSubscriptionHandlingFactory {
    let accountBalanceKey: String
    let locksKey: String
    let reservedKey: String
    
    init(
        accountBalanceKey: String,
        locksKey: String,
        reservedKey: String,
        assetBalanceUpdater: AssetsBalanceUpdater
    ) {
        self.accountBalanceKey = accountBalanceKey
        self.locksKey = locksKey
        self.reservedKey = reservedKey
    }
}

extension EquilibriumSubscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage _: AnyDataProviderRepository<ChainStorageItem>,
        operationManager _: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        switch localStorageKey {
        case accountBalanceKey:
            return EquilibriumAccountSubscription(remoteStorageKey: remoteStorageKey,
                                                  logger: logger)
        case locksKey:
            return EquilibriumLocksSubscription(remoteStorageKey: remoteStorageKey,
                                                logger: logger)
        case reservedKey:
            return EquilibriumReservedSubscription(remoteStorageKey: remoteStorageKey,
                                                   logger: logger)
        default:
            logger.error("Unknown subscription with local key: \(localStorageKey)")
            return EquilibriumAccountSubscription(remoteStorageKey: remoteStorageKey,
                                                  logger: logger)
        }
    }
}

final class EquilibriumAccountSubscription: StorageChildSubscribing {
    let remoteStorageKey: Data
    let logger: LoggerProtocol

    init(
        remoteStorageKey: Data,
        logger: LoggerProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.logger = logger
    }
    
    func processUpdate(_ data: Data?, blockHash: Data?) {
        logger.debug("Did receive asset account update")
    }
}

final class EquilibriumLocksSubscription: StorageChildSubscribing {
    let remoteStorageKey: Data
    let logger: LoggerProtocol

    init(
        remoteStorageKey: Data,
        logger: LoggerProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.logger = logger
    }
    
    func processUpdate(_ data: Data?, blockHash: Data?) {
        logger.debug("Did receive asset account update")
    }
}

final class EquilibriumReservedSubscription: StorageChildSubscribing {
    let remoteStorageKey: Data
    let logger: LoggerProtocol

    init(
        remoteStorageKey: Data,
        logger: LoggerProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.logger = logger
    }
    
    func processUpdate(_ data: Data?, blockHash: Data?) {
        logger.debug("Did receive asset account update")
    }
}
