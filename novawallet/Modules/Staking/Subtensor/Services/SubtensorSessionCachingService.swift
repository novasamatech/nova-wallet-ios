import Foundation
import Operation_iOS

class SubtensorSessionCachingService<Model> {
    private struct CacheEntry {
        let model: Model
        let updatedAt: Date
    }

    let operationQueue: OperationQueue
    let cacheTTL: TimeInterval
    let logger: LoggerProtocol

    let mutex = NSLock()

    private let callStore = CancellableCallStore()

    private var cacheEntry: CacheEntry?
    private var pendingDeliveries: [(queue: DispatchQueue, closure: (Result<Model, Error>) -> Void)] = []

    init(
        operationQueue: OperationQueue,
        cacheTTL: TimeInterval = TimeInterval(15).secondsFromMinutes,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.operationQueue = operationQueue
        self.cacheTTL = cacheTTL
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

        if !forcingRefresh, let model = freshCachedModel() {
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
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return freshCachedModel()
    }
}

private extension SubtensorSessionCachingService {
    func freshCachedModel() -> Model? {
        guard let cacheEntry, Date().timeIntervalSince(cacheEntry.updatedAt) < cacheTTL else {
            return nil
        }

        return cacheEntry.model
    }

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
            cacheEntry = CacheEntry(model: model, updatedAt: Date())
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
