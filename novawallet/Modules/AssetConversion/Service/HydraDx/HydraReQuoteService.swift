import Foundation

final class HydraReQuoteService: ObservableSyncService {
    let childServices: [ObservableSyncServiceProtocol]
    let workQueue: DispatchQueue

    init(
        childServices: [ObservableSyncServiceProtocol],
        workQueue: DispatchQueue = .global()
    ) {
        self.childServices = childServices
        self.workQueue = workQueue
    }

    private func updateSyncState() {
        let isChildSyncing = childServices.contains { $0.getIsSyncing() }

        if isSyncing != isChildSyncing {
            isSyncing = isChildSyncing
        }
    }

    override func stopSyncUp() {
        childServices.forEach { $0.unsubscribeSyncState(self) }
    }

    override func performSyncUp() {
        childServices.forEach { child in
            if child.hasSubscription(for: self) {
                return
            }

            child.subscribeSyncState(
                self,
                queue: workQueue
            ) { [weak self] _, _ in
                self?.mutex.lock()

                self?.updateSyncState()

                self?.mutex.unlock()
            }
        }

        completeImmediate(nil)
    }
}
