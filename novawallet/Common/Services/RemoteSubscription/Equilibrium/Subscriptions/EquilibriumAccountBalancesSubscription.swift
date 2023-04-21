import Foundation

final class EquilibriumAccountBalancesSubscription: StorageChildSubscribing {
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
        balanceUpdater.handleAccountBalances(value: data, blockHash: blockHash)
    }
}
