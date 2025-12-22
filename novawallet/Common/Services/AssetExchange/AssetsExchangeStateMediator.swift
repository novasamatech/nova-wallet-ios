import Foundation
import Operation_iOS

protocol AssetsExchangeStateProviding: AnyObject {
    func throttleStateServices()
}

protocol AssetsExchangeStateRegistring: AnyObject {
    func addStateProvider(_ provider: AssetsExchangeStateProviding)
    func registerStateService(_ service: ObservableSyncServiceProtocol)
    func deregisterStateService(_ service: ObservableSyncServiceProtocol)
}

protocol AssetsExchangeStateManaging: AnyObject {
    func subscribeStateChanges(
        _ target: AnyObject,
        ignoreIfAlreadyAdded: Bool,
        notifyingIn queue: DispatchQueue,
        closure: @escaping () -> Void
    )

    func throttleStateServicesSynchroniously()
}

typealias AssetsExchangeStateMediating = AssetsExchangeStateManaging & AssetsExchangeStateRegistring

final class AssetsExchangeStateMediator {
    private var stateProviders: [WeakWrapper] = []
    private var observers: [WeakObserver] = []

    private let syncQueue: DispatchQueue = .init(label: "io.novawallet.assetexchangestatemediator.\(UUID().uuidString)")

    private func notifyObservers() {
        observers.forEach { observer in
            if observer.target != nil {
                dispatchInQueueWhenPossible(observer.notificationQueue, block: observer.closure)
            }
        }
    }

    private func addObserver(to service: ObservableSyncServiceProtocol) {
        observers.clearEmptyItems()

        service.subscribeSyncState(
            self,
            queue: syncQueue
        ) { [weak self] wasSyncing, isSyncing in
            if wasSyncing, !isSyncing {
                self?.notifyObservers()
            }
        }
    }
}

extension AssetsExchangeStateMediator: AssetsExchangeStateRegistring {
    func addStateProvider(_ provider: AssetsExchangeStateProviding) {
        syncQueue.async {
            self.stateProviders.append(.init(target: provider))
        }
    }

    func registerStateService(_ service: ObservableSyncServiceProtocol) {
        if !service.hasSubscription(for: self) {
            service.subscribeSyncState(self, queue: syncQueue) { [weak self] wasSyncing, isSyncing in
                if wasSyncing, !isSyncing {
                    self?.notifyObservers()
                }
            }
        }
    }

    func deregisterStateService(_ service: ObservableSyncServiceProtocol) {
        service.unsubscribeSyncState(self)
    }
}

extension AssetsExchangeStateMediator: AssetsExchangeStateManaging {
    func subscribeStateChanges(
        _ target: AnyObject,
        ignoreIfAlreadyAdded: Bool,
        notifyingIn queue: DispatchQueue,
        closure: @escaping () -> Void
    ) {
        syncQueue.async {
            if ignoreIfAlreadyAdded, self.observers.contains(where: { $0.target === target }) {
                return
            }

            self.observers = self.observers.filter { $0.target !== target || $0.target == nil }
            self.observers.append(.init(target: target, notificationQueue: queue, closure: closure))
        }
    }

    func throttleStateServicesSynchroniously() {
        syncQueue.sync {
            self.stateProviders.forEach { wrapper in
                if let provider = wrapper.target as? AssetsExchangeStateProviding {
                    provider.throttleStateServices()
                }
            }
        }
    }
}
