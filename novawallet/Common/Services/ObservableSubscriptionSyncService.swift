import Foundation
import SubstrateSdk
import RobinHood

protocol ObservableSubscriptionStateProtocol {
    associatedtype TChange: BatchStorageSubscriptionResult

    init(change: TChange)

    func merging(change: TChange) -> Self
}

protocol ObservableSubscriptionSyncServiceProtocol {
    associatedtype TState

    func createFetchOperation() -> BaseOperation<TState>
}

enum ObservableSubscriptionSyncServiceError: Error {
    case unexpectedState
}

class ObservableSubscriptionSyncService<T: ObservableSubscriptionStateProtocol>: ObservableSyncService,
    ObservableSubscriptionSyncServiceProtocol {
    typealias TState = T

    let runtimeProvider: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let repository: AnyDataProviderRepository<ChainStorageItem>?
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    var state: T?
    var subscription: CallbackBatchStorageSubscription<T.TChange>?

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),

        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.repository = repository
        self.workQueue = workQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    deinit {
        clearSubscription()
    }

    func getState() -> T? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return state
    }

    func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        fatalError("Must be overriden by subsclass")
    }

    override func stopSyncUp() {
        clearSubscription()
    }

    override func performSyncUp() {
        do {
            clearSubscription()

            try subscribe()
        } catch {
            completeImmediate(error)
        }
    }

    // MARK: Private

    private func subscribe() throws {
        let requests = try getRequests()

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
    }

    private func handleStateChangeResult(_ result: Result<T.TChange, Error>) {
        switch result {
        case let .success(change):
            // switch sync state manually if needed to allow others track when new state applied
            if !isSyncing {
                isSyncing = true
            }

            logger.debug("Change: \(change)")

            if let currentState = state {
                state = currentState.merging(change: change)
            } else {
                state = .init(change: change)
            }

            completeImmediate(nil)
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
            completeImmediate(error)
        }
    }

    private func clearSubscription() {
        subscription?.unsubscribe()
        subscription = nil
    }
}

extension ObservableSubscriptionSyncService {
    func createFetchOperation() -> BaseOperation<T> {
        ClosureOperation {
            if let state = self.getState() {
                return state
            }

            var fetchedState: T?

            let semaphore = DispatchSemaphore(value: 0)

            let subscriber = NSObject()
            self.subscribeSyncState(
                subscriber,
                queue: self.workQueue
            ) { _, newIsSyncing in
                if !newIsSyncing, let state = self.getState() {
                    fetchedState = state
                    self.unsubscribeSyncState(subscriber)

                    semaphore.signal()
                }
            }

            semaphore.wait()

            guard let state = fetchedState else {
                throw ObservableSubscriptionSyncServiceError.unexpectedState
            }

            return state
        }
    }
}
