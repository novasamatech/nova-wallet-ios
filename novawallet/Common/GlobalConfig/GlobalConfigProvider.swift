import Foundation
import Operation_iOS

struct GlobalConfigSnapshot {
    let config: GlobalConfig
    let revision: UInt64
}

protocol GlobalConfigProviding {
    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig>
    func createFreshConfigWrapper() -> CompoundOperationWrapper<GlobalConfig>
    func createConfigSnapshotWrapper() -> CompoundOperationWrapper<GlobalConfigSnapshot>
    func addSnapshotObserver(_ observer: AnyObject, closure: @escaping (GlobalConfigSnapshot) -> Void)
}

extension GlobalConfigProviding {
    func addSnapshotObserver(_: AnyObject, closure _: @escaping (GlobalConfigSnapshot) -> Void) {}
}

final class GlobalConfigProvider: BaseFetchOperationFactory {
    private struct Observer {
        weak var owner: AnyObject?
        let closure: (GlobalConfigSnapshot) -> Void
    }

    let configUrl: URL
    private let mutex = NSLock()
    private var snapshot: GlobalConfigSnapshot?
    private var revision: UInt64 = 0
    private var observers: [Observer] = []

    init(configUrl: URL) {
        self.configUrl = configUrl
    }
}

extension GlobalConfigProvider: GlobalConfigProviding {
    func addSnapshotObserver(_ observer: AnyObject, closure: @escaping (GlobalConfigSnapshot) -> Void) {
        mutex.lock()
        observers = observers.filter { $0.owner != nil }
        observers.append(Observer(owner: observer, closure: closure))
        let current = snapshot
        mutex.unlock()
        if let current { closure(current) }
    }

    func createConfigSnapshotWrapper() -> CompoundOperationWrapper<GlobalConfigSnapshot> {
        mutex.lock()
        let current = snapshot
        mutex.unlock()
        return current.map { .createWithResult($0) } ?? createFreshSnapshotWrapper()
    }

    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> {
        mapConfig(createConfigSnapshotWrapper())
    }

    func createFreshConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> {
        mapConfig(createFreshSnapshotWrapper())
    }
}

private extension GlobalConfigProvider {
    func mapConfig(
        _ wrapper: CompoundOperationWrapper<GlobalConfigSnapshot>
    ) -> CompoundOperationWrapper<GlobalConfig> {
        let operation = ClosureOperation { try wrapper.targetOperation.extractNoCancellableResultData().config }
        operation.addDependency(wrapper.targetOperation)
        return wrapper.insertingTail(operation: operation)
    }

    func createFreshSnapshotWrapper() -> CompoundOperationWrapper<GlobalConfigSnapshot> {
        mutex.lock()
        revision += 1
        let requestedRevision = revision
        mutex.unlock()

        let fetch: BaseOperation<GlobalConfig> = createFetchOperation(from: configUrl, shouldUseCache: false)
        let publish = ClosureOperation<GlobalConfigSnapshot> {
            let config = try fetch.extractNoCancellableResultData()
            self.mutex.lock()
            if let current = self.snapshot, current.revision > requestedRevision {
                self.mutex.unlock()
                return current
            }
            let accepted = GlobalConfigSnapshot(config: config, revision: requestedRevision)
            self.snapshot = accepted
            let callbacks = self.observers.filter { $0.owner != nil }.map(\.closure)
            self.mutex.unlock()
            callbacks.forEach { $0(accepted) }
            return accepted
        }
        publish.addDependency(fetch)
        return CompoundOperationWrapper(targetOperation: publish, dependencies: [fetch])
    }
}
