import Foundation

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
