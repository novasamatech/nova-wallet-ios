import Foundation
import Operation_iOS

struct BittensorApiCacheKey: Hashable {
    let method: String
    let path: String
    let query: [String]
    let bodyDigest: Data?
}

struct BittensorApiRouteKey: Hashable {
    let method: String
    let pathTemplate: String
    let accountDigest: Data?
}

struct BittensorApiGenerationOrder: Comparable {
    let asOf: Date
    let sourceBlockNumber: UInt64

    static func < (lhs: BittensorApiGenerationOrder, rhs: BittensorApiGenerationOrder) -> Bool {
        lhs.asOf == rhs.asOf ? lhs.sourceBlockNumber < rhs.sourceBlockNumber : lhs.asOf < rhs.asOf
    }
}

struct BittensorApiFetchedValue {
    let value: Any
    let requestId: String?
    let cacheDirectives: HTTPCacheDirectives
    let generation: BittensorApiGenerationOrder?
}

struct BittensorApiCacheEntry {
    let value: Any
    let requestId: String?
    let receivedAt: TimeInterval
    let generation: BittensorApiGenerationOrder?
}

struct BittensorApiCacheDelivery {
    let entry: BittensorApiCacheEntry
    let isFromExpiredCache: Bool
}

struct BittensorApiCacheJob {
    let key: BittensorApiCacheKey
    let routeKey: BittensorApiRouteKey
    let fetch: () -> CompoundOperationWrapper<BittensorApiFetchedValue>
}

final class BittensorApiResponseCache {
    typealias Delivery = (Result<BittensorApiCacheDelivery, Error>) -> Void
    typealias FetchOutcome = HTTPCacheFetchOutcome<BittensorApiCacheEntry>

    enum NegativeKey: Hashable {
        case route(method: String, pathTemplate: String)
        case request(BittensorApiCacheKey)
    }

    struct NegativeEntry {
        let error: BittensorApiError
        let expiresAt: TimeInterval
    }

    struct Backoff {
        let attempt: Int
        let until: TimeInterval
        let error: BittensorApiError
    }

    struct Receipt {
        let fetched: BittensorApiFetchedValue
        let receivedAt: TimeInterval
    }

    static let routeNotPublishedLifetime: TimeInterval = 600
    static let datasetUnavailableLifetime: TimeInterval = 60
    static let initialBackoff: TimeInterval = 15
    static let maxBackoff: TimeInterval = 300
    static let maxJitter = 0.2

    private let store: HTTPResponseCacheStore<BittensorApiCacheKey, BittensorApiCacheEntry>
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let timeProvider: () -> TimeInterval
    private let jitterProvider: () -> Double
    private let mutex = NSLock()

    private var negativeEntries: [NegativeKey: NegativeEntry] = [:]
    private var backoffs: [BittensorApiRouteKey: Backoff] = [:]
    private var newestGeneration: BittensorApiGenerationOrder?

    init(
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now,
        jitterProvider: @escaping () -> Double = { Double.random(in: 0 ... 1) }
    ) {
        store = HTTPResponseCacheStore(operationQueue: operationQueue, timeProvider: timeProvider)
        self.operationQueue = operationQueue
        self.logger = logger
        self.timeProvider = timeProvider
        self.jitterProvider = jitterProvider
    }

    func createWrapper(for job: BittensorApiCacheJob) -> CompoundOperationWrapper<BittensorApiCacheDelivery> {
        let waiterId = UUID()

        let operation = AsyncClosureOperation<BittensorApiCacheDelivery>(
            operationClosure: { completion in
                self.request(job, waiterId: waiterId, completion: completion)
            },
            cancelationClosure: { [weak self] in
                self?.store.removeWaiter(waiterId, for: job.key)
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

private extension BittensorApiResponseCache {
    func request(_ job: BittensorApiCacheJob, waiterId: UUID, completion: @escaping Delivery) {
        if let immediate = immediateDelivery(for: job, cached: store.peek(job.key)) {
            completion(immediate)

            return
        }

        store.request(
            job.key,
            waiterId: waiterId,
            fetch: { self.createPolicyWrapper(for: job, reloading: nil) },
            completion: { result in
                completion(result.map { BittensorApiCacheDelivery(entry: $0.value, isFromExpiredCache: $0.isExpired) })
            }
        )
    }

    func immediateDelivery(
        for job: BittensorApiCacheJob,
        cached: HTTPCachePeek<BittensorApiCacheEntry>
    ) -> Result<BittensorApiCacheDelivery, Error>? {
        if case let .fresh(entry, _) = cached {
            return .success(BittensorApiCacheDelivery(entry: entry, isFromExpiredCache: false))
        }

        let now = timeProvider()

        mutex.lock()

        let negative = activeNegativeEntry(for: job, now: now)
        let backoff = backoffs[job.routeKey].flatMap { now < $0.until ? $0 : nil }

        mutex.unlock()

        if let negative {
            return .failure(negative.error)
        }

        if let backoff {
            return cached.value.map { .success(BittensorApiCacheDelivery(entry: $0, isFromExpiredCache: true)) }
                ?? .failure(backoff.error)
        }

        return nil
    }

    func createPolicyWrapper(
        for job: BittensorApiCacheJob,
        reloading previous: Receipt?
    ) -> CompoundOperationWrapper<FetchOutcome> {
        let fetchWrapper = job.fetch()

        let outcomeWrapper: CompoundOperationWrapper<FetchOutcome> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let fetched: BittensorApiFetchedValue

                do {
                    fetched = try fetchWrapper.targetOperation.extractNoCancellableResultData()
                } catch {
                    let outcome = try self.resolveFailure(error, for: job, reloading: previous)

                    return .createWithResult(outcome)
                }

                let receipt = Receipt(fetched: fetched, receivedAt: self.timeProvider())

                return self.createSuccessWrapper(for: job, receipt: receipt, reloading: previous)
            }

        outcomeWrapper.addDependency(wrapper: fetchWrapper)

        return outcomeWrapper.insertingHead(operations: fetchWrapper.allOperations)
    }

    func createSuccessWrapper(
        for job: BittensorApiCacheJob,
        receipt: Receipt,
        reloading previous: Receipt?
    ) -> CompoundOperationWrapper<FetchOutcome> {
        clearFailures(for: job)

        guard previous == nil, isOlderThanNewestGeneration(receipt.fetched.generation) else {
            return .createWithResult(resolve(receipt, for: job))
        }

        return createPolicyWrapper(for: job, reloading: receipt)
    }

    func resolve(_ receipt: Receipt, for job: BittensorApiCacheJob) -> FetchOutcome {
        let fetched = receipt.fetched
        let cached = store.peek(job.key)

        if
            let generation = fetched.generation,
            let cachedEntry = cached.value,
            let cachedGeneration = cachedEntry.generation,
            generation < cachedGeneration {
            return .cached(cachedEntry, isExpired: !cached.isFresh)
        }

        if let generation = fetched.generation {
            let previousNewest = raiseNewestGeneration(to: generation)

            if let previousNewest, previousNewest < generation {
                store.removeAll { $0.generation != nil }
            }
        }

        let entry = BittensorApiCacheEntry(
            value: fetched.value,
            requestId: fetched.requestId,
            receivedAt: receipt.receivedAt,
            generation: fetched.generation
        )

        return .response(entry, fetched.cacheDirectives)
    }

    func resolveFailure(
        _ error: Error,
        for job: BittensorApiCacheJob,
        reloading previous: Receipt?
    ) throws -> FetchOutcome {
        let now = timeProvider()

        mutex.lock()

        let failure = registerFailure(error, for: job, now: now)

        mutex.unlock()

        if let backoffDelay = failure.backoffInterval {
            logger.warning(
                "Bittensor API \(job.routeKey.method) \(job.routeKey.pathTemplate) backs off \(Int(backoffDelay)) s"
            )
        }

        if let previous {
            return resolve(previous, for: job)
        }

        guard failure.fallsBackToCache, let cachedEntry = store.peek(job.key).value else {
            throw error
        }

        return .cached(cachedEntry, isExpired: true)
    }

    func clearFailures(for job: BittensorApiCacheJob) {
        mutex.lock()

        backoffs[job.routeKey] = nil
        negativeKeys(for: job).forEach { negativeEntries[$0] = nil }

        mutex.unlock()
    }

    func registerFailure(
        _ error: Error,
        for job: BittensorApiCacheJob,
        now: TimeInterval
    ) -> (fallsBackToCache: Bool, backoffInterval: TimeInterval?) {
        guard let apiError = error as? BittensorApiError else {
            return (false, nil)
        }

        if let lifetime = negativeLifetime(for: apiError) {
            negativeEntries[negativeKey(for: apiError, job: job)] = NegativeEntry(
                error: apiError,
                expiresAt: now + lifetime
            )

            return (false, nil)
        }

        guard isBackoffTrigger(apiError) else {
            return (false, nil)
        }

        if let current = backoffs[job.routeKey], now < current.until {
            return (true, nil)
        }

        let attempt = (backoffs[job.routeKey]?.attempt ?? 0) + 1
        let interval = backoffInterval(forAttempt: attempt)

        backoffs[job.routeKey] = Backoff(attempt: attempt, until: now + interval, error: apiError)

        return (true, interval)
    }

    func isOlderThanNewestGeneration(_ generation: BittensorApiGenerationOrder?) -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let generation, let newestGeneration else {
            return false
        }

        return generation < newestGeneration
    }

    func raiseNewestGeneration(to generation: BittensorApiGenerationOrder) -> BittensorApiGenerationOrder? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let previousNewest = newestGeneration

        if previousNewest.map({ $0 < generation }) ?? true {
            newestGeneration = generation
        }

        return previousNewest
    }

    func routeNegativeKey(for job: BittensorApiCacheJob) -> NegativeKey {
        .route(method: job.routeKey.method, pathTemplate: job.routeKey.pathTemplate)
    }

    func negativeKeys(for job: BittensorApiCacheJob) -> [NegativeKey] {
        [routeNegativeKey(for: job), .request(job.key)]
    }

    func activeNegativeEntry(for job: BittensorApiCacheJob, now: TimeInterval) -> NegativeEntry? {
        negativeKeys(for: job).compactMap { negativeEntries[$0] }.first { now < $0.expiresAt }
    }

    func negativeKey(for error: BittensorApiError, job: BittensorApiCacheJob) -> NegativeKey {
        guard case .routeNotPublished = error else {
            return .request(job.key)
        }

        return routeNegativeKey(for: job)
    }

    func negativeLifetime(for error: BittensorApiError) -> TimeInterval? {
        switch error {
        case .routeNotPublished:
            return Self.routeNotPublishedLifetime
        case .datasetUnavailable:
            return Self.datasetUnavailableLifetime
        default:
            return nil
        }
    }

    func isBackoffTrigger(_ error: BittensorApiError) -> Bool {
        switch error {
        case .rateLimited, .upstreamUnavailable, .upstreamInvalidResponse, .attestationUnavailable:
            return true
        case let .server(statusCode, _, _):
            return (500 ... 599).contains(statusCode)
        default:
            return false
        }
    }

    func backoffInterval(forAttempt attempt: Int) -> TimeInterval {
        let doublings = min(max(attempt - 1, 0), 5)
        let base = min(Self.initialBackoff * TimeInterval(1 << doublings), Self.maxBackoff)
        let jitter = min(max(jitterProvider(), 0), 1) * Self.maxJitter

        return min(base * (1 + jitter), Self.maxBackoff)
    }
}
