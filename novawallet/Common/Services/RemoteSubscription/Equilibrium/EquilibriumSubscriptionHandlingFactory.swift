import Foundation
import RobinHood

final class EquilibriumSubscriptionHandlingFactory {
    let accountBalanceKey: String
    let locksKey: String
    let reservedKey: String
    let balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol
    let locksUpdater: EquillibriumLocksUpdaterProtocol

    init(
        accountBalanceKey: String,
        locksKey: String,
        reservedKey: String,
        balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol,
        locksUpdater: EquillibriumLocksUpdaterProtocol
    ) {
        self.accountBalanceKey = accountBalanceKey
        self.locksKey = locksKey
        self.reservedKey = reservedKey
        self.balanceUpdater = balanceUpdater
        self.locksUpdater = locksUpdater
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
            return EquilibriumAccountBalancesSubscription(
                remoteStorageKey: remoteStorageKey,
                balanceUpdater: balanceUpdater,
                logger: logger
            )
        case locksKey:
            return EquilibriumLocksSubscription(
                remoteStorageKey: remoteStorageKey,
                locksUpdater: locksUpdater
            )
        case reservedKey:
            return EquilibriumReservedSubscription(
                remoteStorageKey: remoteStorageKey,
                balanceUpdater: balanceUpdater,
                logger: logger
            )
        default:
            logger.error("Unknown subscription with local key: \(localStorageKey)")
            return EquilibriumAccountBalancesSubscription(
                remoteStorageKey: remoteStorageKey,
                balanceUpdater: balanceUpdater,
                logger: logger
            )
        }
    }
}
