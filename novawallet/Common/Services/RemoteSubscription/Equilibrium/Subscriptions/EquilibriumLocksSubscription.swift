import Foundation

final class EquilibriumLocksSubscription: StorageChildSubscribing {
    let remoteStorageKey: Data
    let locksUpdater: EquillibriumLocksUpdaterProtocol

    init(
        remoteStorageKey: Data,
        locksUpdater: EquillibriumLocksUpdaterProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.locksUpdater = locksUpdater
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        locksUpdater.handle(value: data, blockHash: blockHash)
    }
}
