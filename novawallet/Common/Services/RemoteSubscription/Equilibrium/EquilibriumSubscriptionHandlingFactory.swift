import Foundation
import RobinHood

final class EquilibriumSubscriptionHandlingFactory {
    let accountBalanceKey: String
    let locksKey: String
    let reservedKey: String
    let balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol

    init(
        accountBalanceKey: String,
        locksKey: String,
        reservedKey: String,
        balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol
    ) {
        self.accountBalanceKey = accountBalanceKey
        self.locksKey = locksKey
        self.reservedKey = reservedKey
        self.balanceUpdater = balanceUpdater
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
            return EquilibriumAccountSubscription(
                remoteStorageKey: remoteStorageKey,
                balanceUpdater: balanceUpdater,
                logger: logger
            )
        case locksKey:
            return EquilibriumLocksSubscription(
                remoteStorageKey: remoteStorageKey,
                logger: logger
            )
        case reservedKey:
            return EquilibriumReservedSubscription(
                remoteStorageKey: remoteStorageKey,
                balanceUpdater: balanceUpdater,
                logger: logger
            )
        default:
            logger.error("Unknown subscription with local key: \(localStorageKey)")
            return EquilibriumAccountSubscription(
                remoteStorageKey: remoteStorageKey,
                balanceUpdater: balanceUpdater,
                logger: logger
            )
        }
    }
}

final class EquilibriumAccountSubscription: StorageChildSubscribing {
    let remoteStorageKey: Data
    let logger: LoggerProtocol
    let balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol

    init(
        remoteStorageKey: Data,
        balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol,
        logger: LoggerProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.balanceUpdater = balanceUpdater
        self.logger = logger
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        logger.debug("Did receive asset account update")
        balanceUpdater.handleAssetAccount(value: data, blockHash: blockHash)
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

    func processUpdate(_: Data?, blockHash _: Data?) {
        logger.debug("Did receive asset account update")
    }
}

final class EquilibriumReservedSubscription: StorageChildSubscribing {
    let remoteStorageKey: Data
    let balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol
    let logger: LoggerProtocol

    init(
        remoteStorageKey: Data,
        balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol,
        logger: LoggerProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.balanceUpdater = balanceUpdater
        self.logger = logger
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        logger.debug("Did receive asset account update")
        balanceUpdater.handleReservedBalance(value: data, blockHash: blockHash)
    }
}
