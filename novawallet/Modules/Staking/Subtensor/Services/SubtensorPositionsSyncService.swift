import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorPositionsSyncServiceProtocol: ApplicationServiceProtocol, ObservableSyncServiceProtocol {
    func add(
        observer: AnyObject,
        onState: @escaping (Multistaking.SubtensorState?) -> Void,
        onFailure: @escaping (Bool) -> Void
    )

    func remove(observer: AnyObject)

    func refresh()
}

final class SubtensorPositionsSyncService: ObservableSyncService {
    let stakeStateSource: SubtensorStakeStateSource
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private lazy var stakeStateSubscription = SubtensorStakeStateSubscription(
        source: stakeStateSource,
        mutex: mutex,
        operationQueue: operationQueue,
        workingQueue: workingQueue,
        onSyncing: { [weak self] in self?.markSyncingImmediate() },
        onState: { [weak self] in self?.publish(state: $0) },
        onFailure: { [weak self] in self?.markFailed($0) }
    )

    private var stateObservable: Observable<Multistaking.SubtensorState?> = .init(state: nil)
    private var failureObservable: Observable<Bool> = .init(state: false)

    init(
        stakeStateSource: SubtensorStakeStateSource,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.stakeStateSource = stakeStateSource
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        stakeStateSubscription.subscribe()
    }

    override func stopSyncUp() {
        stakeStateSubscription.unsubscribe()
    }

    override func deactivate() {
        stakeStateSubscription.unsubscribe()
    }
}

private extension SubtensorPositionsSyncService {
    func publish(state: Multistaking.SubtensorState) {
        failureObservable.state = false

        stateObservable.state = state

        completeImmediate(nil)
    }

    func markFailed(_ error: Error) {
        failureObservable.state = true

        completeImmediate(error)
    }
}

extension SubtensorPositionsSyncService: SubtensorPositionsSyncServiceProtocol {
    func add(
        observer: AnyObject,
        onState: @escaping (Multistaking.SubtensorState?) -> Void,
        onFailure: @escaping (Bool) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.addObserver(with: observer, sendStateOnSubscription: true, queue: .main) { _, state in
            onState(state)
        }

        failureObservable.addObserver(with: observer, sendStateOnSubscription: true, queue: .main) { _, isFailed in
            onFailure(isFailed)
        }
    }

    func remove(observer: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.removeObserver(by: observer)
        failureObservable.removeObserver(by: observer)
    }

    func refresh() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        stakeStateSubscription.refresh()
    }
}
