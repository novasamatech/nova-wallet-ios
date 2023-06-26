import Foundation

protocol ObservableSyncServiceProtocol: SyncServiceProtocol {
    func subscribeSyncState(
        _ target: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (Bool, Bool) -> Void
    )

    func unsubscribeSyncState(_ target: AnyObject)
}

class ObservableSyncService: BaseSyncService, ObservableSyncServiceProtocol {
    private let syncState = Observable<Bool>(state: false)

    override var isSyncing: Bool {
        didSet {
            updateSyncState()
        }
    }

    override var retryAttempt: Int {
        didSet {
            updateSyncState()
        }
    }

    func subscribeSyncState(
        _ target: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (Bool, Bool) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        syncState.addObserver(with: target, queue: queue, closure: closure)
    }

    func unsubscribeSyncState(_ target: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        syncState.removeObserver(by: target)
    }

    private func updateSyncState() {
        syncState.state = isSyncing || retryAttempt > 0
    }
}
