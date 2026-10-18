import Foundation
import Operation_iOS

class SubtensorSessionCachingService<Model> {
    let operationQueue: OperationQueue
    let cache: SubtensorSessionCache<Model>
    let logger: LoggerProtocol

    let mutex = NSLock()

    private let callStore = CancellableCallStore()

    private var pendingDeliveries: [(queue: DispatchQueue, closure: (Result<Model, Error>) -> Void)] = []

    init(
        operationQueue: OperationQueue,
        cache: SubtensorSessionCache<Model>,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.operationQueue = operationQueue
        self.cache = cache
        self.logger = logger
    }

    deinit {
        callStore.cancel()
    }

    func createFetchWrapper() -> CompoundOperationWrapper<Model> {
        fatalError("Must be overriden by subsclass")
    }

    func fetch(
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<Model, Error>) -> Void
    ) {
        fetch(forcingRefresh: false, runningCompletionIn: queue, completion: completion)
    }

    func fetch(
        forcingRefresh: Bool,
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<Model, Error>) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if !forcingRefresh, let model = cache.freshModel() {
            queue.async {
                completion(.success(model))
            }

            return
        }

        pendingDeliveries.append((queue, completion))

        guard forcingRefresh || !callStore.hasCall else {
            return
        }

        callStore.cancel()

        performFetch()
    }

    func cachedModel() -> Model? {
        cache.freshModel()
    }
}

private extension SubtensorSessionCachingService {
    func performFetch() {
        let wrapper = createFetchWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: nil,
            mutex: mutex
        ) { [weak self] result in
            self?.handleFetchResult(result)
        }
    }

    func handleFetchResult(_ result: Result<Model, Error>) {
        if case let .success(model) = result {
            cache.store(model)
        }

        if case let .failure(error) = result {
            logger.error("Fetch error: \(error)")
        }

        let deliveries = pendingDeliveries
        pendingDeliveries = []

        deliveries.forEach { delivery in
            delivery.queue.async {
                delivery.closure(result)
            }
        }
    }
}
