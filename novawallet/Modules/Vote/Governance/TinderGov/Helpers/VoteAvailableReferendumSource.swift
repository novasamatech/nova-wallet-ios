import SoraFoundation
import Operation_iOS

final class VoteAvailableReferendumSource {
    var observers: [WeakWrapper] = []

    private let referendumsSource: ReferendumObservableSourceProtocol
    private let filter: ReferendumFilter.VoteAvailableChanges

    private var changes: [ReferendumIdLocal: DataProviderChange<ReferendumLocal>] = [:]

    private let mutex = NSLock()

    init(
        referendumsSource: ReferendumObservableSourceProtocol,
        filter: ReferendumFilter.VoteAvailableChanges
    ) {
        self.referendumsSource = referendumsSource
        self.filter = filter

        referendumsSource.observe(self)
    }
}

// MARK: ReferendumObservableSourceProtocol

extension VoteAvailableReferendumSource: ReferendumObservableSourceProtocol, WeakWrappersClearing {
    func observe(_ target: any ReferendumsSourceObserver) {
        mutex.lock()
        defer { mutex.unlock() }

        clearEmptyWrappers()

        let weakWrapper = WeakWrapper(target: target)
        observers.append(weakWrapper)

        guard !changes.isEmpty else { return }

        target.didReceive(Array(changes.values))
    }
}

// MARK: ReferendumsSourceObserver

extension VoteAvailableReferendumSource: ReferendumsSourceObserver {
    func didReceive(_ changes: [DataProviderChange<ReferendumLocal>]) {
        let filteredChanges = filter(changes: changes)
        observers.forEach { ($0 as? ReferendumsSourceObserver)?.didReceive(filteredChanges) }
        
        filteredChanges.forEach { change in
            let id = change.itemIdentifier()
            
            if
                let existingChange = self.changes[id],
                change.isDeletion {
                self.changes[id] = nil
            } else {
                self.changes[id] = change
            }
        }
    }
}
