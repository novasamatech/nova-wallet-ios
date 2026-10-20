import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorPositionsSyncServiceProtocol: ApplicationServiceProtocol, ObservableSyncServiceProtocol {
    func add(
        observer: AnyObject,
        onState: @escaping (Multistaking.SubtensorState?) -> Void,
        onFailure: @escaping (Error?) -> Void
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
    private var failureObservable: Observable<SubtensorPositionsSyncFailure?> = .init(state: nil)

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
        failureObservable.state = nil

        stateObservable.state = state

        completeImmediate(nil)
    }

    func markFailed(_ error: Error) {
        failureObservable.state = SubtensorPositionsSyncFailure(error: error)

        completeImmediate(error)
    }
}

extension SubtensorPositionsSyncService: SubtensorPositionsSyncServiceProtocol {
    func add(
        observer: AnyObject,
        onState: @escaping (Multistaking.SubtensorState?) -> Void,
        onFailure: @escaping (Error?) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.addObserver(with: observer, sendStateOnSubscription: true, queue: .main) { _, state in
            onState(state)
        }

        failureObservable.addObserver(with: observer, sendStateOnSubscription: true, queue: .main) { _, failure in
            onFailure(failure?.error)
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

struct SubtensorPositionsSyncFailure: Equatable {
    let error: Error

    static func == (lhs: Self, rhs: Self) -> Bool {
        let lhsError = lhs.error as NSError
        let rhsError = rhs.error as NSError

        return lhsError.domain == rhsError.domain && lhsError.code == rhsError.code
    }
}
