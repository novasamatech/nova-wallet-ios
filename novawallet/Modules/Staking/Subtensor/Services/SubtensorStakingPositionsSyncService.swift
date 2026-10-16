import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorPositionsSyncServiceProtocol: ApplicationServiceProtocol {
    /// `BaseSyncService` only logs and reschedules a failed sync, so failures get their own observable
    func add(
        observer: AnyObject,
        onState: @escaping (Multistaking.SubtensorStakingState?) -> Void,
        onFailure: @escaping (Bool) -> Void
    )

    func remove(observer: AnyObject)

    func refresh()
}

final class SubtensorStakingPositionsSyncService: BaseSyncService {
    let accountId: AccountId
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private lazy var stakeStateSubscription = SubtensorStakeStateSubscription(
        accountId: accountId,
        stakeStateFetchFactory: stakeStateFetchFactory,
        connection: connection,
        runtimeService: runtimeService,
        mutex: mutex,
        operationQueue: operationQueue,
        workingQueue: workingQueue,
        logger: logger,
        onSyncing: { [weak self] in self?.markSyncingImmediate() },
        onState: { [weak self] in self?.publish(state: $0) },
        onFailure: { [weak self] in self?.markFailed($0) }
    )

    private var stateObservable: Observable<Multistaking.SubtensorStakingState?> = .init(state: nil)
    private var failureObservable: Observable<Bool> = .init(state: false)

    init(
        accountId: AccountId,
        stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.stakeStateFetchFactory = stakeStateFetchFactory
        self.connection = connection
        self.runtimeService = runtimeService
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

private extension SubtensorStakingPositionsSyncService {
    func publish(state: Multistaking.SubtensorStakingState) {
        failureObservable.state = false

        stateObservable.state = state

        completeImmediate(state.rootRedeemableError)
    }

    func markFailed(_ error: Error) {
        failureObservable.state = true

        completeImmediate(error)
    }
}

extension SubtensorStakingPositionsSyncService: SubtensorPositionsSyncServiceProtocol {
    func add(
        observer: AnyObject,
        onState: @escaping (Multistaking.SubtensorStakingState?) -> Void,
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
