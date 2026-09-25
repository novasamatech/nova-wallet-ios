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
    let timeToLive: TimeInterval
    let generation: BittensorApiGenerationOrder?
}

struct BittensorApiCacheEntry {
    let value: Any
    let requestId: String?
    let receivedAt: TimeInterval
    let timeToLive: TimeInterval
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

    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let timeProvider: () -> TimeInterval
    private let jitterProvider: () -> Double
    private let mutex = NSLock()

    private var entries: [BittensorApiCacheKey: BittensorApiCacheEntry] = [:]
    private var negativeEntries: [NegativeKey: NegativeEntry] = [:]
    private var backoffs: [BittensorApiRouteKey: Backoff] = [:]
    private var inFlight: [BittensorApiCacheKey: [UUID: Delivery]] = [:]

    init(
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now,
        jitterProvider: @escaping () -> Double = { Double.random(in: 0 ... 1) }
    ) {
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
                self?.removeWaiter(waiterId, key: job.key)
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

private extension BittensorApiResponseCache {
    func request(_ job: BittensorApiCacheJob, waiterId: UUID, completion: @escaping Delivery) {
        mutex.lock()

        let now = timeProvider()

        if let immediate = immediateDelivery(for: job, now: now) {
            mutex.unlock()

            completion(immediate)

            return
        }

        let shouldStartFetch = inFlight[job.key] == nil
        inFlight[job.key, default: [:]][waiterId] = completion

        mutex.unlock()

        if shouldStartFetch {
            startFetch(job, reloading: nil)
        }
    }

    func immediateDelivery(
        for job: BittensorApiCacheJob,
        now: TimeInterval
    ) -> Result<BittensorApiCacheDelivery, Error>? {
        let cached = entries[job.key]

        if let cached, isFresh(cached, at: now) {
            return .success(BittensorApiCacheDelivery(entry: cached, isFromExpiredCache: false))
        }

        if let negative = activeNegativeEntry(for: job, now: now) {
            return .failure(negative.error)
        }

        if let backoff = backoffs[job.routeKey], now < backoff.until {
            return cached.map { .success(BittensorApiCacheDelivery(entry: $0, isFromExpiredCache: true)) }
                ?? .failure(backoff.error)
        }

        return nil
    }

    func removeWaiter(_ waiterId: UUID, key: BittensorApiCacheKey) {
        mutex.lock()

        inFlight[key]?[waiterId] = nil

        mutex.unlock()
    }

    func startFetch(_ job: BittensorApiCacheJob, reloading previous: Receipt?) {
        execute(
            wrapper: job.fetch(),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { result in
            self.completeFetch(job, result: result, reloading: previous)
        }
    }

    func completeFetch(
        _ job: BittensorApiCacheJob,
        result: Result<BittensorApiFetchedValue, Error>,
        reloading previous: Receipt?
    ) {
        mutex.lock()

        let now = timeProvider()
        let outcome: Result<BittensorApiCacheDelivery, Error>
        var backoffDelay: TimeInterval?

        switch result {
        case let .success(fetched):
            backoffs[job.routeKey] = nil
            negativeKeys(for: job).forEach { negativeEntries[$0] = nil }

            let receipt = Receipt(fetched: fetched, receivedAt: now)

            if previous == nil, isOlderThanNewestGeneration(fetched.generation) {
                mutex.unlock()

                startFetch(job, reloading: receipt)

                return
            }

            outcome = .success(store(receipt, for: job.key, now: now))
        case let .failure(error):
            let failure = registerFailure(error, for: job, now: now)
            backoffDelay = failure.backoffInterval

            if let previous {
                outcome = .success(store(previous, for: job.key, now: now))
            } else {
                outcome = failure.outcome
            }
        }

        let waiters = inFlight.removeValue(forKey: job.key)?.values.map { $0 } ?? []

        mutex.unlock()

        if let backoffDelay {
            logger.warning(
                "Bittensor API \(job.routeKey.method) \(job.routeKey.pathTemplate) backs off \(Int(backoffDelay)) s"
            )
        }

        waiters.forEach { $0(outcome) }
    }

    func store(
        _ receipt: Receipt,
        for key: BittensorApiCacheKey,
        now: TimeInterval
    ) -> BittensorApiCacheDelivery {
        let fetched = receipt.fetched

        if
            let generation = fetched.generation,
            let cached = entries[key],
            let cachedGeneration = cached.generation,
            generation < cachedGeneration {
            return BittensorApiCacheDelivery(entry: cached, isFromExpiredCache: !isFresh(cached, at: now))
        }

        if
            let generation = fetched.generation,
            let newest = newestCachedGeneration(),
            newest < generation {
            entries = entries.filter { $0.value.generation == nil }
        }

        let entry = BittensorApiCacheEntry(
            value: fetched.value,
            requestId: fetched.requestId,
            receivedAt: receipt.receivedAt,
            timeToLive: fetched.timeToLive,
            generation: fetched.generation
        )

        entries[key] = entry

        return BittensorApiCacheDelivery(entry: entry, isFromExpiredCache: false)
    }

    func registerFailure(
        _ error: Error,
        for job: BittensorApiCacheJob,
        now: TimeInterval
    ) -> (outcome: Result<BittensorApiCacheDelivery, Error>, backoffInterval: TimeInterval?) {
        guard let apiError = error as? BittensorApiError else {
            return (.failure(error), nil)
        }

        if let lifetime = negativeLifetime(for: apiError) {
            negativeEntries[negativeKey(for: apiError, job: job)] = NegativeEntry(
                error: apiError,
                expiresAt: now + lifetime
            )

            return (.failure(apiError), nil)
        }

        guard isBackoffTrigger(apiError) else {
            return (.failure(apiError), nil)
        }

        if let current = backoffs[job.routeKey], now < current.until {
            return (fallback(for: job.key, error: apiError), nil)
        }

        let attempt = (backoffs[job.routeKey]?.attempt ?? 0) + 1
        let interval = backoffInterval(forAttempt: attempt)

        backoffs[job.routeKey] = Backoff(attempt: attempt, until: now + interval, error: apiError)

        return (fallback(for: job.key, error: apiError), interval)
    }

    func fallback(for key: BittensorApiCacheKey, error: BittensorApiError) -> Result<BittensorApiCacheDelivery, Error> {
        guard let cached = entries[key] else {
            return .failure(error)
        }

        return .success(BittensorApiCacheDelivery(entry: cached, isFromExpiredCache: true))
    }

    func isFresh(_ entry: BittensorApiCacheEntry, at now: TimeInterval) -> Bool {
        let age = now - entry.receivedAt

        return age >= 0 && age < entry.timeToLive
    }

    func isOlderThanNewestGeneration(_ generation: BittensorApiGenerationOrder?) -> Bool {
        guard let generation, let newest = newestCachedGeneration() else {
            return false
        }

        return generation < newest
    }

    func newestCachedGeneration() -> BittensorApiGenerationOrder? {
        entries.values.compactMap(\.generation).max()
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
