import Foundation
import Operation_iOS

final class SubtensorStakeStateSubscription {
    let source: SubtensorStakeStateSource
    let mutex: NSLock
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let onSyncing: () -> Void
    let onState: (Multistaking.SubtensorState) -> Void
    let onFailure: (Error) -> Void

    private(set) var lastState: Multistaking.SubtensorState?
    private(set) var isFetching = false
    private var isSubscribed = false
    private var saveCallStore = CancellableCallStore()

    init(
        source: SubtensorStakeStateSource,
        mutex: NSLock,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        onSyncing: @escaping () -> Void,
        onState: @escaping (Multistaking.SubtensorState) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        self.source = source
        self.mutex = mutex
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.onSyncing = onSyncing
        self.onState = onState
        self.onFailure = onFailure
    }

    func subscribe() {
        isSubscribed = true

        source.add(handler: self)
    }

    func unsubscribe() {
        isSubscribed = false
        isFetching = false

        source.remove(handler: self)
    }

    func refresh() {
        source.refresh()
    }

    func save(
        _ wrapper: CompoundOperationWrapper<Void>,
        completion: @escaping (Error?) -> Void
    ) {
        if let pendingOperations = saveCallStore.operatingCall?.allOperations {
            wrapper.addDependency(operations: pendingOperations)
        }

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: saveCallStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { result in
            switch result {
            case .success:
                completion(nil)
            case let .failure(error):
                completion(error)
            }
        }
    }
}

extension SubtensorStakeStateSubscription: SubtensorStakeStateHandler {
    func handleStakeStateFetching() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isSubscribed else {
            return
        }

        isFetching = true

        onSyncing()
    }

    func handleStakeState(_ state: Multistaking.SubtensorState) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isSubscribed else {
            return
        }

        isFetching = false
        lastState = state

        onState(state)
    }

    func handleStakeStateFailure(_ error: Error) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isSubscribed else {
            return
        }

        isFetching = false

        onFailure(error)
    }
}
