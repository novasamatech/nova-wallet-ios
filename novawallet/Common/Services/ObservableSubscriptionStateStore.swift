import Foundation
import SubstrateSdk
import Operation_iOS

protocol ObservableSubscriptionStateStoreProtocol: ApplicationServiceProtocol {}

typealias EquatableObservableSubscriptionState = ObservableSubscriptionStateProtocol & Equatable

class ObservableSubscriptionStateStore<T: EquatableObservableSubscriptionState>: BaseObservableStateStore<T> {
    let runtimeConnectionStore: RuntimeConnectionStoring
    let repository: AnyDataProviderRepository<ChainStorageItem>?
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    var subscription: CallbackBatchStorageSubscription<T.TChange>?

    init(
        runtimeConnectionStore: RuntimeConnectionStoring,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue
        self.repository = repository
        self.workQueue = workQueue

        super.init(logger: logger)
    }

    deinit {
        clearSubscription()
    }

    func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        fatalError("Must be overriden by subsclass")
    }
}

private extension ObservableSubscriptionStateStore {
    func subscribe() {
        do {
            let requests = try getRequests()

            let connection = try runtimeConnectionStore.getConnection()
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()

            subscription = CallbackBatchStorageSubscription(
                requests: requests,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: repository,
                operationQueue: operationQueue,
                callbackQueue: workQueue
            ) { [weak self] result in
                self?.mutex.lock()

                self?.handleStateChangeResult(result)

                self?.mutex.unlock()
            }

            subscription?.subscribe()
        } catch {
            logger.error("Subscription setup failed: \(error)")
        }
    }

    func handleStateChangeResult(_ result: Result<T.TChange, Error>) {
        do {
            let change = try result.get()

            if let currentState = stateObservable.state {
                stateObservable.state = currentState.merging(change: change)
            } else {
                stateObservable.state = try .init(change: change)
            }

        } catch {
            logger.error("Subscription failed: \(error)")
        }
    }

    func clearSubscription() {
        subscription?.unsubscribe()
        subscription = nil
    }
}

extension ObservableSubscriptionStateStore: ObservableSubscriptionStateStoreProtocol {
    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if subscription == nil {
            subscribe()
        }
    }

    func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearSubscription()
    }
}
