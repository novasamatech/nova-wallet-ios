import SoraFoundation
import Operation_iOS

protocol ReferendumsSourceObserver: AnyObject {
    func didReceive(_ changes: [DataProviderChange<ReferendumLocal>])
}

protocol ReferendumObservableSourceProtocol {
    func observe(_ target: ReferendumsSourceObserver)
}

protocol ReferendumObservableStoreProtocol: ReferendumObservableSourceProtocol {
    func save(referendums: [ReferendumLocal])
    func remove(with ids: [ReferendumIdLocal])
}

protocol WeakWrappersClearing: AnyObject {
    var observers: [WeakWrapper] { get set }
}

extension WeakWrappersClearing {
    func clearEmptyWrappers() {
        observers.removeAll { $0.target == nil }
    }
}

final class ReferendumObservableSource {
    var observers: [WeakWrapper] = []
    private var referendums: [ReferendumIdLocal: ReferendumLocal] = [:]

    private let mutex = NSLock()
}

// MARK: ReferendumObservableSourceProtocol

extension ReferendumObservableSource: ReferendumObservableStoreProtocol, WeakWrappersClearing {
    func save(referendums: [ReferendumLocal]) {
        mutex.lock()
        defer { mutex.unlock() }

        clearEmptyWrappers()

        var changes: [DataProviderChange<ReferendumLocal>] = []

        referendums.forEach { referendum in
            let change: DataProviderChange<ReferendumLocal>

            if let existingReferendum = self.referendums[referendum.index] {
                change = .update(newItem: referendum)
            } else {
                change = .insert(newItem: referendum)
            }

            self.referendums[referendum.index] = referendum

            changes.append(change)
        }

        observers.forEach { weakWrapper in
            let observer = weakWrapper.target as? ReferendumsSourceObserver
            observer?.didReceive(changes)
        }
    }

    func remove(with ids: [ReferendumIdLocal]) {
        mutex.lock()
        defer { mutex.unlock() }

        clearEmptyWrappers()

        var changes: [DataProviderChange<ReferendumLocal>] = []

        ids.forEach {
            referendums[$0] = nil
            changes.append(.delete(deletedIdentifier: "\($0)"))
        }
    }

    func observe(_ target: ReferendumsSourceObserver) {
        mutex.lock()
        defer { mutex.unlock() }

        clearEmptyWrappers()

        let weakWrapper = WeakWrapper(target: target)
        observers.append(weakWrapper)

        guard !referendums.isEmpty else { return }

        let changes: [DataProviderChange<ReferendumLocal>] = referendums.map { .insert(newItem: $0.value) }
        target.didReceive(changes)
    }
}

extension ReferendumObservableSource {
    static let shared = ReferendumObservableSource()
}

// MARK: Helpers

extension DataProviderChange where T == ReferendumLocal {
    func itemIdentifier() -> ReferendumIdLocal {
        switch self {
        case let .insert(newItem):
            return newItem.index
        case let .update(newItem):
            return newItem.index
        case let .delete(deletedIdentifier):
            return UInt(deletedIdentifier)!
        }
    }
}

extension Array where Element == DataProviderChange<ReferendumLocal> {
    func mergeToDict(
        _ dict: [ReferendumIdLocal: ReferendumLocal]
    ) -> [ReferendumIdLocal: ReferendumLocal] {
        reduce(into: dict) { result, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                result[newItem.index] = newItem
            case let .delete(deletedIdentifier):
                result[change.itemIdentifier()] = nil
            }
        }
    }
}
