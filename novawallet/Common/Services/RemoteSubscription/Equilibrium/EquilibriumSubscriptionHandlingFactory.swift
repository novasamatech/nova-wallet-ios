import Foundation
import RobinHood

final class EquilibriumSubscriptionHandlingFactory {
    let accountBalanceKey: String
    let locksKey: String
    let reservedKeys: [String: EquilibriumAssetId]
    let balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol
    let locksUpdater: EquillibriumLocksUpdaterProtocol

    init(
        accountBalanceKey: String,
        locksKey: String,
        reservedKeys: [String: EquilibriumAssetId],
        balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol,
        locksUpdater: EquillibriumLocksUpdaterProtocol
    ) {
        self.accountBalanceKey = accountBalanceKey
        self.locksKey = locksKey
        self.reservedKeys = reservedKeys
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
        default:
            if let assetId = reservedKeys[localStorageKey] {
                return EquilibriumReservedSubscription(
                    remoteStorageKey: remoteStorageKey,
                    assetId: assetId,
                    balanceUpdater: balanceUpdater,
                    logger: logger
                )
            } else {
                logger.error("Unknown subscription with local key: \(localStorageKey)")
                return EquilibriumAccountBalancesSubscription(
                    remoteStorageKey: remoteStorageKey,
                    balanceUpdater: balanceUpdater,
                    logger: logger
                )
            }
        }
    }
}
