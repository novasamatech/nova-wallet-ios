import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorPositionsSyncServiceProtocol: ApplicationServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Multistaking.SubtensorStakingState?>.StateChangeClosure
    )

    func remove(observer: AnyObject)

    /// `BaseSyncService` only logs and reschedules on failure, so a parallel observable is the
    /// one way a caller can tell "still loading" from "we could not read the chain" (spec §3.2)
    func add(
        failureObserver: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Bool>.StateChangeClosure
    )

    func remove(failureObserver: AnyObject)

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
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Multistaking.SubtensorStakingState?>.StateChangeClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.addObserver(
            with: observer,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: queue,
            closure: closure
        )
    }

    func remove(observer: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.removeObserver(by: observer)
    }

    func add(
        failureObserver: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Bool>.StateChangeClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        failureObservable.addObserver(
            with: failureObserver,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: queue,
            closure: closure
        )
    }

    func remove(failureObserver: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        failureObservable.removeObserver(by: failureObserver)
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
