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
    let newestGenerationWhenAccepted: BittensorApiGenerationOrder?
}

struct BittensorApiCacheDelivery {
    let entry: BittensorApiCacheEntry
    let isFromExpiredCache: Bool
}

struct BittensorApiCacheJob {
    let key: BittensorApiCacheKey
    let routeKey: BittensorApiRouteKey
    let currentInvalidationRevision: () -> UInt64
    let admit: () -> CompoundOperationWrapper<BittensorApiAdmission>
    let fetch: (BittensorApiAdmission) -> CompoundOperationWrapper<BittensorApiFetchedValue>
}

final class BittensorApiResponseCache {
    typealias Delivery = (Result<BittensorApiCacheDelivery, Error>) -> Void

    private struct ScopedKey: Hashable {
        let scope: BittensorApiCacheScope
        let request: BittensorApiCacheKey
    }

    private enum NegativeKey: Hashable {
        case route(BittensorApiCacheScope, String, String)
        case request(ScopedKey)
    }

    private struct NegativeEntry {
        let error: BittensorApiError
        let expiresAt: TimeInterval
    }

    private struct Flight {
        let id: UUID
        var waiters: [UUID: Delivery]
    }

    static let routeNotPublishedLifetime: TimeInterval = 600
    static let datasetUnavailableLifetime: TimeInterval = 60

    private let operationQueue: OperationQueue
    private let timeProvider: () -> TimeInterval
    private let mutex = NSLock()
    private var entries: [ScopedKey: BittensorApiCacheEntry] = [:]
    private var flights: [ScopedKey: Flight] = [:]
    private var negatives: [NegativeKey: NegativeEntry] = [:]
    private var activeScope: BittensorApiCacheScope?
    private var minimumInvalidationRevision: UInt64 = 0
    private var newestGeneration: BittensorApiGenerationOrder?

    init(
        operationQueue: OperationQueue,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now
    ) {
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider
    }

    func invalidate(before revision: UInt64) {
        mutex.lock()
        invalidateLocked(before: revision)
        mutex.unlock()
    }

    func peek(_ key: BittensorApiCacheKey, invalidationRevision: UInt64) -> HTTPCachePeek<BittensorApiCacheEntry> {
        mutex.lock()
        defer { mutex.unlock() }
        invalidateLocked(before: invalidationRevision)
        guard let scope = activeScope, let entry = entries[ScopedKey(scope: scope, request: key)] else { return .miss }
        return .expired(entry)
    }

    func createWrapper(for job: BittensorApiCacheJob) -> CompoundOperationWrapper<BittensorApiCacheDelivery> {
        let admission = job.admit()
        let waiterID = UUID()
        let state = WaiterState()
        let operation = AsyncClosureOperation<BittensorApiCacheDelivery>(operationClosure: { completion in
            do {
                let admitted = try admission.targetOperation.extractNoCancellableResultData()
                self.request(job, admission: admitted, waiterID: waiterID, state: state, completion: completion)
            } catch { completion(.failure(error)) }
        }, cancelationClosure: { [weak self] in
            state.cancel()
            self?.removeWaiter(waiterID)
        })
        operation.addDependency(admission.targetOperation)
        return admission.insertingTail(operation: operation)
    }
}

private extension BittensorApiResponseCache {
    func invalidateLocked(before revision: UInt64) {
        guard revision > minimumInvalidationRevision else { return }
        minimumInvalidationRevision = revision
        activeScope = nil
        entries.removeAll()
        negatives.removeAll()
        newestGeneration = nil
    }

    final class WaiterState {
        private let lock = NSLock()
        private var cancelled = false
        func cancel() { lock.lock(); cancelled = true; lock.unlock() }
        var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    }

    func request(
        _ job: BittensorApiCacheJob,
        admission: BittensorApiAdmission,
        waiterID: UUID,
        state: WaiterState,
        completion: @escaping Delivery
    ) {
        let scope = admission.scope
        let key = ScopedKey(scope: scope, request: job.key)
        let currentRevision = job.currentInvalidationRevision()
        mutex.lock()
        guard !state.isCancelled else { mutex.unlock(); return }
        invalidateLocked(before: max(currentRevision, scope.invalidationRevision))
        guard scope.invalidationRevision >= minimumInvalidationRevision else {
            mutex.unlock()
            completion(.failure(BittensorApiError.attestationUnavailable(requestId: nil)))
            return
        }
        if activeScope != scope {
            activeScope = scope
            entries.removeAll()
            negatives.removeAll()
            newestGeneration = nil
        }
        let negativeKeys: [NegativeKey] = [.route(scope, job.routeKey.method, job.routeKey.pathTemplate), .request(key)]
        if let negative = negativeKeys.compactMap({ negatives[$0] }).first(where: { timeProvider() < $0.expiresAt }) {
            mutex.unlock()
            completion(.failure(negative.error))
            return
        }
        if flights[key] != nil {
            flights[key]?.waiters[waiterID] = completion
            mutex.unlock()
            return
        }
        let flightID = UUID()
        flights[key] = Flight(id: flightID, waiters: [waiterID: completion])
        mutex.unlock()
        execute(wrapper: job.fetch(admission), inOperationQueue: operationQueue, runningCallbackIn: nil) { result in
            self.complete(job, key: key, flightID: flightID, result: result)
        }
    }

    func removeWaiter(_ waiterID: UUID) {
        mutex.lock()
        for key in Array(flights.keys) { flights[key]?.waiters[waiterID] = nil }
        mutex.unlock()
    }

    private func complete(
        _ job: BittensorApiCacheJob,
        key: ScopedKey,
        flightID: UUID,
        result: Result<BittensorApiFetchedValue, Error>
    ) {
        let currentRevision = job.currentInvalidationRevision()
        mutex.lock()
        invalidateLocked(before: currentRevision)
        guard let flight = flights[key], flight.id == flightID else { mutex.unlock(); return }
        flights[key] = nil
        let delivery: Result<BittensorApiCacheDelivery, Error>
        if activeScope != key.scope {
            delivery = .failure(BittensorApiError.attestationUnavailable(requestId: nil))
        } else {
            delivery = result.flatMap { fetched in
                if let generation = fetched.generation, let newestGeneration, generation < newestGeneration {
                    return .failure(BittensorApiError.generationStale)
                }
                if let generation = fetched.generation {
                    if newestGeneration.map({ $0 < generation }) ?? false {
                        entries = entries.filter { $0.value.generation == nil }
                    }
                    newestGeneration = generation
                }
                let entry = BittensorApiCacheEntry(
                    value: fetched.value, requestId: fetched.requestId, receivedAt: timeProvider(),
                    generation: fetched.generation, newestGenerationWhenAccepted: newestGeneration
                )
                entries[key] = entry
                return .success(BittensorApiCacheDelivery(entry: entry, isFromExpiredCache: false))
            }
            if case let .failure(error as BittensorApiError) = delivery {
                switch error {
                case .routeNotPublished:
                    negatives[.route(key.scope, job.routeKey.method, job.routeKey.pathTemplate)] = NegativeEntry(
                        error: error, expiresAt: timeProvider() + Self.routeNotPublishedLifetime
                    )
                case .datasetUnavailable:
                    negatives[.request(key)] = NegativeEntry(
                        error: error, expiresAt: timeProvider() + Self.datasetUnavailableLifetime
                    )
                default: break
                }
            }
        }
        mutex.unlock()
        flight.waiters.values.forEach { $0(delivery) }
    }
}
