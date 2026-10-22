import Foundation
import Operation_iOS

struct BittensorApiCacheKey: Hashable {
    let path: String
    let query: [String]
}

struct BittensorApiCacheDrop: Hashable {
    let path: String
    let queryItem: String

    func covers(_ key: BittensorApiCacheKey) -> Bool {
        key.path == path && key.query.contains(queryItem)
    }
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
    let generation: BittensorApiGenerationOrder?
    let directives: HTTPCacheDirectives
}

struct BittensorApiCacheEntry {
    let value: Any
    let requestId: String?
    let generation: BittensorApiGenerationOrder?
    let freshUntil: TimeInterval
}

struct BittensorApiCacheJob {
    let key: BittensorApiCacheKey
    let admit: () -> CompoundOperationWrapper<BittensorApiAdmission>
    let fetch: (BittensorApiAdmission) -> CompoundOperationWrapper<BittensorApiFetchedValue>
}

final class BittensorApiResponseCache {
    private struct ScopedKey: Hashable {
        let scope: BittensorApiCacheScope
        let request: BittensorApiCacheKey
    }

    private let operationQueue: OperationQueue
    private let timeProvider: () -> TimeInterval
    private let mutex = NSLock()
    private var entries: [ScopedKey: BittensorApiCacheEntry] = [:]
    private var activeScope: BittensorApiCacheScope?
    private var newestGeneration: BittensorApiGenerationOrder?
    private var drops: [BittensorApiCacheDrop: TimeInterval] = [:]

    init(operationQueue: OperationQueue, timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now) {
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider
    }

    func drop(_ drop: BittensorApiCacheDrop) {
        mutex.lock()
        drops[drop] = timeProvider()
        entries = entries.filter { !drop.covers($0.key.request) }
        mutex.unlock()
    }

    func peek(_ key: BittensorApiCacheKey) -> HTTPCachePeek<BittensorApiCacheEntry> {
        mutex.lock()
        defer { mutex.unlock() }
        guard let scope = activeScope, let entry = entries[ScopedKey(scope: scope, request: key)] else { return .miss }
        return timeProvider() < entry.freshUntil ? .fresh(entry) : .expired(entry)
    }

    func createWrapper(for job: BittensorApiCacheJob) -> CompoundOperationWrapper<BittensorApiCacheEntry> {
        if case let .fresh(entry) = peek(job.key) {
            return .createWithResult(entry)
        }
        let admission = job.admit()
        let start = ClosureOperation<TimeInterval> {
            let admitted = try admission.targetOperation.extractNoCancellableResultData()
            self.activate(admitted.scope)
            return self.timeProvider()
        }
        start.addDependency(admission.targetOperation)
        let fetch = OperationCombiningService<BittensorApiFetchedValue>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            _ = try start.extractNoCancellableResultData()
            return try job.fetch(admission.targetOperation.extractNoCancellableResultData())
        }
        fetch.addDependency(operations: [start])
        let store = ClosureOperation<BittensorApiCacheEntry> {
            let scope = try admission.targetOperation.extractNoCancellableResultData().scope
            return try self.store(
                key: ScopedKey(scope: scope, request: job.key),
                startedAt: start.extractNoCancellableResultData()
            ) { try fetch.targetOperation.extractNoCancellableResultData() }
        }
        store.addDependency(fetch.targetOperation)
        return fetch.insertingHead(operations: admission.allOperations + [start]).insertingTail(operation: store)
    }
}

private extension BittensorApiResponseCache {
    func activate(_ scope: BittensorApiCacheScope) {
        mutex.lock()
        defer { mutex.unlock() }
        guard activeScope != scope else { return }
        activeScope = scope
        entries.removeAll()
        newestGeneration = nil
        drops.removeAll()
    }

    private func store(
        key: ScopedKey,
        startedAt: TimeInterval,
        fetched: () throws -> BittensorApiFetchedValue
    ) throws -> BittensorApiCacheEntry {
        mutex.lock()
        defer { mutex.unlock() }
        guard activeScope == key.scope else {
            throw BittensorApiError.unavailable(code: nil, requestId: nil)
        }
        let fetched = try fetched()
        if let generation = fetched.generation, let newestGeneration, generation < newestGeneration {
            throw BittensorApiError.generationStale
        }
        if let generation = fetched.generation {
            if newestGeneration.map({ $0 < generation }) ?? false {
                entries = entries.filter { $0.value.generation == nil }
            }
            newestGeneration = generation
        }
        let lifetime: TimeInterval?
        switch fetched.directives {
        case let .reusable(seconds):
            lifetime = seconds
        case .notStorable:
            lifetime = nil
        }
        let entry = BittensorApiCacheEntry(
            value: fetched.value, requestId: fetched.requestId, generation: fetched.generation,
            freshUntil: startedAt + (lifetime ?? 0)
        )
        if lifetime == nil {
            entries[key] = nil
        } else if !drops.contains(where: { $0.key.covers(key.request) && startedAt < $0.value }) {
            entries[key] = entry
        }
        return entry
    }
}
